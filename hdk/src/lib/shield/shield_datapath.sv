`default_nettype none
`timescale 1ns/1ps

module shield_datapath #(
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer AXI_ID_WIDTH = 16,
  parameter integer AXI_DATA_WIDTH = 512,
  parameter integer CL_ADDR_WIDTH = 64,
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64,
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer LINE_WIDTH = 512,
  parameter integer CACHE_DEPTH = 256,
  parameter integer OFFSET_WIDTH = 6,
  parameter integer INDEX_WIDTH = 8,
  parameter integer TAG_WIDTH = 18,
  parameter integer PAGE_OFFSET_WIDTH = 12,
  parameter integer PAGE_SIZE = 4096
)
(
  input  wire clk,
  input  wire rst_n,

  //CL AXI Read Request
  input  wire [CL_ID_WIDTH-1:0]       cl_axi_arid,
  input  wire [CL_ADDR_WIDTH-1:0]     cl_axi_araddr,
  input  wire [7:0]                   cl_axi_arlen,
  input  wire                         cl_axi_arvalid,
  output wire                         cl_axi_arready,

  //CL Read response
  output wire [CL_ID_WIDTH-1:0]       cl_axi_rid, 
  output wire [CL_DATA_WIDTH-1:0]     cl_axi_rdata,
  output wire [1:0]                   cl_axi_rresp, 
  output wire                         cl_axi_rlast, 
  output wire                         cl_axi_rvalid,
  input  wire                         cl_axi_rready,

  //CL Write request
  input  wire [CL_ID_WIDTH-1:0]       cl_axi_awid,
  input  wire [CL_ADDR_WIDTH-1:0]     cl_axi_awaddr,
  input  wire [7:0]                   cl_axi_awlen,
  input  wire                         cl_axi_awvalid,
  output wire                         cl_axi_awready,
  
  //CL Write data
  input  wire [CL_ID_WIDTH-1:0]       cl_axi_wid, //unused
  input  wire [CL_DATA_WIDTH-1:0]     cl_axi_wdata,
  input  wire [CL_DATA_WIDTH/8-1:0]   cl_axi_wstrb, //unused. set to all 1 assumed
  input  wire                         cl_axi_wlast, //unused - calculated internally
  input  wire                         cl_axi_wvalid,
  output wire                         cl_axi_wready,

  //CL Write response
  output wire [CL_ID_WIDTH-1:0]       cl_axi_bid, //unused
  output wire [1:0]                   cl_axi_bresp, //unused - replies ok
  output wire                         cl_axi_bvalid,
  input  wire                         cl_axi_bready,

  //Control signals
  input  wire                         req_type,
  input  wire                         req_en,
  input  wire                         cl_read_req_rdy,
  input  wire                         req_rw_mux_sel,
  input  wire                         req_cycle_mux_sel,
  input  wire                         array_read_index_mux_sel,
  input  wire                         tag_array_wr_en,
  input  wire                         data_array_wr_en,
  input  wire                         shield_read_slv_input_val,
  input  wire                         shield_read_mstr_req_val,
  input  wire                         shield_read_mstr_resp_rdy,
  input  wire                         cl_write_req_rdy,
  input  wire                         shield_write_slv_req_val,
  input  wire                         shield_write_slv_cache_line_rdy,
  input  wire                         data_array_data_mux_sel, //write data from dram or cl
  input  wire                         cl_write_resp_val,
  input  wire                         shield_write_mstr_req_val,
  input  wire                         stream_axi_read_mux_sel,
  input  wire                         stream_axi_write_mux_sel,
  input  wire                         stream_read_req_val,
  input  wire                         stream_write_req_val,


  //Status signals
  output wire                         cl_read_req_val,
  output wire                         tag_match,
  output wire [SHIELD_ADDR_WIDTH-1:0] req_addr_r,
  output wire                         req_type_r,
  output wire                         shield_read_slv_input_rdy,
  output wire                         req_last,
  output wire                         shield_read_mstr_req_rdy,
  output wire                         shield_read_mstr_resp_val,
  output wire [INDEX_WIDTH-1:0]       array_refill_index,
  output wire                         cl_write_req_val,
  output wire                         shield_write_slv_req_rdy,
  output wire                         shield_write_slv_cache_line_val,
  output wire                         cl_write_resp_rdy,
  output wire                         shield_write_mstr_req_rdy,
  output wire                         stream_read_req_rdy,
  output wire                         stream_write_req_rdy,
  output wire                         read_addr_stream_bound,
  output wire                         write_addr_stream_bound,
  output wire                         stream_read_busy,
  output wire                         stream_write_busy,
  output wire                         shield_read_busy,
  output wire                         shield_write_busy,


  //Read master to DRAM
  output wire [AXI_ID_WIDTH-1:0]      m_axi_arid,
  output wire [AXI_ADDR_WIDTH-1:0]    m_axi_araddr,
  output wire [7:0]                   m_axi_arlen,
  output wire [2:0]                   m_axi_arsize,
  output wire [1:0]                   m_axi_arburst,
  output wire [1:0]                   m_axi_arlock,
  output wire [3:0]                   m_axi_arcache,
  output wire [2:0]                   m_axi_arprot,
  output wire [3:0]                   m_axi_arqos,
  output wire [3:0]                   m_axi_arregion,
  output wire                         m_axi_arvalid,
  input  wire                         m_axi_arready,
  input  wire [AXI_ID_WIDTH-1:0]      m_axi_rid,
  input  wire [AXI_DATA_WIDTH-1:0]    m_axi_rdata,
  input  wire [1:0]                   m_axi_rresp,
  input  wire                         m_axi_rlast,
  input  wire                         m_axi_rvalid,
  output wire                         m_axi_rready,

  //Write master to DRAM
  output wire [AXI_ID_WIDTH-1:0]      m_axi_awid,
  output wire [AXI_ADDR_WIDTH-1:0]    m_axi_awaddr,
  output wire [7:0]                   m_axi_awlen,
  output wire [2:0]                   m_axi_awsize,
  output wire [1:0]                   m_axi_awburst,
  output wire [1:0]                   m_axi_awlock,
  output wire [3:0]                   m_axi_awcache,
  output wire [2:0]                   m_axi_awprot,
  output wire [3:0]                   m_axi_awqos,
  output wire [3:0]                   m_axi_awregion,
  output wire                         m_axi_awvalid,
  input  wire                         m_axi_awready,
  output wire [AXI_ID_WIDTH-1:0]      m_axi_wid,
  output wire [AXI_DATA_WIDTH-1:0]    m_axi_wdata,
  output wire [AXI_DATA_WIDTH/8-1:0]  m_axi_wstrb,
  output wire                         m_axi_wlast,
  output wire                         m_axi_wvalid,
  input  wire                         m_axi_wready,
  input  wire [AXI_ID_WIDTH-1:0]      m_axi_bid,
  input  wire [1:0]                   m_axi_bresp,
  input  wire                         m_axi_bvalid,
  output wire                         m_axi_bready

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  //Line -> burst params
  localparam integer BURSTS_PER_LINE = LINE_WIDTH / CL_DATA_WIDTH;
  localparam integer BURSTS_PER_LINE_LOG = $clog2(BURSTS_PER_LINE);
  localparam integer LINE_WIDTH_BYTES = LINE_WIDTH / 8;
  localparam integer CL_DATA_WIDTH_BYTES = CL_DATA_WIDTH / 8;

  localparam integer BURSTS_PER_PAGE = PAGE_SIZE / CL_DATA_WIDTH_BYTES;
  localparam integer BURSTS_PER_PAGE_LOG = $clog2(BURSTS_PER_PAGE);

  //////////////////////////////////////////////////////////////////////////////
  // stage 0: input -> arrays
  //////////////////////////////////////////////////////////////////////////////
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_in;
  logic [7:0]                   req_len_in;
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_0; //Muxed request address
  logic [7:0] req_len_0; //Muxed request length

  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_next_0;
  logic [7:0]                   req_len_next_0;
  logic                         req_last_0;
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_next_1;
  logic [7:0]                   req_len_next_1; 
  logic                         req_last_1;

  logic [SHIELD_ADDR_WIDTH-1:0] read_addr_in;
  logic [SHIELD_ADDR_WIDTH-1:0] write_addr_in;

  assign read_addr_in = cl_axi_araddr[SHIELD_ADDR_WIDTH-1:0];
  assign write_addr_in = cl_axi_awaddr[SHIELD_ADDR_WIDTH-1:0];


 
  //Check if read address is in streaming range
  `ifdef ENABLE_STREAMING
    assign read_addr_stream_bound = (read_addr_in < `STREAM_BOUND_ADDR);
    assign write_addr_stream_bound = (write_addr_in < `STREAM_BOUND_ADDR);
  `else
    assign read_addr_stream_bound = 1'b0;
    assign write_addr_stream_bound = 1'b0;
  `endif

  //Handshake with CL AXI signals
  assign cl_axi_arready = cl_read_req_rdy;
  assign cl_read_req_val = cl_axi_arvalid;

  assign cl_axi_awready = cl_write_req_rdy;
  assign cl_write_req_val = cl_axi_awvalid;

  //Mux for read or write input addr/len
  shield_mux2 #(.WIDTH(SHIELD_ADDR_WIDTH)) req_addr_rw_mux(
    .in0(cl_axi_araddr[SHIELD_ADDR_WIDTH-1:0]),
    .in1(cl_axi_awaddr[SHIELD_ADDR_WIDTH-1:0]),
    .sel(req_rw_mux_sel),
    .out(req_addr_in)
  );

  shield_mux2 #(.WIDTH(8)) req_len_rw_mux(
    .in0(cl_axi_arlen),
    .in1(cl_axi_awlen),
    .sel(req_rw_mux_sel),
    .out(req_len_in)
  );

  //Mux for read addr/len from input or cmdgen
  shield_mux2 #(.WIDTH(SHIELD_ADDR_WIDTH)) req_addr_cycle_mux(
    .in0(req_addr_in),
    .in1(req_addr_next_1), 
    .sel(req_cycle_mux_sel),
    .out(req_addr_0)
  );

  shield_mux2 #(.WIDTH(8)) req_len_cycle_mux(
    .in0(req_len_in),
    .in1(req_len_next_1), 
    .sel(req_cycle_mux_sel),
    .out(req_len_0)
  );


  logic [7:0] burst_count_0; //How many bursts for the next cache line

  //Note that burst_len is the actual number of bursts, and req_len is bursts - 1
  shield_cmd_gen #(
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .OFFSET_WIDTH(OFFSET_WIDTH),
    .BURSTS_PER_LINE(BURSTS_PER_LINE),
    .BURSTS_PER_LINE_LOG(BURSTS_PER_LINE_LOG)) shield_read_cmd_generator(
    .axaddr(req_addr_0),
    .axlen(req_len_0),
    .burst_count(burst_count_0),
    .axlen_next(req_len_next_0),
    .axaddr_next(req_addr_next_0),
    .last(req_last_0)
  );


  //Register command
  logic [7:0]                   burst_count_1; //Length in bursts of the read req
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_1;
  logic                         req_type_1;


  shield_enreg #(.WIDTH(8)) burst_count_reg (
    .clk( clk ),
    .q(burst_count_1),
    .d(burst_count_0),
    .en(req_en)
  );

  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) req_addr_reg (
    .clk( clk ),
    .q(req_addr_1),
    .d(req_addr_0),
    .en(req_en)
  );

  shield_enreg #(.WIDTH(8)) req_len_next_reg (
    .clk( clk ),
    .q(req_len_next_1),
    .d(req_len_next_0),
    .en(req_en)
  );

  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) req_addr_next_reg (
    .clk( clk ),
    .q(req_addr_next_1),
    .d(req_addr_next_0),
    .en(req_en)
  );

  shield_enreg #(.WIDTH(1)) req_last_reg (
    .clk( clk ),
    .q(req_last_1),
    .d(req_last_0),
    .en(req_en)
  );

  shield_enreg #(.WIDTH(1)) req_type_reg (
    .clk(clk),
    .q(req_type_1),
    .d(req_type),
    .en(req_en)
  );

  //Assign as status signal
  assign req_addr_r = req_addr_1;
  assign req_last = req_last_1;
  assign req_type_r = req_type_1;

  //Decode request address
  logic [TAG_WIDTH-1:0]    req_tag_0;
  logic [INDEX_WIDTH-1:0]  req_index_0;
  logic [OFFSET_WIDTH-1:0] req_offset_0;

  assign req_tag_0    = req_addr_0[SHIELD_ADDR_WIDTH-1 -: TAG_WIDTH];
  assign req_index_0  = req_addr_0[SHIELD_ADDR_WIDTH-TAG_WIDTH-1 -: INDEX_WIDTH];
  assign req_offset_0 = req_addr_0[OFFSET_WIDTH-1:0];

  logic [TAG_WIDTH-1:0] req_tag_1;
  logic [INDEX_WIDTH-1:0] req_index_1;
  logic [OFFSET_WIDTH-1:0] req_offset_1;

  assign req_tag_1    = req_addr_1[SHIELD_ADDR_WIDTH-1 -: TAG_WIDTH];
  assign req_index_1  = req_addr_1[SHIELD_ADDR_WIDTH-TAG_WIDTH-1 -: INDEX_WIDTH];
  assign req_offset_1 = req_addr_1[OFFSET_WIDTH-1:0];


  //////////////////////////////////////////////////////////////////////////////
  // stage 1: output of arrays
  //////////////////////////////////////////////////////////////////////////////

  logic [TAG_WIDTH-1:0] read_tag_1; //Output of tag array
  logic [LINE_WIDTH-1:0] read_data_1; //Output of data array

  //Inputs to arrays
  logic [INDEX_WIDTH-1:0] array_read_index; //Address to tag/data arrays
  logic [INDEX_WIDTH-1:0] array_write_index; //write index
  logic [TAG_WIDTH-1:0]   array_write_tag;

  logic [LINE_WIDTH-1:0]       array_write_data;
  logic [BURSTS_PER_LINE-1:0]  array_write_burst_en;
  logic [LINE_WIDTH_BYTES-1:0] array_write_byte_en;


  logic [SHIELD_ADDR_WIDTH-1:0] shield_read_mstr_req_addr;
  logic [SHIELD_ADDR_WIDTH-1:0] shield_read_mstr_resp_addr; //registered addr corresponding to data
  logic [LINE_WIDTH-1:0]        shield_read_mstr_resp_data; //input to data array

  //Busy signals
  logic shield_read_mstr_busy;
  logic shield_read_slv_busy;
  logic shield_write_mstr_busy;
  logic shield_write_slv_busy;

  logic [SHIELD_ADDR_WIDTH-1:0] shield_write_mstr_req_addr;
  logic [SHIELD_ADDR_WIDTH-1:0] shield_write_mstr_req_data;

  //AXI Read signals
  logic [AXI_ID_WIDTH-1:0]      read_mstr_axi_rid;
  logic [AXI_ADDR_WIDTH-1:0]    read_mstr_axi_araddr;
  logic [7:0]                   read_mstr_axi_arlen;
  logic                         read_mstr_axi_arvalid;
  logic                         read_mstr_axi_arready;
  logic [AXI_DATA_WIDTH-1:0]    read_mstr_axi_rdata;
  logic [1:0]                   read_mstr_axi_rresp;
  logic                         read_mstr_axi_rlast;
  logic                         read_mstr_axi_rvalid;
  logic                         read_mstr_axi_rready;

  logic [AXI_ID_WIDTH-1:0]      read_stream_axi_m_rid; //SET TO 0
  logic [AXI_ADDR_WIDTH-1:0]    read_stream_axi_m_araddr;
  logic [7:0]                   read_stream_axi_m_arlen;
  logic                         read_stream_axi_m_arvalid;
  logic                         read_stream_axi_m_arready;
  logic [AXI_DATA_WIDTH-1:0]    read_stream_axi_m_rdata;
  logic [1:0]                   read_stream_axi_m_rresp;
  logic                         read_stream_axi_m_rlast;
  logic                         read_stream_axi_m_rvalid;
  logic                         read_stream_axi_m_rready;

  //To CL
  logic [CL_ID_WIDTH-1:0]       read_slv_axi_rid; //SET TO 0
  logic [CL_DATA_WIDTH-1:0]     read_slv_axi_rdata;
  logic [1:0]                   read_slv_axi_rresp; //ALWAYS SUCCESS
  logic                         read_slv_axi_rlast; //IGNORE FOR NOW
  logic                         read_slv_axi_rvalid;
  logic                         read_slv_axi_rready;

  logic [CL_ID_WIDTH-1:0]       read_stream_axi_s_rid; //SET TO 0
  logic [CL_DATA_WIDTH-1:0]     read_stream_axi_s_rdata;
  logic [1:0]                   read_stream_axi_s_rresp; //ALWAYS SUCCESS
  logic                         read_stream_axi_s_rlast; //IGNORE FOR NOW
  logic                         read_stream_axi_s_rvalid;
  logic                         read_stream_axi_s_rready;


  logic [LINE_WIDTH-1:0]        shield_write_slv_data;
  logic [BURSTS_PER_LINE-1:0]   shield_write_slv_burst_en;

  logic [AXI_ID_WIDTH-1:0]      write_mstr_axi_awid;
  logic [AXI_ADDR_WIDTH-1:0]    write_mstr_axi_awaddr;
  logic [7:0]                   write_mstr_axi_awlen;
  logic [2:0]                   write_mstr_axi_awsize;
  logic [1:0]                   write_mstr_axi_awburst;
  logic [1:0]                   write_mstr_axi_awlock;
  logic [3:0]                   write_mstr_axi_awcache;
  logic [2:0]                   write_mstr_axi_awprot;
  logic [3:0]                   write_mstr_axi_awqos;
  logic [3:0]                   write_mstr_axi_awregion;
  logic                         write_mstr_axi_awvalid;
  logic                         write_mstr_axi_awready;
  logic [AXI_ID_WIDTH-1:0]      write_mstr_axi_wid;
  logic [AXI_DATA_WIDTH-1:0]    write_mstr_axi_wdata;
  logic [AXI_DATA_WIDTH/8-1:0]  write_mstr_axi_wstrb;
  logic                         write_mstr_axi_wlast;
  logic                         write_mstr_axi_wvalid;
  logic                         write_mstr_axi_wready;
  logic [AXI_ID_WIDTH-1:0]      write_mstr_axi_bid;
  logic [1:0]                   write_mstr_axi_bresp;
  logic                         write_mstr_axi_bvalid;
  logic                         write_mstr_axi_bready;

  logic [CL_ID_WIDTH-1:0]       write_slv_axi_wid; 
  logic [CL_DATA_WIDTH-1:0]     write_slv_axi_wdata;
  logic [CL_DATA_WIDTH/8-1:0]   write_slv_axi_wstrb;
  logic                         write_slv_axi_wlast;
  logic                         write_slv_axi_wvalid;
  logic                         write_slv_axi_wready;
  logic [CL_ID_WIDTH-1:0]       write_slv_axi_bid; 
  logic [1:0]                   write_slv_axi_bresp;
  logic                         write_slv_axi_bvalid;
  logic                         write_slv_axi_bready;

  logic [AXI_ID_WIDTH-1:0]      write_stream_axi_m_awid;
  logic [AXI_ADDR_WIDTH-1:0]    write_stream_axi_m_awaddr;
  logic [7:0]                   write_stream_axi_m_awlen;
  logic [2:0]                   write_stream_axi_m_awsize;
  logic [1:0]                   write_stream_axi_m_awburst;
  logic [1:0]                   write_stream_axi_m_awlock;
  logic [3:0]                   write_stream_axi_m_awcache;
  logic [2:0]                   write_stream_axi_m_awprot;
  logic [3:0]                   write_stream_axi_m_awqos;
  logic [3:0]                   write_stream_axi_m_awregion;
  logic                         write_stream_axi_m_awvalid;
  logic                         write_stream_axi_m_awready;
  logic [AXI_ID_WIDTH-1:0]      write_stream_axi_m_wid;
  logic [AXI_DATA_WIDTH-1:0]    write_stream_axi_m_wdata;
  logic [AXI_DATA_WIDTH/8-1:0]  write_stream_axi_m_wstrb;
  logic                         write_stream_axi_m_wlast;
  logic                         write_stream_axi_m_wvalid;
  logic                         write_stream_axi_m_wready;
  logic [AXI_ID_WIDTH-1:0]      write_stream_axi_m_bid;
  logic [1:0]                   write_stream_axi_m_bresp;
  logic                         write_stream_axi_m_bvalid;
  logic                         write_stream_axi_m_bready;

  logic [CL_ID_WIDTH-1:0]       write_stream_axi_s_wid;
  logic [CL_DATA_WIDTH-1:0]     write_stream_axi_s_wdata;
  logic [CL_DATA_WIDTH/8-1:0]   write_stream_axi_s_wstrb; //IGNORED FOR NOW
  logic                         write_stream_axi_s_wlast;
  logic                         write_stream_axi_s_wvalid;
  logic                         write_stream_axi_s_wready;
  logic [CL_ID_WIDTH-1:0]       write_stream_axi_s_bid; //unused
  logic [1:0]                   write_stream_axi_s_bresp; //unused - replies ok
  logic                         write_stream_axi_s_bvalid;
  logic                         write_stream_axi_s_bready;


  shield_mux2 #(.WIDTH(INDEX_WIDTH)) array_read_index_mux(
    .in0(req_index_0),
    .in1(req_index_1),
    .sel(array_read_index_mux_sel),
    .out(array_read_index)
  );

  //Mux input to data arary between CL and DRAM
  shield_mux2 #(.WIDTH(LINE_WIDTH)) array_write_data_mux(
    .in0(shield_read_mstr_resp_data),
    .in1(shield_write_slv_data     ),
    .sel(data_array_data_mux_sel   ),
    .out(array_write_data          )
  );
  shield_mux2 #(.WIDTH(BURSTS_PER_LINE)) array_write_burst_en_mux(
    .in0({BURSTS_PER_LINE{1'b1}}  ),
    .in1(shield_write_slv_burst_en),
    .sel(data_array_data_mux_sel  ),
    .out(array_write_burst_en     )
  );

  shield_mux2 #(.WIDTH(INDEX_WIDTH)) array_write_index_mux(
    .in0(shield_read_mstr_resp_addr[SHIELD_ADDR_WIDTH-TAG_WIDTH-1 -: INDEX_WIDTH]),
    .in1(req_index_1),
    .sel(data_array_data_mux_sel),
    .out(array_write_index)
  );

  //Generate byte enable from burst enable
  genvar i;
  generate
    for(i = 0; i < BURSTS_PER_LINE; i++) begin
      assign array_write_byte_en[(i*CL_DATA_WIDTH_BYTES) +: CL_DATA_WIDTH_BYTES] = 
        array_write_burst_en[i] ? ({CL_DATA_WIDTH_BYTES{1'b1}}) : ({CL_DATA_WIDTH_BYTES{1'b0}});
    end
  endgenerate

  //Instantiate tag and data arrays
  //assign array_write_index = shield_read_mstr_resp_addr[SHIELD_ADDR_WIDTH-TAG_WIDTH-1 -: INDEX_WIDTH];
  assign array_write_tag   = shield_read_mstr_resp_addr[SHIELD_ADDR_WIDTH-1 -: TAG_WIDTH];

  assign array_refill_index = array_write_index;

  shield_ram #(.DATA_WIDTH(TAG_WIDTH), .ADDR_WIDTH(INDEX_WIDTH)) tag_array (
    .clk(clk),
    .wr_addr( array_write_index ),
    .wr_en  ( tag_array_wr_en ),
    .wr_data( array_write_tag ),
    .rd_addr( array_read_index ),
    .rd_data( read_tag_1 )
  );
  shield_ram_byte_en #(
    .DATA_WIDTH(LINE_WIDTH),
    .ADDR_WIDTH(INDEX_WIDTH),
    .ENABLE_WIDTH(LINE_WIDTH_BYTES)) data_array (
    .clk(clk),
    .wr_addr( array_write_index ),
    .wr_en  ( data_array_wr_en ),
    .wr_data( array_write_data ),
    .wr_byte_en(array_write_byte_en),
    .rd_addr( array_read_index ),
    .rd_data( read_data_1 )
  );

  assign tag_match = (read_tag_1 == req_tag_1);

  //data array feeds into fifo, which directly conects back to CL

  shield_read_slv #(
    .CL_ID_WIDTH(CL_ID_WIDTH),
    .CL_DATA_WIDTH(CL_DATA_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .OFFSET_WIDTH(OFFSET_WIDTH),
    .BURSTS_PER_LINE(BURSTS_PER_LINE),
    .BURSTS_PER_LINE_LOG(BURSTS_PER_LINE_LOG)
  ) shield_read_slv_inst(
    .clk(clk),
    .rst_n(rst_n),
    .cache_line(read_data_1),
    .burst_count(burst_count_1),
    .burst_start_offset(req_offset_1),
    .burst_last(req_last_1),
    .input_val(shield_read_slv_input_val),
    .input_rdy(shield_read_slv_input_rdy),
    .busy(shield_read_slv_busy),
    .s_axi_rid   (read_slv_axi_rid),
    .s_axi_rdata (read_slv_axi_rdata),
    .s_axi_rresp (read_slv_axi_rresp),
    .s_axi_rlast (read_slv_axi_rlast),
    .s_axi_rvalid(read_slv_axi_rvalid),
    .s_axi_rready(read_slv_axi_rready)
  );

  //Read master
  assign shield_read_mstr_req_addr = req_addr_1;
  shield_read_mstr #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .LINE_WIDTH       (LINE_WIDTH),
    .OFFSET_WIDTH     (OFFSET_WIDTH)
  ) shield_read_mstr_inst(
    .clk           (clk),
    .rst_n         (rst_n),
    .req_addr      (shield_read_mstr_req_addr),
    .req_val       (shield_read_mstr_req_val),
    .req_rdy       (shield_read_mstr_req_rdy),
    .resp_addr     (shield_read_mstr_resp_addr),
    .resp_data     (shield_read_mstr_resp_data),
    .resp_val      (shield_read_mstr_resp_val),
    .resp_rdy      (shield_read_mstr_resp_rdy),
    .busy          (shield_read_mstr_busy),
    .m_axi_arid    (  ),
    .m_axi_araddr  (read_mstr_axi_araddr   ),
    .m_axi_arlen   (read_mstr_axi_arlen    ),
    .m_axi_arsize  ( ),
    .m_axi_arburst ( ),
    .m_axi_arlock  ( ),
    .m_axi_arcache ( ),
    .m_axi_arprot  ( ),
    .m_axi_arqos   ( ),
    .m_axi_arregion( ),
    .m_axi_arvalid (read_mstr_axi_arvalid  ),
    .m_axi_arready (read_mstr_axi_arready  ),
    .m_axi_rid     (read_mstr_axi_rid    ),
    .m_axi_rdata   (read_mstr_axi_rdata   ),
    .m_axi_rresp   (read_mstr_axi_rresp   ),
    .m_axi_rlast   (read_mstr_axi_rlast   ),
    .m_axi_rvalid  (read_mstr_axi_rvalid  ),
    .m_axi_rready  (read_mstr_axi_rready   )
  );

  assign shield_read_busy = (shield_read_slv_busy || shield_read_mstr_busy);

  //Shield write slave
  shield_write_slv #(
    .CL_ID_WIDTH(CL_ID_WIDTH),
    .CL_DATA_WIDTH(CL_DATA_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .OFFSET_WIDTH(OFFSET_WIDTH),
    .BURSTS_PER_LINE(BURSTS_PER_LINE),
    .BURSTS_PER_LINE_LOG(BURSTS_PER_LINE_LOG)
  ) shield_write_slv_inst(
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_wid          (write_slv_axi_wid     ),
    .s_axi_wdata        (write_slv_axi_wdata   ),
    .s_axi_wstrb        (write_slv_axi_wstrb   ),
    .s_axi_wlast        (write_slv_axi_wlast   ),
    .s_axi_wvalid       (write_slv_axi_wvalid  ),
    .s_axi_wready       (write_slv_axi_wready  ),
    .busy               (shield_write_slv_busy ),
    .burst_count        (burst_count_1  ),
    .burst_start_offset (req_offset_1   ),
    .req_val            (shield_write_slv_req_val), //only valid if request type is write
    .req_rdy            (shield_write_slv_req_rdy ),
    .cache_line         (shield_write_slv_data ),
    .cache_line_burst_en(shield_write_slv_burst_en ),
    .cache_line_val     (shield_write_slv_cache_line_val ),
    .cache_line_rdy     (shield_write_slv_cache_line_rdy )
  );

  //Write master
  assign shield_write_mstr_req_addr = {read_tag_1, req_index_1, {OFFSET_WIDTH{1'b0}}};
  assign shield_write_mstr_req_data = read_data_1;
  shield_write_mstr #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .LINE_WIDTH       (LINE_WIDTH),
    .OFFSET_WIDTH     (OFFSET_WIDTH)
  ) shield_write_mstr_isnt(
    .clk           (clk),
    .rst_n         (rst_n),
    .req_addr      (shield_write_mstr_req_addr),
    .req_data      (read_data_1),
    .req_val       (shield_write_mstr_req_val ),
    .req_rdy       (shield_write_mstr_req_rdy ),
    .busy          (shield_write_mstr_busy   ),
    .m_axi_awid    (write_mstr_axi_awid      ),
    .m_axi_awaddr  (write_mstr_axi_awaddr    ),
    .m_axi_awlen   (write_mstr_axi_awlen     ),
    .m_axi_awsize  (write_mstr_axi_awsize    ),
    .m_axi_awburst (write_mstr_axi_awburst   ),
    .m_axi_awlock  (write_mstr_axi_awlock    ),
    .m_axi_awcache (write_mstr_axi_awcache   ),
    .m_axi_awprot  (write_mstr_axi_awprot    ),
    .m_axi_awqos   (write_mstr_axi_awqos     ),
    .m_axi_awregion(write_mstr_axi_awregion  ),
    .m_axi_awvalid (write_mstr_axi_awvalid   ),
    .m_axi_awready (write_mstr_axi_awready   ),
    .m_axi_wid     (write_mstr_axi_wid       ),
    .m_axi_wdata   (write_mstr_axi_wdata     ),
    .m_axi_wstrb   (write_mstr_axi_wstrb     ),
    .m_axi_wlast   (write_mstr_axi_wlast     ),
    .m_axi_wvalid  (write_mstr_axi_wvalid    ),
    .m_axi_wready  (write_mstr_axi_wready    ),
    .m_axi_bid     (write_mstr_axi_bid       ),
    .m_axi_bresp   (write_mstr_axi_bresp     ),
    .m_axi_bvalid  (write_mstr_axi_bvalid    ),
    .m_axi_bready  (write_mstr_axi_bready    )
  );

  assign shield_write_busy = (shield_write_mstr_busy || shield_write_slv_busy);


  stream #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH    (CL_ADDR_WIDTH),
    .CL_ID_WIDTH      (CL_ID_WIDTH),
    .CL_DATA_WIDTH    (CL_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .PAGE_OFFSET_WIDTH(PAGE_OFFSET_WIDTH),
    .PAGE_SIZE        (PAGE_SIZE)
  ) stream_inst(
    .clk             (clk),
    .rst_n           (rst_n),
    .rd_req_addr     (read_addr_in),
    .rd_req_len      (cl_axi_arlen),
    .rd_req_flush    (1'b0),
    .rd_req_val      (stream_read_req_val),
    .rd_req_rdy      (stream_read_req_rdy),
    .rd_busy         (stream_read_busy),

    .wr_req_addr     (write_addr_in),
    .wr_req_len      (cl_axi_awlen),
    .wr_req_flush    (1'b0),
    .wr_req_val      (stream_write_req_val),
    .wr_req_rdy      (stream_write_req_rdy),
    .wr_busy         (stream_write_busy),

    .s_axi_rid       (read_stream_axi_s_rid),
    .s_axi_rdata     (read_stream_axi_s_rdata    ),
    .s_axi_rresp     (read_stream_axi_s_rresp),
    .s_axi_rlast     (read_stream_axi_s_rlast),
    .s_axi_rvalid    (read_stream_axi_s_rvalid   ),
    .s_axi_rready    (read_stream_axi_s_rready   ),

    .s_axi_wid       (write_stream_axi_s_wid   ),
    .s_axi_wdata     (write_stream_axi_s_wdata ),
    .s_axi_wstrb     (write_stream_axi_s_wstrb ),
    .s_axi_wlast     (write_stream_axi_s_wlast ),
    .s_axi_wvalid    (write_stream_axi_s_wvalid),
    .s_axi_wready    (write_stream_axi_s_wready),
    .s_axi_bid       (write_stream_axi_s_bid   ), //unused
    .s_axi_bresp     (write_stream_axi_s_bresp ), //unused - replies ok
    .s_axi_bvalid    (write_stream_axi_s_bvalid),
    .s_axi_bready    (write_stream_axi_s_bready),

    .m_axi_arid      ( ),
    .m_axi_araddr    (read_stream_axi_m_araddr   ),
    .m_axi_arlen     (read_stream_axi_m_arlen    ),
    .m_axi_arsize    ( ),
    .m_axi_arburst   ( ),
    .m_axi_arlock    ( ),
    .m_axi_arcache   ( ),
    .m_axi_arprot    ( ),
    .m_axi_arqos     ( ),
    .m_axi_arregion  ( ),
    .m_axi_arvalid   (read_stream_axi_m_arvalid  ),
    .m_axi_arready   (read_stream_axi_m_arready  ),
    .m_axi_rid       (read_stream_axi_m_rid      ),
    .m_axi_rdata     (read_stream_axi_m_rdata    ),
    .m_axi_rresp     (read_stream_axi_m_rresp    ),
    .m_axi_rlast     (read_stream_axi_m_rlast    ),
    .m_axi_rvalid    (read_stream_axi_m_rvalid   ),
    .m_axi_rready    (read_stream_axi_m_rready   ),

    .m_axi_awid      (write_stream_axi_m_awid     ),
    .m_axi_awaddr    (write_stream_axi_m_awaddr   ),
    .m_axi_awlen     (write_stream_axi_m_awlen    ),
    .m_axi_awsize    (write_stream_axi_m_awsize   ),
    .m_axi_awburst   (write_stream_axi_m_awburst  ),
    .m_axi_awlock    (write_stream_axi_m_awlock   ),
    .m_axi_awcache   (write_stream_axi_m_awcache  ),
    .m_axi_awprot    (write_stream_axi_m_awprot   ),
    .m_axi_awqos     (write_stream_axi_m_awqos    ),
    .m_axi_awregion  (write_stream_axi_m_awregion ),
    .m_axi_awvalid   (write_stream_axi_m_awvalid  ),
    .m_axi_awready   (write_stream_axi_m_awready  ),
    .m_axi_wid       (write_stream_axi_m_wid      ),
    .m_axi_wdata     (write_stream_axi_m_wdata    ),
    .m_axi_wstrb     (write_stream_axi_m_wstrb    ),
    .m_axi_wlast     (write_stream_axi_m_wlast    ),
    .m_axi_wvalid    (write_stream_axi_m_wvalid   ),
    .m_axi_wready    (write_stream_axi_m_wready   ),
    .m_axi_bid       (write_stream_axi_m_bid      ),
    .m_axi_bresp     (write_stream_axi_m_bresp    ),
    .m_axi_bvalid    (write_stream_axi_m_bvalid   ),
    .m_axi_bready    (write_stream_axi_m_bready   )
  );

  axi_read_mux #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH    (CL_ADDR_WIDTH),
    .CL_ID_WIDTH      (CL_ID_WIDTH),
    .CL_DATA_WIDTH    (CL_DATA_WIDTH)
  ) axi_read_mux_inst (
    .shield_m_axi_arid    ({AXI_ID_WIDTH{1'b0}}),
    .shield_m_axi_araddr  (read_mstr_axi_araddr  ),
    .shield_m_axi_arlen   (read_mstr_axi_arlen   ),
    .shield_m_axi_arsize  (3'b110),
    .shield_m_axi_arburst (2'b01),
    .shield_m_axi_arlock  (2'b00),
    .shield_m_axi_arcache (4'b0011),
    .shield_m_axi_arprot  (3'b000),
    .shield_m_axi_arqos   (4'b0000),
    .shield_m_axi_arregion(4'b0000),
    .shield_m_axi_arvalid (read_mstr_axi_arvalid ),
    .shield_m_axi_arready (read_mstr_axi_arready ),
    .shield_m_axi_rid     (read_mstr_axi_rid   ),
    .shield_m_axi_rdata   (read_mstr_axi_rdata ),
    .shield_m_axi_rresp   (read_mstr_axi_rresp ),
    .shield_m_axi_rlast   (read_mstr_axi_rlast ),
    .shield_m_axi_rvalid  (read_mstr_axi_rvalid),
    .shield_m_axi_rready  (read_mstr_axi_rready),
    .shield_s_axi_rid     (read_slv_axi_rid),
    .shield_s_axi_rdata   (read_slv_axi_rdata),
    .shield_s_axi_rresp   (read_slv_axi_rresp),
    .shield_s_axi_rlast   (read_slv_axi_rlast),
    .shield_s_axi_rvalid  (read_slv_axi_rvalid),
    .shield_s_axi_rready  (read_slv_axi_rready),

    .stream_m_axi_arid    ({AXI_ID_WIDTH{1'b0}}),
    .stream_m_axi_araddr  (read_stream_axi_m_araddr  ),
    .stream_m_axi_arlen   (read_stream_axi_m_arlen   ),
    .stream_m_axi_arsize  (3'b110),
    .stream_m_axi_arburst (2'b01),
    .stream_m_axi_arlock  (2'b00),
    .stream_m_axi_arcache (4'b0011),
    .stream_m_axi_arprot  (3'b000),
    .stream_m_axi_arqos   (4'b0000),
    .stream_m_axi_arregion(4'b0000),
    .stream_m_axi_arvalid (read_stream_axi_m_arvalid ),
    .stream_m_axi_arready (read_stream_axi_m_arready ),
    .stream_m_axi_rid     (read_stream_axi_m_rid   ),
    .stream_m_axi_rdata   (read_stream_axi_m_rdata ),
    .stream_m_axi_rresp   (read_stream_axi_m_rresp ),
    .stream_m_axi_rlast   (read_stream_axi_m_rlast ),
    .stream_m_axi_rvalid  (read_stream_axi_m_rvalid),
    .stream_m_axi_rready  (read_stream_axi_m_rready),
    .stream_s_axi_rid     (read_stream_axi_s_rid),
    .stream_s_axi_rdata   (read_stream_axi_s_rdata),
    .stream_s_axi_rresp   (read_stream_axi_s_rresp),
    .stream_s_axi_rlast   (read_stream_axi_s_rlast),
    .stream_s_axi_rvalid  (read_stream_axi_s_rvalid),
    .stream_s_axi_rready  (read_stream_axi_s_rready),

    .dram_axi_arid        (m_axi_arid),
    .dram_axi_araddr      (m_axi_araddr),
    .dram_axi_arlen       (m_axi_arlen),
    .dram_axi_arsize      (m_axi_arsize),
    .dram_axi_arburst     (m_axi_arburst),
    .dram_axi_arlock      (m_axi_arlock),
    .dram_axi_arcache     (m_axi_arcache),
    .dram_axi_arprot      (m_axi_arprot),
    .dram_axi_arqos       (m_axi_arqos),
    .dram_axi_arregion    (m_axi_arregion),
    .dram_axi_arvalid     (m_axi_arvalid),
    .dram_axi_arready     (m_axi_arready),
    .dram_axi_rid         (m_axi_rid),
    .dram_axi_rdata       (m_axi_rdata),
    .dram_axi_rresp       (m_axi_rresp),
    .dram_axi_rlast       (m_axi_rlast),
    .dram_axi_rvalid      (m_axi_rvalid),
    .dram_axi_rready      (m_axi_rready),

    .cl_axi_rid           (cl_axi_rid   ),
    .cl_axi_rdata         (cl_axi_rdata ),
    .cl_axi_rresp         (cl_axi_rresp ), 
    .cl_axi_rlast         (cl_axi_rlast ), 
    .cl_axi_rvalid        (cl_axi_rvalid),
    .cl_axi_rready        (cl_axi_rready),

    .sel                  (stream_axi_read_mux_sel)
  );

  axi_write_mux #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH    (CL_ADDR_WIDTH),
    .CL_ID_WIDTH      (CL_ID_WIDTH),
    .CL_DATA_WIDTH    (CL_DATA_WIDTH)
  ) axi_write_mux_inst (
    .shield_m_axi_awid    (write_mstr_axi_awid    ),
    .shield_m_axi_awaddr  (write_mstr_axi_awaddr  ),
    .shield_m_axi_awlen   (write_mstr_axi_awlen   ),
    .shield_m_axi_awsize  (write_mstr_axi_awsize  ),
    .shield_m_axi_awburst (write_mstr_axi_awburst ),
    .shield_m_axi_awlock  (write_mstr_axi_awlock  ),
    .shield_m_axi_awcache (write_mstr_axi_awcache ),
    .shield_m_axi_awprot  (write_mstr_axi_awprot  ),
    .shield_m_axi_awqos   (write_mstr_axi_awqos   ),
    .shield_m_axi_awregion(write_mstr_axi_awregion),
    .shield_m_axi_awvalid (write_mstr_axi_awvalid ),
    .shield_m_axi_awready (write_mstr_axi_awready ),
    .shield_m_axi_wid     (write_mstr_axi_wid     ),
    .shield_m_axi_wdata   (write_mstr_axi_wdata   ),
    .shield_m_axi_wstrb   (write_mstr_axi_wstrb   ),
    .shield_m_axi_wlast   (write_mstr_axi_wlast   ),
    .shield_m_axi_wvalid  (write_mstr_axi_wvalid  ),
    .shield_m_axi_wready  (write_mstr_axi_wready  ),
    .shield_m_axi_bid     (write_mstr_axi_bid     ),
    .shield_m_axi_bresp   (write_mstr_axi_bresp   ),
    .shield_m_axi_bvalid  (write_mstr_axi_bvalid  ),
    .shield_m_axi_bready  (write_mstr_axi_bready  ),

    .shield_s_axi_wid     (write_slv_axi_wid    ),
    .shield_s_axi_wdata   (write_slv_axi_wdata  ),
    .shield_s_axi_wstrb   (write_slv_axi_wstrb  ),
    .shield_s_axi_wlast   (write_slv_axi_wlast  ),
    .shield_s_axi_wvalid  (write_slv_axi_wvalid ),
    .shield_s_axi_wready  (write_slv_axi_wready ),
    .shield_s_axi_bid     ({CL_ID_WIDTH{1'b0}}   ),
    .shield_s_axi_bresp   (2'b00 ),
    .shield_s_axi_bvalid  (cl_write_resp_val ),
    .shield_s_axi_bready  (cl_write_resp_rdy ),

    .stream_m_axi_awid    (write_stream_axi_m_awid    ),
    .stream_m_axi_awaddr  (write_stream_axi_m_awaddr  ),
    .stream_m_axi_awlen   (write_stream_axi_m_awlen   ),
    .stream_m_axi_awsize  (write_stream_axi_m_awsize  ),
    .stream_m_axi_awburst (write_stream_axi_m_awburst ),
    .stream_m_axi_awlock  (write_stream_axi_m_awlock  ),
    .stream_m_axi_awcache (write_stream_axi_m_awcache ),
    .stream_m_axi_awprot  (write_stream_axi_m_awprot  ),
    .stream_m_axi_awqos   (write_stream_axi_m_awqos   ),
    .stream_m_axi_awregion(write_stream_axi_m_awregion),
    .stream_m_axi_awvalid (write_stream_axi_m_awvalid ),
    .stream_m_axi_awready (write_stream_axi_m_awready ),
    .stream_m_axi_wid     (write_stream_axi_m_wid     ),
    .stream_m_axi_wdata   (write_stream_axi_m_wdata   ),
    .stream_m_axi_wstrb   (write_stream_axi_m_wstrb   ),
    .stream_m_axi_wlast   (write_stream_axi_m_wlast   ),
    .stream_m_axi_wvalid  (write_stream_axi_m_wvalid  ),
    .stream_m_axi_wready  (write_stream_axi_m_wready  ),
    .stream_m_axi_bid     (write_stream_axi_m_bid     ),
    .stream_m_axi_bresp   (write_stream_axi_m_bresp   ),
    .stream_m_axi_bvalid  (write_stream_axi_m_bvalid  ),
    .stream_m_axi_bready  (write_stream_axi_m_bready  ),

    .stream_s_axi_wid     (write_stream_axi_s_wid   ),
    .stream_s_axi_wdata   (write_stream_axi_s_wdata ),
    .stream_s_axi_wstrb   (write_stream_axi_s_wstrb ),
    .stream_s_axi_wlast   (write_stream_axi_s_wlast ),
    .stream_s_axi_wvalid  (write_stream_axi_s_wvalid),
    .stream_s_axi_wready  (write_stream_axi_s_wready),
    .stream_s_axi_bid     (write_stream_axi_s_bid   ),
    .stream_s_axi_bresp   (write_stream_axi_s_bresp ),
    .stream_s_axi_bvalid  (write_stream_axi_s_bvalid),
    .stream_s_axi_bready  (write_stream_axi_s_bready),

    .dram_axi_awid        (m_axi_awid        ),
    .dram_axi_awaddr      (m_axi_awaddr      ),
    .dram_axi_awlen       (m_axi_awlen       ),
    .dram_axi_awsize      (m_axi_awsize      ),
    .dram_axi_awburst     (m_axi_awburst     ),
    .dram_axi_awlock      (m_axi_awlock      ),
    .dram_axi_awcache     (m_axi_awcache     ),
    .dram_axi_awprot      (m_axi_awprot      ),
    .dram_axi_awqos       (m_axi_awqos       ),
    .dram_axi_awregion    (m_axi_awregion    ),
    .dram_axi_awvalid     (m_axi_awvalid     ),
    .dram_axi_awready     (m_axi_awready     ),
    .dram_axi_wid         (m_axi_wid         ),
    .dram_axi_wdata       (m_axi_wdata       ),
    .dram_axi_wstrb       (m_axi_wstrb       ),
    .dram_axi_wlast       (m_axi_wlast       ),
    .dram_axi_wvalid      (m_axi_wvalid      ),
    .dram_axi_wready      (m_axi_wready      ),
    .dram_axi_bid         (m_axi_bid         ),
    .dram_axi_bresp       (m_axi_bresp       ),
    .dram_axi_bvalid      (m_axi_bvalid      ),
    .dram_axi_bready      (m_axi_bready      ),

    .cl_axi_wid           (cl_axi_wid    ), //unused
    .cl_axi_wdata         (cl_axi_wdata  ),
    .cl_axi_wstrb         (cl_axi_wstrb  ), //unused. set to all 1 assumed
    .cl_axi_wlast         (cl_axi_wlast  ), //unused - calculated internally
    .cl_axi_wvalid        (cl_axi_wvalid ),
    .cl_axi_wready        (cl_axi_wready ),
    .cl_axi_bid           (cl_axi_bid    ), //unused
    .cl_axi_bresp         (cl_axi_bresp  ), //unused - replies ok
    .cl_axi_bvalid        (cl_axi_bvalid ),
    .cl_axi_bready        (cl_axi_bready ),

    .sel                  (stream_axi_write_mux_sel)

  );



endmodule : shield_datapath

`default_nettype wire
