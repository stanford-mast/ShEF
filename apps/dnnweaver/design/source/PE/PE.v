`timescale 1ns/1ps
`include "common.vh"
module PE #(
  // INPUT PARAMETERS
  parameter integer PE_BUF_ADDR_WIDTH   = 10,
  parameter integer OP_WIDTH            = 16,
  parameter integer ACC_WIDTH           = 16,
  parameter integer LAYER_NORM          = "NO"
)
(
  // PORTS
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         mask,
  input  wire  [ CTRL_WIDTH           -1 : 0 ]        ctrl,
  input  wire                                         src_2_sel,

  input  wire  [ OP_WIDTH             -1 : 0 ]        read_data_0,
  input  wire  [ OP_WIDTH             -1 : 0 ]        read_data_1,
  input  wire  [ OP_WIDTH             -1 : 0 ]        read_data_2,
  output wire  [ OP_WIDTH             -1 : 0 ]        lrn_center,
  output wire  [ OP_WIDTH             -1 : 0 ]        write_data,
  output wire  [ OP_WIDTH             -1 : 0 ]        pe_buffer_read_data,
  input  wire                                         pe_neuron_read_req,
  input  wire  [ OP_WIDTH             -1 : 0 ]        pe_neuron_write_data,
  input  wire                                         pe_neuron_write_req,
  input  wire  [ PE_BUF_ADDR_WIDTH    -1 : 0 ]        pe_neuron_write_addr,
  output wire                                         write_valid
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer OP_CODE_WIDTH  = 3;
  localparam integer CTRL_WIDTH     = 10+2*PE_BUF_ADDR_WIDTH;
// ******************************************************************
// WIRES & REGS
// ******************************************************************
  // data
  wire [ OP_WIDTH           -1 : 0 ]  data_in;
  wire [ OP_WIDTH           -1 : 0 ]  pe_buffer_write_data;
  wire [ OP_WIDTH           -1 : 0 ]  pe_buffer_read_data_d;
  wire                                data_valid;
  wire                                centre_data_valid;
  // fifo
  wire                                _pe_buffer_write_req;
  wire                                pe_buffer_write_req;
  wire                                pe_buffer_read_req;
  wire                                _pe_buffer_read_req;

  wire                                flush, flush_d;
  wire                                enable;
  wire [ OP_CODE_WIDTH      -1 : 0 ]  op_code;

  wire [ PE_BUF_ADDR_WIDTH  -1 : 0 ]  buf_rd_addr;
  wire [ PE_BUF_ADDR_WIDTH-1:0] _buf_wr_addr;
  wire [ PE_BUF_ADDR_WIDTH-1:0] buf_wr_addr;

  wire [ OP_WIDTH-1:0] conv_out;

  // Normalization FIFO
  wire norm_fifo_push;
  wire norm_fifo_pop;
  wire norm_fifo_empty;
  wire norm_fifo_full;
  wire [OP_WIDTH-1:0] norm_fifo_data_in;
  wire [OP_WIDTH-1:0] norm_fifo_data_out;

// ******************************************************************
// LOGIC
// ******************************************************************

  assign {norm_fifo_push, norm_fifo_pop,
    buf_rd_addr, _buf_wr_addr,
    flush, write_valid, _pe_buffer_write_req, _pe_buffer_read_req, enable, op_code} = ctrl;

  assign pe_buffer_read_req = _pe_buffer_read_req || pe_neuron_read_req;
  assign pe_buffer_write_req = _pe_buffer_write_req || pe_neuron_write_req;
  assign buf_wr_addr = pe_neuron_write_req ?
    pe_neuron_write_addr : _buf_wr_addr;
// ******************************************************************
// INSTANTIATIONS
// ******************************************************************

  wire                         macc_enable;
  wire                         macc_clear;
  wire [OP_CODE_WIDTH -1 : 0]  macc_op_code;
  wire [OP_WIDTH      -1 : 0]  macc_op_0;
  wire [OP_WIDTH      -1 : 0]  macc_op_1;
  wire [OP_WIDTH      -1 : 0]  macc_op_add;
  wire [OP_WIDTH      -1 : 0]  macc_out;

  assign macc_enable    = enable && mask;
  assign macc_clear     = !mask;
  assign macc_op_code   = op_code;

  assign macc_op_0      = read_data_0;
  assign macc_op_1      = read_data_1;
  assign macc_op_add    = src_2_sel_dd == `SRC_2_BIAS ?
    read_data_2 : pe_buffer_read_data;

  assign conv_out     = !flush_d ? macc_out : pe_buffer_read_data_d;

// ******************************************************************
// Delays
// ******************************************************************

  register #(
    .NUM_STAGES               ( 2                        ),
    .DATA_WIDTH               ( 1                        )
  ) src_2_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( src_2_sel                ),
    .DOUT                     ( src_2_sel_dd             )
  );

  register #(
    .NUM_STAGES               ( 3                        ),
    .DATA_WIDTH               ( 1                        )
  ) macc_en_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( flush                    ),
    .DOUT                     ( flush_d                  )
  );

  register #(
    .NUM_STAGES               ( 3                        ),
    .DATA_WIDTH               ( OP_WIDTH                 )
  ) fifo_out_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( pe_buffer_read_data      ),
    .DOUT                     ( pe_buffer_read_data_d    )
  );
// ******************************************************************

// ******************************************************************
// MACC
// ******************************************************************
  macc #(
    .OP_0_WIDTH               ( OP_WIDTH                 ),
    .OP_1_WIDTH               ( OP_WIDTH                 ),
    .ACC_WIDTH                ( OP_WIDTH                 ),
    .OUT_WIDTH                ( OP_WIDTH                 )
  ) MACC_pe (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .enable                   ( macc_enable              ),  //input
    .clear                    ( macc_clear               ),  //input
    .op_code                  ( macc_op_code             ),  //input
    .op_0                     ( macc_op_0                ),  //input
    .op_1                     ( macc_op_1                ),  //input
    .op_add                   ( macc_op_add              ),  //input
    .out                      ( macc_out                 )   //input
  );
// ******************************************************************

// ******************************************************************
// PE Buffer
// ******************************************************************
  //assign pe_buffer_write_data = !flush_d ? macc_out : pe_buffer_read_data_d;
  assign pe_buffer_write_data = pe_neuron_write_req ? pe_neuron_write_data :
    !flush_d ? macc_out : pe_buffer_read_data_d;
  ram #(
    .DATA_WIDTH               ( OP_WIDTH                 ),
    .ADDR_WIDTH               ( PE_BUF_ADDR_WIDTH        )
  ) pe_buffer (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .s_write_req              ( pe_buffer_write_req      ),  //input
    .s_write_data             ( pe_buffer_write_data     ),  //input
    .s_write_addr             ( buf_wr_addr              ),  //input
    .s_read_req               ( pe_buffer_read_req       ),  //input
    .s_read_data              ( pe_buffer_read_data      ),  //output
    .s_read_addr              ( buf_rd_addr              )   //input
  );
// ******************************************************************

// ******************************************************************
// PE Buffer
// ******************************************************************
  wire activation_enable = 1'b0;
  activation #(
    .OP_WIDTH                 ( OP_WIDTH                 )
  ) ReLU (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .enable                   ( activation_enable        ),  //input
    .in                       ( conv_out                 ),  //input
    .out                      ( write_data               )   //output
  );
// ******************************************************************

// ******************************************************************
// Normalization - Store element being normalized
// ******************************************************************
  assign norm_fifo_data_in = read_data_0;
  assign lrn_center = norm_fifo_data_out;
  fifo#(
    .DATA_WIDTH               ( OP_WIDTH                 ),
    .ADDR_WIDTH               ( 4                        )
  ) norm_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( norm_fifo_push           ),  //input
    .pop                      ( norm_fifo_pop            ),  //input
    .data_in                  ( norm_fifo_data_in        ),  //input
    .data_out                 ( norm_fifo_data_out       ),  //output
    .full                     ( norm_fifo_full           ),  //output
    .empty                    ( norm_fifo_empty          ),  //output
    .fifo_count               (                          )   //output
  );
// ******************************************************************

`ifdef TOPLEVEL_PE
  initial
  begin
    $dumpfile("PE.vcd");
    $dumpvars(0,PE);
  end
`endif



endmodule
