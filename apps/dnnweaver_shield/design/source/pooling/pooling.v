`timescale 1ns/1ps
module pooling
#(  // INPUT PARAMETERS
  parameter integer OP_WIDTH            = 16,
  parameter integer NUM_COMPARATOR        = 1,
  parameter integer NUM_PE                = 4,
  parameter integer COUNTER_WIDTH         = 4,
  parameter integer KERNEL_SIZE_WIDTH     = 4,
  parameter integer KERNEL_STRIDE_WIDTH   = 2,
  parameter integer ROW_COUNT_WIDTH       = 6,
  parameter integer CTRL_WIDTH            = 7,
  parameter integer CFG_WIDTH             = 3,
  parameter integer STRIDE_WIDTH          = 2,
  parameter integer KERNEL_SIZE_W         = 2
)
(   // PORTS
  input  wire                             clk,
  input  wire                             reset,
  output wire                             ready,
  input  wire [ CTRL_WIDTH      -1 : 0]   ctrl,
  input  wire [ CFG_WIDTH       -1 : 0]   cfg,
  input  wire [ DATA_IN_WIDTH   -1 : 0]   write_data,
  input  wire                             write_req,
  output wire                             write_ready,
  output wire [ DATA_IN_WIDTH   -1 : 0]   read_data,
  output wire                             read_req,
  input  wire                             read_ready
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer DATA_IN_WIDTH  = OP_WIDTH * NUM_PE;
  localparam integer DATA_OUT_WIDTH = OP_WIDTH * NUM_PE;
// ******************************************************************
// Wires and Regs
// ******************************************************************
  wire                                        _pool_valid;
  reg                                         pool_valid;

  wire                                        row_fifo_mux_sel;
  reg  [ OP_WIDTH             -1 : 0 ]        row_fifo_in;
  wire [ OP_WIDTH             -1 : 0 ]        _row_fifo_in;
  wire [ OP_WIDTH             -1 : 0 ]        row_fifo_out;
  wire signed [ OP_WIDTH             -1 : 0 ]        row_fifo_out_dd;
  reg                                         row_fifo_push;
  wire                                        _row_fifo_push;
  wire                                        row_fifo_pop;
  wire                                        row_fifo_pop_d;
  wire                                        row_fifo_empty;

  wire [ DATA_IN_WIDTH        -1 : 0 ]        pool_fifo_in;
  wire [ DATA_OUT_WIDTH       -1 : 0 ]        pool_fifo_out;
  wire                                        pool_fifo_push;
  wire                                        pool_fifo_pop;
  wire                                        pool_fifo_pop_d;
  wire                                        pool_fifo_empty;
  wire                                        pool_fifo_full;

  wire [ DATA_IN_WIDTH        -1 : 0 ]        sipo_data_out;

  wire signed [ OP_WIDTH             -1 : 0 ]        comp_in_0;
  wire signed [ OP_WIDTH             -1 : 0 ]        comp_in_1;
  wire signed [ OP_WIDTH             -1 : 0 ]        comp_in_2;
  wire signed [ OP_WIDTH             -1 : 0 ]        comp_in_2_d;

  wire signed [ OP_WIDTH             -1 : 0 ]        comp_out_kw2_d;
  wire signed [ OP_WIDTH             -1 : 0 ]        comp_out_kw2;
  wire signed [ OP_WIDTH             -1 : 0 ]        comp_out_kw3;
  wire signed [ OP_WIDTH             -1 : 0 ]        _comp_out_kw2;
  wire signed [ OP_WIDTH             -1 : 0 ]        _comp_out_kw3;
  wire signed [ OP_WIDTH             -1 : 0 ]        current_row_out;
  wire signed [ OP_WIDTH             -1 : 0 ]        next_row_out;

  wire                                        sel;
  wire                                        sel_d;

  wire                                        shift;
  wire                                        pop;
  reg                                         pop_d;
  reg                                         pop_dd;

  wire                                        pool_w_inc;
  wire [ COUNTER_WIDTH        -1 : 0 ]        pool_w_count;
  wire [ COUNTER_WIDTH        -1 : 0 ]        pool_w_max_count;
  wire                                        pool_w_overflow;

  wire                                        pool_h_inc;
  wire [ COUNTER_WIDTH        -1 : 0 ]        pool_h_count;
  wire [ COUNTER_WIDTH        -1 : 0 ]        pool_h_max_count;
  wire                                        pool_h_overflow;

  wire                                        comp_done;

  wire [ STRIDE_WIDTH         -1 : 0 ]        stride;
  wire                                        kernel_size_switch;
  reg  [ DATA_IN_WIDTH        -1 : 0 ]        shifter_data;

// ******************************************************************
// Pool-FIFO-Input
// ******************************************************************

  assign ready = !pool_fifo_empty;

  assign pool_fifo_in = write_data;
  assign pool_fifo_push = write_req;
  assign write_ready = !pool_fifo_full;

  assign {
    pool_pad_row,
    _pool_valid,
    row_fifo_mux_sel,
    row_fifo_pop,
    _row_fifo_push,
    pop,
    shift} = ctrl;

  assign pool_fifo_pop = pop && !pool_pad_row;

  fifo#(
    .DATA_WIDTH               ( DATA_IN_WIDTH            ),
    .ADDR_WIDTH               ( 5                        )
  ) pool_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( pool_fifo_push           ),  //input
    .pop                      ( pool_fifo_pop            ),  //input
    .data_in                  ( pool_fifo_in             ),  //input
    .data_out                 ( pool_fifo_out            ),  //output
    .full                     ( pool_fifo_full           ),  //output
    .empty                    ( pool_fifo_empty          ),  //output
    .fifo_count               (                          )   //output
  );

  assign {kernel_size_switch, stride} = cfg;
  reg pad_row_d;
  reg pad_row_dd;
  always@(posedge clk) pad_row_d <= pool_pad_row;
  always@(posedge clk) pad_row_dd <= pad_row_d;
  always@(posedge clk) pop_d <= pop;
  always@(posedge clk) pop_dd <= pop_d;
  always@(posedge clk)
  begin
    if (reset)
      shifter_data <= 0;
    else if (pad_row_dd)
      shifter_data <= 0;
    else if (pop_dd)
      shifter_data <= pool_fifo_out;
    else if (shift)
      shifter_data <= {pool_fifo_out, shifter_data} >> (stride * OP_WIDTH);
  end

  assign {comp_in_2,
          comp_in_1,
          comp_in_0} = shifter_data[0+:3*OP_WIDTH];

  // Pooled output: Current row
  assign _comp_out_kw2 = comp_in_0 > comp_in_1 ? comp_in_0 : comp_in_1;
  assign _comp_out_kw3 = comp_in_2_d > comp_out_kw2 ? comp_in_2_d : comp_out_kw2;

  register #(1, OP_WIDTH)
  kw2_delay1 (clk, reset, _comp_out_kw2, comp_out_kw2);
  register #(1, OP_WIDTH)
  kw2_delay2 (clk, reset, comp_out_kw2, comp_out_kw2_d);
  register #(1, OP_WIDTH)
  kw3_delay1 (clk, reset, _comp_out_kw3, comp_out_kw3);
  register #(1, OP_WIDTH)
  comp_in_2_delay (clk, reset, comp_in_2, comp_in_2_d);
  register #(2, OP_WIDTH)
  row_fifo_out_delay (clk, reset, row_fifo_out, row_fifo_out_dd);


  assign current_row_out = kernel_size_switch ? comp_out_kw3 : comp_out_kw2_d;

  assign next_row_out = current_row_out > row_fifo_out_dd ?
                        current_row_out : row_fifo_out_dd;


  assign _row_fifo_in = row_fifo_mux_sel ? current_row_out : next_row_out;

  always @(posedge clk)
  begin
    if (reset)
      row_fifo_in <= 0;
    else
      row_fifo_in <= _row_fifo_in;
  end

  always @(posedge clk)
  begin
    if (reset)
      row_fifo_push <= 0;
    else
      row_fifo_push <= _row_fifo_push;
  end

  fifo#(
    .DATA_WIDTH               ( OP_WIDTH                 ),
    .ADDR_WIDTH               ( 7                        )
  ) row_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( row_fifo_push            ),  //input
    .pop                      ( row_fifo_pop             ),  //input
    .data_in                  ( row_fifo_in              ),  //input
    .data_out                 ( row_fifo_out             ),  //output
    .full                     ( row_fifo_full            ),  //output
    .empty                    ( row_fifo_empty           ),  //output
    .fifo_count               (                          )   //output
  );

  always @(posedge clk)
    if (reset)
      pool_valid <= 1'b0;
    else
      pool_valid <= _pool_valid;

  sipo #(
    // INPUT PARAMETERS
    .DATA_IN_WIDTH            ( OP_WIDTH                 ),
    .DATA_OUT_WIDTH           ( DATA_OUT_WIDTH           )
  ) sipo_output (
    // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .enable                   ( pool_valid               ),
    .data_in                  ( row_fifo_in              ),
    .ready                    (                          ),
    .data_out                 ( sipo_data_out            ),
    .out_valid                ( sipo_data_valid          )
  );

  assign read_data = sipo_data_out;
  assign read_req = sipo_data_valid;

endmodule
