`timescale 1ns/1ps
`include "common.vh"
module PE_dummy #(
  // INPUT PARAMETERS
  parameter integer PE_BUF_ADDR_WIDTH   = 10,
  parameter integer OP_WIDTH            = 16,
  parameter integer ACC_WIDTH           = 16,
  parameter integer LAYER_NORM          = "NO"
)
(
  // PORTS
  input  wire                           clk,
  input  wire                           reset,
  input  wire [ CTRL_WIDTH    -1 : 0 ]  ctrl,
  output wire                           write_valid
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer OP_CODE_WIDTH  = 3;
  localparam integer CTRL_WIDTH     = 8+2*PE_BUF_ADDR_WIDTH;
// ******************************************************************
// WIRES & REGS
// ******************************************************************
  // control
  wire                                fifo_push_norm;
  wire                                fifo_pop_norm;
  // data
  wire [ OP_WIDTH           -1 : 0 ]  data_in;
  wire [ OP_WIDTH           -1 : 0 ]  pe_buffer_write_data;
  wire [ OP_WIDTH           -1 : 0 ]  pe_buffer_read_data_d;
  wire                                data_valid;
  wire                                centre_data_valid;
  // fifo
  wire                                pe_buffer_write_req;
  wire                                pe_buffer_read_req;
  wire                                is_normalization;

  wire                                flush, flush_d;
  wire                                enable;
  wire [ OP_CODE_WIDTH      -1 : 0 ]  op_code;

  wire [ PE_BUF_ADDR_WIDTH  -1 : 0 ]  buf_rd_addr, buf_wr_addr;

  wire [ OP_WIDTH-1:0] conv_out;

// ******************************************************************
// LOGIC
// ******************************************************************

  assign {buf_rd_addr, buf_wr_addr,
    flush, write_valid, pe_buffer_write_req, pe_buffer_read_req, enable, op_code} = ctrl;

endmodule
