`default_nettype none

module cl_sdp_axi_mstr #(
  parameter integer AXI_ID_WIDTH =  6,
  parameter integer AXI_DATA_WIDTH = 64,
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer C_LENGTH_WIDTH = 32
)(
  // System signals
  input wire        clk,
  input wire        rst_n,

  // Control signals
  input  wire  rd_ctrl_start,
  output wire  rd_ctrl_done,
  input  wire [AXI_ADDR_WIDTH-1:0] rd_ctrl_offset,
  input  wire [C_LENGTH_WIDTH-1:0] rd_ctrl_length,

  input  wire  wr_ctrl_start,
  output wire  wr_ctrl_done,
  input  wire [AXI_ADDR_WIDTH-1:0] wr_ctrl_offset,
  input  wire [C_LENGTH_WIDTH-1:0] wr_ctrl_length,

  // Data signals
  output wire [AXI_DATA_WIDTH - 1:0] rd_data,
  output wire                          rd_valid,
  input  wire                          rd_ready,

  input  wire [AXI_DATA_WIDTH - 1:0] wr_data,
  input  wire                          wr_valid,
  output wire                          wr_ready,

  // AXI4 signals
  output wire [AXI_ID_WIDTH-1:0]           m_axi_awid,
  output wire [AXI_ADDR_WIDTH-1:0]         m_axi_awaddr,
  output wire [7:0]                        m_axi_awlen,
  output wire [2:0]                        m_axi_awsize,
  output wire [1:0]                        m_axi_awburst,
  output wire [1:0]                        m_axi_awlock,
  output wire [3:0]                        m_axi_awcache,
  output wire [2:0]                        m_axi_awprot,
  output wire [3:0]                        m_axi_awqos,
  output wire [3:0]                        m_axi_awregion,
  output wire                              m_axi_awvalid,
  input  wire                              m_axi_awready,
  output wire [AXI_ID_WIDTH-1:0]           m_axi_wid,
  output wire [AXI_DATA_WIDTH-1:0]         m_axi_wdata,
  output wire [AXI_DATA_WIDTH/8-1:0]       m_axi_wstrb,
  output wire                              m_axi_wlast,
  output wire                              m_axi_wvalid,
  input  wire                              m_axi_wready,
  input  wire [AXI_ID_WIDTH-1:0]           m_axi_bid,
  input  wire [1:0]                        m_axi_bresp,
  input  wire                              m_axi_bvalid,
  output wire                              m_axi_bready,
  output wire [AXI_ID_WIDTH-1:0]           m_axi_arid,
  output wire [AXI_ADDR_WIDTH-1:0]         m_axi_araddr,
  output wire [7:0]                        m_axi_arlen,
  output wire [2:0]                        m_axi_arsize,
  output wire [1:0]                        m_axi_arburst,
  output wire [1:0]                        m_axi_arlock,
  output wire [3:0]                        m_axi_arcache,
  output wire [2:0]                        m_axi_arprot,
  output wire [3:0]                        m_axi_arqos,
  output wire [3:0]                        m_axi_arregion,
  output wire                              m_axi_arvalid,
  input  wire                              m_axi_arready,
  input  wire [AXI_ID_WIDTH-1:0]           m_axi_rid,
  input  wire [AXI_DATA_WIDTH-1:0]         m_axi_rdata,
  input  wire [1:0]                        m_axi_rresp,
  input  wire                              m_axi_rlast,
  input  wire                              m_axi_rvalid,
  output wire                              m_axi_rready
);
  ////////////////////////////////////
  //Local params
  ////////////////////////////////////
  localparam integer LP_DW_BYTES      = AXI_DATA_WIDTH/8;
  localparam integer LP_AXI_BURST_LEN = 4096/LP_DW_BYTES < 256 ? 4096/LP_DW_BYTES : 256;
  localparam integer LP_LOG_BURST_LEN = $clog2(LP_AXI_BURST_LEN);
  localparam integer LP_RD_MAX_OUTSTANDING = 3;

  localparam integer LP_RD_FIFO_DEPTH   = LP_AXI_BURST_LEN*(LP_RD_MAX_OUTSTANDING + 1);
  localparam integer LP_WR_FIFO_DEPTH   = LP_AXI_BURST_LEN;
  
  ////////////////////////////////////
  // Variables
  ////////////////////////////////////
  logic rd_tvalid;
  logic rd_tready_n;
  logic [AXI_DATA_WIDTH-1:0] rd_tdata;
  logic ctrl_rd_fifo_prog_full;
  logic rd_fifo_tvalid_n;
  logic rd_fifo_tready; 
  logic [AXI_DATA_WIDTH-1:0] rd_fifo_tdata;

  logic wr_tvalid;
  logic wr_tready_n;
  logic [AXI_DATA_WIDTH-1:0] wr_tdata;
  logic wr_fifo_tvalid_n;
  logic wr_fifo_tready;
  logic [AXI_DATA_WIDTH-1:0] wr_fifo_tdata;


  ////////////////////////////////////
  // Datapath
  ////////////////////////////////////
  // Tie off unused signals
  assign m_axi_awid     = {AXI_ID_WIDTH{1'b0}};
  assign m_axi_awburst  = 2'b01;
  assign m_axi_awlock   = 2'b00;
  assign m_axi_awcache  = 4'b0011;
  assign m_axi_awprot   = 3'b000;
  assign m_axi_awqos    = 4'b0000;
  assign m_axi_awregion = 4'b0000;
  assign m_axi_wid      = {AXI_ID_WIDTH{1'b0}};
  assign m_axi_arburst  = 2'b01;
  assign m_axi_arlock   = 2'b00;
  assign m_axi_arcache  = 4'b0011;
  assign m_axi_arprot   = 3'b000;
  assign m_axi_arqos    = 4'b0000;
  assign m_axi_arregion = 4'b0000;

  // Instantiate read and write masters
  cl_sdp_axi_read_master #(
    .C_ADDR_WIDTH      ( AXI_ADDR_WIDTH ),
    .C_DATA_WIDTH      ( AXI_DATA_WIDTH ),
    .C_ID_WIDTH        ( AXI_ID_WIDTH   ),
    .C_NUM_CHANNELS    ( 1 ),
    .C_LENGTH_WIDTH    ( C_LENGTH_WIDTH ),
    .C_BURST_LEN       ( LP_AXI_BURST_LEN ),
    .C_LOG_BURST_LEN   ( LP_LOG_BURST_LEN ),
    .C_MAX_OUTSTANDING ( LP_RD_MAX_OUTSTANDING )
  ) inst_axi_read_master (
    .aclk          ( clk ),
    .areset        ( ~rst_n ),

    .ctrl_start    ( rd_ctrl_start ),
    .ctrl_done     ( rd_ctrl_done ), 
    .ctrl_offset   ( rd_ctrl_offset ),
    .ctrl_length   ( rd_ctrl_length ),
    .ctrl_prog_full( ctrl_rd_fifo_prog_full ),

    .arvalid       ( m_axi_arvalid ),
    .arready       ( m_axi_arready ),
    .araddr        ( m_axi_araddr ),
    .arid          ( m_axi_arid   ),
    .arlen         ( m_axi_arlen  ),
    .arsize        ( m_axi_arsize ),
    .rvalid        ( m_axi_rvalid ),
    .rready        ( m_axi_rready ),
    .rdata         ( m_axi_rdata  ),
    .rlast         ( m_axi_rlast  ),
    .rid           ( m_axi_rid    ),
    .rresp         ( m_axi_rresp  ),

    .m_tvalid      ( rd_tvalid ),
    .m_tready      ( ~rd_tready_n ),
    .m_tdata       ( rd_tdata )
  );

  xpm_fifo_sync # (
      .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
      .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
      .FIFO_WRITE_DEPTH          (LP_RD_FIFO_DEPTH),   //positive integer
      .WRITE_DATA_WIDTH          (AXI_DATA_WIDTH),        //positive integer
      .WR_DATA_COUNT_WIDTH       ($clog2(LP_RD_FIFO_DEPTH)+1),       //positive integer, Not used
      .PROG_FULL_THRESH          (LP_AXI_BURST_LEN-2),               //positive integer
      .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
      .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
      .FIFO_READ_LATENCY         (1),                //positive integer;
      .READ_DATA_WIDTH           (AXI_DATA_WIDTH),               //positive integer
      .RD_DATA_COUNT_WIDTH       ($clog2(LP_RD_FIFO_DEPTH)+1),               //positive integer, not used
      .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
      .DOUT_RESET_VALUE          ("0"),              //string, don't care
      .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;

  ) inst_rd_xpm_fifo_sync (
      .sleep         ( 1'b0             ) ,
      .rst           ( ~rst_n           ) ,
      .wr_clk        ( clk           ) ,
      .wr_en         ( rd_tvalid        ) ,
      .din           ( rd_tdata         ) ,
      .full          ( rd_tready_n      ) ,
      .prog_full     ( ctrl_rd_fifo_prog_full) ,
      .wr_data_count (                  ) ,
      .overflow      (                  ) ,
      .wr_rst_busy   (                  ) ,
      .rd_en         ( rd_fifo_tready   ) ,
      .dout          ( rd_fifo_tdata    ) ,
      .empty         ( rd_fifo_tvalid_n ) ,
      .prog_empty    (                  ) ,
      .rd_data_count (                  ) ,
      .underflow     (                  ) ,
      .rd_rst_busy   (                  ) ,
      .injectsbiterr ( 1'b0             ) ,
      .injectdbiterr ( 1'b0             ) ,
      .sbiterr       (                  ) ,
      .dbiterr       (                  ) 

  );

  // Assign FIFO signals to output
  assign rd_data = rd_fifo_tdata;
  assign rd_valid = ~rd_fifo_tvalid_n;
  assign rd_fifo_tready = rd_ready;

  cl_sdp_axi_write_master #(
    .C_ADDR_WIDTH       ( AXI_ADDR_WIDTH ),
    .C_DATA_WIDTH       ( AXI_DATA_WIDTH ),
    .C_MAX_LENGTH_WIDTH ( C_LENGTH_WIDTH ),
    .C_BURST_LEN        ( LP_AXI_BURST_LEN ),
    .C_LOG_BURST_LEN    ( LP_LOG_BURST_LEN )
  ) inst_axi_write_master (
    .aclk          ( clk ),
    .areset        ( ~rst_n ),

    .ctrl_start    ( wr_ctrl_start ),
    .ctrl_offset   ( wr_ctrl_offset ),
    .ctrl_length   ( wr_ctrl_length ),
    .ctrl_done     ( wr_ctrl_done ),


    .awaddr   ( m_axi_awaddr ),
    .awlen    ( m_axi_awlen  ),
    .awsize   ( m_axi_awsize ),
    .awvalid  ( m_axi_awvalid),
    .awready  ( m_axi_awready),
    .wdata    ( m_axi_wdata  ),
    .wstrb    ( m_axi_wstrb  ),
    .wlast    ( m_axi_wlast  ),
    .wvalid   ( m_axi_wvalid ),
    .wready   ( m_axi_wready ),
    .bresp    ( m_axi_bresp  ),
    .bvalid   ( m_axi_bvalid ),
    .bready   ( m_axi_bready ),

    .s_tvalid ( ~wr_fifo_tvalid_n ),
    .s_tready ( wr_fifo_tready ),
    .s_tdata  ( wr_fifo_tdata )
  );

  xpm_fifo_sync # (
    .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
    .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
    .FIFO_WRITE_DEPTH          (LP_WR_FIFO_DEPTH),   //positive integer
    .WRITE_DATA_WIDTH          (AXI_DATA_WIDTH),        //positive integer
    .WR_DATA_COUNT_WIDTH       ($clog2(LP_WR_FIFO_DEPTH)),       //positive integer, Not used
    .PROG_FULL_THRESH          (10),               //positive integer
    .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
    .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
    .FIFO_READ_LATENCY         (1),                //positive integer;
    .READ_DATA_WIDTH           (AXI_DATA_WIDTH),               //positive integer
    .RD_DATA_COUNT_WIDTH       ($clog2(LP_WR_FIFO_DEPTH)),               //positive integer, not used
    .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
    .DOUT_RESET_VALUE          ("0"),              //string, don't care
    .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;
  
  ) inst_wr_xpm_fifo_sync (
    .sleep         ( 1'b0             ) ,
    .rst           ( ~rst_n           ) ,
    .wr_clk        ( clk           ) ,
    .wr_en         ( wr_tvalid        ) ,
    .din           ( wr_tdata         ) ,
    .full          ( wr_tready_n      ) ,
    .prog_full     ( ) ,
    .wr_data_count (                  ) ,
    .overflow      (                  ) ,
    .wr_rst_busy   (                  ) ,
    .rd_en         ( wr_fifo_tready   ) ,
    .dout          ( wr_fifo_tdata    ) ,
    .empty         ( wr_fifo_tvalid_n ) ,
    .prog_empty    (                  ) ,
    .rd_data_count (                  ) ,
    .underflow     (                  ) ,
    .rd_rst_busy   (                  ) ,
    .injectsbiterr ( 1'b0             ) ,
    .injectdbiterr ( 1'b0             ) ,
    .sbiterr       (                  ) ,
    .dbiterr       (                  ) 
  
  );

  assign wr_tvalid = wr_valid;
  assign wr_tdata = wr_data;
  assign wr_ready = ~wr_tready_n;

endmodule

`default_nettype wire
