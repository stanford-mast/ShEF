//Mark Zhao
//8/26/20
//simple muxes for axi

module axi_read_mux
#(
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer AXI_ID_WIDTH = 16,
  parameter integer AXI_DATA_WIDTH = 512,
  parameter integer CL_ADDR_WIDTH = 64,
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64
)(
  input  logic [AXI_ID_WIDTH-1:0]    shield_m_axi_arid    ,
  input  logic [AXI_ADDR_WIDTH-1:0]  shield_m_axi_araddr  ,
  input  logic [7:0]                 shield_m_axi_arlen   ,
  input  logic [2:0]                 shield_m_axi_arsize  ,
  input  logic [1:0]                 shield_m_axi_arburst ,
  input  logic [1:0]                 shield_m_axi_arlock  ,
  input  logic [3:0]                 shield_m_axi_arcache ,
  input  logic [2:0]                 shield_m_axi_arprot  ,
  input  logic [3:0]                 shield_m_axi_arqos   ,
  input  logic [3:0]                 shield_m_axi_arregion,
  input  logic                       shield_m_axi_arvalid ,
  output logic                       shield_m_axi_arready ,
  output logic [AXI_ID_WIDTH-1:0]    shield_m_axi_rid     ,
  output logic [AXI_DATA_WIDTH-1:0]  shield_m_axi_rdata   ,
  output logic [1:0]                 shield_m_axi_rresp   ,
  output logic                       shield_m_axi_rlast   ,
  output logic                       shield_m_axi_rvalid  ,
  input  logic                       shield_m_axi_rready  ,
  input  logic [CL_ID_WIDTH-1:0]     shield_s_axi_rid     ,
  input  logic [CL_DATA_WIDTH-1:0]   shield_s_axi_rdata   ,
  input  logic [1:0]                 shield_s_axi_rresp   ,
  input  logic                       shield_s_axi_rlast   ,
  input  logic                       shield_s_axi_rvalid  ,
  output logic                       shield_s_axi_rready  ,

  input  logic [AXI_ID_WIDTH-1:0]    stream_m_axi_arid    ,
  input  logic [AXI_ADDR_WIDTH-1:0]  stream_m_axi_araddr  ,
  input  logic [7:0]                 stream_m_axi_arlen   ,
  input  logic [2:0]                 stream_m_axi_arsize  ,
  input  logic [1:0]                 stream_m_axi_arburst ,
  input  logic [1:0]                 stream_m_axi_arlock  ,
  input  logic [3:0]                 stream_m_axi_arcache ,
  input  logic [2:0]                 stream_m_axi_arprot  ,
  input  logic [3:0]                 stream_m_axi_arqos   ,
  input  logic [3:0]                 stream_m_axi_arregion,
  input  logic                       stream_m_axi_arvalid ,
  output logic                       stream_m_axi_arready ,
  output logic [AXI_ID_WIDTH-1:0]    stream_m_axi_rid     ,
  output logic [AXI_DATA_WIDTH-1:0]  stream_m_axi_rdata   ,
  output logic [1:0]                 stream_m_axi_rresp   ,
  output logic                       stream_m_axi_rlast   ,
  output logic                       stream_m_axi_rvalid  ,
  input  logic                       stream_m_axi_rready  ,
  input  logic [CL_ID_WIDTH-1:0]     stream_s_axi_rid     ,
  input  logic [CL_DATA_WIDTH-1:0]   stream_s_axi_rdata   ,
  input  logic [1:0]                 stream_s_axi_rresp   ,
  input  logic                       stream_s_axi_rlast   ,
  input  logic                       stream_s_axi_rvalid  ,
  output logic                       stream_s_axi_rready  ,

  output logic [AXI_ID_WIDTH-1:0]    dram_axi_arid,
  output logic [AXI_ADDR_WIDTH-1:0]  dram_axi_araddr,
  output logic [7:0]                 dram_axi_arlen,
  output logic [2:0]                 dram_axi_arsize,
  output logic [1:0]                 dram_axi_arburst,
  output logic [1:0]                 dram_axi_arlock,
  output logic [3:0]                 dram_axi_arcache,
  output logic [2:0]                 dram_axi_arprot,
  output logic [3:0]                 dram_axi_arqos,
  output logic [3:0]                 dram_axi_arregion,
  output logic                       dram_axi_arvalid,
  input  logic                       dram_axi_arready,
  input  logic [AXI_ID_WIDTH-1:0]    dram_axi_rid,
  input  logic [AXI_DATA_WIDTH-1:0]  dram_axi_rdata,
  input  logic [1:0]                 dram_axi_rresp,
  input  logic                       dram_axi_rlast,
  input  logic                       dram_axi_rvalid,
  output logic                       dram_axi_rready,


  output logic [CL_ID_WIDTH-1:0]     cl_axi_rid, 
  output logic [CL_DATA_WIDTH-1:0]   cl_axi_rdata,
  output logic [1:0]                 cl_axi_rresp, 
  output logic                       cl_axi_rlast, 
  output logic                       cl_axi_rvalid,
  input  logic                       cl_axi_rready,


  input  logic                       sel
);
  // DRAM master -> slave
  always_comb begin
    if(sel == 1'b0) begin
      dram_axi_arid     = shield_m_axi_arid    ;
      dram_axi_araddr   = shield_m_axi_araddr  ;
      dram_axi_arlen    = shield_m_axi_arlen   ;
      dram_axi_arsize   = shield_m_axi_arsize  ;
      dram_axi_arburst  = shield_m_axi_arburst ;
      dram_axi_arlock   = shield_m_axi_arlock  ;
      dram_axi_arcache  = shield_m_axi_arcache ;
      dram_axi_arprot   = shield_m_axi_arprot  ;
      dram_axi_arqos    = shield_m_axi_arqos   ;
      dram_axi_arregion = shield_m_axi_arregion;
      dram_axi_arvalid  = shield_m_axi_arvalid ;

      dram_axi_rready   = shield_m_axi_rready  ;
    end
    else begin
      dram_axi_arid     = stream_m_axi_arid    ;
      dram_axi_araddr   = stream_m_axi_araddr  ;
      dram_axi_arlen    = stream_m_axi_arlen   ;
      dram_axi_arsize   = stream_m_axi_arsize  ;
      dram_axi_arburst  = stream_m_axi_arburst ;
      dram_axi_arlock   = stream_m_axi_arlock  ;
      dram_axi_arcache  = stream_m_axi_arcache ;
      dram_axi_arprot   = stream_m_axi_arprot  ;
      dram_axi_arqos    = stream_m_axi_arqos   ;
      dram_axi_arregion = stream_m_axi_arregion;
      dram_axi_arvalid  = stream_m_axi_arvalid ;

      dram_axi_rready   = stream_m_axi_rready  ;
    end
  end

  // DRAM slave->master signals
  always_comb begin
    if(sel == 1'b0) begin
      shield_m_axi_arready   = dram_axi_arready      ;

      shield_m_axi_rid       = dram_axi_rid          ;
      shield_m_axi_rdata     = dram_axi_rdata        ;
      shield_m_axi_rresp     = dram_axi_rresp        ;
      shield_m_axi_rlast     = dram_axi_rlast        ;
      shield_m_axi_rvalid    = dram_axi_rvalid       ;

      stream_m_axi_arready   = 1'b0                  ;

      stream_m_axi_rid       = {AXI_ID_WIDTH{1'b0}}  ;
      stream_m_axi_rdata     = {AXI_DATA_WIDTH{1'b0}};
      stream_m_axi_rresp     = 2'b00                 ;
      stream_m_axi_rlast     = 1'b0                  ;
      stream_m_axi_rvalid    = 1'b0                  ;
    end
    else begin
      stream_m_axi_arready   = dram_axi_arready      ;

      stream_m_axi_rid       = dram_axi_rid          ;
      stream_m_axi_rdata     = dram_axi_rdata        ;
      stream_m_axi_rresp     = dram_axi_rresp        ;
      stream_m_axi_rlast     = dram_axi_rlast        ;
      stream_m_axi_rvalid    = dram_axi_rvalid       ;

      shield_m_axi_arready   = 1'b0                  ;

      shield_m_axi_rid       = {AXI_ID_WIDTH{1'b0}}  ;
      shield_m_axi_rdata     = {AXI_DATA_WIDTH{1'b0}};
      shield_m_axi_rresp     = 2'b00                 ;
      shield_m_axi_rlast     = 1'b0                  ;
      shield_m_axi_rvalid    = 1'b0                  ;
    end
  end

  //CL master -> slave
  always_comb begin
    if(sel == 1'b0) begin
      shield_s_axi_rready    = cl_axi_rready;
      stream_s_axi_rready    = 1'b0         ;
    end
    else begin
      stream_s_axi_rready    = cl_axi_rready;
      shield_s_axi_rready    = 1'b0         ;
    end
  end

  //CL slave->master
  always_comb begin
    if(sel == 1'b0) begin
      cl_axi_rid     = shield_s_axi_rid   ;
      cl_axi_rdata   = shield_s_axi_rdata ;
      cl_axi_rresp   = shield_s_axi_rresp ;
      cl_axi_rlast   = shield_s_axi_rlast ;
      cl_axi_rvalid  = shield_s_axi_rvalid;
    end
    else begin
      cl_axi_rid     = stream_s_axi_rid   ;
      cl_axi_rdata   = stream_s_axi_rdata ;
      cl_axi_rresp   = stream_s_axi_rresp ;
      cl_axi_rlast   = stream_s_axi_rlast ;
      cl_axi_rvalid  = stream_s_axi_rvalid;
    end
  end
endmodule : axi_read_mux

module axi_write_mux
#(
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer AXI_ID_WIDTH = 16,
  parameter integer AXI_DATA_WIDTH = 512,
  parameter integer CL_ADDR_WIDTH = 64,
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64
)(
  input  logic [AXI_ID_WIDTH-1:0]      shield_m_axi_awid,
  input  logic [AXI_ADDR_WIDTH-1:0]    shield_m_axi_awaddr,
  input  logic [7:0]                   shield_m_axi_awlen,
  input  logic [2:0]                   shield_m_axi_awsize,
  input  logic [1:0]                   shield_m_axi_awburst,
  input  logic [1:0]                   shield_m_axi_awlock,
  input  logic [3:0]                   shield_m_axi_awcache,
  input  logic [2:0]                   shield_m_axi_awprot,
  input  logic [3:0]                   shield_m_axi_awqos,
  input  logic [3:0]                   shield_m_axi_awregion,
  input  logic                         shield_m_axi_awvalid,
  output logic                         shield_m_axi_awready,
  input  logic [AXI_ID_WIDTH-1:0]      shield_m_axi_wid,
  input  logic [AXI_DATA_WIDTH-1:0]    shield_m_axi_wdata,
  input  logic [AXI_DATA_WIDTH/8-1:0]  shield_m_axi_wstrb,
  input  logic                         shield_m_axi_wlast,
  input  logic                         shield_m_axi_wvalid,
  output logic                         shield_m_axi_wready,
  output logic [AXI_ID_WIDTH-1:0]      shield_m_axi_bid,
  output logic [1:0]                   shield_m_axi_bresp,
  output logic                         shield_m_axi_bvalid,
  input  logic                         shield_m_axi_bready,

  output logic [CL_ID_WIDTH-1:0]       shield_s_axi_wid,
  output logic [CL_DATA_WIDTH-1:0]     shield_s_axi_wdata,
  output logic [CL_DATA_WIDTH/8-1:0]   shield_s_axi_wstrb,
  output logic                         shield_s_axi_wlast,
  output logic                         shield_s_axi_wvalid,
  input  logic                         shield_s_axi_wready,
  input  logic [CL_ID_WIDTH-1:0]       shield_s_axi_bid,
  input  logic [1:0]                   shield_s_axi_bresp,
  input  logic                         shield_s_axi_bvalid,
  output logic                         shield_s_axi_bready,

  input  logic [AXI_ID_WIDTH-1:0]      stream_m_axi_awid,
  input  logic [AXI_ADDR_WIDTH-1:0]    stream_m_axi_awaddr,
  input  logic [7:0]                   stream_m_axi_awlen,
  input  logic [2:0]                   stream_m_axi_awsize,
  input  logic [1:0]                   stream_m_axi_awburst,
  input  logic [1:0]                   stream_m_axi_awlock,
  input  logic [3:0]                   stream_m_axi_awcache,
  input  logic [2:0]                   stream_m_axi_awprot,
  input  logic [3:0]                   stream_m_axi_awqos,
  input  logic [3:0]                   stream_m_axi_awregion,
  input  logic                         stream_m_axi_awvalid,
  output logic                         stream_m_axi_awready,
  input  logic [AXI_ID_WIDTH-1:0]      stream_m_axi_wid,
  input  logic [AXI_DATA_WIDTH-1:0]    stream_m_axi_wdata,
  input  logic [AXI_DATA_WIDTH/8-1:0]  stream_m_axi_wstrb,
  input  logic                         stream_m_axi_wlast,
  input  logic                         stream_m_axi_wvalid,
  output logic                         stream_m_axi_wready,
  output logic [AXI_ID_WIDTH-1:0]      stream_m_axi_bid,
  output logic [1:0]                   stream_m_axi_bresp,
  output logic                         stream_m_axi_bvalid,
  input  logic                         stream_m_axi_bready,

  output logic [CL_ID_WIDTH-1:0]       stream_s_axi_wid,
  output logic [CL_DATA_WIDTH-1:0]     stream_s_axi_wdata,
  output logic [CL_DATA_WIDTH/8-1:0]   stream_s_axi_wstrb,
  output logic                         stream_s_axi_wlast,
  output logic                         stream_s_axi_wvalid,
  input  logic                         stream_s_axi_wready,
  input  logic [CL_ID_WIDTH-1:0]       stream_s_axi_bid,
  input  logic [1:0]                   stream_s_axi_bresp,
  input  logic                         stream_s_axi_bvalid,
  output logic                         stream_s_axi_bready,
  
  output logic [AXI_ID_WIDTH-1:0]      dram_axi_awid,
  output logic [AXI_ADDR_WIDTH-1:0]    dram_axi_awaddr,
  output logic [7:0]                   dram_axi_awlen,
  output logic [2:0]                   dram_axi_awsize,
  output logic [1:0]                   dram_axi_awburst,
  output logic [1:0]                   dram_axi_awlock,
  output logic [3:0]                   dram_axi_awcache,
  output logic [2:0]                   dram_axi_awprot,
  output logic [3:0]                   dram_axi_awqos,
  output logic [3:0]                   dram_axi_awregion,
  output logic                         dram_axi_awvalid,
  input  logic                         dram_axi_awready,
  output logic [AXI_ID_WIDTH-1:0]      dram_axi_wid,
  output logic [AXI_DATA_WIDTH-1:0]    dram_axi_wdata,
  output logic [AXI_DATA_WIDTH/8-1:0]  dram_axi_wstrb,
  output logic                         dram_axi_wlast,
  output logic                         dram_axi_wvalid,
  input  logic                         dram_axi_wready,
  input  logic [AXI_ID_WIDTH-1:0]      dram_axi_bid,
  input  logic [1:0]                   dram_axi_bresp,
  input  logic                         dram_axi_bvalid,
  output logic                         dram_axi_bready,

  input  logic [CL_ID_WIDTH-1:0]       cl_axi_wid, //unused
  input  logic [CL_DATA_WIDTH-1:0]     cl_axi_wdata,
  input  logic [CL_DATA_WIDTH/8-1:0]   cl_axi_wstrb, //unused. set to all 1 assumed
  input  logic                         cl_axi_wlast, //unused - calculated internally
  input  logic                         cl_axi_wvalid,
  output logic                         cl_axi_wready,
  output logic [CL_ID_WIDTH-1:0]       cl_axi_bid, //unused
  output logic [1:0]                   cl_axi_bresp, //unused - replies ok
  output logic                         cl_axi_bvalid,
  input  logic                         cl_axi_bready,

  input  logic                         sel
);
  //DRAM master->slave
  always_comb begin
    if(sel == 1'b0) begin
      dram_axi_awid     = shield_m_axi_awid    ;
      dram_axi_awaddr   = shield_m_axi_awaddr  ;
      dram_axi_awlen    = shield_m_axi_awlen   ; 
      dram_axi_awsize   = shield_m_axi_awsize  ; 
      dram_axi_awburst  = shield_m_axi_awburst ; 
      dram_axi_awlock   = shield_m_axi_awlock  ; 
      dram_axi_awcache  = shield_m_axi_awcache ; 
      dram_axi_awprot   = shield_m_axi_awprot  ; 
      dram_axi_awqos    = shield_m_axi_awqos   ; 
      dram_axi_awregion = shield_m_axi_awregion;
      dram_axi_awvalid  = shield_m_axi_awvalid ;

      dram_axi_wid      = shield_m_axi_wid     ;
      dram_axi_wdata    = shield_m_axi_wdata   ;
      dram_axi_wstrb    = shield_m_axi_wstrb   ;
      dram_axi_wlast    = shield_m_axi_wlast   ;
      dram_axi_wvalid   = shield_m_axi_wvalid  ;

      dram_axi_bready   = shield_m_axi_bready  ;
    end
    else begin
      dram_axi_awid     = stream_m_axi_awid    ;
      dram_axi_awaddr   = stream_m_axi_awaddr  ;
      dram_axi_awlen    = stream_m_axi_awlen   ; 
      dram_axi_awsize   = stream_m_axi_awsize  ; 
      dram_axi_awburst  = stream_m_axi_awburst ; 
      dram_axi_awlock   = stream_m_axi_awlock  ; 
      dram_axi_awcache  = stream_m_axi_awcache ; 
      dram_axi_awprot   = stream_m_axi_awprot  ; 
      dram_axi_awqos    = stream_m_axi_awqos   ; 
      dram_axi_awregion = stream_m_axi_awregion;
      dram_axi_awvalid  = stream_m_axi_awvalid ;

      dram_axi_wid      = stream_m_axi_wid     ;
      dram_axi_wdata    = stream_m_axi_wdata   ;
      dram_axi_wstrb    = stream_m_axi_wstrb   ;
      dram_axi_wlast    = stream_m_axi_wlast   ;
      dram_axi_wvalid   = stream_m_axi_wvalid  ;

      dram_axi_bready   = stream_m_axi_bready  ;
    end
  end

  //DRAM slave->master
  always_comb begin
    if(sel == 1'b0) begin
      shield_m_axi_awready  = dram_axi_awready  ;
      shield_m_axi_wready   = dram_axi_wready   ;
      shield_m_axi_bid      = dram_axi_bid      ;
      shield_m_axi_bresp    = dram_axi_bresp    ;
      shield_m_axi_bvalid   = dram_axi_bvalid   ;

      stream_m_axi_awready  = 1'b0  ;
      stream_m_axi_wready   = 1'b0  ;
      stream_m_axi_bid      = {AXI_ID_WIDTH{1'b0}}  ;
      stream_m_axi_bresp    = 2'b00 ;
      stream_m_axi_bvalid   = 1'b0  ;
    end
    else begin
      stream_m_axi_awready  = dram_axi_awready  ;
      stream_m_axi_wready   = dram_axi_wready   ;
      stream_m_axi_bid      = dram_axi_bid      ;
      stream_m_axi_bresp    = dram_axi_bresp    ;
      stream_m_axi_bvalid   = dram_axi_bvalid   ;

      shield_m_axi_awready  = 1'b0  ;
      shield_m_axi_wready   = 1'b0  ;
      shield_m_axi_bid      = {AXI_ID_WIDTH{1'b0}}  ;
      shield_m_axi_bresp    = 2'b00 ;
      shield_m_axi_bvalid   = 1'b0  ;
    end
  end

  //CL master-> slave
  always_comb begin
    if(sel == 1'b0) begin
      shield_s_axi_wid    = cl_axi_wid    ;
      shield_s_axi_wdata  = cl_axi_wdata  ;
      shield_s_axi_wstrb  = cl_axi_wstrb  ;
      shield_s_axi_wlast  = cl_axi_wlast  ;
      shield_s_axi_wvalid = cl_axi_wvalid ;
      shield_s_axi_bready = cl_axi_bready ;

      stream_s_axi_wid    = {CL_ID_WIDTH{1'b0}};
      stream_s_axi_wdata  = {CL_DATA_WIDTH{1'b0}};
      stream_s_axi_wstrb  = {(CL_DATA_WIDTH/8){1'b0}};
      stream_s_axi_wlast  = 1'b0;
      stream_s_axi_wvalid = 1'b0;
      stream_s_axi_bready = 1'b0;
    end
    else begin
      stream_s_axi_wid    = cl_axi_wid    ;
      stream_s_axi_wdata  = cl_axi_wdata  ;
      stream_s_axi_wstrb  = cl_axi_wstrb  ;
      stream_s_axi_wlast  = cl_axi_wlast  ;
      stream_s_axi_wvalid = cl_axi_wvalid ;
      stream_s_axi_bready = cl_axi_bready ;

      shield_s_axi_wid    = {CL_ID_WIDTH{1'b0}};
      shield_s_axi_wdata  = {CL_DATA_WIDTH{1'b0}};
      shield_s_axi_wstrb  = {(CL_DATA_WIDTH/8){1'b0}};
      shield_s_axi_wlast  = 1'b0;
      shield_s_axi_wvalid = 1'b0;
      shield_s_axi_bready = 1'b0;
    end
  end

  //CL slave->master
  always_comb begin
    if(sel == 1'b0) begin
      cl_axi_wready   = shield_s_axi_wready  ;
      cl_axi_bid      = shield_s_axi_bid     ;
      cl_axi_bresp    = shield_s_axi_bresp   ;
      cl_axi_bvalid   = shield_s_axi_bvalid  ;
    end
    else begin
      cl_axi_wready   = stream_s_axi_wready  ;
      cl_axi_bid      = stream_s_axi_bid     ;
      cl_axi_bresp    = stream_s_axi_bresp   ;
      cl_axi_bvalid   = stream_s_axi_bvalid  ;
    end
  end
  

endmodule : axi_write_mux
