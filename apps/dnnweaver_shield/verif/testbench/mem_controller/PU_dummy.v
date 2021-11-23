`timescale 1ns/1ps
`include "common.vh"
module PU_dummy
#( // INPUT PARAMETERS
  parameter integer PU_ID             = 0,
  parameter integer OP_WIDTH          = 16,
  parameter integer AXI_DATA_WIDTH    = 64,
  parameter integer ACC_WIDTH         = 48,
  parameter integer NUM_PE            = 4,
  parameter         MODE              = "FPGA",
  parameter integer VECGEN_CTRL_W     = 9,
  parameter integer TID_WIDTH         = 16,
  parameter integer PAD_WIDTH         = 3,
  parameter integer STRIDE_SIZE_W     = 3,
  parameter integer VECGEN_CFG_W      = STRIDE_SIZE_W + PAD_WIDTH,
  parameter integer WR_ADDR_WIDTH     = 7,
  parameter integer RD_ADDR_WIDTH     = WR_ADDR_WIDTH+`C_LOG_2(NUM_PE),
  parameter integer PE_BUF_ADDR_WIDTH = 10,
  parameter integer LAYER_PARAM_WIDTH = 10,
  parameter integer POOL_CTRL_WIDTH   = 7,
  parameter integer POOL_CFG_WIDTH    = 3,

  parameter integer D_TYPE_W          = 2,
  parameter integer RD_LOOP_W         = 10
)( // PORTS
  input  wire                                         clk,
  input  wire                                         reset,

  // PU_controller
  input  wire  [ PE_CTRL_WIDTH        -1 : 0 ]        pe_ctrl,
  input  wire                                         bias_read_req,
  input  wire                                         wb_read_req,
  input  wire  [ RD_ADDR_WIDTH        -1 : 0 ]        wb_read_addr,
  // PU Source and Destination Select
  input  wire  [ `SRC_0_SEL_WIDTH     -1 : 0 ]        src_0_sel,
  input  wire  [ `SRC_1_SEL_WIDTH     -1 : 0 ]        src_1_sel,
  input  wire  [ `SRC_2_SEL_WIDTH     -1 : 0 ]        src_2_sel,
  input  wire  [ `OUT_SEL_WIDTH       -1 : 0 ]        out_sel,
  input  wire  [ `DST_SEL_WIDTH       -1 : 0 ]        dst_sel,

  input  wire  [ NUM_PE               -1 : 0 ]        vecgen_mask,

  input  wire  [ DATA_IN_WIDTH        -1 : 0 ]        vecgen_wr_data,

  input  wire  [ POOL_CTRL_WIDTH      -1 : 0 ]        pool_ctrl,
  input  wire  [ POOL_CFG_WIDTH       -1 : 0 ]        pool_cfg,

  input  wire  [ AXI_DATA_WIDTH        -1 : 0 ]        read_data,
  input  wire  [ RD_LOOP_W            -1 : 0 ]        read_id,
  input  wire  [ D_TYPE_W             -1 : 0 ]        read_d_type,
  input  wire                                         read_ready,
  output wire                                         read_req,

  input  wire                                         write_ready,
  output wire  [ DATA_OUT_WIDTH       -1 : 0 ]        write_data,
  output wire                                         write_req
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer DATA_IN_WIDTH            = OP_WIDTH * NUM_PE;
  localparam integer DATA_OUT_WIDTH           = OP_WIDTH * NUM_PE;
  localparam integer PE_OP_CODE_WIDTH         = 3;
  localparam integer DATA_POOLING_OUT_WIDTH   = DATA_IN_WIDTH;
  localparam integer COUNTER_WIDTH            = `C_LOG_2(NUM_PE)+1;
  localparam integer PE_CTRL_WIDTH            = 8 + 2*PE_BUF_ADDR_WIDTH;

// ******************************************************************
// WIRES
// ******************************************************************
  genvar i;

  wire [ DATA_IN_WIDTH        -1 : 0 ]        pe_write_data;

  wire [ 1024                 -1 : 0 ]        GND;


  // -- weight buffer -- //
  reg                                         wb_bias_valid;
  reg  [ OP_WIDTH             -1 : 0 ]        wb_bias_data;
  wire [ OP_WIDTH             -1 : 0 ]        wb_read_data;
  reg                                         wb_write_req;
  wire                                        wb_weight_read_req;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        wb_write_data;
  reg  [ WR_ADDR_WIDTH        -1 : 0 ]        wb_write_addr;

  // -- pooling -- //
  wire [ DATA_IN_WIDTH        -1 : 0 ]        pool_write_data;
  wire                                        pool_write_req;
  wire                                        pool_write_ready;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        pool_read_data;
  wire                                        pool_read_req;
  wire                                        pool_read_ready;
  wire [ POOL_CTRL_WIDTH      -1 : 0 ]        pool_ctrl_d;
  wire [ POOL_CFG_WIDTH       -1 : 0 ]        pool_cfg_d;

  wire pu_bias_read_req;

// ******************************************************************
// Connections
// ******************************************************************
  assign GND = 1024'd0;

  register #(3, POOL_CTRL_WIDTH)
  pool_ctrl_delay (clk, reset, pool_ctrl, pool_ctrl_d);
  register #(3, POOL_CFG_WIDTH)
  pool_cfg_delay (clk, reset, pool_cfg, pool_cfg_d);



// ==================================================================
// PE dummy
// ==================================================================

  PE #(   // INPUT PARAMETERS
    .OP_WIDTH                 ( OP_WIDTH                 ),  //parameter
    .ACC_WIDTH                ( ACC_WIDTH                )   //parameter
  ) u_PE (// PORTS
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .ctrl                     ( pe_ctrl                  ),  //input
    .write_valid              ( pe_write_valid           )   //output
  );

  assign pe_write_req = pe_write_valid;





// ==================================================================
// Pooling Module
// ==================================================================

  assign pool_write_req = pe_write_req && (out_sel_d == `OUT_POOL);
  assign pool_write_data = pe_write_data;
  assign pool_read_ready = 1'b1;
  pooling_dummy #(
    // INPUT PARAMETERS
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   )
  ) pool_DUT (
    // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .ready                    (                          ),
    .cfg                      ( pool_cfg_d               ),
    .ctrl                     ( pool_ctrl_d              ),
    .read_data                ( pool_read_data           ),
    .read_req                 ( pool_read_req            ),
    .read_ready               ( pool_read_ready          ),
    .write_data               ( pool_write_data          ),
    .write_req                ( pool_write_req           ),
    .write_ready              ( pool_write_ready         )
  );
// ==================================================================

reg out_sel_d;
register #(3, `OUT_SEL_WIDTH)
out_sel_delay (clk, reset, out_sel, out_sel_d);

  assign write_req = out_sel_d == `OUT_POOL ? pool_read_req : pe_write_req;
  assign write_data = out_sel_d == `OUT_POOL ? pool_read_data : pe_write_data;

endmodule
