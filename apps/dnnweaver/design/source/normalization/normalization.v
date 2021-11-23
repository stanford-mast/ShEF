`timescale 1ns/1ps
module normalization
#( // INPUT PARAMETERS
  parameter integer OP_WIDTH      = 16,
  parameter integer NUM_PE        = 4
)( // PORTS
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         enable,
  input  wire  [ DATA_IN_WIDTH        -1 : 0 ]        square_sum,
  input  wire  [ DATA_IN_WIDTH        -1 : 0 ]        lrn_center,
  output wire  [ DATA_OUT_WIDTH       -1 : 0 ]        norm_out,
  output wire                                         out_valid
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer DATA_IN_WIDTH  = OP_WIDTH * NUM_PE;
  localparam integer DATA_OUT_WIDTH = OP_WIDTH * NUM_PE;
  localparam integer SQSUM_FIFO_WIDTH = DATA_IN_WIDTH;
  localparam integer LRN_CENTER_FIFO_WIDTH = DATA_IN_WIDTH;

// ******************************************************************
// WIRES
// ******************************************************************
  reg [1:0] state;
  reg [1:0] next_state;

  wire done;
  reg [NUM_PE-1:0] enable_shifter;

  wire lrn_center_valid;

  wire lrn_center_fifo_push;
  wire lrn_center_fifo_pop;
  wire lrn_center_fifo_empty;
  wire lrn_center_fifo_full;
  wire [LRN_CENTER_FIFO_WIDTH-1:0] lrn_center_fifo_out;
  wire [LRN_CENTER_FIFO_WIDTH-1:0] lrn_center_fifo_in;

  wire [OP_WIDTH-1:0] lrn_center_ser;


  wire sqsum_valid;

  wire sqsum_fifo_push;
  wire sqsum_fifo_pop;
  wire sqsum_fifo_empty;
  wire sqsum_fifo_full;
  wire [SQSUM_FIFO_WIDTH-1:0] sqsum_fifo_out;
  wire [SQSUM_FIFO_WIDTH-1:0] sqsum_fifo_in;

  wire [OP_WIDTH-1:0] sqsum_ser;
  reg sqsum_ser_valid;

  wire [OP_WIDTH-1:0] lrn_weight;
  reg lrn_weight_valid;

  wire [OP_WIDTH-1:0] mult_out;
  wire mult_valid;

// ******************************************************************
// Logic
// ******************************************************************
  assign sqsum_fifo_push = enable;
  assign sqsum_fifo_pop = (state == 1);
  assign sqsum_fifo_in = square_sum;

  assign lrn_center_fifo_push = enable;
  assign lrn_center_fifo_in = lrn_center;
  assign lrn_center_fifo_pop = sqsum_valid;

  register #(1, 1)
  u_sqsum_vld (clk, reset, sqsum_fifo_pop, sqsum_valid);

  register #(1, 1)
  u_lrn_vld (clk, reset, sqsum_valid, lrn_center_valid);

  always @(posedge clk)
    sqsum_ser_valid <= state == 2;

  always @(posedge clk)
    if (reset)
      lrn_weight_valid <= 0;
    else
      lrn_weight_valid <= sqsum_ser_valid;

// ******************************************************************
// INSTANTIATIONS
// ******************************************************************

  fifo#(
    .DATA_WIDTH               ( SQSUM_FIFO_WIDTH         ),
    .ADDR_WIDTH               ( 2                        ),
    .TYPE                     ( "MLAB"                   )
  ) sqsum_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( sqsum_fifo_push          ),  //input
    .pop                      ( sqsum_fifo_pop           ),  //input
    .data_in                  ( sqsum_fifo_in            ),  //input
    .data_out                 ( sqsum_fifo_out           ),  //output
    .full                     (                          ),  //output
    .empty                    ( sqsum_fifo_empty         ),  //output
    .fifo_count               (                          )   //output
  );

  fifo#(
    .DATA_WIDTH               ( LRN_CENTER_FIFO_WIDTH    ),
    .ADDR_WIDTH               ( 2                        ),
    .TYPE                     ( "MLAB"                   )
  ) lrn_center_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( lrn_center_fifo_push     ),  //input
    .pop                      ( lrn_center_fifo_pop      ),  //input
    .data_in                  ( lrn_center_fifo_in       ),  //input
    .data_out                 ( lrn_center_fifo_out      ),  //output
    .full                     (                          ),  //output
    .empty                    ( lrn_center_fifo_empty    ),  //output
    .fifo_count               (                          )   //output
  );


  piso_norm
     #( // INPUT PARAMETERS
    .DATA_IN_WIDTH            ( DATA_IN_WIDTH            ),
    .DATA_OUT_WIDTH           ( OP_WIDTH                 )
  ) sqsum_serializer
  (  // PORTS
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .ENABLE                   ( sqsum_valid              ),
    .DATA_IN                  ( sqsum_fifo_out           ),
    .READY                    (                          ),
    .DATA_OUT                 ( sqsum_ser                ),
    .OUT_VALID                (                          )
  );

  ROM #(
    .DATA_WIDTH               ( OP_WIDTH                 ),
    .ADDR_WIDTH               ( 6                        )
  ) u_lrn_lut (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .address                  ( sqsum_ser[5:0]           ),
    .enable                   ( sqsum_ser_valid          ),
    .data_out                 ( lrn_weight               )
  );

  piso_norm
     #( // INPUT PARAMETERS
    .DATA_IN_WIDTH            ( DATA_IN_WIDTH            ),
    .DATA_OUT_WIDTH           ( OP_WIDTH                 )
  ) lrn_center_serializer
  (  // PORTS
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .ENABLE                   ( lrn_center_valid         ),
    .DATA_IN                  ( lrn_center_fifo_out      ),
    .READY                    (                          ),
    .DATA_OUT                 ( lrn_center_ser           ),
    .OUT_VALID                (                          )
  );


  multiplier #(
    .WIDTH_0                  ( OP_WIDTH                 ),
    .WIDTH_1                  ( OP_WIDTH                 ),
    .WIDTH_OUT                ( OP_WIDTH                 )
  ) norm_mult (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .ENABLE                   ( lrn_weight_valid         ),
    .MUL_0                    ( lrn_center_ser           ),
    .MUL_1                    ( lrn_weight               ),
    .OUT                      ( mult_out                 ),
    .OUT_VALID                ( mult_valid               )
  );


  sipo #(
    .DATA_IN_WIDTH            ( OP_WIDTH                 ),
    .DATA_OUT_WIDTH           ( DATA_OUT_WIDTH           )
  ) sipo_norm (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .enable                   ( mult_valid               ),
    .data_in                  ( mult_out                 ),
    .ready                    (                          ),
    .data_out                 ( norm_out                 ),
    .out_valid                ( out_valid                )
  );

// ******************************************************************
  always @(*)
  begin
    next_state = state;
    case (state)
      0: begin
        if (!sqsum_fifo_empty)
          next_state = 1;
      end
      1:begin
        next_state = 2;
      end
      2:begin
        if (done && !sqsum_fifo_empty)
          next_state = 1;
        else if (done)
          next_state = 0;
      end
    endcase
  end

  always @(posedge clk)
  begin
    if (reset)
      state <= 'b0;
    else
      state <= next_state;
  end

  always @(posedge clk)
  begin
    if (reset)
      enable_shifter <= 'b0;
    else if (state == 1)
      enable_shifter <= 1'b1;
    else if (state == 2)
      enable_shifter <= enable_shifter << 1;
  end

  assign done = enable_shifter[NUM_PE-1];

endmodule
