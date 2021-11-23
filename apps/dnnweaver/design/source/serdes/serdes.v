`include "common.vh"
module serdes #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_COUNT        = 10,
  parameter integer OUT_COUNT       = 10,
  parameter integer OP_WIDTH        = 16,
  parameter integer IN_WIDTH        = IN_COUNT * OP_WIDTH,
  parameter integer OUT_WIDTH       = OUT_COUNT * OP_WIDTH,
  parameter integer COUNT_W         = `C_LOG_2(IN_COUNT+1)
)
(
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire  [ COUNT_W              -1 : 0 ]        count,
  input  wire                                         s_write_flush,
  input  wire                                         s_write_req,
  output wire                                         s_write_ready,
  input  wire  [ IN_WIDTH             -1 : 0 ]        s_write_data,
  output wire                                         m_write_req,
  input  wire                                         m_write_ready,
  output wire  [ OUT_WIDTH            -1 : 0 ]        m_write_data
);

wire serdes_fifo_push;
wire serdes_fifo_full;
wire [IN_WIDTH-1:0] serdes_fifo_in;

wire serdes_fifo_pop;
wire serdes_fifo_empty;
wire [IN_WIDTH-1:0] serdes_fifo_out;

wire cfg_fifo_push;
wire cfg_fifo_full;
wire [COUNT_W-1:0] cfg_fifo_in;

wire cfg_fifo_pop;
wire cfg_fifo_empty;
wire [COUNT_W-1:0] cfg_fifo_out;

assign serdes_fifo_push = s_write_req;
assign s_write_ready = !serdes_fifo_full;
assign serdes_fifo_in = s_write_data;

assign cfg_fifo_push = s_write_req;
assign cfg_fifo_in = count;

assign serdes_fifo_pop = (state == 0) ? !serdes_fifo_empty : serdes_count == serdes_max;
assign cfg_fifo_pop = serdes_fifo_pop;

reg [1:0] state;
reg [1:0] next_state;

reg flush_sticky;
always @(posedge clk)
  if (reset)
    flush_sticky <= 1'b0;
  else if (s_write_flush)
    flush_sticky <= 1'b1;
  else if (state == 0)
    flush_sticky <= 1'b0;

wire flush;
assign flush = flush_sticky || s_write_flush;

always @(*)
begin
  next_state = state;
  case (state)
    0: begin
      if (!serdes_fifo_empty)
        next_state = 1;
    end
    1:begin
      if ((serdes_count == serdes_max) && serdes_fifo_empty && flush)
        next_state = 2;
      else if ((serdes_count == serdes_max || serdes_max == IN_COUNT) && serdes_fifo_empty)
        next_state = 0;
    end
    2:begin
      if (m_write_req)
        next_state = 0;
    end
  endcase
end

always @(posedge clk)
  if (reset)
    state <= 0;
  else
    state <= next_state;









fifo#(
  .DATA_WIDTH               ( IN_WIDTH                 ),
  .ADDR_WIDTH               ( 3                        )
) data_fifo (
  .clk                      ( clk                      ),  //input
  .reset                    ( reset                    ),  //input
  .push                     ( serdes_fifo_push         ),  //input
  .pop                      ( serdes_fifo_pop          ),  //input
  .data_in                  ( serdes_fifo_in           ),  //input
  .data_out                 ( serdes_fifo_out          ),  //output
  .full                     ( serdes_fifo_full         ),  //output
  .empty                    ( serdes_fifo_empty        ),  //output
  .fifo_count               (                          )   //output
);

fifo#(
  .DATA_WIDTH               ( COUNT_W                  ),
  .ADDR_WIDTH               ( 5                        )
) cfg_fifo (
  .clk                      ( clk                      ),  //input
  .reset                    ( reset                    ),  //input
  .push                     ( cfg_fifo_push            ),  //input
  .pop                      ( cfg_fifo_pop             ),  //input
  .data_in                  ( cfg_fifo_in              ),  //input
  .data_out                 ( cfg_fifo_out             ),  //output
  .full                     ( cfg_fifo_full            ),  //output
  .empty                    ( cfg_fifo_empty           ),  //output
  .fifo_count               (                          )   //output
);

reg [COUNT_W-1:0] shift_count;

always @(posedge clk)
begin
  if (reset)
    shift_count <= IN_COUNT;
  else if (s_write_req)
    shift_count <= count-1;
end

wire [COUNT_W-1:0] serdes_default;
wire [COUNT_W-1:0] serdes_min;
wire [COUNT_W-1:0] serdes_max;
wire [COUNT_W-1:0] serdes_count;

wire serdes_inc;
wire next_ser_data;
wire serdes_clear;

assign serdes_min = 'b0;
assign serdes_default = 'b0;
assign serdes_max = cfg_fifo_out;
assign serdes_inc = (state == 1);
assign serdes_clear = (state == 0);

counter #(
  .COUNT_WIDTH              ( COUNT_W                  )
)
serializer_counter (
  .CLK                      ( clk                      ),  //input
  .RESET                    ( reset                    ),  //input
  .CLEAR                    ( serdes_clear             ),  //input
  .DEFAULT                  ( serdes_default           ),  //input
  .INC                      ( serdes_inc               ),  //input
  .DEC                      ( 1'b0                     ),  //input
  .MIN_COUNT                ( serdes_min               ),  //input
  .MAX_COUNT                ( serdes_max               ),  //input
  .OVERFLOW                 ( next_ser_data            ),  //output
  .UNDERFLOW                (                          ),  //output
  .COUNT                    ( serdes_count             )   //output
);

reg [IN_WIDTH-1:0] serializer_data;
reg [OUT_WIDTH-1:0] deserializer_data;

reg serializer_pop;
//reg serializer_shift;
always @(posedge clk)
  serializer_pop <= (state != 2) && !serdes_fifo_empty && serdes_fifo_pop;

//always @(posedge clk)
  //serializer_shift <= (state == 1) && serdes_count != 0;

wire serializer_shift = (state == 1) && serdes_count != serdes_max;
always @(posedge clk)
begin
  if (reset)
    serializer_data <= 0;
  else if (serializer_pop)
    serializer_data <= serdes_fifo_out;
  else if (serializer_shift)
    serializer_data <= serializer_data >> OP_WIDTH;
end

wire [OP_WIDTH-1:0] serial_data;
assign serial_data = serializer_data[OP_WIDTH-1:0];

reg serial_data_v;
wire sipo_data_v;
always @(posedge clk)
  serial_data_v <= (serializer_shift) && (serdes_max != IN_COUNT);

assign sipo_data_v = (serial_data_v || (state == 2 && !m_write_req));

reg [COUNT_W-1:0] sipo_count;

always @(posedge clk)
  if (reset)
    sipo_count <= 0;
  else if (m_write_req)
    sipo_count <= 0;
  else if (serial_data_v)
    sipo_count <= sipo_count + 1;

wire [OP_WIDTH-1:0] sipo_data_in;
wire [OUT_WIDTH-1:0] sipo_data_out;
wire sipo_data_out_v;
assign sipo_data_in = serial_data_v ? serial_data : 0;

sipo #(
  // INPUT PARAMETERS
  .DATA_IN_WIDTH            ( OP_WIDTH                 ),
  .DATA_OUT_WIDTH           ( OUT_WIDTH                )
) sipo_output (
    // PORTS
  .clk                      ( clk                      ),
  .reset                    ( reset                    ),
  .enable                   ( sipo_data_v              ),
  .data_in                  ( sipo_data_in             ),
  .ready                    (                          ),
  .data_out                 ( sipo_data_out            ),
  .out_valid                ( sipo_data_out_v          )
);

assign m_write_data = serdes_max == IN_COUNT ? serdes_fifo_out : sipo_data_out;
assign m_write_req = serdes_max == IN_COUNT ? serializer_pop: sipo_data_out_v;

endmodule
