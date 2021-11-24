// Mark Zhao
//
//

module cl_sdp
(
  `include "cl_ports.vh" // Fixed port definition
);
  `include "free_common_defines.vh"
  `include "cl_sdp_defines.vh" // CL Defines for cl_hello_world TODO
  `include "cl_id_defines.vh" //PCI IDs

  //---------------------------------------------
  // Start with Tie-Off of Unused Interfaces
  //---------------------------------------------
  // the developer should use the next set of `include
  // to properly tie-off any unused interface
  // The list is put in the top of the module
  // to avoid cases where developer may forget to
  // remove it from the end of the file
  
  `include "unused_flr_template.inc"
  `ifndef USE_DRAM //If use_dram is not defined, plug in unused templates
    `include "unused_ddr_a_b_d_template.inc"
    `include "unused_dma_pcis_template.inc"
  `endif
  `include "unused_pcim_template.inc"
  //`include "unused_dma_pcis_template.inc"
  `include "unused_cl_sda_template.inc"
  `include "unused_sh_bar1_template.inc"
  `include "unused_apppf_irq_template.inc"

  // localparams
  localparam integer CL_AXI_ADDR_WIDTH = 32;
  localparam integer CL_AXI_DATA_WIDTH = 32;
  localparam integer CL_AXI_ID_WIDTH = 16;

  //-------------------------------------------------
  // Internal signals
  //-------------------------------------------------
  //DMA PCIs 
  axi_bus_t sh_cl_dma_pcis_bus(); //From shell
  //Internal AXI master
  axi_bus_t cl_axi_mstr_bus();
  //DDR buses
  axi_bus_t lcl_cl_sh_ddra();
  axi_bus_t lcl_cl_sh_ddrb();
  axi_bus_t cl_sh_ddr_bus();
  axi_bus_t lcl_cl_sh_ddrd();

  // Application signals
  logic start;
  logic done;

  logic [CL_AXI_ID_WIDTH-1:0]        sdp_m_axi_awid;
  logic [CL_AXI_ADDR_WIDTH-1:0]      sdp_m_axi_awaddr;
  logic [7:0]                        sdp_m_axi_awlen;
  logic [2:0]                        sdp_m_axi_awsize;
  logic [1:0]                        sdp_m_axi_awburst;
  logic [1:0]                        sdp_m_axi_awlock;
  logic [3:0]                        sdp_m_axi_awcache;
  logic [2:0]                        sdp_m_axi_awprot;
  logic [3:0]                        sdp_m_axi_awqos;
  logic [3:0]                        sdp_m_axi_awregion;
  logic                              sdp_m_axi_awvalid;
  logic                              sdp_m_axi_awready;
  logic [CL_AXI_ID_WIDTH-1:0]        sdp_m_axi_wid;
  logic [CL_AXI_DATA_WIDTH-1:0]      sdp_m_axi_wdata;
  logic [CL_AXI_DATA_WIDTH/8-1:0]    sdp_m_axi_wstrb;
  logic                              sdp_m_axi_wlast;
  logic                              sdp_m_axi_wvalid;
  logic                              sdp_m_axi_wready;
  logic [CL_AXI_ID_WIDTH-1:0]        sdp_m_axi_bid;
  logic [1:0]                        sdp_m_axi_bresp;
  logic                              sdp_m_axi_bvalid;
  logic                              sdp_m_axi_bready;
  logic [CL_AXI_ID_WIDTH-1:0]        sdp_m_axi_arid;
  logic [CL_AXI_ADDR_WIDTH-1:0]      sdp_m_axi_araddr;
  logic [7:0]                        sdp_m_axi_arlen;
  logic [2:0]                        sdp_m_axi_arsize;
  logic [1:0]                        sdp_m_axi_arburst;
  logic [1:0]                        sdp_m_axi_arlock;
  logic [3:0]                        sdp_m_axi_arcache;
  logic [2:0]                        sdp_m_axi_arprot;
  logic [3:0]                        sdp_m_axi_arqos;
  logic [3:0]                        sdp_m_axi_arregion;
  logic                              sdp_m_axi_arvalid;
  logic                              sdp_m_axi_arready;
  logic [CL_AXI_ID_WIDTH-1:0]        sdp_m_axi_rid;
  logic [CL_AXI_DATA_WIDTH-1:0]      sdp_m_axi_rdata;
  logic [1:0]                        sdp_m_axi_rresp;
  logic                              sdp_m_axi_rlast;
  logic                              sdp_m_axi_rvalid;
  logic                              sdp_m_axi_rready;


  // shield logic
  logic [3:0] shield_state;


  //-------------------------------------------------
  // ID Values
  //-------------------------------------------------
  assign cl_sh_id0[31:0] = `CL_SH_ID0;
  assign cl_sh_id1[31:0] = `CL_SH_ID1;

  //-------------------------------------------------
  // Reset Synchronization
  //-------------------------------------------------
  (* dont_touch = "true" *) logic pipe_rst_n;
  logic pre_sync_rst_n;
  (* dont_touch = "true" *) logic sync_rst_n;
  //reset synchronizer
  lib_pipe #(.WIDTH(1), .STAGES(4)) PIPE_RST_N (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(rst_main_n), .out_bus(pipe_rst_n));

  always_ff @(negedge pipe_rst_n or posedge clk_main_a0) begin
    if (!pipe_rst_n) begin
      pre_sync_rst_n <= 0;
      sync_rst_n <= 0;
    end
    else begin
      pre_sync_rst_n <= 1;
      sync_rst_n <= pre_sync_rst_n;
    end
  end

  //-------------------------------------------------
  // PCIe OCL AXI-L (SH to CL) Timing Flops
  //-------------------------------------------------
  (* dont_touch = "true" *) logic sh_ocl_sync_rst_n;
  lib_pipe #(.WIDTH(1), .STAGES(4)) SH_OCL_SLC_RST_N (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(sync_rst_n), .out_bus(sh_ocl_sync_rst_n));
  // Write address                                                                                                              
  logic        sh_ocl_awvalid_q;
  logic [31:0] sh_ocl_awaddr_q;
  logic        ocl_sh_awready_q;
                                                                                                                              
  // Write data                                                                                                                
  logic        sh_ocl_wvalid_q;
  logic [31:0] sh_ocl_wdata_q;
  logic [ 3:0] sh_ocl_wstrb_q;
  logic        ocl_sh_wready_q;
                                                                                                                              
  // Write response                                                                                                            
  logic        ocl_sh_bvalid_q;
  logic [ 1:0] ocl_sh_bresp_q;
  logic        sh_ocl_bready_q;
                                                                                                                              
  // Read address                                                                                                              
  logic        sh_ocl_arvalid_q;
  logic [31:0] sh_ocl_araddr_q;
  logic        ocl_sh_arready_q;
                                                                                                                              
  // Read data/response                                                                                                        
  logic        ocl_sh_rvalid_q;
  logic [31:0] ocl_sh_rdata_q;
  logic [ 1:0] ocl_sh_rresp_q;
  logic        sh_ocl_rready_q;

  axi_register_slice_light AXIL_OCL_REG_SLC (
   .aclk          (clk_main_a0),
   .aresetn       (sh_ocl_sync_rst_n),
   .s_axi_awaddr  (sh_ocl_awaddr),
   .s_axi_awprot   (2'h0),
   .s_axi_awvalid (sh_ocl_awvalid),
   .s_axi_awready (ocl_sh_awready),
   .s_axi_wdata   (sh_ocl_wdata),
   .s_axi_wstrb   (sh_ocl_wstrb),
   .s_axi_wvalid  (sh_ocl_wvalid),
   .s_axi_wready  (ocl_sh_wready),
   .s_axi_bresp   (ocl_sh_bresp),
   .s_axi_bvalid  (ocl_sh_bvalid),
   .s_axi_bready  (sh_ocl_bready),
   .s_axi_araddr  (sh_ocl_araddr),
   .s_axi_arvalid (sh_ocl_arvalid),
   .s_axi_arready (ocl_sh_arready),
   .s_axi_rdata   (ocl_sh_rdata),
   .s_axi_rresp   (ocl_sh_rresp),
   .s_axi_rvalid  (ocl_sh_rvalid),
   .s_axi_rready  (sh_ocl_rready),
   .m_axi_awaddr  (sh_ocl_awaddr_q),
   .m_axi_awprot  (),
   .m_axi_awvalid (sh_ocl_awvalid_q),
   .m_axi_awready (ocl_sh_awready_q),
   .m_axi_wdata   (sh_ocl_wdata_q),
   .m_axi_wstrb   (sh_ocl_wstrb_q),
   .m_axi_wvalid  (sh_ocl_wvalid_q),
   .m_axi_wready  (ocl_sh_wready_q),
   .m_axi_bresp   (ocl_sh_bresp_q),
   .m_axi_bvalid  (ocl_sh_bvalid_q),
   .m_axi_bready  (sh_ocl_bready_q),
   .m_axi_araddr  (sh_ocl_araddr_q),
   .m_axi_arvalid (sh_ocl_arvalid_q),
   .m_axi_arready (ocl_sh_arready_q),
   .m_axi_rdata   (ocl_sh_rdata_q),
   .m_axi_rresp   (ocl_sh_rresp_q),
   .m_axi_rvalid  (ocl_sh_rvalid_q),
   .m_axi_rready  (sh_ocl_rready_q)
  );

  //-------------------------------------------------
  // Control and Status Registers (Accessed from PCIe AppPF BAR0)
  //-------------------------------------------------
  logic [31:0] free_control_reg0;
  logic [31:0] free_control_reg1;
  logic [31:0] free_control_reg2;
  logic [31:0] free_control_reg3;
  logic [31:0] free_control_reg4;
  logic [31:0] free_control_reg5;
  logic [31:0] free_control_reg6;
  logic [31:0] free_control_reg7;
  logic [31:0] free_control_reg8;
  logic [31:0] free_control_reg9;
  logic [31:0] free_control_reg10;
  logic [31:0] free_control_reg11;
  logic [31:0] free_control_reg12;
  logic [31:0] free_control_reg13;
  logic [31:0] free_control_reg14;
  logic [31:0] free_control_reg15;
  logic [31:0] start_count_r;
  logic [31:0] done_count_r;
  logic [31:0] free_status_reg2;
  logic [31:0] free_status_reg3;
  logic [31:0] free_status_reg4;
  logic [31:0] free_status_reg5;
  logic [31:0] free_status_reg6;
  logic [31:0] free_status_reg7;
  logic [31:0] free_status_reg8;
  logic [31:0] free_status_reg9;
  logic [31:0] free_status_reg10;
  logic [31:0] free_status_reg11;
  logic [31:0] free_status_reg12;
  logic [31:0] free_status_reg13;
  logic [31:0] free_status_reg14;
  logic [31:0] free_status_reg15;
  free_control_s_axi #(
    .C_S_AXI_ADDR_WIDTH( 32 ),
    .C_S_AXI_DATA_WIDTH( 32 )
  )
  FREE_CONTROL_REG_FILE (
    .ACLK    (clk_main_a0),
    .ARESET  (~sh_ocl_sync_rst_n),
    .ACLK_EN (1'b1),
    .AWADDR  (sh_ocl_awaddr_q),
    .AWVALID (sh_ocl_awvalid_q),
    .AWREADY (ocl_sh_awready_q),
    .WDATA   (sh_ocl_wdata_q),
    .WSTRB   (sh_ocl_wstrb_q),
    .WVALID  (sh_ocl_wvalid_q),
    .WREADY  (ocl_sh_wready_q),
    .BRESP   (ocl_sh_bresp_q),
    .BVALID  (ocl_sh_bvalid_q),
    .BREADY  (sh_ocl_bready_q),
    .ARADDR  (sh_ocl_araddr_q),
    .ARVALID (sh_ocl_arvalid_q),
    .ARREADY (ocl_sh_arready_q),
    .RDATA   (ocl_sh_rdata_q),
    .RRESP   (ocl_sh_rresp_q),
    .RVALID  (ocl_sh_rvalid_q),
    .RREADY  (sh_ocl_rready_q),
    .control_reg0  (free_control_reg0 ),
    .control_reg1  (free_control_reg1 ),
    .control_reg2  (free_control_reg2 ),
    .control_reg3  (free_control_reg3 ),
    .control_reg4  (free_control_reg4 ),
    .control_reg5  (free_control_reg5 ),
    .control_reg6  (free_control_reg6 ),
    .control_reg7  (free_control_reg7 ),
    .control_reg8  (free_control_reg8 ),
    .control_reg9  (free_control_reg9 ),
    .control_reg10 (free_control_reg10),
    .control_reg11 (free_control_reg11),
    .control_reg12 (free_control_reg12),
    .control_reg13 (free_control_reg13),
    .control_reg14 (free_control_reg14),
    .control_reg15 (free_control_reg15),
    .status_reg0   (start_count_r ),
    .status_reg1   (done_count_r ),
    .status_reg2   (free_status_reg2 ),
    .status_reg3   (free_status_reg3 ),
    .status_reg4   (free_status_reg4 ),
    .status_reg5   (free_status_reg5 ),
    .status_reg6   (free_status_reg6 ),
    .status_reg7   (free_status_reg7 ),
    .status_reg8   (free_status_reg8 ),
    .status_reg9   (free_status_reg9 ),
    .status_reg10  (free_status_reg10),
    .status_reg11  (free_status_reg11),
    .status_reg12  (free_status_reg12),
    .status_reg13  (free_status_reg13),
    .status_reg14  (free_status_reg14),
    .status_reg15  (free_status_reg15)
  );

  //Assign status registers here
  always_ff @(posedge clk_main_a0) begin
    if(!sh_ocl_sync_rst_n) begin
      start_count_r <= 32'd0;
    end
    else begin
      if (start) begin
        start_count_r <= start_count_r + 1'b1;
      end
    end
  end

  always_ff @(posedge clk_main_a0) begin
    if(!sh_ocl_sync_rst_n) begin
      done_count_r <= 32'd0;
    end
    else begin
      if(done) begin
        done_count_r <= done_count_r + 1'b1;
      end
    end
  end

  //----------------------------------------- 
  // DDR
  //-----------------------------------------
  `ifdef USE_DRAM
    //Connect DDR C if defined
    `ifdef USE_DDR_C
      assign cl_sh_ddr_awid = cl_sh_ddr_bus.awid;
      assign cl_sh_ddr_awaddr = cl_sh_ddr_bus.awaddr;
      assign cl_sh_ddr_awlen = cl_sh_ddr_bus.awlen;
      assign cl_sh_ddr_awsize = cl_sh_ddr_bus.awsize;
      assign cl_sh_ddr_awvalid = cl_sh_ddr_bus.awvalid;
      assign cl_sh_ddr_bus.awready = sh_cl_ddr_awready;
      assign cl_sh_ddr_wid = 16'b0;
      assign cl_sh_ddr_wdata = cl_sh_ddr_bus.wdata;
      assign cl_sh_ddr_wstrb = cl_sh_ddr_bus.wstrb;
      assign cl_sh_ddr_wlast = cl_sh_ddr_bus.wlast;
      assign cl_sh_ddr_wvalid = cl_sh_ddr_bus.wvalid;
      assign cl_sh_ddr_bus.wready = sh_cl_ddr_wready;
      assign cl_sh_ddr_bus.bid = sh_cl_ddr_bid;
      assign cl_sh_ddr_bus.bresp = sh_cl_ddr_bresp;
      assign cl_sh_ddr_bus.bvalid = sh_cl_ddr_bvalid;
      assign cl_sh_ddr_bready = cl_sh_ddr_bus.bready;
      assign cl_sh_ddr_arid = cl_sh_ddr_bus.arid;
      assign cl_sh_ddr_araddr = cl_sh_ddr_bus.araddr;
      assign cl_sh_ddr_arlen = cl_sh_ddr_bus.arlen;
      assign cl_sh_ddr_arsize = cl_sh_ddr_bus.arsize;
      assign cl_sh_ddr_arvalid = cl_sh_ddr_bus.arvalid;
      assign cl_sh_ddr_bus.arready = sh_cl_ddr_arready;
      assign cl_sh_ddr_bus.rid = sh_cl_ddr_rid;
      assign cl_sh_ddr_bus.rresp = sh_cl_ddr_rresp;
      assign cl_sh_ddr_bus.rvalid = sh_cl_ddr_rvalid;
      assign cl_sh_ddr_bus.rdata = sh_cl_ddr_rdata;
      assign cl_sh_ddr_bus.rlast = sh_cl_ddr_rlast;
      assign cl_sh_ddr_rready = cl_sh_ddr_bus.rready;
      // Unused *burst signals
      assign cl_sh_ddr_arburst[1:0] = 2'b01;
      assign cl_sh_ddr_awburst[1:0] = 2'b01;
    `else
      `include "unused_ddr_c_template.inc"
      assign cl_sh_ddr_bus.awready = 1'b0;
      assign cl_sh_ddr_bus.wready = 1'b0;
      assign cl_sh_ddr_bus.bid = 16'b0;
      assign cl_sh_ddr_bus.bresp = 2'b0;
      assign cl_sh_ddr_bus.bvalid = 1'b0;
      assign cl_sh_ddr_bus.arready = 1'b0;
      assign cl_sh_ddr_bus.rid = 16'b0;
      assign cl_sh_ddr_bus.rresp = 2'b0;
      assign cl_sh_ddr_bus.rvalid = 1'b0;
      assign cl_sh_ddr_bus.rdata = 512'b0;
      assign cl_sh_ddr_bus.rlast = 1'b0;
    `endif

    //Connect PCIs to internal wire
    assign sh_cl_dma_pcis_bus.awvalid = sh_cl_dma_pcis_awvalid;
    assign sh_cl_dma_pcis_bus.awaddr = sh_cl_dma_pcis_awaddr;
    assign sh_cl_dma_pcis_bus.awid = {10'd0, sh_cl_dma_pcis_awid};
    assign sh_cl_dma_pcis_bus.awlen = sh_cl_dma_pcis_awlen;
    assign sh_cl_dma_pcis_bus.awsize = sh_cl_dma_pcis_awsize;
    assign cl_sh_dma_pcis_awready = sh_cl_dma_pcis_bus.awready;
    assign sh_cl_dma_pcis_bus.wid = 16'd0;
    assign sh_cl_dma_pcis_bus.wvalid = sh_cl_dma_pcis_wvalid;
    assign sh_cl_dma_pcis_bus.wdata = sh_cl_dma_pcis_wdata;
    assign sh_cl_dma_pcis_bus.wstrb = sh_cl_dma_pcis_wstrb;
    assign sh_cl_dma_pcis_bus.wlast = sh_cl_dma_pcis_wlast;
    assign cl_sh_dma_pcis_wready = sh_cl_dma_pcis_bus.wready;
    assign cl_sh_dma_pcis_bvalid = sh_cl_dma_pcis_bus.bvalid;
    assign cl_sh_dma_pcis_bresp = sh_cl_dma_pcis_bus.bresp;
    assign sh_cl_dma_pcis_bus.bready = sh_cl_dma_pcis_bready;
    assign cl_sh_dma_pcis_bid = sh_cl_dma_pcis_bus.bid[5:0];
    assign sh_cl_dma_pcis_bus.arvalid = sh_cl_dma_pcis_arvalid;
    assign sh_cl_dma_pcis_bus.araddr = sh_cl_dma_pcis_araddr;
    assign sh_cl_dma_pcis_bus.arid = {10'd0, sh_cl_dma_pcis_arid};
    assign sh_cl_dma_pcis_bus.arlen = sh_cl_dma_pcis_arlen;
    assign sh_cl_dma_pcis_bus.arsize = sh_cl_dma_pcis_arsize;
    assign cl_sh_dma_pcis_arready = sh_cl_dma_pcis_bus.arready;
    assign cl_sh_dma_pcis_rvalid = sh_cl_dma_pcis_bus.rvalid;
    assign cl_sh_dma_pcis_rid = sh_cl_dma_pcis_bus.rid[5:0];
    assign cl_sh_dma_pcis_rlast = sh_cl_dma_pcis_bus.rlast;
    assign cl_sh_dma_pcis_rresp = sh_cl_dma_pcis_bus.rresp;
    assign cl_sh_dma_pcis_rdata = sh_cl_dma_pcis_bus.rdata;
    assign sh_cl_dma_pcis_bus.rready = sh_cl_dma_pcis_rready;
    // Unused 'full' signals
    assign cl_sh_dma_rd_full  = 1'b0;
    assign cl_sh_dma_wr_full  = 1'b0;

    //TODO: Replace this with axi master from application!!!
    // assign cl_axi_mstr_bus.awid     =  16'b0;
    // assign cl_axi_mstr_bus.awaddr   =  64'b0;
    // assign cl_axi_mstr_bus.awlen    =   8'b0;
    // assign cl_axi_mstr_bus.awsize   =   3'b0;
    // assign cl_axi_mstr_bus.awvalid  =   1'b0;
    // assign cl_axi_mstr_bus.wid      =  16'b0;
    // assign cl_axi_mstr_bus.wdata    = 512'b0;
    // assign cl_axi_mstr_bus.wstrb    =  64'b0;
    // assign cl_axi_mstr_bus.wlast    =   1'b0;
    // assign cl_axi_mstr_bus.wvalid   =   1'b0;
    // assign cl_axi_mstr_bus.bready   =   1'b0;
    // assign cl_axi_mstr_bus.arid     =  16'b0;
    // assign cl_axi_mstr_bus.araddr   =  64'b0;
    // assign cl_axi_mstr_bus.arlen    =   8'b0;
    // assign cl_axi_mstr_bus.arsize   =   3'b0;
    // assign cl_axi_mstr_bus.arvalid  =   1'b0;
    // assign cl_axi_mstr_bus.rready   =   1'b0;

    (* dont_touch = "true" *) logic dma_ddr_slv_sync_rst_n;
    lib_pipe #(.WIDTH(1), .STAGES(4)) DMA_DDR_SLV_SLC_RST_N (
      .clk(clk_main_a0), .rst_n(1'b1), .in_bus(sync_rst_n), .out_bus(dma_ddr_slv_sync_rst_n));
    free_dma_ddr_slv CL_DMA_DDR_SLV(
      .aclk(clk_main_a0),
      .aresetn(dma_ddr_slv_sync_rst_n),
      .sh_cl_dma_pcis_bus(sh_cl_dma_pcis_bus),
      .cl_axi_mstr_bus(cl_axi_mstr_bus),
      .lcl_cl_sh_ddra(lcl_cl_sh_ddra),
      .lcl_cl_sh_ddrb(lcl_cl_sh_ddrb),
      .lcl_cl_sh_ddrd(lcl_cl_sh_ddrd),
      .cl_sh_ddr     (cl_sh_ddr_bus)
    );

    //Instantiate controller
    logic [7:0] sh_ddr_stat_addr_q[2:0];
    logic[2:0] sh_ddr_stat_wr_q;
    logic[2:0] sh_ddr_stat_rd_q; 
    logic[31:0] sh_ddr_stat_wdata_q[2:0];
    logic[2:0] ddr_sh_stat_ack_q;
    logic[31:0] ddr_sh_stat_rdata_q[2:0];
    logic[7:0] ddr_sh_stat_int_q[2:0];
    
    
    lib_pipe #(.WIDTH(1+1+8+32), .STAGES(8)) PIPE_DDR_STAT0 (.clk(clk_main_a0), .rst_n(sync_rst_n),
                                                   .in_bus({sh_ddr_stat_wr0, sh_ddr_stat_rd0, sh_ddr_stat_addr0, sh_ddr_stat_wdata0}),
                                                   .out_bus({sh_ddr_stat_wr_q[0], sh_ddr_stat_rd_q[0], sh_ddr_stat_addr_q[0], sh_ddr_stat_wdata_q[0]})
                                                   );
    
    
    lib_pipe #(.WIDTH(1+8+32), .STAGES(8)) PIPE_DDR_STAT_ACK0 (.clk(clk_main_a0), .rst_n(sync_rst_n),
                                                   .in_bus({ddr_sh_stat_ack_q[0], ddr_sh_stat_int_q[0], ddr_sh_stat_rdata_q[0]}),
                                                   .out_bus({ddr_sh_stat_ack0, ddr_sh_stat_int0, ddr_sh_stat_rdata0})
                                                   );
    
    
    lib_pipe #(.WIDTH(1+1+8+32), .STAGES(8)) PIPE_DDR_STAT1 (.clk(clk_main_a0), .rst_n(sync_rst_n),
                                                   .in_bus({sh_ddr_stat_wr1, sh_ddr_stat_rd1, sh_ddr_stat_addr1, sh_ddr_stat_wdata1}),
                                                   .out_bus({sh_ddr_stat_wr_q[1], sh_ddr_stat_rd_q[1], sh_ddr_stat_addr_q[1], sh_ddr_stat_wdata_q[1]})
                                                   );
    
    
    lib_pipe #(.WIDTH(1+8+32), .STAGES(8)) PIPE_DDR_STAT_ACK1 (.clk(clk_main_a0), .rst_n(sync_rst_n),
                                                   .in_bus({ddr_sh_stat_ack_q[1], ddr_sh_stat_int_q[1], ddr_sh_stat_rdata_q[1]}),
                                                   .out_bus({ddr_sh_stat_ack1, ddr_sh_stat_int1, ddr_sh_stat_rdata1})
                                                   );
    
    lib_pipe #(.WIDTH(1+1+8+32), .STAGES(8)) PIPE_DDR_STAT2 (.clk(clk_main_a0), .rst_n(sync_rst_n),
                                                   .in_bus({sh_ddr_stat_wr2, sh_ddr_stat_rd2, sh_ddr_stat_addr2, sh_ddr_stat_wdata2}),
                                                   .out_bus({sh_ddr_stat_wr_q[2], sh_ddr_stat_rd_q[2], sh_ddr_stat_addr_q[2], sh_ddr_stat_wdata_q[2]})
                                                   );
    
    
    lib_pipe #(.WIDTH(1+8+32), .STAGES(8)) PIPE_DDR_STAT_ACK2 (.clk(clk_main_a0), .rst_n(sync_rst_n),
                                                   .in_bus({ddr_sh_stat_ack_q[2], ddr_sh_stat_int_q[2], ddr_sh_stat_rdata_q[2]}),
                                                   .out_bus({ddr_sh_stat_ack2, ddr_sh_stat_int2, ddr_sh_stat_rdata2})
                                                   ); 
    
    //convert to 2D 
    logic[15:0] cl_sh_ddr_awid_2d[2:0];
    logic[63:0] cl_sh_ddr_awaddr_2d[2:0];
    logic[7:0] cl_sh_ddr_awlen_2d[2:0];
    logic[2:0] cl_sh_ddr_awsize_2d[2:0];
    logic[1:0] cl_sh_ddr_awburst_2d[2:0];
    logic cl_sh_ddr_awvalid_2d [2:0];
    logic[2:0] sh_cl_ddr_awready_2d;
    
    logic[15:0] cl_sh_ddr_wid_2d[2:0];
    logic[511:0] cl_sh_ddr_wdata_2d[2:0];
    logic[63:0] cl_sh_ddr_wstrb_2d[2:0];
    logic[2:0] cl_sh_ddr_wlast_2d;
    logic[2:0] cl_sh_ddr_wvalid_2d;
    logic[2:0] sh_cl_ddr_wready_2d;
    
    logic[15:0] sh_cl_ddr_bid_2d[2:0];
    logic[1:0] sh_cl_ddr_bresp_2d[2:0];
    logic[2:0] sh_cl_ddr_bvalid_2d;
    logic[2:0] cl_sh_ddr_bready_2d;
    
    logic[15:0] cl_sh_ddr_arid_2d[2:0];
    logic[63:0] cl_sh_ddr_araddr_2d[2:0];
    logic[7:0] cl_sh_ddr_arlen_2d[2:0];
    logic[2:0] cl_sh_ddr_arsize_2d[2:0];
    logic[1:0] cl_sh_ddr_arburst_2d[2:0];
    logic[2:0] cl_sh_ddr_arvalid_2d;
    logic[2:0] sh_cl_ddr_arready_2d;
    
    logic[15:0] sh_cl_ddr_rid_2d[2:0];
    logic[511:0] sh_cl_ddr_rdata_2d[2:0];
    logic[1:0] sh_cl_ddr_rresp_2d[2:0];
    logic[2:0] sh_cl_ddr_rlast_2d;
    logic[2:0] sh_cl_ddr_rvalid_2d;
    logic[2:0] cl_sh_ddr_rready_2d;
    
    assign cl_sh_ddr_awid_2d = '{lcl_cl_sh_ddrd.awid, lcl_cl_sh_ddrb.awid, lcl_cl_sh_ddra.awid};
    assign cl_sh_ddr_awaddr_2d = '{lcl_cl_sh_ddrd.awaddr, lcl_cl_sh_ddrb.awaddr, lcl_cl_sh_ddra.awaddr};
    assign cl_sh_ddr_awlen_2d = '{lcl_cl_sh_ddrd.awlen, lcl_cl_sh_ddrb.awlen, lcl_cl_sh_ddra.awlen};
    assign cl_sh_ddr_awsize_2d = '{lcl_cl_sh_ddrd.awsize, lcl_cl_sh_ddrb.awsize, lcl_cl_sh_ddra.awsize};
    assign cl_sh_ddr_awvalid_2d = '{lcl_cl_sh_ddrd.awvalid, lcl_cl_sh_ddrb.awvalid, lcl_cl_sh_ddra.awvalid};
    assign cl_sh_ddr_awburst_2d = {2'b01, 2'b01, 2'b01};
    assign {lcl_cl_sh_ddrd.awready, lcl_cl_sh_ddrb.awready, lcl_cl_sh_ddra.awready} = sh_cl_ddr_awready_2d;
    
    assign cl_sh_ddr_wid_2d = '{lcl_cl_sh_ddrd.wid, lcl_cl_sh_ddrb.wid, lcl_cl_sh_ddra.wid};
    assign cl_sh_ddr_wdata_2d = '{lcl_cl_sh_ddrd.wdata, lcl_cl_sh_ddrb.wdata, lcl_cl_sh_ddra.wdata};
    assign cl_sh_ddr_wstrb_2d = '{lcl_cl_sh_ddrd.wstrb, lcl_cl_sh_ddrb.wstrb, lcl_cl_sh_ddra.wstrb};
    assign cl_sh_ddr_wlast_2d = {lcl_cl_sh_ddrd.wlast, lcl_cl_sh_ddrb.wlast, lcl_cl_sh_ddra.wlast};
    assign cl_sh_ddr_wvalid_2d = {lcl_cl_sh_ddrd.wvalid, lcl_cl_sh_ddrb.wvalid, lcl_cl_sh_ddra.wvalid};
    assign {lcl_cl_sh_ddrd.wready, lcl_cl_sh_ddrb.wready, lcl_cl_sh_ddra.wready} = sh_cl_ddr_wready_2d;
    
    assign {lcl_cl_sh_ddrd.bid, lcl_cl_sh_ddrb.bid, lcl_cl_sh_ddra.bid} = {sh_cl_ddr_bid_2d[2], sh_cl_ddr_bid_2d[1], sh_cl_ddr_bid_2d[0]};
    assign {lcl_cl_sh_ddrd.bresp, lcl_cl_sh_ddrb.bresp, lcl_cl_sh_ddra.bresp} = {sh_cl_ddr_bresp_2d[2], sh_cl_ddr_bresp_2d[1], sh_cl_ddr_bresp_2d[0]};
    assign {lcl_cl_sh_ddrd.bvalid, lcl_cl_sh_ddrb.bvalid, lcl_cl_sh_ddra.bvalid} = sh_cl_ddr_bvalid_2d;
    assign cl_sh_ddr_bready_2d = {lcl_cl_sh_ddrd.bready, lcl_cl_sh_ddrb.bready, lcl_cl_sh_ddra.bready};
    
    assign cl_sh_ddr_arid_2d = '{lcl_cl_sh_ddrd.arid, lcl_cl_sh_ddrb.arid, lcl_cl_sh_ddra.arid};
    assign cl_sh_ddr_araddr_2d = '{lcl_cl_sh_ddrd.araddr, lcl_cl_sh_ddrb.araddr, lcl_cl_sh_ddra.araddr};
    assign cl_sh_ddr_arlen_2d = '{lcl_cl_sh_ddrd.arlen, lcl_cl_sh_ddrb.arlen, lcl_cl_sh_ddra.arlen};
    assign cl_sh_ddr_arsize_2d = '{lcl_cl_sh_ddrd.arsize, lcl_cl_sh_ddrb.arsize, lcl_cl_sh_ddra.arsize};
    assign cl_sh_ddr_arvalid_2d = {lcl_cl_sh_ddrd.arvalid, lcl_cl_sh_ddrb.arvalid, lcl_cl_sh_ddra.arvalid};
    assign cl_sh_ddr_arburst_2d = {2'b01, 2'b01, 2'b01};
    assign {lcl_cl_sh_ddrd.arready, lcl_cl_sh_ddrb.arready, lcl_cl_sh_ddra.arready} = sh_cl_ddr_arready_2d;
    
    assign {lcl_cl_sh_ddrd.rid, lcl_cl_sh_ddrb.rid, lcl_cl_sh_ddra.rid} = {sh_cl_ddr_rid_2d[2], sh_cl_ddr_rid_2d[1], sh_cl_ddr_rid_2d[0]};
    assign {lcl_cl_sh_ddrd.rresp, lcl_cl_sh_ddrb.rresp, lcl_cl_sh_ddra.rresp} = {sh_cl_ddr_rresp_2d[2], sh_cl_ddr_rresp_2d[1], sh_cl_ddr_rresp_2d[0]};
    assign {lcl_cl_sh_ddrd.rdata, lcl_cl_sh_ddrb.rdata, lcl_cl_sh_ddra.rdata} = {sh_cl_ddr_rdata_2d[2], sh_cl_ddr_rdata_2d[1], sh_cl_ddr_rdata_2d[0]};
    assign {lcl_cl_sh_ddrd.rlast, lcl_cl_sh_ddrb.rlast, lcl_cl_sh_ddra.rlast} = sh_cl_ddr_rlast_2d;
    assign {lcl_cl_sh_ddrd.rvalid, lcl_cl_sh_ddrb.rvalid, lcl_cl_sh_ddra.rvalid} = sh_cl_ddr_rvalid_2d;
    assign cl_sh_ddr_rready_2d = {lcl_cl_sh_ddrd.rready, lcl_cl_sh_ddrb.rready, lcl_cl_sh_ddra.rready};
    
    (* dont_touch = "true" *) logic sh_ddr_sync_rst_n;
    lib_pipe #(.WIDTH(1), .STAGES(4)) SH_DDR_SLC_RST_N (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(sync_rst_n), .out_bus(sh_ddr_sync_rst_n));
    sh_ddr #(
      `ifdef USE_DDR_A
        .DDR_A_PRESENT(1),
      `else
        .DDR_A_PRESENT(0),
      `endif
      `ifdef USE_DDR_B
        .DDR_B_PRESENT(1),
      `else
        .DDR_B_PRESENT(0),
      `endif
      `ifdef USE_DDR_D
        .DDR_D_PRESENT(1)
      `else
        .DDR_D_PRESENT(0)
      `endif
       ) SH_DDR
       (
       .clk(clk_main_a0),
       .rst_n(sh_ddr_sync_rst_n),
    
       .stat_clk(clk_main_a0),
       .stat_rst_n(sh_ddr_sync_rst_n),
    
    
       .CLK_300M_DIMM0_DP(CLK_300M_DIMM0_DP),
       .CLK_300M_DIMM0_DN(CLK_300M_DIMM0_DN),
       .M_A_ACT_N(M_A_ACT_N),
       .M_A_MA(M_A_MA),
       .M_A_BA(M_A_BA),
       .M_A_BG(M_A_BG),
       .M_A_CKE(M_A_CKE),
       .M_A_ODT(M_A_ODT),
       .M_A_CS_N(M_A_CS_N),
       .M_A_CLK_DN(M_A_CLK_DN),
       .M_A_CLK_DP(M_A_CLK_DP),
       .M_A_PAR(M_A_PAR),
       .M_A_DQ(M_A_DQ),
       .M_A_ECC(M_A_ECC),
       .M_A_DQS_DP(M_A_DQS_DP),
       .M_A_DQS_DN(M_A_DQS_DN),
       .cl_RST_DIMM_A_N(cl_RST_DIMM_A_N),
       
       
       .CLK_300M_DIMM1_DP(CLK_300M_DIMM1_DP),
       .CLK_300M_DIMM1_DN(CLK_300M_DIMM1_DN),
       .M_B_ACT_N(M_B_ACT_N),
       .M_B_MA(M_B_MA),
       .M_B_BA(M_B_BA),
       .M_B_BG(M_B_BG),
       .M_B_CKE(M_B_CKE),
       .M_B_ODT(M_B_ODT),
       .M_B_CS_N(M_B_CS_N),
       .M_B_CLK_DN(M_B_CLK_DN),
       .M_B_CLK_DP(M_B_CLK_DP),
       .M_B_PAR(M_B_PAR),
       .M_B_DQ(M_B_DQ),
       .M_B_ECC(M_B_ECC),
       .M_B_DQS_DP(M_B_DQS_DP),
       .M_B_DQS_DN(M_B_DQS_DN),
       .cl_RST_DIMM_B_N(cl_RST_DIMM_B_N),
    
       .CLK_300M_DIMM3_DP(CLK_300M_DIMM3_DP),
       .CLK_300M_DIMM3_DN(CLK_300M_DIMM3_DN),
       .M_D_ACT_N(M_D_ACT_N),
       .M_D_MA(M_D_MA),
       .M_D_BA(M_D_BA),
       .M_D_BG(M_D_BG),
       .M_D_CKE(M_D_CKE),
       .M_D_ODT(M_D_ODT),
       .M_D_CS_N(M_D_CS_N),
       .M_D_CLK_DN(M_D_CLK_DN),
       .M_D_CLK_DP(M_D_CLK_DP),
       .M_D_PAR(M_D_PAR),
       .M_D_DQ(M_D_DQ),
       .M_D_ECC(M_D_ECC),
       .M_D_DQS_DP(M_D_DQS_DP),
       .M_D_DQS_DN(M_D_DQS_DN),
       .cl_RST_DIMM_D_N(cl_RST_DIMM_D_N),
    
       //------------------------------------------------------
       // DDR-4 Interface from CL (AXI-4)
       //------------------------------------------------------
       .cl_sh_ddr_awid(cl_sh_ddr_awid_2d),
       .cl_sh_ddr_awaddr(cl_sh_ddr_awaddr_2d),
       .cl_sh_ddr_awlen(cl_sh_ddr_awlen_2d),
       .cl_sh_ddr_awsize(cl_sh_ddr_awsize_2d),
       .cl_sh_ddr_awvalid(cl_sh_ddr_awvalid_2d),
       .cl_sh_ddr_awburst(cl_sh_ddr_awburst_2d),
       .sh_cl_ddr_awready(sh_cl_ddr_awready_2d),
    
       .cl_sh_ddr_wid(cl_sh_ddr_wid_2d),
       .cl_sh_ddr_wdata(cl_sh_ddr_wdata_2d),
       .cl_sh_ddr_wstrb(cl_sh_ddr_wstrb_2d),
       .cl_sh_ddr_wlast(cl_sh_ddr_wlast_2d),
       .cl_sh_ddr_wvalid(cl_sh_ddr_wvalid_2d),
       .sh_cl_ddr_wready(sh_cl_ddr_wready_2d),
    
       .sh_cl_ddr_bid(sh_cl_ddr_bid_2d),
       .sh_cl_ddr_bresp(sh_cl_ddr_bresp_2d),
       .sh_cl_ddr_bvalid(sh_cl_ddr_bvalid_2d),
       .cl_sh_ddr_bready(cl_sh_ddr_bready_2d),
    
       .cl_sh_ddr_arid(cl_sh_ddr_arid_2d),
       .cl_sh_ddr_araddr(cl_sh_ddr_araddr_2d),
       .cl_sh_ddr_arlen(cl_sh_ddr_arlen_2d),
       .cl_sh_ddr_arsize(cl_sh_ddr_arsize_2d),
       .cl_sh_ddr_arvalid(cl_sh_ddr_arvalid_2d),
       .cl_sh_ddr_arburst(cl_sh_ddr_arburst_2d),
       .sh_cl_ddr_arready(sh_cl_ddr_arready_2d),
    
       .sh_cl_ddr_rid(sh_cl_ddr_rid_2d),
       .sh_cl_ddr_rdata(sh_cl_ddr_rdata_2d),
       .sh_cl_ddr_rresp(sh_cl_ddr_rresp_2d),
       .sh_cl_ddr_rlast(sh_cl_ddr_rlast_2d),
       .sh_cl_ddr_rvalid(sh_cl_ddr_rvalid_2d),
       .cl_sh_ddr_rready(cl_sh_ddr_rready_2d),
    
       .sh_cl_ddr_is_ready(),
    
       .sh_ddr_stat_addr0  (sh_ddr_stat_addr_q[0]) ,
       .sh_ddr_stat_wr0    (sh_ddr_stat_wr_q[0]     ) , 
       .sh_ddr_stat_rd0    (sh_ddr_stat_rd_q[0]     ) , 
       .sh_ddr_stat_wdata0 (sh_ddr_stat_wdata_q[0]  ) , 
       .ddr_sh_stat_ack0   (ddr_sh_stat_ack_q[0]    ) ,
       .ddr_sh_stat_rdata0 (ddr_sh_stat_rdata_q[0]  ),
       .ddr_sh_stat_int0   (ddr_sh_stat_int_q[0]    ),
    
       .sh_ddr_stat_addr1  (sh_ddr_stat_addr_q[1]) ,
       .sh_ddr_stat_wr1    (sh_ddr_stat_wr_q[1]     ) , 
       .sh_ddr_stat_rd1    (sh_ddr_stat_rd_q[1]     ) , 
       .sh_ddr_stat_wdata1 (sh_ddr_stat_wdata_q[1]  ) , 
       .ddr_sh_stat_ack1   (ddr_sh_stat_ack_q[1]    ) ,
       .ddr_sh_stat_rdata1 (ddr_sh_stat_rdata_q[1]  ),
       .ddr_sh_stat_int1   (ddr_sh_stat_int_q[1]    ),
    
       .sh_ddr_stat_addr2  (sh_ddr_stat_addr_q[2]) ,
       .sh_ddr_stat_wr2    (sh_ddr_stat_wr_q[2]     ) , 
       .sh_ddr_stat_rd2    (sh_ddr_stat_rd_q[2]     ) , 
       .sh_ddr_stat_wdata2 (sh_ddr_stat_wdata_q[2]  ) , 
       .ddr_sh_stat_ack2   (ddr_sh_stat_ack_q[2]    ) ,
       .ddr_sh_stat_rdata2 (ddr_sh_stat_rdata_q[2]  ),
       .ddr_sh_stat_int2   (ddr_sh_stat_int_q[2]    ) 
       );
  `endif

  //----------------------------------------- 
  // Application Logic
  //-----------------------------------------
  //Interpret control signals
  logic start_r;

  //SIngle pulse start
  always_ff @(posedge clk_main_a0) begin
    if (!sh_ocl_sync_rst_n) begin
      start_r <= 0;
    end
    else begin
      start_r <= free_control_reg0[0];
    end
  end
  assign start = ((free_control_reg0[0] == 1'b1) && (start_r == 1'b0)) ? 1'b1 : 1'b0;


  (* dont_touch = "true" *) logic app_sync_rst_n;
  lib_pipe #(.WIDTH(1), .STAGES(4)) DW_RST_N (.clk(clk_main_a0), .rst_n(1'b1), .in_bus(sync_rst_n), .out_bus(app_sync_rst_n));

  cl_sdp_driver #(
    .AXI_ADDR_WIDTH   ( CL_AXI_ADDR_WIDTH   ),
    .AXI_DATA_WIDTH   ( CL_AXI_DATA_WIDTH   ),
    .AXI_ID_WIDTH     ( CL_AXI_ID_WIDTH     ),
    .C_LENGTH_WIDTH   ( 32 )
  ) cl_sdp_driver_inst (
    .clk              ( clk_main_a0    ),
    .rst_n            ( app_sync_rst_n ),
    .start            ( start          ),
    .done             ( done           ),
    .command          ( free_control_reg1 ),
    .storage_addr     ( free_control_reg2 ),
    .memory_addr      ( free_control_reg3 ),
    .file_len         ( free_control_reg4 ),
    .m_axi_awid       (sdp_m_axi_awid    ),
    .m_axi_awaddr     (sdp_m_axi_awaddr  ),
    .m_axi_awlen      (sdp_m_axi_awlen   ),
    .m_axi_awsize     (sdp_m_axi_awsize  ),
    .m_axi_awburst    (sdp_m_axi_awburst ),
    .m_axi_awlock     (sdp_m_axi_awlock  ),
    .m_axi_awcache    (sdp_m_axi_awcache ),
    .m_axi_awprot     (sdp_m_axi_awprot  ),
    .m_axi_awqos      (sdp_m_axi_awqos   ),
    .m_axi_awregion   (sdp_m_axi_awregion),
    .m_axi_awvalid    (sdp_m_axi_awvalid ),
    .m_axi_awready    (sdp_m_axi_awready ),
    .m_axi_wid        (sdp_m_axi_wid     ),
    .m_axi_wdata      (sdp_m_axi_wdata   ),
    .m_axi_wstrb      (sdp_m_axi_wstrb   ),
    .m_axi_wlast      (sdp_m_axi_wlast   ),
    .m_axi_wvalid     (sdp_m_axi_wvalid  ),
    .m_axi_wready     (sdp_m_axi_wready  ),
    .m_axi_bid        (sdp_m_axi_bid     ),
    .m_axi_bresp      (sdp_m_axi_bresp   ),
    .m_axi_bvalid     (sdp_m_axi_bvalid  ),
    .m_axi_bready     (sdp_m_axi_bready  ),
    .m_axi_arid       (sdp_m_axi_arid    ),
    .m_axi_araddr     (sdp_m_axi_araddr  ),
    .m_axi_arlen      (sdp_m_axi_arlen   ),  
    .m_axi_arsize     (sdp_m_axi_arsize  ),
    .m_axi_arburst    (sdp_m_axi_arburst ),
    .m_axi_arlock     (sdp_m_axi_arlock  ),
    .m_axi_arcache    (sdp_m_axi_arcache ),
    .m_axi_arprot     (sdp_m_axi_arprot  ),
    .m_axi_arqos      (sdp_m_axi_arqos   ),
    .m_axi_arregion   (sdp_m_axi_arregion),
    .m_axi_arvalid    (sdp_m_axi_arvalid ),
    .m_axi_arready    (sdp_m_axi_arready ),
    .m_axi_rid        (sdp_m_axi_rid     ),
    .m_axi_rdata      (sdp_m_axi_rdata   ),
    .m_axi_rresp      (sdp_m_axi_rresp   ),
    .m_axi_rlast      (sdp_m_axi_rlast   ),
    .m_axi_rvalid     (sdp_m_axi_rvalid  ),
    .m_axi_rready     (sdp_m_axi_rready  )
  );

  // Axi width converter
  //axi_dwidth_converter_64b_to_512b AXI_DWIDTH_CONVERTER_TO_SH (
  //  .s_axi_aclk               (clk_main_a0),
  //  .s_axi_aresetn            (app_sync_rst_n),
  //  .s_axi_awid               ( sdp_m_axi_awid           ),
  //  .s_axi_awaddr             ( {32'd0, sdp_m_axi_awaddr}),
  //  .s_axi_awlen              ( {4'd0, sdp_m_axi_awlen}  ),
  //  .s_axi_awsize             ( sdp_m_axi_awsize         ),
  //  .s_axi_awburst            ( sdp_m_axi_awburst        ),
  //  .s_axi_awlock             ( sdp_m_axi_awlock         ),
  //  .s_axi_awcache            ( sdp_m_axi_awcache        ),
  //  .s_axi_awprot             ( sdp_m_axi_awprot         ),
  //  .s_axi_awqos              ( sdp_m_axi_awqos          ),
  //  .s_axi_awvalid            ( sdp_m_axi_awvalid        ),
  //  .s_axi_awready            ( sdp_m_axi_awready        ),
  //  .s_axi_wdata              ( sdp_m_axi_wdata          ),
  //  .s_axi_wstrb              ( sdp_m_axi_wstrb          ),
  //  .s_axi_wlast              ( sdp_m_axi_wlast          ),
  //  .s_axi_wvalid             ( sdp_m_axi_wvalid         ),
  //  .s_axi_wready             ( sdp_m_axi_wready         ),
  //  .s_axi_bid                ( sdp_m_axi_bid            ),
  //  .s_axi_bresp              ( sdp_m_axi_bresp          ),
  //  .s_axi_bvalid             ( sdp_m_axi_bvalid         ),
  //  .s_axi_bready             ( sdp_m_axi_bready         ),
  //  .s_axi_arid               ( sdp_m_axi_arid           ),
  //  .s_axi_araddr             ( {32'd0, sdp_m_axi_araddr}),
  //  .s_axi_arlen              ( {4'd0, sdp_m_axi_arlen}  ),
  //  .s_axi_arsize             ( sdp_m_axi_arsize         ),
  //  .s_axi_arburst            ( sdp_m_axi_arburst        ),
  //  .s_axi_arlock             ( sdp_m_axi_arlock         ),
  //  .s_axi_arcache            ( sdp_m_axi_arcache        ),
  //  .s_axi_arprot             ( sdp_m_axi_arprot         ),
  //  .s_axi_arqos              ( sdp_m_axi_arqos          ),
  //  .s_axi_arvalid            ( sdp_m_axi_arvalid        ),
  //  .s_axi_arready            ( sdp_m_axi_arready        ),
  //  .s_axi_rid                ( sdp_m_axi_rid            ),
  //  .s_axi_rdata              ( sdp_m_axi_rdata          ),
  //  .s_axi_rresp              ( sdp_m_axi_rresp          ),
  //  .s_axi_rlast              ( sdp_m_axi_rlast          ),
  //  .s_axi_rvalid             ( sdp_m_axi_rvalid         ),
  //  .s_axi_rready             ( sdp_m_axi_rready         ),
  //  .m_axi_awaddr             ( cl_axi_mstr_bus.awaddr         ),
  //  .m_axi_awlen              ( cl_axi_mstr_bus.awlen          ),
  //  .m_axi_awsize             ( cl_axi_mstr_bus.awsize         ),
  //  .m_axi_awburst            (         ),
  //  .m_axi_awlock             (         ),
  //  .m_axi_awcache            (         ),
  //  .m_axi_awprot             (         ),
  //  .m_axi_awqos              (         ),
  //  .m_axi_awvalid            ( cl_axi_mstr_bus.awvalid        ),
  //  .m_axi_awready            ( cl_axi_mstr_bus.awready        ),
  //  .m_axi_wdata              ( cl_axi_mstr_bus.wdata          ),
  //  .m_axi_wstrb              ( cl_axi_mstr_bus.wstrb          ),
  //  .m_axi_wlast              ( cl_axi_mstr_bus.wlast          ),
  //  .m_axi_wvalid             ( cl_axi_mstr_bus.wvalid         ),
  //  .m_axi_wready             ( cl_axi_mstr_bus.wready         ),
  //  .m_axi_bresp              ( cl_axi_mstr_bus.bresp          ),
  //  .m_axi_bvalid             ( cl_axi_mstr_bus.bvalid         ),
  //  .m_axi_bready             ( cl_axi_mstr_bus.bready         ),
  //  .m_axi_araddr             ( cl_axi_mstr_bus.araddr         ),
  //  .m_axi_arlen              ( cl_axi_mstr_bus.arlen          ),
  //  .m_axi_arsize             ( cl_axi_mstr_bus.arsize         ),
  //  .m_axi_arburst            (         ),
  //  .m_axi_arlock             (         ),
  //  .m_axi_arcache            (         ),
  //  .m_axi_arprot             (         ),
  //  .m_axi_arqos              (         ),
  //  .m_axi_arvalid            ( cl_axi_mstr_bus.arvalid        ),
  //  .m_axi_arready            ( cl_axi_mstr_bus.arready        ),
  //  .m_axi_rdata              ( cl_axi_mstr_bus.rdata          ),
  //  .m_axi_rresp              ( cl_axi_mstr_bus.rresp          ),
  //  .m_axi_rlast              ( cl_axi_mstr_bus.rlast          ),
  //  .m_axi_rvalid             ( cl_axi_mstr_bus.rvalid         ),
  //  .m_axi_rready             ( cl_axi_mstr_bus.rready         )
  //);
  //assign cl_axi_mstr_bus.awid     =  16'b0;
  //assign cl_axi_mstr_bus.wid      =  16'b0;
  //assign cl_axi_mstr_bus.arid     =  16'b0;

  
  // TODO: Connect back once driver works
  //cl_sdp_driver #(
  //  .AXI_ADDR_WIDTH   ( CL_AXI_ADDR_WIDTH   ),
  //  .AXI_DATA_WIDTH   ( CL_AXI_DATA_WIDTH   ),
  //  .AXI_ID_WIDTH     ( CL_AXI_ID_WIDTH     )
  //) cl_sdp_driver_inst (
  //  .clk              ( clk_main_a0    ),
  //  .rst_n            ( app_sync_rst_n ),
  //  .start            ( start          ),
  //  .done             ( done           ),
  //  .m_axi_awid       (sdp_m_axi_awid    ),
  //  .m_axi_awaddr     (sdp_m_axi_awaddr  ),
  //  .m_axi_awlen      (sdp_m_axi_awlen   ),
  //  .m_axi_awsize     (sdp_m_axi_awsize  ),
  //  .m_axi_awburst    (sdp_m_axi_awburst ),
  //  .m_axi_awlock     (sdp_m_axi_awlock  ),
  //  .m_axi_awcache    (sdp_m_axi_awcache ),
  //  .m_axi_awprot     (sdp_m_axi_awprot  ),
  //  .m_axi_awqos      (sdp_m_axi_awqos   ),
  //  .m_axi_awregion   (sdp_m_axi_awregion),
  //  .m_axi_awvalid    (sdp_m_axi_awvalid ),
  //  .m_axi_awready    (sdp_m_axi_awready ),
  //  .m_axi_wid        (sdp_m_axi_wid     ),
  //  .m_axi_wdata      (sdp_m_axi_wdata   ),
  //  .m_axi_wstrb      (sdp_m_axi_wstrb   ),
  //  .m_axi_wlast      (sdp_m_axi_wlast   ),
  //  .m_axi_wvalid     (sdp_m_axi_wvalid  ),
  //  .m_axi_wready     (sdp_m_axi_wready  ),
  //  .m_axi_bid        (sdp_m_axi_bid     ),
  //  .m_axi_bresp      (sdp_m_axi_bresp   ),
  //  .m_axi_bvalid     (sdp_m_axi_bvalid  ),
  //  .m_axi_bready     (sdp_m_axi_bready  ),
  //  .m_axi_arid       (sdp_m_axi_arid    ),
  //  .m_axi_araddr     (sdp_m_axi_araddr  ),
  //  .m_axi_arlen      (sdp_m_axi_arlen   ),  
  //  .m_axi_arsize     (sdp_m_axi_arsize  ),
  //  .m_axi_arburst    (sdp_m_axi_arburst ),
  //  .m_axi_arlock     (sdp_m_axi_arlock  ),
  //  .m_axi_arcache    (sdp_m_axi_arcache ),
  //  .m_axi_arprot     (sdp_m_axi_arprot  ),
  //  .m_axi_arqos      (sdp_m_axi_arqos   ),
  //  .m_axi_arregion   (sdp_m_axi_arregion),
  //  .m_axi_arvalid    (sdp_m_axi_arvalid ),
  //  .m_axi_arready    (sdp_m_axi_arready ),
  //  .m_axi_rid        (sdp_m_axi_rid     ),
  //  .m_axi_rdata      (sdp_m_axi_rdata   ),
  //  .m_axi_rresp      (sdp_m_axi_rresp   ),
  //  .m_axi_rlast      (sdp_m_axi_rlast   ),
  //  .m_axi_rvalid     (sdp_m_axi_rvalid  ),
  //  .m_axi_rready     (sdp_m_axi_rready  )
  //);
  //Shield module
  shield_wrapper #(
    .AXI_ADDR_WIDTH(64),
    .AXI_ID_WIDTH(16),
    .AXI_DATA_WIDTH(512),
    .CL_ADDR_WIDTH(64),
    .CL_ID_WIDTH(16),
    .CL_DATA_WIDTH(CL_AXI_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(32),
    .LINE_WIDTH(512),
    .CACHE_DEPTH(256)
  )
  shield_wrapper_inst(
    .clk(clk_main_a0),
    .rst_n(app_sync_rst_n),
    .s_axi_awid           (sdp_m_axi_awid    ),
    .s_axi_awaddr         ({32'd0, sdp_m_axi_awaddr}  ),
    .s_axi_awlen          (sdp_m_axi_awlen   ),
    .s_axi_awsize         (sdp_m_axi_awsize  ),
    .s_axi_awburst        (sdp_m_axi_awburst ),
    .s_axi_awlock         (sdp_m_axi_awlock  ),
    .s_axi_awcache        (sdp_m_axi_awcache ),
    .s_axi_awprot         (sdp_m_axi_awprot  ),
    .s_axi_awqos          (sdp_m_axi_awqos   ),
    .s_axi_awregion       (sdp_m_axi_awregion),
    .s_axi_awvalid        (sdp_m_axi_awvalid ),
    .s_axi_awready        (sdp_m_axi_awready ),
    .s_axi_wid            (sdp_m_axi_wid     ),
    .s_axi_wdata          (sdp_m_axi_wdata   ),
    .s_axi_wstrb          (sdp_m_axi_wstrb   ),
    .s_axi_wlast          (sdp_m_axi_wlast   ),
    .s_axi_wvalid         (sdp_m_axi_wvalid  ),
    .s_axi_wready         (sdp_m_axi_wready  ),
    .s_axi_bid            (sdp_m_axi_bid     ),
    .s_axi_bresp          (sdp_m_axi_bresp   ),
    .s_axi_bvalid         (sdp_m_axi_bvalid  ),
    .s_axi_bready         (sdp_m_axi_bready  ),
    .s_axi_arid           (sdp_m_axi_arid    ),
    .s_axi_araddr         ({32'd0, sdp_m_axi_araddr}  ),
    .s_axi_arlen          (sdp_m_axi_arlen   ),
    .s_axi_arsize         (sdp_m_axi_arsize  ),
    .s_axi_arburst        (sdp_m_axi_arburst ),
    .s_axi_arlock         (sdp_m_axi_arlock  ),
    .s_axi_arcache        (sdp_m_axi_arcache ),
    .s_axi_arprot         (sdp_m_axi_arprot  ),
    .s_axi_arqos          (sdp_m_axi_arqos   ),
    .s_axi_arregion       (sdp_m_axi_arregion),
    .s_axi_arvalid        (sdp_m_axi_arvalid ),
    .s_axi_arready        (sdp_m_axi_arready ),
    .s_axi_rid            (sdp_m_axi_rid     ),
    .s_axi_rdata          (sdp_m_axi_rdata   ),
    .s_axi_rresp          (sdp_m_axi_rresp   ),
    .s_axi_rlast          (sdp_m_axi_rlast   ),
    .s_axi_rvalid         (sdp_m_axi_rvalid  ),
    .s_axi_rready         (sdp_m_axi_rready  ),
    .m_axi_awid           (cl_axi_mstr_bus.awid    ),
    .m_axi_awaddr         (cl_axi_mstr_bus.awaddr  ),
    .m_axi_awlen          (cl_axi_mstr_bus.awlen   ),
    .m_axi_awsize         (cl_axi_mstr_bus.awsize  ),
    .m_axi_awburst        ( ),
    .m_axi_awlock         ( ),
    .m_axi_awcache        ( ),
    .m_axi_awprot         ( ),
    .m_axi_awqos          ( ),
    .m_axi_awregion       (),
    .m_axi_awvalid        (cl_axi_mstr_bus.awvalid ),
    .m_axi_awready        (cl_axi_mstr_bus.awready ),
    .m_axi_wid            (cl_axi_mstr_bus.wid     ),
    .m_axi_wdata          (cl_axi_mstr_bus.wdata   ),
    .m_axi_wstrb          (cl_axi_mstr_bus.wstrb   ),
    .m_axi_wlast          (cl_axi_mstr_bus.wlast   ),
    .m_axi_wvalid         (cl_axi_mstr_bus.wvalid  ),
    .m_axi_wready         (cl_axi_mstr_bus.wready  ),
    .m_axi_bid            (cl_axi_mstr_bus.bid     ),
    .m_axi_bresp          (cl_axi_mstr_bus.bresp   ),
    .m_axi_bvalid         (cl_axi_mstr_bus.bvalid  ),
    .m_axi_bready         (cl_axi_mstr_bus.bready  ),
    .m_axi_arid           (cl_axi_mstr_bus.arid    ),
    .m_axi_araddr         (cl_axi_mstr_bus.araddr  ),
    .m_axi_arlen          (cl_axi_mstr_bus.arlen   ),
    .m_axi_arsize         (cl_axi_mstr_bus.arsize  ),
    .m_axi_arburst        ( ),
    .m_axi_arlock         ( ),
    .m_axi_arcache        ( ),
    .m_axi_arprot         ( ),
    .m_axi_arqos          ( ),
    .m_axi_arregion       (),
    .m_axi_arvalid        (cl_axi_mstr_bus.arvalid ),
    .m_axi_arready        (cl_axi_mstr_bus.arready ),
    .m_axi_rid            (cl_axi_mstr_bus.rid     ),
    .m_axi_rdata          (cl_axi_mstr_bus.rdata   ),
    .m_axi_rresp          (cl_axi_mstr_bus.rresp   ),
    .m_axi_rlast          (cl_axi_mstr_bus.rlast   ),
    .m_axi_rvalid         (cl_axi_mstr_bus.rvalid  ),
    .m_axi_rready         (cl_axi_mstr_bus.rready  ),
    .shield_state         (shield_state)
  );



endmodule
