`include "common.vh"
module read_info #(
  parameter integer NUM_PU = 1,
  parameter integer PU_LOOP_W = 20,
  parameter integer D_TYPE_W = 2,
  parameter integer RD_SIZE_W = 20
)
(
  input wire clk,
  input wire reset,
  output reg stream_pu_push,
  output reg [PU_ID_W-1:0] stream_pu_id,
  output reg stream_push,
  output reg buffer_push,
  input wire stream_pu_full,
  input wire stream_full,
  input wire buffer_full,
  output wire inbuf_pop,
  output wire read_info_full,
  input wire inbuf_empty,
  input wire rd_req,
  input wire [RD_SIZE_W-1:0]rd_req_size,
  input wire [PU_ID_W-1:0]rd_req_pu_id,
  input wire [D_TYPE_W-1:0]rd_req_d_type,
  output wire [PU_ID_W-1:0] pu_id,
  output wire [D_TYPE_W-1:0] d_type
);

localparam integer PU_ID_W = `C_LOG_2(NUM_PU)+1;
localparam integer RD_INFO_W = PU_ID_W + D_TYPE_W + RD_SIZE_W;

wire read_info_push;
wire read_info_pop;
wire [RD_INFO_W-1:0] read_info_data_in;
wire [RD_INFO_W-1:0] read_info_data_out;
wire read_info_empty;

wire [RD_SIZE_W-1:0] rvalid_default;
wire rvalid_inc;
wire [RD_SIZE_W-1:0] rvalid_min;
wire [RD_SIZE_W-1:0] rvalid_max;
wire next_read;
wire [RD_SIZE_W-1:0] rvalid_count;

assign read_info_push = rd_req;
assign read_info_data_in = {rd_req_pu_id, rd_req_d_type, rd_req_size};

assign read_info_pop = state == 0 ? !read_info_empty : rvalid_count == rvalid_max;
assign {pu_id, d_type, rvalid_max} = read_info_data_out;

  fifo #(
    .DATA_WIDTH               ( RD_INFO_W                ),
    .ADDR_WIDTH               ( 5                        )
  ) read_info_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( read_info_push           ),  //input
    .pop                      ( read_info_pop            ),  //input
    .data_in                  ( read_info_data_in        ),  //input
    .data_out                 ( read_info_data_out       ),  //output
    .full                     ( read_info_full           ),  //output
    .empty                    ( read_info_empty          ),  //output
    .fifo_count               (                          )   //output
  );

  assign rvalid_default = 0;
  assign rvalid_min = 0;
  assign inbuf_pop = rvalid_inc && !(rvalid_count == rvalid_max);
  wire output_fifo_full;
  assign output_fifo_full =
    (d_type == 0 && stream_full ||
      d_type == 1 && buffer_full ||
      d_type == 2 && stream_pu_full);
  assign rvalid_inc = ((!inbuf_empty && !output_fifo_full) || next_read) && state == 1;
  counter #(
    .COUNT_WIDTH              ( RD_SIZE_W                )
  )
  rvalid_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( rvalid_default           ),  //input
    .INC                      ( rvalid_inc               ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( rvalid_min               ),  //input
    .MAX_COUNT                ( rvalid_max               ),  //input
    .OVERFLOW                 ( next_read                ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( rvalid_count             )   //output
  );
// ==================================================================

reg state;
reg next_state;

always @(*)
begin
  next_state = state;
  case (state)
    0: begin
      if (!read_info_empty)
        next_state = 1;
    end
    1:begin
      if (rvalid_count == rvalid_max && read_info_empty)
        next_state = 0;
    end
  endcase
end

always @(posedge clk)
  if (reset)
    state <= 0;
  else
    state <= next_state;


reg _buffer_push;
reg _stream_push;
reg _stream_pu_push;
reg [PU_ID_W-1:0] _stream_pu_id;

always @(posedge clk)
begin
  if (reset) begin
    _buffer_push <= 1'b0;
    _stream_push <= 1'b0;
    _stream_pu_push <= 1'b0;
    _stream_pu_id <= 'b0;
  end else begin
    _buffer_push <= inbuf_pop && (d_type == 1);
    _stream_push <= inbuf_pop && (d_type == 0);
    _stream_pu_push <= inbuf_pop && (d_type == 2);
    _stream_pu_id <= pu_id;
  end
end

always @(posedge clk)
begin
  if (reset) begin
    buffer_push <= 1'b0;
    stream_push <= 1'b0;
    stream_pu_push <= 1'b0;
    stream_pu_id <= 'b0;
  end else begin
    buffer_push <= _buffer_push;
    stream_push <= _stream_push;
    stream_pu_push <= _stream_pu_push;
    stream_pu_id <= _stream_pu_id;
  end
end


endmodule
