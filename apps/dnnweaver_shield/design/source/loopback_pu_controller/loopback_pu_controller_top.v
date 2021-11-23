`include "common.vh"
module loopback_pu_controller_top #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer PU_TID_WIDTH      = 16,
  parameter integer AXI_TID_WIDTH     = 6,
  parameter integer NUM_PU            = 1,
  parameter integer NUM_PE            = 1,
  parameter integer ADDR_W            = 32,
  parameter integer OP_WIDTH          = 16,
  parameter integer AXI_DATA_W        = 64,
  parameter integer BASE_ADDR_W       = ADDR_W,
  parameter integer OFFSET_ADDR_W     = ADDR_W,
  parameter integer TX_SIZE_WIDTH     = 20,
  parameter integer RD_LOOP_W         = 10,
  parameter integer D_TYPE_W          = 2,
  parameter integer ROM_ADDR_W        = 3,
  parameter integer AXI_WSTRB_W       = AXI_DATA_W / 8,
  parameter integer STREAM_DATA_W     = NUM_PE * OP_WIDTH
) (
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                        clk,
  input  wire                                        reset,

  input  wire                                        start,
  output wire                                        done,

  // Debug
  output wire [ 16                   -1 : 0 ]        dbg_kw,
  output wire [ 16                   -1 : 0 ]        dbg_kh,
  output wire [ 16                   -1 : 0 ]        dbg_iw,
  output wire [ 16                   -1 : 0 ]        dbg_ih,
  output wire [ 16                   -1 : 0 ]        dbg_ic,
  output wire [ 16                   -1 : 0 ]        dbg_oc,

  output wire [ 32                   -1 : 0 ]        buffer_read_count,
  output wire [ 32                   -1 : 0 ]        stream_read_count,
  output wire [ 11                   -1 : 0 ]        inbuf_count,
  output wire [ NUM_PU               -1 : 0 ]        pu_write_valid,
  output wire [ ROM_ADDR_W           -1 : 0 ]        wr_cfg_idx,
  output wire [ ROM_ADDR_W           -1 : 0 ]        rd_cfg_idx,
  output wire [ NUM_PU               -1 : 0 ]        outbuf_push,

  output wire [ 3                    -1 : 0 ]        pu_controller_state,
  output wire [ 2                    -1 : 0 ]        vecgen_state,
  output reg  [ 16                   -1 : 0 ]        vecgen_read_count,

  output wire [ AXI_TID_WIDTH        -1 : 0 ]        M_AXI_AWID,
  output wire [ ADDR_W               -1 : 0 ]        M_AXI_AWADDR,
  output wire [ 4                    -1 : 0 ]        M_AXI_AWLEN,
  output wire [ 3                    -1 : 0 ]        M_AXI_AWSIZE,
  output wire [ 2                    -1 : 0 ]        M_AXI_AWBURST,
  output wire [ 2                    -1 : 0 ]        M_AXI_AWLOCK,
  output wire [ 4                    -1 : 0 ]        M_AXI_AWCACHE,
  output wire [ 3                    -1 : 0 ]        M_AXI_AWPROT,
  output wire [ 4                    -1 : 0 ]        M_AXI_AWQOS,
  output wire                                        M_AXI_AWVALID,
  input  wire                                        M_AXI_AWREADY,
  output wire [ AXI_TID_WIDTH        -1 : 0 ]        M_AXI_WID,
  output wire [ AXI_DATA_W           -1 : 0 ]        M_AXI_WDATA,
  output wire [ AXI_WSTRB_W          -1 : 0 ]        M_AXI_WSTRB,
  output wire                                        M_AXI_WLAST,
  output wire                                        M_AXI_WVALID,
  input  wire                                        M_AXI_WREADY,
  input  wire [ AXI_TID_WIDTH        -1 : 0 ]        M_AXI_BID,
  input  wire [ 2                    -1 : 0 ]        M_AXI_BRESP,
  input  wire                                        M_AXI_BVALID,
  output wire                                        M_AXI_BREADY,
  output wire [ AXI_TID_WIDTH        -1 : 0 ]        M_AXI_ARID,
  output wire [ ADDR_W               -1 : 0 ]        M_AXI_ARADDR,
  output wire [ 4                    -1 : 0 ]        M_AXI_ARLEN,
  output wire [ 3                    -1 : 0 ]        M_AXI_ARSIZE,
  output wire [ 2                    -1 : 0 ]        M_AXI_ARBURST,
  output wire [ 2                    -1 : 0 ]        M_AXI_ARLOCK,
  output wire [ 4                    -1 : 0 ]        M_AXI_ARCACHE,
  output wire [ 3                    -1 : 0 ]        M_AXI_ARPROT,
  output wire [ 4                    -1 : 0 ]        M_AXI_ARQOS,
  output wire                                        M_AXI_ARVALID,
  input  wire                                        M_AXI_ARREADY,
  input  wire [ AXI_TID_WIDTH        -1 : 0 ]        M_AXI_RID,
  input  wire [ AXI_DATA_W           -1 : 0 ]        M_AXI_RDATA,
  input  wire [ 2                    -1 : 0 ]        M_AXI_RRESP,
  input  wire                                        M_AXI_RLAST,
  input  wire                                        M_AXI_RVALID,
  output wire                                        M_AXI_RREADY
);
  localparam integer DATA_WIDTH         = NUM_PE * OP_WIDTH;
  localparam integer PAD_WIDTH          = 3;
  localparam integer STRIDE_SIZE_W      = 3;
  localparam integer LAYER_PARAM_WIDTH  = 10;
  localparam integer L_TYPE_WIDTH       = 2;

  localparam integer PE_CTRL_WIDTH      = 8 + 2*PE_BUF_ADDR_WIDTH;
  localparam integer PE_BUF_ADDR_WIDTH  = 10;
  localparam integer VECGEN_CTRL_W      = 9;
  localparam integer WR_ADDR_WIDTH      = 7;
  localparam integer RD_ADDR_WIDTH      = WR_ADDR_WIDTH+`C_LOG_2(NUM_PE);
  localparam integer PE_OP_CODE_WIDTH   = 3;
  localparam integer DATA_IN_WIDTH      = OP_WIDTH * NUM_PE;
  localparam integer VECGEN_CFG_W       = STRIDE_SIZE_W + PAD_WIDTH;
  localparam integer POOL_CTRL_WIDTH    = 7;
  localparam integer POOL_CFG_WIDTH     = 3;

  localparam integer PU_DATA_W = NUM_PE * OP_WIDTH;
  localparam integer OUTBUF_DATA_W = NUM_PU * PU_DATA_W;

// ******************************************************************
// Regs and Wires
// ******************************************************************
  wire [ RD_LOOP_W            -1 : 0 ]        pu_id_buf;
  wire [ D_TYPE_W             -1 : 0 ]        d_type_buf;
  wire [ PU_DATA_W            -1 : 0 ]        stream_fifo_data_out;

  wire [ OUTBUF_DATA_W        -1 : 0 ]        outbuf_data_in;
  wire [ NUM_PU               -1 : 0 ]        outbuf_full;

  wire [ AXI_DATA_W           -1 : 0 ]        buffer_read_data_out;

// ******************************************************************

// ==================================================================
// Memory Controller module
// ==================================================================
  mem_controller_top #(
  // INPUT PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_PU                   ( NUM_PU                   ),
    .ADDR_W                   ( ADDR_W                   ),
    .AXI_DATA_W               ( AXI_DATA_W               ),
    .BASE_ADDR_W              ( BASE_ADDR_W              ),
    .OFFSET_ADDR_W            ( OFFSET_ADDR_W            ),
    .RD_LOOP_W                ( RD_LOOP_W                ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .ROM_ADDR_W               ( ROM_ADDR_W               )
  ) mem_ctrl_top ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     (                          ),

    // Debug
    .rd_cfg_idx               ( rd_cfg_idx               ),
    .wr_cfg_idx               ( wr_cfg_idx               ),
    .pu_write_valid           ( pu_write_valid           ),
    .inbuf_count              ( inbuf_count              ),
    .buffer_read_count        ( buffer_read_count        ),
    .stream_read_count        ( stream_read_count        ),

    .outbuf_full              ( outbuf_full              ),
    .outbuf_push              ( outbuf_push              ),
    .outbuf_data_in           ( outbuf_data_in           ),

    .stream_fifo_empty        ( stream_fifo_empty        ),
    .stream_fifo_pop          ( stream_fifo_pop          ),
    .stream_fifo_data_out     ( stream_fifo_data_out     ),

    .buffer_read_empty        ( buffer_read_empty        ),
    .buffer_read_pop          ( buffer_read_pop          ),
    .buffer_read_data_out     ( buffer_read_data_out     ),

    .pu_id_buf                ( pu_id_buf                ),
    .d_type_buf               ( d_type_buf               ),
    .next_read                ( next_read                ),
    .M_AXI_AWID               ( M_AXI_AWID               ),
    .M_AXI_AWADDR             ( M_AXI_AWADDR             ),
    .M_AXI_AWLEN              ( M_AXI_AWLEN              ),
    .M_AXI_AWSIZE             ( M_AXI_AWSIZE             ),
    .M_AXI_AWBURST            ( M_AXI_AWBURST            ),
    .M_AXI_AWLOCK             ( M_AXI_AWLOCK             ),
    .M_AXI_AWCACHE            ( M_AXI_AWCACHE            ),
    .M_AXI_AWPROT             ( M_AXI_AWPROT             ),
    .M_AXI_AWQOS              ( M_AXI_AWQOS              ),
    .M_AXI_AWVALID            ( M_AXI_AWVALID            ),
    .M_AXI_AWREADY            ( M_AXI_AWREADY            ),
    .M_AXI_WID                ( M_AXI_WID                ),
    .M_AXI_WDATA              ( M_AXI_WDATA              ),
    .M_AXI_WSTRB              ( M_AXI_WSTRB              ),
    .M_AXI_WLAST              ( M_AXI_WLAST              ),
    .M_AXI_WVALID             ( M_AXI_WVALID             ),
    .M_AXI_WREADY             ( M_AXI_WREADY             ),
    .M_AXI_BID                ( M_AXI_BID                ),
    .M_AXI_BRESP              ( M_AXI_BRESP              ),
    .M_AXI_BVALID             ( M_AXI_BVALID             ),
    .M_AXI_BREADY             ( M_AXI_BREADY             ),
    .M_AXI_ARID               ( M_AXI_ARID               ),
    .M_AXI_ARADDR             ( M_AXI_ARADDR             ),
    .M_AXI_ARLEN              ( M_AXI_ARLEN              ),
    .M_AXI_ARSIZE             ( M_AXI_ARSIZE             ),
    .M_AXI_ARBURST            ( M_AXI_ARBURST            ),
    .M_AXI_ARLOCK             ( M_AXI_ARLOCK             ),
    .M_AXI_ARCACHE            ( M_AXI_ARCACHE            ),
    .M_AXI_ARPROT             ( M_AXI_ARPROT             ),
    .M_AXI_ARQOS              ( M_AXI_ARQOS              ),
    .M_AXI_ARVALID            ( M_AXI_ARVALID            ),
    .M_AXI_ARREADY            ( M_AXI_ARREADY            ),
    .M_AXI_RID                ( M_AXI_RID                ),
    .M_AXI_RDATA              ( M_AXI_RDATA              ),
    .M_AXI_RRESP              ( M_AXI_RRESP              ),
    .M_AXI_RLAST              ( M_AXI_RLAST              ),
    .M_AXI_RVALID             ( M_AXI_RVALID             ),
    .M_AXI_RREADY             ( M_AXI_RREADY             )
  );
// ==================================================================

// ==================================================================
// Loopback
// ==================================================================

wire stream_read_ready;
assign stream_read_ready = !stream_fifo_empty;
wire buffer_read_ready;
assign buffer_read_ready = !buffer_read_empty;

// Write to DDR
wire [STREAM_DATA_W-1:0] stream_write_data;
wire stream_write_req;
wire stream_write_ready;

assign outbuf_data_in = stream_write_data;
assign outbuf_push = stream_write_req;
assign stream_write_ready = !outbuf_full;

loopback #(
  .AXI_DATA_W               ( STREAM_DATA_W            )
) u_loopback (
  .clk                      ( clk                      ),
  .reset                    ( reset                    ),
  .stream_read_req          ( stream_fifo_pop          ),
  .stream_read_data         ( stream_fifo_data_out     ),
  .stream_read_ready        ( stream_read_ready        ),
  .buffer_read_req          ( buffer_read_pop          ),
  .buffer_read_data         ( buffer_read_data_out     ),
  .buffer_read_ready        ( buffer_read_ready        ),
  .stream_write_req         ( stream_write_req         ),
  .stream_write_data        ( stream_write_data        ),
  .stream_write_ready       ( stream_write_ready       )
);

// ==================================================================


// ==================================================================
// PU Controller
// ==================================================================
  wire vecgen_ready = 1'b1;

  wire [VECGEN_CTRL_W - 1:0]   vecgen_ctrl;

  wire vectorgen_nextData;
  wire vectorgen_lastData;
  wire vectorgen_pop;
  wire vectorgen_shift;
  wire vectorgen_nextrow;
  wire vectorgen_skip;
  wire vectorgen_endrow;
  wire vectorgen_start;
  wire vectorgen_nextfm;

  assign {
    vectorgen_nextData,
    vectorgen_lastData,
    vectorgen_pop,
    vectorgen_shift,
    vectorgen_nextrow,
    vectorgen_skip,
    vectorgen_endrow,
    vectorgen_start,
    vectorgen_nextfm
    } = vecgen_ctrl;

  reg [16-1:0] nextData_count;
  always @(posedge clk)
  begin
    if (reset)
      nextData_count <= 'b0;
    else if (vectorgen_nextData)
      nextData_count <= nextData_count + 1;
  end

  //assign dbg_iw = nextData_count;

  PU_controller
  #(  // PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .WEIGHT_ADDR_WIDTH        ( RD_ADDR_WIDTH            ),
    .PE_CTRL_W                ( PE_CTRL_WIDTH            ),
    .VECGEN_CTRL_W            ( VECGEN_CTRL_W            ),
    .TID_WIDTH                ( PU_TID_WIDTH             ),
    .PAD_WIDTH                ( PAD_WIDTH                ),
    .LAYER_PARAM_WIDTH        ( LAYER_PARAM_WIDTH        )
  ) u_controller (   // PORTS
    .clk                      ( clk                      ), //input
    .reset                    ( reset                    ), //input
    .start                    ( start                    ), //input
    .dbg_kw                   ( dbg_kw                   ), //output
    .dbg_kh                   ( dbg_kh                   ), //output
    .dbg_iw                   ( dbg_iw                   ), //output
    .dbg_ih                   ( dbg_ih                   ), //output
    .dbg_ic                   ( dbg_ic                   ), //output
    .dbg_oc                   ( dbg_oc                   ), //output
    .done                     ( done                     ), //output
    .state                    ( pu_controller_state      ), //output
    .pe_ctrl                  (                          ), //output
    .vectorgen_ready          ( vecgen_ready             ), //input
    .buffer_read_empty        ( buffer_read_empty        ), //input
    .buffer_read_req          (                          ), //output
    .vectorgen_ctrl           ( vecgen_ctrl              ), //output
    .vectorgen_cfg            (                          ), //output
    .pe_piso_read_req         (                          ), //output
    .wb_read_req              (                          ), //output
    .wb_read_addr             (                          ), //output
    .pe_write_mask            (                          ), //output
    .pool_cfg                 (                          ), //output
    .pool_ctrl                (                          ), //output
    .src_0_sel                (                          ), //output
    .src_1_sel                (                          ), //output
    .src_2_sel                (                          ), //output
    .bias_read_req            (                          ), //output
    .out_sel                  (                          ), //output
    .dst_sel                  (                          )  //output
  );
// ==================================================================




endmodule
