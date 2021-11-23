`include "dw_params.vh"
`include "common.vh"
module dnn_accelerator #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer PU_TID_WIDTH      = 16,
  parameter integer AXI_TID_WIDTH     = 6,
  parameter integer NUM_PU            = `num_pu,
  parameter integer ADDR_W            = 32,
  parameter integer OP_WIDTH          = 16,
  parameter integer AXI_DATA_W        = 64,
  parameter integer NUM_PE            = `num_pe,
  parameter integer BASE_ADDR_W       = ADDR_W,
  parameter integer OFFSET_ADDR_W     = ADDR_W,
  parameter integer TX_SIZE_WIDTH     = 20,
  parameter integer RD_LOOP_W         = 32,
  parameter integer D_TYPE_W          = 2,
  parameter integer RD_ROM_ADDR_W     = `C_LOG_2(`max_rd_mem_idx+2),
  parameter integer WR_ROM_ADDR_W     = `C_LOG_2(`max_wr_mem_idx+2),
  parameter integer SERDES_COUNT_W    = `C_LOG_2(NUM_PE+1),
  parameter integer PE_SEL_W          = `C_LOG_2(NUM_PE),
  parameter integer PU_ID_W           = `C_LOG_2(NUM_PU)+1,
  parameter integer LAYER_PARAM_WIDTH = 10,
  parameter integer PARAM_C_WIDTH     = 32
) (
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                        clk,
  input  wire                                        reset,
  input  wire                                        start,
  output wire                                        done,
  // Debug
  output wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_kw,
  output wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_kh,
  output wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_iw,
  output wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_ih,
  output wire [ PARAM_C_WIDTH        -1 : 0 ]        dbg_ic,
  output wire [ PARAM_C_WIDTH        -1 : 0 ]        dbg_oc,

  output wire [ 32                   -1 : 0 ]        buffer_read_count,
  output wire [ 32                   -1 : 0 ]        stream_read_count,
  output wire [ 11                   -1 : 0 ]        inbuf_count,
  output wire [ NUM_PU               -1 : 0 ]        pu_write_valid,
  output wire [ WR_ROM_ADDR_W        -1 : 0 ]        wr_cfg_idx,
  output wire [ RD_ROM_ADDR_W        -1 : 0 ]        rd_cfg_idx,
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
  output wire [ AXI_DATA_W/8         -1 : 0 ]        M_AXI_WSTRB,
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
  //localparam integer NUM_PE             = `num_pe;
  //localparam integer OP_WIDTH           = 16;
  localparam integer DATA_WIDTH         = NUM_PE * OP_WIDTH;
  //localparam integer TID_WIDTH          = 16;
  localparam integer PAD_WIDTH          = 3;
  localparam integer STRIDE_SIZE_W      = 3;
  localparam integer L_TYPE_WIDTH       = 2;

  localparam integer PE_CTRL_WIDTH      = 10 + 2*PE_BUF_ADDR_WIDTH;
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
  // localparam integer PE_CTRL_WIDTH            = 8 + 2*PE_BUF_ADDR_WIDTH;
  // localparam integer PE_BUF_ADDR_WIDTH = 10;
  // localparam integer VECGEN_CTRL_W     = 9;
  // localparam integer WR_ADDR_WIDTH     = 7;
  // localparam integer RD_ADDR_WIDTH     = WR_ADDR_WIDTH+`C_LOG_2(NUM_PE);
  // localparam integer PE_OP_CODE_WIDTH         = 3;
  // localparam integer DATA_IN_WIDTH            = OP_WIDTH * NUM_PE;
  // localparam integer VECGEN_CFG_W      = STRIDE_SIZE_W + PAD_WIDTH;
  // localparam integer POOL_CTRL_WIDTH   = 7;
  // localparam integer POOL_CFG_WIDTH    = 3;
  // localparam integer LAYER_PARAM_WIDTH  = 10;
  // localparam integer PAD_WIDTH          = 3;
  // localparam integer STRIDE_SIZE_W      = 3;

// ******************************************************************
// Regs and Wires
// ******************************************************************

  wire [ L_TYPE_WIDTH         -1 : 0 ]        l_type;

  wire                                        pe_neuron_bias;
  wire [ PE_SEL_W             -1 : 0 ]        pe_neuron_sel;
  wire                                        pe_neuron_read_req;

  wire                                        lrn_enable;

  wire                                        rd_req;
  wire                                        rd_ready;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size;
  wire [ ADDR_W               -1 : 0 ]        rd_addr;
  wire                                        wr_req;
  wire [ ADDR_W               -1 : 0 ]        wr_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size;
  wire                                        wr_done;

  wire [ PU_ID_W              -1 : 0 ]        pu_id_buf;
  wire [ D_TYPE_W             -1 : 0 ]        d_type_buf;
  wire [ PU_DATA_W            -1 : 0 ]        stream_fifo_data_out;


  localparam STREAM_PU_DATA_W = NUM_PE*NUM_PU*OP_WIDTH;
  wire [ NUM_PU               -1 : 0 ]        stream_pu_empty;
  wire [ NUM_PU               -1 : 0 ]        stream_pu_pop;
  wire [ STREAM_PU_DATA_W     -1 : 0 ]        stream_pu_data_out;

  wire [ OUTBUF_DATA_W        -1 : 0 ]        outbuf_data_in;
  //wire [ NUM_PU               -1 : 0 ]        outbuf_push;
  wire [ NUM_PU               -1 : 0 ]        outbuf_full;

  wire [ SERDES_COUNT_W       -1 : 0 ]        pu_serdes_count;

  wire [ PE_CTRL_WIDTH        -1 : 0 ]        pe_ctrl;
  wire [ RD_ADDR_WIDTH        -1 : 0 ]        wb_read_addr;
  wire                                        wb_read_req;
  //-----------vectorgen-----------
  wire [ DATA_IN_WIDTH        -1 : 0 ]        vecgen_rd_data;
  wire                                        vecgen_rd_req;
  wire                                        vecgen_rd_ready;
  wire [ VECGEN_CTRL_W        -1 : 0 ]        vecgen_ctrl;
  wire [ VECGEN_CFG_W         -1 : 0 ]        vecgen_cfg;
  wire                                        vecgen_ready;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        vecgen_wr_data;
  wire                                        vecgen_wr_valid;
  wire [ NUM_PE               -1 : 0 ]        vecgen_mask;

  // PU Source and Destination Select
  wire [ `SRC_0_SEL_WIDTH     -1 : 0 ]        src_0_sel;
  wire [ `SRC_1_SEL_WIDTH     -1 : 0 ]        src_1_sel;
  wire [ `SRC_2_SEL_WIDTH     -1 : 0 ]        src_2_sel;
  wire [ `OUT_SEL_WIDTH       -1 : 0 ]        out_sel;
  wire [ `DST_SEL_WIDTH       -1 : 0 ]        dst_sel;

  //Pooling
  wire [ POOL_CTRL_WIDTH      -1 : 0 ]        pool_ctrl;
  wire [ POOL_CFG_WIDTH       -1 : 0 ]        pool_cfg;

  wire                                        bias_read_req;

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
    .RD_ROM_ADDR_W            ( RD_ROM_ADDR_W            ),
    .WR_ROM_ADDR_W            ( WR_ROM_ADDR_W            )
  ) mem_ctrl_top ( // PORTS

    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),

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

    .stream_pu_empty          ( stream_pu_empty          ),
    .stream_pu_pop            ( stream_pu_pop            ),
    .stream_pu_data_out       ( stream_pu_data_out       ),

    .buffer_read_empty        ( buffer_read_empty        ),
    .buffer_read_req          ( buffer_read_req          ),
    .buffer_read_last         ( buffer_read_last         ),
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
// PU
// ==================================================================


  wire                                        pu_vecgen_ready;
  assign pu_vecgen_ready = PU_GEN[NUM_PU-1].pu_vecgen_ready;

  genvar i;
  generate
    for (i = 0; i < NUM_PU; i = i + 1)
    begin: PU_GEN

      wire                                        pu_write_ready;
      reg                                         buffer_read_data_valid;
      wire [ PU_DATA_W            -1 : 0 ]        pu_write_data;
      wire [ AXI_DATA_W           -1 : 0 ]        pu_read_data;
      wire [ D_TYPE_W             -1 : 0 ]        pu_read_d_type;
      wire [ 10                   -1 : 0 ]        pu_read_id;

      wire                                        pu_read_ready;
      wire                                        pu_read_req;
      wire                                        pu_write_req;

      //-----------vectorgen-----------
      wire [ DATA_IN_WIDTH        -1 : 0 ]        pu_vecgen_rd_data;
      wire                                        pu_vecgen_rd_req;
      wire                                        pu_vecgen_rd_ready;
      wire [ VECGEN_CTRL_W        -1 : 0 ]        pu_vecgen_ctrl;
      wire [ VECGEN_CFG_W         -1 : 0 ]        pu_vecgen_cfg;
      wire                                        pu_vecgen_ready;
      wire [ DATA_IN_WIDTH        -1 : 0 ]        pu_vecgen_wr_data;
      wire                                        pu_vecgen_wr_valid;
      wire [ NUM_PE               -1 : 0 ]        pu_vecgen_mask;

      wire [ 2                    -1 : 0 ]        pu_vecgen_state;

      assign pu_vecgen_cfg = vecgen_cfg;
      assign pu_vecgen_rd_data = stream_pu_data_out[i*PU_DATA_W+:PU_DATA_W];
      assign pu_vecgen_rd_ready = !stream_pu_empty[i];
      //assign pu_vecgen_ctrl = (l_type == 2) ? vecgen_ctrl : 'b0;
      //assign stream_pu_pop[i] = pu_vecgen_rd_req && l_type == 2;
      assign pu_vecgen_ctrl = 'b0;
      assign stream_pu_pop[i] = 'b0;

      vectorgen # (
        .OP_WIDTH                 ( OP_WIDTH                 ),
        .TID_WIDTH                ( PU_TID_WIDTH             ),
        .MAX_STRIDE               ( 1                        ),
        .NUM_PE                   ( NUM_PE                   )
      ) pu_vecgen (
        .clk                      ( clk                      ),
        .reset                    ( reset                    ),
        .ready                    ( pu_vecgen_ready          ),
        .state                    ( pu_vecgen_state          ),
        .ctrl                     ( pu_vecgen_ctrl           ),
        .cfg                      ( pu_vecgen_cfg            ),
        .read_data                ( pu_vecgen_rd_data        ),
        .read_ready               ( pu_vecgen_rd_ready       ),
        .read_req                 ( pu_vecgen_rd_req         ),
        .write_data               ( pu_vecgen_wr_data        ),
        .write_valid              ( pu_vecgen_wr_valid       )
        );

      assign pu_read_data = buffer_read_data_out;
      assign pu_read_ready = !buffer_read_empty; //  && !(next_read);

      assign pu_read_id = pu_id_buf;
      assign pu_read_d_type = d_type_buf;

      assign pu_write_ready = !outbuf_full[i];
      assign outbuf_push[i] = pu_write_req;
      assign outbuf_data_in[i*PU_DATA_W+:PU_DATA_W] = pu_write_data;

      always @(posedge clk)
        if (reset)
          buffer_read_data_valid <= 1'b0;
        else
          buffer_read_data_valid <= (buffer_read_req && !buffer_read_empty);

      wire [ PU_DATA_W            -1 : 0 ]        pu_read_data0;
      //assign pu_read_data0 = l_type == 2 ? pu_vecgen_wr_data: vecgen_wr_data;
      assign pu_read_data0 = vecgen_wr_data;
      PU #(
        // Parameters
        .PU_ID                    ( i                        ),
        .OP_WIDTH                 ( OP_WIDTH                 ),
        .NUM_PE                   ( NUM_PE                   ),
        .SERDES_COUNT_W           ( SERDES_COUNT_W           ),
        .WR_ADDR_WIDTH            ( WR_ADDR_WIDTH            ),
        .RD_ADDR_WIDTH            ( RD_ADDR_WIDTH            )
      ) u_PU (
        // IO
        .clk                      ( clk                      ), //input
        .reset                    ( reset                    ), //input
        .pe_ctrl                  ( pe_ctrl                  ), //input
        .lrn_enable               ( lrn_enable               ), //input
        .pu_serdes_count          ( pu_serdes_count          ), //input
        .pe_neuron_sel            ( pe_neuron_sel            ), //input
        .pe_neuron_bias           ( pe_neuron_bias           ), //input
        .pe_neuron_read_req       ( pe_neuron_read_req       ), //input
        .vecgen_mask              ( vecgen_mask              ), //input
        .vecgen_wr_data           ( pu_read_data0            ), //input
        .wb_read_addr             ( wb_read_addr             ), //input
        .wb_read_req              ( wb_read_req              ), //input
        .bias_read_req            ( bias_read_req            ), //input
        .src_0_sel                ( src_0_sel                ), //input
        .src_1_sel                ( src_1_sel                ), //input
        .src_2_sel                ( src_2_sel                ), //input
        .out_sel                  ( out_sel                  ), //input
        .dst_sel                  ( dst_sel                  ), //input
        .pool_cfg                 ( pool_cfg                 ), //input
        .pool_ctrl                ( pool_ctrl                ), //input
        .read_id                  ( pu_read_id               ), //input
        .read_d_type              ( pu_read_d_type           ), //input
        .buffer_read_data_valid   ( buffer_read_data_valid   ), //input
        .read_req                 ( pu_read_req              ), //output
        .read_data                ( pu_read_data             ), //input,
        .write_data               ( pu_write_data            ), //output
        .write_req                ( pu_write_req             ), //output
        .write_ready              ( pu_write_ready           )  //input
        );

    end
  endgenerate

  // ==================================================================

  // ==================================================================
  // Generate Vectors
  // ==================================================================

  assign vecgen_rd_data = stream_fifo_data_out;
  //assign vecgen_rd_ready = !stream_fifo_empty && d_type_buf == 0;
  assign vecgen_rd_ready = !stream_fifo_empty;// && d_type_buf == 0;
  //assign inbuf_pop = vecgen_rd_req || d_type_buf == 1;
  //assign stream_fifo_pop = vecgen_rd_req && (l_type != 2);
  assign stream_fifo_pop = vecgen_rd_req;
  //assign write_data = vecgen_wr_data;
  //assign write_req = vecgen_wr_valid;

  //reg [16-1:0] vecgen_read_count;
  always @(posedge clk)
    if (reset)
      vecgen_read_count <= 0;
    else if (buffer_read_last)
      vecgen_read_count <= vecgen_read_count + 1'b1;

  wire [ VECGEN_CTRL_W        -1 : 0 ]        stream_vecgen_ctrl;
  //assign stream_vecgen_ctrl = (l_type != 2) ? vecgen_ctrl : 'b0;
  assign stream_vecgen_ctrl = vecgen_ctrl;

  vectorgen # (
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .TID_WIDTH                ( PU_TID_WIDTH             ),
    .NUM_PE                   ( NUM_PE                   )
  ) vecgen (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .ready                    ( vecgen_ready             ),
    .state                    ( vecgen_state             ),
    .ctrl                     ( stream_vecgen_ctrl       ),
    .cfg                      ( vecgen_cfg               ),
    .read_data                ( vecgen_rd_data           ),
    .read_ready               ( vecgen_rd_ready          ),
    .read_req                 ( vecgen_rd_req            ),
    .write_data               ( vecgen_wr_data           ),
    .write_valid              ( vecgen_wr_valid          )
    );
  // ==================================================================

  // ==================================================================
  // PU controller
  // ==================================================================
  wire [ PE_OP_CODE_WIDTH     -1 : 0 ]        pe_op_code;
  wire                                        pe_enable;
  wire                                        pe_write_req;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        pe_write_data;

  wire                                        pu_done;
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
    .done                     ( pu_done                  ), //output
    .l_type                   ( l_type                   ), //output
    .dbg_kw                   ( dbg_kw                   ), //output
    .dbg_kh                   ( dbg_kh                   ), //output
    .dbg_iw                   ( dbg_iw                   ), //output
    .dbg_ih                   ( dbg_ih                   ), //output
    .dbg_ic                   ( dbg_ic                   ), //output
    .dbg_oc                   ( dbg_oc                   ), //output
    .state                    ( pu_controller_state      ), //output
    .pe_ctrl                  ( pe_ctrl                  ), //output
    .lrn_enable               ( lrn_enable               ), //input
    .pu_serdes_count          ( pu_serdes_count          ), //input
    .pe_neuron_sel            ( pe_neuron_sel            ), //input
    .pe_neuron_bias           ( pe_neuron_bias           ), //output
    .pe_neuron_read_req       ( pe_neuron_read_req       ), //input
    .buffer_read_empty        ( buffer_read_empty        ), //input
    .buffer_read_req          ( buffer_read_req          ), //output
    .buffer_read_last         ( buffer_read_last         ), //input
    .vectorgen_ready          ( vecgen_ready             ), //input
    .pu_vecgen_ready          ( pu_vecgen_ready          ), //input
    .vectorgen_ctrl           ( vecgen_ctrl              ), //output
    .vectorgen_cfg            ( vecgen_cfg               ), //output
    .pe_piso_read_req         ( pe_piso_read_req         ), //output
    .wb_read_req              ( wb_read_req              ), //output
    .wb_read_addr             ( wb_read_addr             ), //output
    .pe_write_mask            ( vecgen_mask              ), //output
    .pool_cfg                 ( pool_cfg                 ), //output
    .pool_ctrl                ( pool_ctrl                ), //output
    .src_0_sel                ( src_0_sel                ), //output
    .src_1_sel                ( src_1_sel                ), //output
    .src_2_sel                ( src_2_sel                ), //output
    .bias_read_req            ( bias_read_req            ), //output
    .out_sel                  ( out_sel                  ), //output
    .dst_sel                  ( dst_sel                  )  //output
    );
  // ==================================================================


`ifdef TOPLEVEL_dnn_accelerator
  initial
  begin
    $dumpfile("dnn_accelerator.vcd");
    $dumpvars(0,dnn_accelerator);
  end
`endif
endmodule
