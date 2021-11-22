//Mark Zhao
//8/13/20
//Top level module for stream write
`include "free_common_defines.vh"

`default_nettype none

module stream_write #(
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer AXI_ID_WIDTH = 16,
  parameter integer AXI_DATA_WIDTH = 512,
  parameter integer CL_ADDR_WIDTH = 64,
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64,
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer PAGE_OFFSET_WIDTH = 12,
  parameter integer PAGE_SIZE = 4096
)
(
  input  wire clk,
  input  wire rst_n,

  //Request from datapath
  input  wire [SHIELD_ADDR_WIDTH-1:0] req_addr,
  input  wire [8:0] req_burst_count,
  input  wire                         req_flush,
  input  wire                         req_last,
  input  wire                         req_val,
  output wire                         req_rdy,

  output wire                         busy,

  //Input from CL
  input  wire [CL_ID_WIDTH-1:0]       s_axi_wid,
  input  wire [CL_DATA_WIDTH-1:0]     s_axi_wdata,
  input  wire [CL_DATA_WIDTH/8-1:0]   s_axi_wstrb, //IGNORED FOR NOW
  input  wire                         s_axi_wlast,
  input  wire                         s_axi_wvalid,
  output wire                         s_axi_wready,
  output wire [CL_ID_WIDTH-1:0]       s_axi_bid, //unused
  output wire [1:0]                   s_axi_bresp, //unused - replies ok
  output wire                         s_axi_bvalid,
  input  wire                         s_axi_bready,

  //Output to DRAM
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
  localparam CL_STATE_IDLE        = 4'd0,
             CL_STATE_RXFER       = 4'd1,
             CL_STATE_FLUSH_INIT  = 4'd2,
             CL_STATE_FLUSH       = 4'd3,
             CL_STATE_RESP        = 4'd4;

  localparam AXI_STATE_IDLE        = 4'd0,
             AXI_STATE_INIT_CRYPTO = 4'd1,
             AXI_STATE_WR_DATA_REQ = 4'd2,
             AXI_STATE_AES_ENCRYPT = 4'd3,
             AXI_STATE_AES_REQ     = 4'd4,
             AXI_STATE_WRITE_DATA  = 4'd5,
             AXI_STATE_WR_TAG_REQ  = 4'd6,
             AXI_STATE_WR_TAG      = 4'd7,
             AXI_STATE_WR_TAG_RESP = 4'd8;
      

  //The size of the buffer tag - aligned to page size
  localparam integer BUFFER_TAG_WIDTH = SHIELD_ADDR_WIDTH-PAGE_OFFSET_WIDTH;
  localparam integer AXI_DATA_WIDTH_BYTES = AXI_DATA_WIDTH / 8;
  localparam integer PLAINTEXT_RAM_INDEX_WIDTH = $clog2(PAGE_SIZE / AXI_DATA_WIDTH_BYTES);
  localparam integer AXI_BURST_OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH_BYTES);

  //How many cl bursts fit in an axi burst
  localparam integer CL_TO_AXI_BURSTS = AXI_DATA_WIDTH / CL_DATA_WIDTH; 
  localparam integer CL_TO_AXI_BURSTS_LOG = $clog2(CL_TO_AXI_BURSTS);

  localparam integer CL_DATA_WIDTH_BYTES = CL_DATA_WIDTH / 8;

  //FIFO params
  localparam integer AXI_FIFO_DEPTH = PAGE_SIZE / AXI_DATA_WIDTH_BYTES; //needs to be big enough to hold entire ram

  //address params
  localparam integer MAC_TAG_PER_BURST = AXI_DATA_WIDTH / 128;
  localparam integer MAC_TAG_PER_BURST_LOG = $clog2(MAC_TAG_PER_BURST);

  localparam integer AES_BURSTS_PER_PAGE = PAGE_SIZE / AXI_DATA_WIDTH_BYTES; //how many aes rounds in page
  localparam integer AES_BURSTS_PER_PAGE_LOG = $clog2(AES_BURSTS_PER_PAGE);

  localparam integer AXI_WSTRB_WIDTH = AXI_DATA_WIDTH / 8;

  `ifdef USE_PMAC
    `ifdef NUM_PMAC_PARALLEL_4
      localparam integer PMAC_DATA_WIDTH = 512;
    `elsif NUM_PMAC_PARALLEL_8
      localparam integer PMAC_DATA_WIDTH = 1024;
    `elsif NUM_PMAC_PARALLEL_16
      localparam integer PMAC_DATA_WIDTH = 2048;
    `endif
    localparam integer PMAC_DATA_WIDTH_BYTES = PMAC_DATA_WIDTH / 8;
    localparam integer PMAC_BURST_COUNT = 4096 / PMAC_DATA_WIDTH_BYTES;
  `endif

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  //CL FSM
  logic [3:0] cl_state_r;
  logic [3:0] next_cl_state;

  //Registers for RAM state
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_r;
  logic [BUFFER_TAG_WIDTH-1:0]  buffer_tag_r;
  logic                         buffer_tag_valid_r;
  logic [BUFFER_TAG_WIDTH-1:0]  flush_tag_r;
  logic                         req_last_r;

  //RAM read/write signals
  logic [PLAINTEXT_RAM_INDEX_WIDTH-1:0] pt_ram_read_index;
  logic [PLAINTEXT_RAM_INDEX_WIDTH-1:0] pt_ram_write_index;
  logic [AXI_DATA_WIDTH_BYTES-1:0]      pt_ram_write_byte_en;
  logic [AXI_DATA_WIDTH-1:0] plaintext;
  logic [AXI_DATA_WIDTH-1:0] pt_ram_dout;
  logic [PLAINTEXT_RAM_INDEX_WIDTH-1:0] pt_ram_write_start_index;
  logic [CL_TO_AXI_BURSTS_LOG-1:0] burst_start_index;
  logic [CL_TO_AXI_BURSTS_LOG-1:0] burst_index_r;


  //Control signals
  logic cs_req_rdy;
  logic cs_buffer_tag_we;
  logic cs_buffer_tag_valid;
  logic cs_pt_ram_write_index_incr;
  logic cs_cl_rxfer;
  logic cs_s_axi_wready;
  logic cs_ram_aes_fifo_we;
  logic cs_pt_ram_read_index_incr;
  logic cs_flush_go;
  logic cs_s_axi_bvalid;

  //Status signals
  logic buffer_tag_match;
  logic last_line_burst;
  logic burst_done;
  logic ram_aes_fifo_full;
  logic flush_done;


  //AXI FSM
  logic [3:0] axi_state_r;
  logic [3:0] next_axi_state;

  logic [AXI_DATA_WIDTH-1:0] ram_aes_fifo_dout;


  //aes logic
  logic [AXI_DATA_WIDTH-1:0] aes_pad;
  logic [AXI_DATA_WIDTH-1:0] ciphertext;
  logic aes_enc_done;

  //AXI logic
  logic [AXI_ADDR_WIDTH-1:0] flush_addr;
  logic [AXI_ADDR_WIDTH-1:0] flush_addr_r;
  logic [SHIELD_ADDR_WIDTH-1:0] tag_addr_aligned_mask;
  logic [AXI_ADDR_WIDTH-1:0] tag_addr_r;
  logic [MAC_TAG_PER_BURST_LOG-1:0] tag_offset_r;
  logic axi_write_done;
  logic axi_write_last;
  logic [7:0] axi_write_count;

  logic [AXI_DATA_WIDTH-1:0] aes_axi_fifo_dout;
  logic                      aes_axi_fifo_empty;
  logic                      aes_axi_fifo_full;
  logic                      aes_axi_fifo_rd_en;

  logic aes_axi_fifo_txfer;


  //mac logic
  `ifdef USE_HMAC
    logic [AXI_DATA_WIDTH-1:0] axi_hmac_fifo_dout;
  `elsif USE_PMAC
    logic [PMAC_DATA_WIDTH-1:0] axi_hmac_fifo_dout;
  `endif
  logic [AXI_DATA_WIDTH-1:0] aes_mac_fifo_dout;
  logic                      aes_mac_fifo_empty;
  logic                      aes_mac_fifo_full;
  logic                      aes_mac_fifo_rd_en;

  logic [127:0]              mac_tag;
  logic                      mac_tag_val;

  logic [AXI_DATA_WIDTH-1:0] mac_tag_burst;
  logic [AXI_WSTRB_WIDTH-1:0] mac_tag_wstrb;

  logic axi_awvalid_r;

  //control
  logic cs_aes_req_val;
  logic cs_aes_resp_rdy;
  logic cs_flush_rdy;
  logic cs_mac_req_val;
  logic cs_aes_out_fifo_we;
  logic cs_mac_tag_rdy;
  logic cs_m_axi_awvalid;
  logic cs_req_addr_mux_sel;
  logic cs_axi_wdata_mux_sel;
  logic cs_m_axi_bready;
  logic cs_axi_awvalid_r_val;
  logic cs_axi_awvalid_r_we;

  //status
  logic ram_aes_fifo_empty;
  logic aes_req_rdy;
  logic aes_resp_val;
  logic mac_req_rdy;


  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //Store addr corresponding to current req
  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) addr_reg(
    .clk(clk),
    .q(req_addr_r),
    .d(req_addr),
    .en(cs_req_rdy)
  );

  //Store the tag corresponding to page currently in RAM
  shield_enrstreg #(.WIDTH(BUFFER_TAG_WIDTH)) buffer_tag_reg(
    .clk(clk),
    .rst_n(rst_n),
    .q(buffer_tag_r),
    .d(req_addr[SHIELD_ADDR_WIDTH-1 -: BUFFER_TAG_WIDTH]),
    .en(cs_buffer_tag_we)
  );
  shield_enrstreg #(.WIDTH(1)) buffer_tag_valid_reg(
    .clk(clk),
    .rst_n(rst_n),
    .q(buffer_tag_valid_r),
    .d(cs_buffer_tag_valid),
    .en(cs_buffer_tag_we)
  );

  shield_enreg #(.WIDTH(1)) last_reg(
    .clk(clk),
    .q(req_last_r),
    .d(req_last),
    .en(cs_req_rdy)
  );

  assign buffer_tag_match = (req_addr[SHIELD_ADDR_WIDTH-1 -: BUFFER_TAG_WIDTH] == buffer_tag_r);

  //Store the tag of the buffer-to-flush
  shield_enrstreg #(.WIDTH(BUFFER_TAG_WIDTH)) flush_tag_reg(
    .clk(clk),
    .rst_n(rst_n),
    .q(flush_tag_r),
    .d(buffer_tag_r),
    .en(cs_buffer_tag_we)
  );



  //RAM for plaintext
  //Generate addresses for RAM
  assign pt_ram_write_start_index = req_addr[PAGE_OFFSET_WIDTH-1 -: PLAINTEXT_RAM_INDEX_WIDTH];
  shield_counter #(.C_WIDTH(PLAINTEXT_RAM_INDEX_WIDTH)) ram_write_index_counter(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //load by main FSM
    .incr(cs_pt_ram_write_index_incr),
    .decr(1'b0),
    .load_value(pt_ram_write_start_index),
    .count(pt_ram_write_index),
    .is_zero()
  );
  
  //Index into each PT RAM line (width converter)
  assign burst_start_index = req_addr[AXI_BURST_OFFSET_WIDTH-1 -: CL_TO_AXI_BURSTS_LOG];
  shield_counter #(
    .C_WIDTH(CL_TO_AXI_BURSTS_LOG)
  ) burst_index_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //loaded by main fsm, wraps around
    .incr(cs_cl_rxfer),
    .decr(1'b0),
    .load_value(burst_start_index),
    .count(burst_index_r),
    .is_zero()
  );
  //Set when this rxfer is the last one in this line
  assign last_line_burst = (burst_index_r == {CL_TO_AXI_BURSTS_LOG{1'b1}});

  //Counter to track remaining bursts to expect
  shield_counter #(
    .C_WIDTH(9)
  ) burst_count_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //loaded by main FSM
    .incr(1'b0),
    .decr(cs_cl_rxfer),
    .load_value(req_burst_count),
    .count(),
    .is_zero(burst_done)
  );

  //Create the byte enable signal for the RAM
  genvar i;
  generate
    for(i = 0; i < CL_TO_AXI_BURSTS; i++) begin
      assign pt_ram_write_byte_en[i*(CL_DATA_WIDTH_BYTES) +: CL_DATA_WIDTH_BYTES] =
        (burst_index_r == i) ? ({CL_DATA_WIDTH_BYTES{1'b1}}) : ({CL_DATA_WIDTH_BYTES{1'b0}});
    end
  endgenerate

  //Just duplicate the data signal - the byte en will handle the rest
  assign plaintext = {CL_TO_AXI_BURSTS{s_axi_wdata}};
  shield_ram_byte_en #(
    .DATA_WIDTH(AXI_DATA_WIDTH), 
    .ADDR_WIDTH(PLAINTEXT_RAM_INDEX_WIDTH),
    .ENABLE_WIDTH(AXI_DATA_WIDTH_BYTES)) plaintext_ram(
    .clk(clk),
    .wr_addr( pt_ram_write_index ),
    .wr_en  ( cs_cl_rxfer ),
    .wr_data( plaintext ),
    .wr_byte_en( pt_ram_write_byte_en ),
    .rd_addr( pt_ram_read_index ),
    .rd_data( pt_ram_dout )
  );


  //Counter for ram read index
  shield_counter #(
    .C_WIDTH(PLAINTEXT_RAM_INDEX_WIDTH)
  ) ram_read_index_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //Okay to reset this early - won't be reset until all flushed
    .incr(cs_pt_ram_read_index_incr),
    .decr(1'b0),
    .load_value(0),
    .count(pt_ram_read_index),
    .is_zero(flush_done)
  );

  //tie off unused axi signals
  assign s_axi_bid = {CL_ID_WIDTH{1'b0}};
  assign s_axi_bresp = 2'b00;


  //FIFO for RAM -> aes
	xpm_fifo_sync # (
	  .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
	  .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
	  .FIFO_WRITE_DEPTH          (AXI_FIFO_DEPTH),   //positive integer
	  .WRITE_DATA_WIDTH          (AXI_DATA_WIDTH),               //positive integer
	  .WR_DATA_COUNT_WIDTH       ($clog2(AXI_FIFO_DEPTH)),               //positive integer, Not used
	  .PROG_FULL_THRESH          (10),               //positive integer, Not used 
	  .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
	  .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
	  .FIFO_READ_LATENCY         (0),                //positive integer;
	  .READ_DATA_WIDTH           (AXI_DATA_WIDTH),               //positive integer
	  .RD_DATA_COUNT_WIDTH       ($clog2(AXI_FIFO_DEPTH)),               //positive integer, not used
	  .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
	  .DOUT_RESET_VALUE          ("0"),              //string, don't care
	  .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;
	) ram_aes_fifo_sync (
  	.sleep         ( 1'b0             ) ,
  	.rst           ( ~rst_n           ) ,
  	.wr_clk        ( clk           ) ,
  	.wr_en         ( cs_ram_aes_fifo_we ) ,
  	.din           ( pt_ram_dout ) ,
  	.full          ( ram_aes_fifo_full ) ,
  	.prog_full     (                  ) ,
  	.wr_data_count (                  ) ,
  	.overflow      (                  ) ,
  	.wr_rst_busy   (                  ) ,
  	.rd_en         ( cs_aes_out_fifo_we   ) ,
  	.dout          ( ram_aes_fifo_dout ) ,
  	.empty         ( ram_aes_fifo_empty ) ,
  	.prog_empty    (                  ) ,
  	.rd_data_count (                  ) ,
  	.underflow     (                  ) ,
  	.rd_rst_busy   (                  ) ,
  	.injectsbiterr ( 1'b0             ) ,
  	.injectdbiterr ( 1'b0             ) ,
  	.sbiterr       (                  ) ,
  	.dbiterr       (                  ) 
	);

  aes_parallel aes_parallel_inst(
    .clk(clk),
    .rst_n(rst_n),
    .nonce(96'd0),
    .counter(32'd0),
    .req_val(cs_aes_req_val),
    .req_rdy(aes_req_rdy),
    .pad(aes_pad),
    .pad_val(aes_resp_val),
    .pad_rdy(cs_aes_resp_rdy)
  );
  //genvar j;
  //generate
  //  for(j = 0; j < NUM_AES; j++) begin
  //    aes #(.DATA_WIDTH(128)) aes_inst(
  //      .clk(clk),
  //      .rst_n(rst_n),
  //      .nonce(96'd0), //TODO: Set to IV plus chunk count
  //      .counter(32'd0), //TODO: 32 bit block counter for this chunk
  //      .req_val(cs_aes_req_val[j]),
  //      .req_rdy(aes_req_rdy[j]),
  //      .pad(aes_pad[j*128 +: 128]),
  //      .pad_val(aes_resp_val[j]),
  //      .pad_rdy(cs_aes_resp_rdy[j])
  //    );
  //  end
  //endgenerate

  `ifdef NO_ENCRYPT
    assign ciphertext = ram_aes_fifo_dout;
  `else
    assign ciphertext = ram_aes_fifo_dout ^ aes_pad;
  `endif

  //Store the address of the buffer-to-flush
  assign flush_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, flush_tag_r, {(PAGE_OFFSET_WIDTH){1'b0}}};
  shield_enreg #(.WIDTH(AXI_ADDR_WIDTH)) flush_addr_reg(
    .clk(clk),
    .q(flush_addr_r),
    .d(flush_addr),
    .en(cs_flush_rdy)
  );

  //compute address for tag
  assign tag_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << (PAGE_OFFSET_WIDTH + MAC_TAG_PER_BURST_LOG);
  assign tag_addr_r = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, ((flush_addr_r & tag_addr_aligned_mask) >> (MAC_TAG_PER_BURST_LOG + (PAGE_OFFSET_WIDTH - AXI_BURST_OFFSET_WIDTH)))} + `TAG_BASE_ADDR;
  assign tag_offset_r = flush_addr_r[PAGE_OFFSET_WIDTH +: MAC_TAG_PER_BURST_LOG];


  //Counter to track remaining bursts to encrypt
  shield_counter #(
    .C_WIDTH(AES_BURSTS_PER_PAGE_LOG+1)
  ) encrypt_count_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_flush_rdy), //loaded by main FSM
    .incr(1'b0),
    .decr(cs_aes_out_fifo_we),
    .load_value(AES_BURSTS_PER_PAGE),
    .count(),
    .is_zero(aes_enc_done)
  );


  //FIFO for aes -> mac
	xpm_fifo_sync # (
	  .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
	  .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
	  .FIFO_WRITE_DEPTH          (AXI_FIFO_DEPTH),   //positive integer
	  .WRITE_DATA_WIDTH          (AXI_DATA_WIDTH),               //positive integer
	  .WR_DATA_COUNT_WIDTH       ($clog2(AXI_FIFO_DEPTH)),               //positive integer, Not used
	  .PROG_FULL_THRESH          (16),               //positive integer, Not used 
	  .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
	  .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
	  .FIFO_READ_LATENCY         (0),                //positive integer;
    `ifdef USE_HMAC
	    .READ_DATA_WIDTH           (AXI_DATA_WIDTH),               //positive integer
    `elsif USE_PMAC
	    .READ_DATA_WIDTH           (PMAC_DATA_WIDTH),               //positive integer
    `endif
	  .RD_DATA_COUNT_WIDTH       (),               //positive integer, not used
	  .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
	  .DOUT_RESET_VALUE          ("0"),              //string, don't care
	  .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;
	) aes_mac_fifo_sync (
  	.sleep         ( 1'b0             ) ,
  	.rst           ( ~rst_n           ) ,
  	.wr_clk        ( clk           ) ,
  	.wr_en         ( cs_aes_out_fifo_we ) ,
  	.din           ( ciphertext ) ,
  	.full          ( aes_mac_fifo_full ) ,
  	.prog_full     (                  ) ,
  	.wr_data_count (                  ) ,
  	.overflow      (                  ) ,
  	.wr_rst_busy   (                  ) ,
  	.rd_en         ( aes_mac_fifo_rd_en ) ,
  	.dout          ( aes_mac_fifo_dout ) ,
  	.empty         ( aes_mac_fifo_empty ) ,
  	.prog_empty    (                  ) ,
  	.rd_data_count (                  ) ,
  	.underflow     (                  ) ,
  	.rd_rst_busy   (                  ) ,
  	.injectsbiterr ( 1'b0             ) ,
  	.injectdbiterr ( 1'b0             ) ,
  	.sbiterr       (                  ) ,
  	.dbiterr       (                  ) 
	);

  `ifdef USE_HMAC
    hmac_stream #(.DATA_COUNT_BURSTS(64)) hmac_stream_inst(
      .clk(clk),
      .rst_n(rst_n),

      .req_val(cs_mac_req_val),
      .req_rdy(mac_req_rdy),
      .stream_data(aes_mac_fifo_dout),
      .stream_data_val(~aes_mac_fifo_empty),
      .stream_data_rdy(aes_mac_fifo_rd_en),

      .hmac(mac_tag),
      .hmac_val(mac_tag_val),
      .hmac_rdy(cs_mac_tag_rdy)
    );
  `elsif USE_PMAC
    pmac #(.DATA_WIDTH(PMAC_DATA_WIDTH)) pmac_stream_inst(
      .clk(clk),
      .rst_n(rst_n),

      .req_val(cs_mac_req_val),
      .req_len(PMAC_BURST_COUNT),
      .req_rdy(mac_req_rdy),
      .stream_data(aes_mac_fifo_dout),
      .stream_data_val(~aes_mac_fifo_empty),
      .stream_data_rdy(aes_mac_fifo_rd_en),

      .pmac(mac_tag),
      .pmac_val(mac_tag_val),
      .pmac_rdy(cs_mac_tag_rdy)
    );
  `endif

  integer k;
  always_comb begin
    for(k=0; k < MAC_TAG_PER_BURST; k++) begin
      if(k == tag_offset_r) begin
        mac_tag_burst[(k*128) +: 128] = mac_tag;
        mac_tag_wstrb[(k*16) +: 16] = {16{1'b1}};
      end
      else begin
        mac_tag_burst[(k*128) +: 128] = {128{1'b0}};
        mac_tag_wstrb[(k*16) +: 16] = {16{1'b0}};
      end
    end
  end




  //FIFO for aes -> axi
	xpm_fifo_sync # (
	  .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
	  .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
	  .FIFO_WRITE_DEPTH          (AXI_FIFO_DEPTH),   //positive integer
	  .WRITE_DATA_WIDTH          (AXI_DATA_WIDTH),               //positive integer
	  .WR_DATA_COUNT_WIDTH       ($clog2(AXI_FIFO_DEPTH)),               //positive integer, Not used
	  .PROG_FULL_THRESH          (10),               //positive integer, Not used 
	  .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
	  .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
	  .FIFO_READ_LATENCY         (0),                //positive integer;
	  .READ_DATA_WIDTH           (AXI_DATA_WIDTH),               //positive integer
	  .RD_DATA_COUNT_WIDTH       ($clog2(AXI_FIFO_DEPTH)),               //positive integer, not used
	  .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
	  .DOUT_RESET_VALUE          ("0"),              //string, don't care
	  .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;
	) aes_axi_fifo_sync (
  	.sleep         ( 1'b0             ) ,
  	.rst           ( ~rst_n           ) ,
  	.wr_clk        ( clk           ) ,
  	.wr_en         ( cs_aes_out_fifo_we ) ,
  	.din           ( ciphertext ) ,
  	.full          ( aes_axi_fifo_full ) ,
  	.prog_full     (                  ) ,
  	.wr_data_count (                  ) ,
  	.overflow      (                  ) ,
  	.wr_rst_busy   (                  ) ,
  	.rd_en         ( aes_axi_fifo_rd_en ) ,
  	.dout          ( aes_axi_fifo_dout ) ,
  	.empty         ( aes_axi_fifo_empty ) ,
  	.prog_empty    (                  ) ,
  	.rd_data_count (                  ) ,
  	.underflow     (                  ) ,
  	.rd_rst_busy   (                  ) ,
  	.injectsbiterr ( 1'b0             ) ,
  	.injectdbiterr ( 1'b0             ) ,
  	.sbiterr       (                  ) ,
  	.dbiterr       (                  ) 
	);

  shield_mux2 #(.WIDTH(AXI_ADDR_WIDTH)) req_addr_mux(
    .in0(flush_addr_r),
    .in1(tag_addr_r),
    .sel(cs_req_addr_mux_sel),
    .out(m_axi_awaddr)
  );
  shield_mux2 #(.WIDTH(8)) req_len_mux(
    .in0(8'd63),
    .in1(8'd0),
    .sel(cs_req_addr_mux_sel),
    .out(m_axi_awlen)
  );

  //Counter to track remaining bursts to write out to DRAM
  assign aes_axi_fifo_txfer = (aes_axi_fifo_rd_en && (!aes_axi_fifo_empty));
  shield_counter #(
    .C_WIDTH(8)
  ) axi_write_count_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_flush_rdy), //loaded by main FSM
    .incr(1'b0),
    .decr(aes_axi_fifo_txfer),
    .load_value(8'd64),
    .count(axi_write_count),
    .is_zero(axi_write_done)
  );


  //Tie off unused AXI signals
  assign m_axi_awid = {AXI_ID_WIDTH{1'b0}};
  assign m_axi_awsize = 3'b110; //write 64B
  assign m_axi_awburst = 2'b01;
	assign m_axi_awlock   = 2'b00;
	assign m_axi_awcache  = 4'b0011;
	assign m_axi_awprot   = 3'b000;
	assign m_axi_awqos    = 4'b0000;
	assign m_axi_awregion = 4'b0000;

  assign m_axi_wid = {AXI_ID_WIDTH{1'b0}};

  shield_mux2 #(.WIDTH(AXI_DATA_WIDTH)) axi_wdata_mux(
    .in0(aes_axi_fifo_dout),
    .in1(mac_tag_burst),
    .sel(cs_axi_wdata_mux_sel),
    .out(m_axi_wdata)
  );

  shield_mux2 #(.WIDTH(AXI_WSTRB_WIDTH)) axi_wstrb_mux(
    .in0({AXI_WSTRB_WIDTH{1'b1}}),
    .in1(mac_tag_wstrb),
    .sel(cs_axi_wdata_mux_sel),
    .out(m_axi_wstrb)
  );

  assign axi_write_last = (axi_write_count == 8'd1);
  shield_mux2 #(.WIDTH(1)) axi_wlast_mux(
    .in0(axi_write_last),
    .in1(1'b1),
    .sel(cs_axi_wdata_mux_sel),
    .out(m_axi_wlast)
  );

  shield_mux2 #(.WIDTH(1)) axi_wvalid_mux(
    .in0((~aes_axi_fifo_empty)),
    .in1(mac_tag_val),
    .sel(cs_axi_wdata_mux_sel),
    .out(m_axi_wvalid)
  );

  shield_mux2 #(.WIDTH(1)) axi_wready_mux(
    .in0(m_axi_wready),
    .in1(1'b0),
    .sel(cs_axi_wdata_mux_sel),
    .out(aes_axi_fifo_rd_en)
  );

  shield_enreg #(.WIDTH(1)) axi_awvalid_reg(
    .clk(clk),
    .q(axi_awvalid_r),
    .d(cs_axi_awvalid_r_val),
    .en(cs_axi_awvalid_r_we)
  );


  //////////////////////////////////////////////////////////////////////////////
  // Control logic
  //////////////////////////////////////////////////////////////////////////////
  //FSM for accepting writes into RAM
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      cl_state_r <= CL_STATE_IDLE;
    end
    else begin
      cl_state_r <= next_cl_state;
    end
  end

  //State transition
  always_comb begin
    next_cl_state = cl_state_r;
    case (cl_state_r)
      CL_STATE_IDLE: begin
        if(req_val) begin
          if(req_flush) begin
            next_cl_state = CL_STATE_FLUSH_INIT;
          end
          //Does the request match what is currently stored in RAM?
          else if(buffer_tag_match && buffer_tag_valid_r) begin //RAM valid and match
            next_cl_state = CL_STATE_RXFER;
          end
          else if(!buffer_tag_valid_r) begin //If tag is invalid, also ok to write
            next_cl_state = CL_STATE_RXFER;
          end
          else begin //valid tag, but miss - flush RAM before accepting write reqs
            next_cl_state = CL_STATE_FLUSH_INIT;
          end
        end
      end
      CL_STATE_RXFER: begin //receive writes from cl
        if(burst_done) begin
          if(req_last_r) begin
            next_cl_state = CL_STATE_RESP;
          end
          else begin
            next_cl_state = CL_STATE_IDLE;
          end
        end
      end
      CL_STATE_FLUSH_INIT: begin //initialize flush
        if(cs_flush_rdy && ram_aes_fifo_empty) begin //wait for ram-aes fifo to be empty
          next_cl_state = CL_STATE_FLUSH;
        end
      end
      CL_STATE_FLUSH: begin
        if(flush_done) begin
          next_cl_state = CL_STATE_RXFER;
        end
      end
      CL_STATE_RESP: begin
        if(s_axi_bready) begin
          next_cl_state = CL_STATE_IDLE;
        end
      end
    endcase
  end

  //Output logic
  //Output
  always_comb begin
    cs_req_rdy = 1'b0;
    cs_buffer_tag_we = 1'b0;
    cs_buffer_tag_valid = 1'b0;
    cs_pt_ram_write_index_incr = 1'b0;
    cs_cl_rxfer = 1'b0;
    cs_s_axi_wready = 1'b0;
    cs_ram_aes_fifo_we = 1'b0;
    cs_pt_ram_read_index_incr = 1'b0;
    cs_flush_go = 1'b0;
    cs_s_axi_bvalid = 1'b0;
    case (cl_state_r)
      CL_STATE_IDLE: begin //signal ready for accepting writes
        cs_req_rdy = 1'b1;
        if(req_val) begin //valid request - register tag
          cs_buffer_tag_we = 1'b1;
          cs_buffer_tag_valid = 1'b1;
        end
      end
      CL_STATE_RXFER: begin //receive writes
        if(!burst_done) begin
          cs_s_axi_wready = 1'b1;
          if(s_axi_wvalid) begin //rxfer
            cs_cl_rxfer = 1'b1;
            //Increment ram write index if necessary
            if(last_line_burst) begin
              cs_pt_ram_write_index_incr = 1'b1;
            end
          end
        end
      end
      CL_STATE_FLUSH_INIT: begin 
        //it takes 1 cycle to increment ram index, plus 1 cycle to read contents of ram
        //index starts at 0, so when fifo is empty, begin incrementing read index
        if(ram_aes_fifo_empty && cs_flush_rdy) begin
          cs_flush_go = 1'b1;
          cs_pt_ram_read_index_incr = 1'b1;
        end
      end
      CL_STATE_FLUSH: begin //first time we reach this state, read index = 1, dout = ram[0]
        cs_ram_aes_fifo_we = 1'b1;
        //Assume that fifo is never full - ok if fifo is large enough since we check for empty
        cs_pt_ram_read_index_incr = 1'b1;
      end
      CL_STATE_RESP: begin //write bresp
        cs_s_axi_bvalid = 1'b1;
      end
    endcase
  end

  assign req_rdy = cs_req_rdy;
  assign s_axi_wready = cs_s_axi_wready;
  assign s_axi_bvalid = cs_s_axi_bvalid;

  //FSM for ram -> axi
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      axi_state_r <= AXI_STATE_IDLE;
    end
    else begin
      axi_state_r <= next_axi_state;
    end
  end

  always_comb begin
    next_axi_state = axi_state_r;
    case (axi_state_r)
      AXI_STATE_IDLE: begin //wait for cl fsm to trigger flush
        if(cs_flush_go) begin
          next_axi_state = AXI_STATE_INIT_CRYPTO;
        end
      end
      AXI_STATE_INIT_CRYPTO: begin //init crypto modules
        if((aes_req_rdy) && mac_req_rdy) begin
          //next_axi_state = AXI_STATE_WR_DATA_REQ;
          next_axi_state = AXI_STATE_AES_ENCRYPT;
        end
      end
      //AXI_STATE_WR_DATA_REQ: begin
      //  if(m_axi_awready) begin
      //    next_axi_state = AXI_STATE_AES_ENCRYPT;
      //  end
      //end
      AXI_STATE_AES_ENCRYPT: begin
        if((!aes_mac_fifo_full) && (!aes_axi_fifo_full) && (!ram_aes_fifo_empty) && (aes_resp_val)) begin
          next_axi_state = AXI_STATE_AES_REQ;
        end
      end
      AXI_STATE_AES_REQ: begin
        if(aes_enc_done) begin
          next_axi_state = AXI_STATE_WRITE_DATA;
        end
        else begin
          if(aes_req_rdy) begin
            next_axi_state = AXI_STATE_AES_ENCRYPT;
          end
        end
      end
      AXI_STATE_WRITE_DATA: begin
        if(axi_write_done && m_axi_bvalid) begin
          //next_axi_state = AXI_STATE_WR_TAG_REQ;
          next_axi_state = AXI_STATE_WR_TAG;
        end
      end
      //AXI_STATE_WR_TAG_REQ: begin
      //  if(m_axi_awready) begin
      //    next_axi_state = AXI_STATE_WR_TAG;
      //  end
      //end
      AXI_STATE_WR_TAG: begin
        if(m_axi_wready && m_axi_wvalid) begin
          next_axi_state = AXI_STATE_WR_TAG_RESP;
        end
      end
      AXI_STATE_WR_TAG_RESP: begin
        if(m_axi_bvalid) begin
          next_axi_state = AXI_STATE_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_flush_rdy = 1'b0;
    cs_aes_req_val = 1'b0;
    cs_aes_resp_rdy = 1'b0;
    cs_mac_req_val = 1'b0;
    cs_aes_out_fifo_we = 1'b0;
    cs_mac_tag_rdy = 1'b0;
    cs_m_axi_awvalid = 1'b0;
    cs_req_addr_mux_sel = 1'b0;
    cs_axi_wdata_mux_sel = 1'b0;
    cs_m_axi_bready = 1'b0;

    cs_axi_awvalid_r_val = 1'b0;
    cs_axi_awvalid_r_we = 1'b0;

    case (axi_state_r)
      AXI_STATE_IDLE: begin //wait for flush signal - store flush addr
        cs_flush_rdy = 1'b1;

        // Clear awvalid flag
        cs_axi_awvalid_r_val = 1'b0;
        cs_axi_awvalid_r_we = 1'b1;
      end
      AXI_STATE_INIT_CRYPTO: begin
        if((aes_req_rdy) && mac_req_rdy) begin
          cs_aes_req_val = 1'b1;
          cs_mac_req_val = 1'b1;
        end
      end
      //AXI_STATE_WR_DATA_REQ: begin
      //  cs_m_axi_awvalid = 1'b1;
      //  cs_req_addr_mux_sel = 1'b0; //data address
      //end
      AXI_STATE_AES_ENCRYPT: begin
        if((!aes_mac_fifo_full) && (!aes_axi_fifo_full) && (!ram_aes_fifo_empty) && (aes_resp_val)) begin
          cs_aes_resp_rdy = 1'b1;
          cs_aes_out_fifo_we = 1'b1;
        end

        // Set awvalid if not already done
        cs_req_addr_mux_sel = 1'b0;
        cs_axi_wdata_mux_sel = 1'b0;
        if ((axi_awvalid_r == 1'b0) && m_axi_wvalid) begin
          cs_m_axi_awvalid = 1'b1;
          if(m_axi_awready) begin
            cs_axi_awvalid_r_val = 1'b1;
            cs_axi_awvalid_r_we = 1'b1;
          end
        end
      end
      AXI_STATE_AES_REQ: begin
        cs_axi_wdata_mux_sel = 1'b0;
        if(!aes_enc_done) begin
          cs_aes_req_val = 1'b1;
        end

        // Set awvalid if not already done
        cs_req_addr_mux_sel = 1'b0;
        cs_axi_wdata_mux_sel = 1'b0;
        if ((axi_awvalid_r == 1'b0) && m_axi_wvalid) begin
          cs_m_axi_awvalid = 1'b1;
          if(m_axi_awready) begin
            cs_axi_awvalid_r_val = 1'b1;
            cs_axi_awvalid_r_we = 1'b1;
          end
        end
      end
      AXI_STATE_WRITE_DATA: begin
        // Set awvalid if not already done
        cs_req_addr_mux_sel = 1'b0;
        cs_axi_wdata_mux_sel = 1'b0;
        if ((axi_awvalid_r == 1'b0) && m_axi_wvalid) begin
          cs_m_axi_awvalid = 1'b1;
          if(m_axi_awready) begin
            cs_axi_awvalid_r_val = 1'b1;
            cs_axi_awvalid_r_we = 1'b1;
          end
        end
        else if(axi_write_done && m_axi_bvalid) begin
          cs_m_axi_bready = 1'b1;

          // Clear the awvalid reg
          cs_axi_awvalid_r_val = 1'b0;
          cs_axi_awvalid_r_we = 1'b1;
        end
      end
      //AXI_STATE_WR_TAG_REQ: begin
      //  cs_axi_wdata_mux_sel = 1'b1;
      //  cs_req_addr_mux_sel = 1'b1;
      //  cs_m_axi_awvalid = 1'b1;
      //end
      AXI_STATE_WR_TAG: begin
        cs_axi_wdata_mux_sel = 1'b1;
        cs_req_addr_mux_sel = 1'b1;

        //ready to write
        if ((axi_awvalid_r == 1'b0) && m_axi_wvalid) begin
          // write addr
          cs_m_axi_awvalid = 1'b1;
          if (m_axi_awready) begin
            cs_axi_awvalid_r_val = 1'b1;
            cs_axi_awvalid_r_we = 1'b1;
          end
        end
        if(m_axi_wready && m_axi_wvalid) begin
          cs_mac_tag_rdy = 1'b1;
        end
      end
      AXI_STATE_WR_TAG_RESP: begin
        cs_m_axi_bready = 1'b1;
      end
    endcase
  end

  assign m_axi_awvalid = cs_m_axi_awvalid;
  assign m_axi_bready = cs_m_axi_bready;

  assign busy = (axi_state_r != AXI_STATE_IDLE) || (cl_state_r != CL_STATE_IDLE);


endmodule : stream_write
`default_nettype wire
