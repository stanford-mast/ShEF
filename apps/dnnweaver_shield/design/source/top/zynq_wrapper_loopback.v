`include "dw_params.vh"
module zynq_wrapper_loopback #(
  parameter READ_ADDR_BASE_0   = 32'h00000000,
  parameter WRITE_ADDR_BASE_0  = 32'h02000000
)
(
  inout wire [14:0]   DDR_addr,
  inout wire [2:0]    DDR_ba,
  inout wire          DDR_cas_n,
  inout wire          DDR_ck_n,
  inout wire          DDR_ck_p,
  inout wire          DDR_cke,
  inout wire          DDR_cs_n,
  inout wire [3:0]    DDR_dm,
  inout wire [31:0]   DDR_dq,
  inout wire [3:0]    DDR_dqs_n,
  inout wire [3:0]    DDR_dqs_p,
  inout wire          DDR_odt,
  inout wire          DDR_ras_n,
  inout wire          DDR_reset_n,
  inout wire          DDR_we_n,
  inout wire          FIXED_IO_ddr_vrn,
  inout wire          FIXED_IO_ddr_vrp,
  inout wire [53:0]   FIXED_IO_mio,
  inout wire          FIXED_IO_ps_clk,
  inout wire          FIXED_IO_ps_porb,
  inout wire          FIXED_IO_ps_srstb
);

  wire [ 16                   -1 : 0 ]        dbg_kw;
  wire [ 16                   -1 : 0 ]        dbg_kh;
  wire [ 16                   -1 : 0 ]        dbg_iw;
  wire [ 16                   -1 : 0 ]        dbg_ih;
  wire [ 16                   -1 : 0 ]        dbg_ic;
  wire [ 16                   -1 : 0 ]        dbg_oc;

  wire [ 32                   -1 : 0 ]        buffer_read_count;
  wire [ 32                   -1 : 0 ]        vecgen_read_count;
  wire [ 32                   -1 : 0 ]        stream_read_count;
  wire [ 11                   -1 : 0 ]        inbuf_count;
  wire [ NUM_PU               -1 : 0 ]        pu_write_valid;
  wire [ NUM_PU               -1 : 0 ]        outbuf_push;
  wire [ ROM_ADDR_W           -1 : 0 ]        wr_cfg_idx;
  wire [ ROM_ADDR_W           -1 : 0 ]        rd_cfg_idx;
  wire [ 3                    -1 : 0 ]        pu_controller_state;
  wire [ 2                    -1 : 0 ]        vecgen_state;

  wire                                        ACLK;
  wire                                        ARESETN;

  wire                                        clk;
  wire                                        reset;

  wire [ 31                      : 0 ]        M_AXI_GP0_awaddr;
  wire [ 2                       : 0 ]        M_AXI_GP0_awprot;
  wire                                        M_AXI_GP0_awready;
  wire                                        M_AXI_GP0_awvalid;
  wire [ 31                      : 0 ]        M_AXI_GP0_wdata;
  wire [ 3                       : 0 ]        M_AXI_GP0_wstrb;
  wire                                        M_AXI_GP0_wvalid;
  wire                                        M_AXI_GP0_wready;
  wire [ 1                       : 0 ]        M_AXI_GP0_bresp;
  wire                                        M_AXI_GP0_bvalid;
  wire                                        M_AXI_GP0_bready;
  wire [ 31                      : 0 ]        M_AXI_GP0_araddr;
  wire [ 2                       : 0 ]        M_AXI_GP0_arprot;
  wire                                        M_AXI_GP0_arvalid;
  wire                                        M_AXI_GP0_arready;
  wire [ 31                      : 0 ]        M_AXI_GP0_rdata;
  wire [ 1                       : 0 ]        M_AXI_GP0_rresp;
  wire                                        M_AXI_GP0_rvalid;
  wire                                        M_AXI_GP0_rready;

  wire [ 31                      : 0 ]        S_AXI_HP0_araddr;
  wire [ 1                       : 0 ]        S_AXI_HP0_arburst;
  wire [ 3                       : 0 ]        S_AXI_HP0_arcache;
  wire [ 5                       : 0 ]        S_AXI_HP0_arid;
  wire [ 3                       : 0 ]        S_AXI_HP0_arlen;
  wire [ 1                       : 0 ]        S_AXI_HP0_arlock;
  wire [ 2                       : 0 ]        S_AXI_HP0_arprot;
  wire [ 3                       : 0 ]        S_AXI_HP0_arqos;
  wire                                        S_AXI_HP0_arready;
  wire [ 2                       : 0 ]        S_AXI_HP0_arsize;
  wire                                        S_AXI_HP0_arvalid;
  wire [ 31                      : 0 ]        S_AXI_HP0_awaddr;
  wire [ 1                       : 0 ]        S_AXI_HP0_awburst;
  wire [ 3                       : 0 ]        S_AXI_HP0_awcache;
  wire [ 5                       : 0 ]        S_AXI_HP0_awid;
  wire [ 3                       : 0 ]        S_AXI_HP0_awlen;
  wire [ 1                       : 0 ]        S_AXI_HP0_awlock;
  wire [ 2                       : 0 ]        S_AXI_HP0_awprot;
  wire [ 3                       : 0 ]        S_AXI_HP0_awqos;
  wire                                        S_AXI_HP0_awready;
  wire [ 2                       : 0 ]        S_AXI_HP0_awsize;
  wire                                        S_AXI_HP0_awvalid;
  wire [ 5                       : 0 ]        S_AXI_HP0_bid;
  wire                                        S_AXI_HP0_bready;
  wire [ 1                       : 0 ]        S_AXI_HP0_bresp;
  wire                                        S_AXI_HP0_bvalid;
  wire [ 63                      : 0 ]        S_AXI_HP0_rdata;
  wire [ 5                       : 0 ]        S_AXI_HP0_rid;
  wire                                        S_AXI_HP0_rlast;
  wire                                        S_AXI_HP0_rready;
  wire [ 1                       : 0 ]        S_AXI_HP0_rresp;
  wire                                        S_AXI_HP0_rvalid;
  wire [ 63                      : 0 ]        S_AXI_HP0_wdata;
  wire [ 5                       : 0 ]        S_AXI_HP0_wid;
  wire                                        S_AXI_HP0_wlast;
  wire                                        S_AXI_HP0_wready;
  wire [ 7                       : 0 ]        S_AXI_HP0_wstrb;
  wire                                        S_AXI_HP0_wvalid;

    localparam integer  C_S_AXI_DATA_WIDTH    = 32;
    localparam integer  C_S_AXI_ADDR_WIDTH    = 32;
    localparam integer  C_M_AXI_DATA_WIDTH    = 64;
    localparam integer  C_M_AXI_ADDR_WIDTH    = 32;

    localparam integer FIFO_ADDR_WIDTH = 4;

  assign reset = !ARESETN;
  assign clk = ACLK;

zc702 zynq_i (
    .DDR_addr                 ( DDR_addr                 ),
    .DDR_ba                   ( DDR_ba                   ),
    .DDR_cas_n                ( DDR_cas_n                ),
    .DDR_ck_n                 ( DDR_ck_n                 ),
    .DDR_ck_p                 ( DDR_ck_p                 ),
    .DDR_cke                  ( DDR_cke                  ),
    .DDR_cs_n                 ( DDR_cs_n                 ),
    .DDR_dm                   ( DDR_dm                   ),
    .DDR_dq                   ( DDR_dq                   ),
    .DDR_dqs_n                ( DDR_dqs_n                ),
    .DDR_dqs_p                ( DDR_dqs_p                ),
    .DDR_odt                  ( DDR_odt                  ),
    .DDR_ras_n                ( DDR_ras_n                ),
    .DDR_reset_n              ( DDR_reset_n              ),
    .DDR_we_n                 ( DDR_we_n                 ),
    .FCLK_CLK0                ( ACLK                ),
    .FCLK_RESET0_N            ( ARESETN            ),
    .FIXED_IO_ddr_vrn         ( FIXED_IO_ddr_vrn         ),
    .FIXED_IO_ddr_vrp         ( FIXED_IO_ddr_vrp         ),
    .FIXED_IO_mio             ( FIXED_IO_mio             ),
    .FIXED_IO_ps_clk          ( FIXED_IO_ps_clk          ),
    .FIXED_IO_ps_porb         ( FIXED_IO_ps_porb         ),
    .FIXED_IO_ps_srstb        ( FIXED_IO_ps_srstb        ),
    .M_AXI_GP0_araddr         ( M_AXI_GP0_araddr         ),
    .M_AXI_GP0_arprot         ( M_AXI_GP0_arprot         ),
    .M_AXI_GP0_arready        ( M_AXI_GP0_arready        ),
    .M_AXI_GP0_arvalid        ( M_AXI_GP0_arvalid        ),
    .M_AXI_GP0_awaddr         ( M_AXI_GP0_awaddr         ),
    .M_AXI_GP0_awprot         ( M_AXI_GP0_awprot         ),
    .M_AXI_GP0_awready        ( M_AXI_GP0_awready        ),
    .M_AXI_GP0_awvalid        ( M_AXI_GP0_awvalid        ),
    .M_AXI_GP0_bready         ( M_AXI_GP0_bready         ),
    .M_AXI_GP0_bresp          ( M_AXI_GP0_bresp          ),
    .M_AXI_GP0_bvalid         ( M_AXI_GP0_bvalid         ),
    .M_AXI_GP0_rdata          ( M_AXI_GP0_rdata          ),
    .M_AXI_GP0_rready         ( M_AXI_GP0_rready         ),
    .M_AXI_GP0_rresp          ( M_AXI_GP0_rresp          ),
    .M_AXI_GP0_rvalid         ( M_AXI_GP0_rvalid         ),
    .M_AXI_GP0_wdata          ( M_AXI_GP0_wdata          ),
    .M_AXI_GP0_wready         ( M_AXI_GP0_wready         ),
    .M_AXI_GP0_wstrb          ( M_AXI_GP0_wstrb          ),
    .M_AXI_GP0_wvalid         ( M_AXI_GP0_wvalid         ),
    .S_AXI_HP0_araddr         ( S_AXI_HP0_araddr         ),
    .S_AXI_HP0_arburst        ( S_AXI_HP0_arburst        ),
    .S_AXI_HP0_arcache        ( S_AXI_HP0_arcache        ),
    .S_AXI_HP0_arid           ( S_AXI_HP0_arid           ),
    .S_AXI_HP0_arlen          ( S_AXI_HP0_arlen          ),
    .S_AXI_HP0_arlock         ( S_AXI_HP0_arlock         ),
    .S_AXI_HP0_arprot         ( S_AXI_HP0_arprot         ),
    .S_AXI_HP0_arqos          ( S_AXI_HP0_arqos          ),
    .S_AXI_HP0_arready        ( S_AXI_HP0_arready        ),
    .S_AXI_HP0_arsize         ( S_AXI_HP0_arsize         ),
    .S_AXI_HP0_arvalid        ( S_AXI_HP0_arvalid        ),
    .S_AXI_HP0_awaddr         ( S_AXI_HP0_awaddr         ),
    .S_AXI_HP0_awburst        ( S_AXI_HP0_awburst        ),
    .S_AXI_HP0_awcache        ( S_AXI_HP0_awcache        ),
    .S_AXI_HP0_awid           ( S_AXI_HP0_awid           ),
    .S_AXI_HP0_awlen          ( S_AXI_HP0_awlen          ),
    .S_AXI_HP0_awlock         ( S_AXI_HP0_awlock         ),
    .S_AXI_HP0_awprot         ( S_AXI_HP0_awprot         ),
    .S_AXI_HP0_awqos          ( S_AXI_HP0_awqos          ),
    .S_AXI_HP0_awready        ( S_AXI_HP0_awready        ),
    .S_AXI_HP0_awsize         ( S_AXI_HP0_awsize         ),
    .S_AXI_HP0_awvalid        ( S_AXI_HP0_awvalid        ),
    .S_AXI_HP0_bid            ( S_AXI_HP0_bid            ),
    .S_AXI_HP0_bready         ( S_AXI_HP0_bready         ),
    .S_AXI_HP0_bresp          ( S_AXI_HP0_bresp          ),
    .S_AXI_HP0_bvalid         ( S_AXI_HP0_bvalid         ),
    .S_AXI_HP0_rdata          ( S_AXI_HP0_rdata          ),
    .S_AXI_HP0_rid            ( S_AXI_HP0_rid            ),
    .S_AXI_HP0_rlast          ( S_AXI_HP0_rlast          ),
    .S_AXI_HP0_rready         ( S_AXI_HP0_rready         ),
    .S_AXI_HP0_rresp          ( S_AXI_HP0_rresp          ),
    .S_AXI_HP0_rvalid         ( S_AXI_HP0_rvalid         ),
    .S_AXI_HP0_wdata          ( S_AXI_HP0_wdata          ),
    .S_AXI_HP0_wid            ( S_AXI_HP0_wid            ),
    .S_AXI_HP0_wlast          ( S_AXI_HP0_wlast          ),
    .S_AXI_HP0_wready         ( S_AXI_HP0_wready         ),
    .S_AXI_HP0_wstrb          ( S_AXI_HP0_wstrb          ),
    .S_AXI_HP0_wvalid         ( S_AXI_HP0_wvalid         )
  );

  wire [31:0] slv_reg0_in, slv_reg0_out;
  wire [31:0] slv_reg1_in, slv_reg1_out;
  wire [31:0] slv_reg2_in, slv_reg2_out;
  wire [31:0] slv_reg3_in, slv_reg3_out;
  wire [31:0] slv_reg4_in, slv_reg4_out;
  wire [31:0] slv_reg5_in, slv_reg5_out;
  wire [31:0] slv_reg6_in, slv_reg6_out;
  wire [31:0] slv_reg7_in, slv_reg7_out;

  wire [31:0] slv_reg8_in, slv_reg8_out;
  wire [31:0] slv_reg9_in, slv_reg9_out;
  wire [31:0] slv_reg10_in, slv_reg10_out;
  wire [31:0] slv_reg11_in, slv_reg11_out;
  wire [31:0] slv_reg12_in, slv_reg12_out;
  wire [31:0] slv_reg13_in, slv_reg13_out;
  wire [31:0] slv_reg14_in, slv_reg14_out;
  wire [31:0] slv_reg15_in, slv_reg15_out;

  reg slv_reg0_out_d;

  always @(posedge clk)
    if (reset)
      slv_reg0_out_d <= 0;
    else
      slv_reg0_out_d <= slv_reg0_out[0];

  wire start = slv_reg0_out[0] ^ slv_reg0_out_d;

  //assign slv_reg0_in = slv_reg0_out;
  //assign slv_reg1_in = slv_reg1_out;
  //assign slv_reg2_in = slv_reg2_out;
  //assign slv_reg3_in = slv_reg3_out;
  //assign slv_reg4_in = slv_reg4_out;
  //assign slv_reg5_in = slv_reg5_out;
  //assign slv_reg6_in = slv_reg6_out;
  //assign slv_reg7_in = slv_reg7_out;
  //assign slv_reg8_in = slv_reg8_out;
  //assign slv_reg9_in = slv_reg9_out;
  //assign slv_reg10_in = slv_reg10_out;
  //assign slv_reg11_in = slv_reg11_out;
  //assign slv_reg12_in = slv_reg12_out;
  //assign slv_reg13_in = slv_reg13_out;
  //assign slv_reg14_in = slv_reg14_out;
  //assign slv_reg15_in = slv_reg15_out;

  assign slv_reg0_in = start_count;
  assign slv_reg1_in = done_count;

  wire [32*3-1:0] dnnweaver;
  assign dnnweaver = 96'h7265766165774E4E44;

  wire [32*3-1:0] version;
  assign version = 96'h30302E31;

  //assign {slv_reg4_in, slv_reg3_in, slv_reg2_in} = dnnweaver;
  //assign {slv_reg7_in, slv_reg6_in, slv_reg5_in} = version;
  assign slv_reg2_in = dbg_kw;
  assign slv_reg3_in = dbg_kh;
  assign slv_reg4_in = dbg_iw;
  assign slv_reg5_in = dbg_ih;
  assign slv_reg6_in = dbg_ic;
  assign slv_reg7_in = dbg_oc;

  // assign slv_reg5_in = pu_controller_state;
  // assign slv_reg6_in = buffer_read_count;
  // assign slv_reg7_in = stream_read_count;

  assign slv_reg8_in = rd_cfg_idx;
  assign slv_reg9_in = wr_cfg_idx;

  assign slv_reg10_in = read_count;
  assign slv_reg11_in = write_count;

  assign slv_reg12_in = PU0_write_count;
  assign slv_reg13_in = PU1_write_count;

  assign slv_reg14_in = read_addr;
  assign slv_reg15_in = write_addr;

  reg [31:0] start_count;
  reg [31:0] done_count;

  reg [31:0] read_count;
  reg [31:0] read_addr;
  reg [31:0] write_count;
  reg [31:0] write_addr;

  reg [31:0] PU0_write_count;
  reg [31:0] PU1_write_count;

  always @(posedge clk)
    if(reset)
      PU0_write_count <= 0;
    else if (outbuf_push[0])
      PU0_write_count <= PU0_write_count + 1'b1;

  always @(posedge clk)
    if(reset)
      PU1_write_count <= 0;
    else if (outbuf_push[1])
      PU1_write_count <= PU1_write_count + 1'b1;

  always @(posedge clk)
    if (reset)
      read_count <= 0;
    else if (S_AXI_HP0_rready && S_AXI_HP0_rvalid)
      read_count <= read_count + 1'b1;

  always @(posedge clk)
    if (reset)
      read_addr <= 0;
    else if (S_AXI_HP0_arready && S_AXI_HP0_arvalid)
      read_addr <= S_AXI_HP0_araddr;

  always @(posedge clk)
    if (reset)
      write_count <= 0;
    else if (S_AXI_HP0_wready && S_AXI_HP0_wvalid)
      write_count <= write_count + 1'b1;

  always @(posedge clk)
    if (reset)
      write_addr <= 0;
    else if (S_AXI_HP0_awready && S_AXI_HP0_awvalid)
      write_addr <= S_AXI_HP0_awaddr;

  always @(posedge clk)
    if (reset)
      start_count <= 0;
    else if (start)
      start_count <= start_count + 1'b1;

  always @(posedge clk)
    if (reset)
      done_count <= 0;
    else if (done)
      done_count <= done_count + 1'b1;

  axi4lite_slave #(
    .AXIS_DATA_WIDTH          ( 32                       ),
    .AXIS_ADDR_WIDTH          ( 32                       )
  ) axi_slave_i (

    .slv_reg0_in              ( slv_reg0_in              ),  //input  register 0
    .slv_reg0_out             ( slv_reg0_out             ),  //output register 0
    .slv_reg1_in              ( slv_reg1_in              ),  //input  register 1
    .slv_reg1_out             ( slv_reg1_out             ),  //output register 1
    .slv_reg2_in              ( slv_reg2_in              ),  //input  register 2
    .slv_reg2_out             ( slv_reg2_out             ),  //output register 2
    .slv_reg3_in              ( slv_reg3_in              ),  //input  register 3
    .slv_reg3_out             ( slv_reg3_out             ),  //output register 3
    .slv_reg4_in              ( slv_reg4_in              ),  //input  register 4
    .slv_reg4_out             ( slv_reg4_out             ),  //output register 4
    .slv_reg5_in              ( slv_reg5_in              ),  //input  register 5
    .slv_reg5_out             ( slv_reg5_out             ),  //output register 5
    .slv_reg6_in              ( slv_reg6_in              ),  //input  register 6
    .slv_reg6_out             ( slv_reg6_out             ),  //output register 6
    .slv_reg7_in              ( slv_reg7_in              ),  //input  register 7
    .slv_reg7_out             ( slv_reg7_out             ),  //output register 7

    .slv_reg8_in              ( slv_reg8_in              ),  //input  register 8
    .slv_reg8_out             ( slv_reg8_out             ),  //output register 8
    .slv_reg9_in              ( slv_reg9_in              ),  //input  register 9
    .slv_reg9_out             ( slv_reg9_out             ),  //output register 9
    .slv_reg10_in             ( slv_reg10_in             ),  //input  register 10
    .slv_reg10_out            ( slv_reg10_out            ),  //output register 10
    .slv_reg11_in             ( slv_reg11_in             ),  //input  register 11
    .slv_reg11_out            ( slv_reg11_out            ),  //output register 11
    .slv_reg12_in             ( slv_reg12_in             ),  //input  register 12
    .slv_reg12_out            ( slv_reg12_out            ),  //output register 12
    .slv_reg13_in             ( slv_reg13_in             ),  //input  register 13
    .slv_reg13_out            ( slv_reg13_out            ),  //output register 13
    .slv_reg14_in             ( slv_reg14_in             ),  //input  register 14
    .slv_reg14_out            ( slv_reg14_out            ),  //output register 14
    .slv_reg15_in             ( slv_reg15_in             ),  //input  register 15
    .slv_reg15_out            ( slv_reg15_out            ),  //output register 15

    .S_AXI_ACLK               ( ACLK                     ),  //input
    .S_AXI_ARESETN            ( ARESETN                  ),  //input

    .S_AXI_AWADDR             ( M_AXI_GP0_awaddr         ),  //input
    .S_AXI_AWPROT             ( M_AXI_GP0_awprot         ),  //input
    .S_AXI_AWVALID            ( M_AXI_GP0_awvalid        ),  //input
    .S_AXI_AWREADY            ( M_AXI_GP0_awready        ),  //output

    .S_AXI_WDATA              ( M_AXI_GP0_wdata          ),  //input
    .S_AXI_WSTRB              ( M_AXI_GP0_wstrb          ),  //input
    .S_AXI_WVALID             ( M_AXI_GP0_wvalid         ),  //input
    .S_AXI_WREADY             ( M_AXI_GP0_wready         ),  //output

    .S_AXI_BRESP              ( M_AXI_GP0_bresp          ),  //output
    .S_AXI_BVALID             ( M_AXI_GP0_bvalid         ),  //output
    .S_AXI_BREADY             ( M_AXI_GP0_bready         ),  //input

    .S_AXI_ARADDR             ( M_AXI_GP0_araddr         ),  //input
    .S_AXI_ARPROT             ( M_AXI_GP0_arprot         ),  //input
    .S_AXI_ARVALID            ( M_AXI_GP0_arvalid        ),  //input
    .S_AXI_ARREADY            ( M_AXI_GP0_arready        ),  //output

    .S_AXI_RDATA              ( M_AXI_GP0_rdata          ),  //output
    .S_AXI_RRESP              ( M_AXI_GP0_rresp          ),  //output
    .S_AXI_RVALID             ( M_AXI_GP0_rvalid         ),  //output
    .S_AXI_RREADY             ( M_AXI_GP0_rready         )   //input
  );
//--------------------------------------------------------------

  localparam integer TID_WIDTH         = 6;
  localparam integer NUM_PU            = `num_pu;
  localparam integer NUM_PE            = `num_pe;
  localparam integer ADDR_W            = C_M_AXI_ADDR_WIDTH;
  localparam integer OP_WIDTH          = 16;
  localparam integer DATA_W            = C_M_AXI_DATA_WIDTH;
  localparam integer BASE_ADDR_W       = ADDR_W;
  localparam integer OFFSET_ADDR_W     = ADDR_W;
  localparam integer TX_SIZE_WIDTH     = 20;
  localparam integer RD_LOOP_W         = 32;
  localparam integer D_TYPE_W          = 2;
  localparam integer ROM_ADDR_W        = 3;

// ==================================================================
// Dnn Accelerator
// ==================================================================
  loopback_pu_controller_top #(
  // INPUT PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_PU                   ( NUM_PU                   ),
    .ADDR_W                   ( ADDR_W                   ),
    .AXI_DATA_W               ( DATA_W                   ),
    .BASE_ADDR_W              ( BASE_ADDR_W              ),
    .OFFSET_ADDR_W            ( OFFSET_ADDR_W            ),
    .RD_LOOP_W                ( RD_LOOP_W                ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .ROM_ADDR_W               ( ROM_ADDR_W               )
  ) accelerator ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),

    .rd_cfg_idx               ( rd_cfg_idx               ),
    .wr_cfg_idx               ( wr_cfg_idx               ),

    .pu_controller_state      ( pu_controller_state      ),
    .vecgen_state             ( vecgen_state             ),
    .vecgen_read_count        ( vecgen_read_count        ),

    .dbg_kw                   ( dbg_kw                   ), //output
    .dbg_kh                   ( dbg_kh                   ), //output
    .dbg_iw                   ( dbg_iw                   ), //output
    .dbg_ih                   ( dbg_ih                   ), //output
    .dbg_ic                   ( dbg_ic                   ), //output
    .dbg_oc                   ( dbg_oc                   ), //output
    .outbuf_push              ( outbuf_push              ),

    .pu_write_valid           ( pu_write_valid           ),
    .inbuf_count              ( inbuf_count              ),
    .buffer_read_count        ( buffer_read_count        ),
    .stream_read_count        ( stream_read_count        ),

    .M_AXI_AWID               ( S_AXI_HP0_awid           ),
    .M_AXI_AWADDR             ( S_AXI_HP0_awaddr         ),
    .M_AXI_AWLEN              ( S_AXI_HP0_awlen          ),
    .M_AXI_AWSIZE             ( S_AXI_HP0_awsize         ),
    .M_AXI_AWBURST            ( S_AXI_HP0_awburst        ),
    .M_AXI_AWLOCK             ( S_AXI_HP0_awlock         ),
    .M_AXI_AWCACHE            ( S_AXI_HP0_awcache        ),
    .M_AXI_AWPROT             ( S_AXI_HP0_awprot         ),
    .M_AXI_AWQOS              ( S_AXI_HP0_awqos          ),
    .M_AXI_AWVALID            ( S_AXI_HP0_awvalid        ),
    .M_AXI_AWREADY            ( S_AXI_HP0_awready        ),
    .M_AXI_WID                ( S_AXI_HP0_wid            ),
    .M_AXI_WDATA              ( S_AXI_HP0_wdata          ),
    .M_AXI_WSTRB              ( S_AXI_HP0_wstrb          ),
    .M_AXI_WLAST              ( S_AXI_HP0_wlast          ),
    .M_AXI_WVALID             ( S_AXI_HP0_wvalid         ),
    .M_AXI_WREADY             ( S_AXI_HP0_wready         ),
    .M_AXI_BID                ( S_AXI_HP0_bid            ),
    .M_AXI_BRESP              ( S_AXI_HP0_bresp          ),
    .M_AXI_BVALID             ( S_AXI_HP0_bvalid         ),
    .M_AXI_BREADY             ( S_AXI_HP0_bready         ),
    .M_AXI_ARID               ( S_AXI_HP0_arid           ),
    .M_AXI_ARADDR             ( S_AXI_HP0_araddr         ),
    .M_AXI_ARLEN              ( S_AXI_HP0_arlen          ),
    .M_AXI_ARSIZE             ( S_AXI_HP0_arsize         ),
    .M_AXI_ARBURST            ( S_AXI_HP0_arburst        ),
    .M_AXI_ARLOCK             ( S_AXI_HP0_arlock         ),
    .M_AXI_ARCACHE            ( S_AXI_HP0_arcache        ),
    .M_AXI_ARPROT             ( S_AXI_HP0_arprot         ),
    .M_AXI_ARQOS              ( S_AXI_HP0_arqos          ),
    .M_AXI_ARVALID            ( S_AXI_HP0_arvalid        ),
    .M_AXI_ARREADY            ( S_AXI_HP0_arready        ),
    .M_AXI_RID                ( S_AXI_HP0_rid            ),
    .M_AXI_RDATA              ( S_AXI_HP0_rdata          ),
    .M_AXI_RRESP              ( S_AXI_HP0_rresp          ),
    .M_AXI_RLAST              ( S_AXI_HP0_rlast          ),
    .M_AXI_RVALID             ( S_AXI_HP0_rvalid         ),
    .M_AXI_RREADY             ( S_AXI_HP0_rready         )
  );
// ==================================================================




endmodule
