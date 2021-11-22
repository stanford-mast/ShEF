//Mark Zhao
//7/22/20
//Top level module for stream
`include "free_common_defines.vh"

`default_nettype none

// NOTE: AXI_DATA_WIDTH must be set to 512

module stream_read #(
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
  input  wire req_flush,
  input  wire req_last,
  input  wire                         req_val,
  output wire                         req_rdy,

  output wire                         busy,

  //Output to CL
  output wire [CL_ID_WIDTH-1:0]            s_axi_rid, //SET TO 0
  output wire [CL_DATA_WIDTH-1:0]          s_axi_rdata,
  output wire [1:0]                        s_axi_rresp, //ALWAYS SUCCESS
  output wire                              s_axi_rlast, 
  output wire                              s_axi_rvalid,
  input  wire                              s_axi_rready,

  //Output to DRAM
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
  output wire                         m_axi_rready

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE        = 4'd0,
             STATE_INIT_CRYPTO = 4'd1,
             STATE_RD_DATA_REQ = 4'd2,
             STATE_RD_DATA     = 4'd3,
             STATE_RD_TAG_REQ  = 4'd4,
             STATE_RD_TAG      = 4'd5,
             STATE_TXFER       = 4'd6,
             STATE_TAG_CHECK   = 4'd7,
             STATE_FAIL        = 4'd8;
             
  localparam STATE_AES_IDLE    = 3'd0,
             STATE_AES_REQ     = 3'd1,
             STATE_AES_DECRYPT = 3'd2,
             STATE_AES_TXFER   = 3'd3,
             STATE_AES_RAM_READ = 3'd4,
             STATE_AES_BUFFER = 3'd5;
             
  localparam STATE_AXI_IDLE    = 3'd0,
             STATE_AXI_TXFER     = 3'd1,
             STATE_AXI_RAM_READ = 3'd2;
             

  localparam integer BUFFER_TAG_WIDTH = SHIELD_ADDR_WIDTH-PAGE_OFFSET_WIDTH;

  localparam integer HMAC_TAG_WIDTH = 128;
  localparam integer HMAC_TAG_PER_BURST = AXI_DATA_WIDTH / HMAC_TAG_WIDTH;
  localparam integer HMAC_TAG_PER_BURST_LOG = $clog2(HMAC_TAG_PER_BURST);

  localparam integer AXI_DATA_WIDTH_BYTES = AXI_DATA_WIDTH / 8;
  localparam integer AXI_FIFO_DEPTH = 4096 / AXI_DATA_WIDTH_BYTES;
  localparam integer AXI_BURST_OFFSET_WIDTH = $clog2(AXI_DATA_WIDTH_BYTES);

  localparam integer AXI_BURSTS_PER_PAGE = PAGE_SIZE / AXI_DATA_WIDTH_BYTES;
  localparam integer PLAINTEXT_RAM_INDEX_WIDTH = $clog2(4096 / AXI_DATA_WIDTH_BYTES);

  localparam integer CL_TO_AXI_BURSTS = AXI_DATA_WIDTH / CL_DATA_WIDTH; 
  localparam integer CL_TO_AXI_BURSTS_LOG = $clog2(CL_TO_AXI_BURSTS);
  
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
  //////////////////////////////Main FSM/////////////////////////
  //request
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_r;
  logic [AXI_ADDR_WIDTH-1:0] data_addr;
  logic [AXI_ADDR_WIDTH-1:0] tag_addr;
  logic [HMAC_TAG_PER_BURST_LOG-1:0] tag_offset;
  logic [SHIELD_ADDR_WIDTH-1:0] data_addr_aligned_mask;
  logic [SHIELD_ADDR_WIDTH-1:0] tag_addr_aligned_mask;

  //AXI hmac tag
  logic [HMAC_TAG_WIDTH-1:0] axi_tag;
  logic [HMAC_TAG_WIDTH-1:0] axi_tag_r;

  //HMAC calculated tag
  logic [127:0] hmac_tag;

  //Buffer tag 
  logic [BUFFER_TAG_WIDTH-1:0] buffer_tag_r;
  logic buffer_tag_valid_r;

  logic [3:0] state_r;
  logic [3:0] next_state;

  //Control signals
  logic cs_req_rdy;
  logic cs_req_addr_we;
  logic cs_buffer_tag_we;
  logic cs_buffer_tag_valid;
  logic cs_req_addr_mux_sel;
  logic cs_m_axi_arvalid;
  logic cs_axi_fifo_en;
  logic cs_m_axi_rready;
  logic cs_axi_tag_reg_we;
  logic cs_hmac_go;
  logic cs_aes_go;
  logic cs_aes_goto_txfer;
  logic cs_hmac_tag_rdy;
  logic cs_s_axi_rlast;

  //Status signals
  logic buffer_tag_match;
  logic hmac_req_rdy;
  logic hmac_tag_val;
  logic hmac_tag_match;

  //misc
  logic input_rxfer; //1 when a valid input is transferred
  logic load_input;

  //FIFO signals
  logic axi_aes_fifo_we;
  logic axi_aes_fifo_full;
  logic axi_hmac_fifo_we;
  logic axi_hmac_fifo_full;
  ///////////////////////////////////////////////////////
  /////////////////////AES/RAM FSM//////////////////////////////////
  logic [2:0] aes_state_r;
  logic [2:0] next_aes_state;

  logic [95:0] aes_iv;
  logic [AXI_DATA_WIDTH-1:0] aes_pad;

  //FIFO OUTPUT
  logic [AXI_DATA_WIDTH-1:0] axi_aes_fifo_dout;

  logic axi_hmac_fifo_rd_en;
  logic axi_hmac_fifo_empty;

  `ifdef USE_HMAC
    logic [AXI_DATA_WIDTH-1:0] axi_hmac_fifo_dout;
  `elsif USE_PMAC
    logic [PMAC_DATA_WIDTH-1:0] axi_hmac_fifo_dout;
  `endif

  logic [AXI_DATA_WIDTH-1:0] plaintext;

  //Control
  logic cs_aes_req_val;
  logic cs_aes_resp_rdy;
  logic               cs_pt_ram_write_en;
  logic               cs_crypto_aes_rdy;

  logic               cs_pt_ram_read_index_incr;
  logic               cs_burst_index_mux_sel;
  logic               cs_s_axi_rvalid;
  logic               cs_cl_txfer;


  //status
  logic aes_req_rdy;
  logic aes_resp_val;
  logic axi_aes_fifo_empty;
  logic last_line_burst;


  //RAM Input
  logic [PLAINTEXT_RAM_INDEX_WIDTH-1:0] pt_ram_read_index;
  logic [PLAINTEXT_RAM_INDEX_WIDTH-1:0] pt_ram_write_index;

  //RAM Output
  logic [PLAINTEXT_RAM_INDEX_WIDTH-1:0] ram_read_start_index;

  //Output to CL
  logic [CL_TO_AXI_BURSTS_LOG-1:0] burst_start_index;
  logic [CL_TO_AXI_BURSTS_LOG-1:0] burst_index_r;
  logic [8:0] burst_count;
  logic burst_done;
  logic req_last_r;

  logic [AXI_DATA_WIDTH-1:0] pt_ram_dout;

  // AXI FSM signals
  logic [2:0] axi_state_r;
  logic [2:0] next_axi_state;

  logic ram_read_ok;

  ///////////////////////////////////////////////////////




  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////

  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) addr_reg(
    .clk(clk),
    .q(req_addr_r),
    .d(req_addr),
    .en(cs_req_addr_we)
  );

  //Register for current buffer tag
  shield_enreg #(.WIDTH(BUFFER_TAG_WIDTH)) buffer_tag_reg(
    .clk(clk),
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

  assign buffer_tag_match = (req_addr[SHIELD_ADDR_WIDTH-1 -: BUFFER_TAG_WIDTH] == buffer_tag_r);

  //Calculate read addresses
  assign data_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << PAGE_OFFSET_WIDTH;
  assign data_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, (req_addr_r & data_addr_aligned_mask)}; //Align to page
  assign tag_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << (PAGE_OFFSET_WIDTH + HMAC_TAG_PER_BURST_LOG);
  assign tag_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, ((req_addr_r & tag_addr_aligned_mask) >> (HMAC_TAG_PER_BURST_LOG + (PAGE_OFFSET_WIDTH - AXI_BURST_OFFSET_WIDTH)))} + `TAG_BASE_ADDR;
  assign tag_offset = req_addr_r[PAGE_OFFSET_WIDTH +: HMAC_TAG_PER_BURST_LOG];


  //AXI Signals
  //Tie off unused axi signals
  assign m_axi_arid = {AXI_ID_WIDTH{1'b0}};
  assign m_axi_arsize = 3'b110; //read 64B
  assign m_axi_arburst = 2'b01;
	assign m_axi_arlock   = 2'b00;
	assign m_axi_arcache  = 4'b0011;
	assign m_axi_arprot   = 3'b000;
	assign m_axi_arqos    = 4'b0000;
	assign m_axi_arregion = 4'b0000;
  //Need to assign araddr, arlen, and arvalid

  shield_mux2 #(.WIDTH(AXI_ADDR_WIDTH)) req_addr_mux(
    .in0(data_addr),
    .in1(tag_addr),
    .sel(cs_req_addr_mux_sel),
    .out(m_axi_araddr)
  );
  shield_mux2 #(.WIDTH(8)) req_len_mux(
    .in0(8'd63),
    .in1(8'd0),
    .sel(cs_req_addr_mux_sel),
    .out(m_axi_arlen)
  );

  //Register for HMAC tag from dram
  //mux the read data to tag
  shield_muxp #(
    .BUS_WIDTH(AXI_DATA_WIDTH),
    .OUTPUT_WIDTH(HMAC_TAG_WIDTH),
    .SELECT_WIDTH(HMAC_TAG_PER_BURST_LOG),
    .SELECT_COUNT(HMAC_TAG_PER_BURST)
  ) tag_mux(
    .in_bus(m_axi_rdata),
    .sel(tag_offset),
    .out(axi_tag)
  );
  shield_enreg #(.WIDTH(HMAC_TAG_WIDTH)) axi_tag_reg (
    .clk(clk),
    .q(axi_tag_r),
    .d(axi_tag),
    .en(cs_axi_tag_reg_we)
  );


  //FIFO for axi -> aes
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
	  .RD_DATA_COUNT_WIDTH       (),               //positive integer, not used
	  .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
	  .DOUT_RESET_VALUE          ("0"),              //string, don't care
	  .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;
	) axi_aes_fifo_sync (
  	.sleep         ( 1'b0             ) ,
  	.rst           ( ~rst_n           ) ,
  	.wr_clk        ( clk           ) ,
  	.wr_en         ( axi_aes_fifo_we ) ,
  	.din           ( m_axi_rdata ) ,
  	.full          ( axi_aes_fifo_full ) ,
  	.prog_full     (                  ) ,
  	.wr_data_count (                  ) ,
  	.overflow      (                  ) ,
  	.wr_rst_busy   (                  ) ,
  	.rd_en         ( cs_pt_ram_write_en ) ,
  	.dout          ( axi_aes_fifo_dout ) ,
  	.empty         ( axi_aes_fifo_empty ) ,
  	.prog_empty    (                  ) ,
  	.rd_data_count (                  ) ,
  	.underflow     (                  ) ,
  	.rd_rst_busy   (                  ) ,
  	.injectsbiterr ( 1'b0             ) ,
  	.injectdbiterr ( 1'b0             ) ,
  	.sbiterr       (                  ) ,
  	.dbiterr       (                  ) 
	);

  //FIFO for axi -> hmac
	xpm_fifo_sync # (
	  .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
	  .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
	  .FIFO_WRITE_DEPTH          (AXI_FIFO_DEPTH),   //positive integer
	  .WRITE_DATA_WIDTH          (AXI_DATA_WIDTH),               //positive integer
	  .WR_DATA_COUNT_WIDTH       ($clog2(AXI_FIFO_DEPTH)+1),               //positive integer, Not used
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
	) axi_hmac_fifo_sync (
  	.sleep         ( 1'b0             ) ,
  	.rst           ( ~rst_n           ) ,
  	.wr_clk        ( clk           ) ,
  	.wr_en         ( axi_hmac_fifo_we ) ,
  	.din           ( m_axi_rdata ) ,
  	.full          ( axi_hmac_fifo_full ) ,
  	.prog_full     (                  ) ,
  	.wr_data_count (                  ) ,
  	.overflow      (                  ) ,
  	.wr_rst_busy   (                  ) ,
  	.rd_en         ( axi_hmac_fifo_rd_en ) ,
  	.dout          ( axi_hmac_fifo_dout ) ,
  	.empty         ( axi_hmac_fifo_empty ) ,
  	.prog_empty    (                  ) ,
  	.rd_data_count (                  ) ,
  	.underflow     (                  ) ,
  	.rd_rst_busy   (                  ) ,
  	.injectsbiterr ( 1'b0             ) ,
  	.injectdbiterr ( 1'b0             ) ,
  	.sbiterr       (                  ) ,
  	.dbiterr       (                  ) 
	);

  //FIFO write control signals
//  assign axi_aes_fifo_we = (cs_axi_fifo_en && m_axi_rvalid);
//  assign axi_hmac_fifo_we = (cs_axi_fifo_en && m_axi_rvalid);
  always_comb begin
    axi_aes_fifo_we = 1'b0;
    axi_hmac_fifo_we = 1'b0;
    if(cs_axi_fifo_en) begin
      if(m_axi_rvalid && (!axi_hmac_fifo_full) && (!axi_aes_fifo_full)) begin
        axi_hmac_fifo_we = 1'b1;
        axi_aes_fifo_we = 1'b1;
      end
    end
  end

  //Crypto module instantiation
  assign aes_iv = 96'd0;
  aes_parallel aes_parallel_inst(
    .clk(clk),
    .rst_n(rst_n),
    .nonce(aes_iv),
    .counter(32'd0),
    .req_val(cs_aes_req_val),
    .req_rdy(aes_req_rdy),
    .pad(aes_pad),
    .pad_val(aes_resp_val),
    .pad_rdy(cs_aes_resp_rdy)
  );
  //assign aes_iv = 96'd0;
  //genvar i;
  //generate
  //  for(i = 0; i < NUM_AES; i++) begin
  //    aes #(.DATA_WIDTH(128)) aes_inst(
  //      .clk(clk),
  //      .rst_n(rst_n),
  //      .nonce(aes_iv), //TODO: Set to IV plus chunk count
  //      .counter(32'd0), //TODO: 32 bit block counter for this chunk
  //      .req_val(cs_aes_req_val[i]),
  //      .req_rdy(aes_req_rdy[i]),
  //      .pad(aes_pad[i*128 +: 128]),
  //      .pad_val(aes_resp_val[i]),
  //      .pad_rdy(cs_aes_resp_rdy[i])
  //    );
  //  end
  //endgenerate
  
  `ifdef NO_ENCRYPT
    assign plaintext = axi_aes_fifo_dout;
  `else
    assign plaintext = aes_pad ^ axi_aes_fifo_dout;
  `endif


  //RAM for plaintext
  shield_ram #(.DATA_WIDTH(AXI_DATA_WIDTH), .ADDR_WIDTH(PLAINTEXT_RAM_INDEX_WIDTH)) plaintext_ram(
    .clk(clk),
    .wr_addr( pt_ram_write_index ),
    .wr_en  ( cs_pt_ram_write_en ),
    .wr_data( plaintext ),
    .rd_addr( pt_ram_read_index ),
    .rd_data( pt_ram_dout )
  );

  //Counter for RAM write index
  shield_counter #(.C_WIDTH(PLAINTEXT_RAM_INDEX_WIDTH)) ram_write_index_counter(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_crypto_aes_rdy), //load when aes is idling
    .incr(cs_pt_ram_write_en),
    .decr(1'b0),
    .load_value(0),
    .count(pt_ram_write_index),
    .is_zero()
  );

  //Counter for RAM read index
  assign ram_read_start_index = req_addr[PAGE_OFFSET_WIDTH-1 -: PLAINTEXT_RAM_INDEX_WIDTH];
  shield_counter #(.C_WIDTH(PLAINTEXT_RAM_INDEX_WIDTH)) ram_read_index_counter(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //load by main FSM
    .incr(cs_pt_ram_read_index_incr),
    .decr(1'b0),
    .load_value(ram_read_start_index),
    .count(pt_ram_read_index),
    .is_zero()
  );

  //Counter for select signal
  assign burst_start_index = req_addr[AXI_BURST_OFFSET_WIDTH-1 -: CL_TO_AXI_BURSTS_LOG];
  shield_counter #(
    .C_WIDTH(CL_TO_AXI_BURSTS_LOG)
  ) burst_index_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //loaded by main fsm, wraps around
    .incr(cs_cl_txfer),
    .decr(1'b0),
    .load_value(burst_start_index),
    .count(burst_index_r),
    .is_zero()
  );
  assign last_line_burst = (burst_index_r == {CL_TO_AXI_BURSTS_LOG{1'b1}});

  //counter for remaining bursts
  shield_counter #(
    .C_WIDTH(9)
  ) burst_count_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy), //loaded by main FSM
    .incr(1'b0),
    .decr(cs_cl_txfer),
    .load_value(req_burst_count),
    .count(burst_count),
    .is_zero(burst_done)
  );

  //Reset that stores if this is the last request
  shield_enreg #(.WIDTH(1)) req_last_reg(
    .clk( clk ),
    .q(req_last_r),
    .d(req_last),
    .en(cs_req_rdy)
  );


  //Mux to CL
  shield_muxp #(
    .BUS_WIDTH(AXI_DATA_WIDTH),
    .OUTPUT_WIDTH(CL_DATA_WIDTH),
    .SELECT_WIDTH(CL_TO_AXI_BURSTS_LOG),
    .SELECT_COUNT(CL_TO_AXI_BURSTS)
  ) cache_line_mux (
    .in_bus(pt_ram_dout),
    .sel(burst_index_r),
    .out(s_axi_rdata)
  );

  //Tie off unused axi signals
  assign s_axi_rid = 0;
  assign s_axi_rresp = 2'b0;

  //HMAC module
  `ifdef USE_HMAC
    hmac_stream #(.DATA_COUNT_BURSTS(64)) hmac_stream_inst(
      .clk(clk),
      .rst_n(rst_n),

      .req_val(cs_hmac_go),
      .req_rdy(hmac_req_rdy),
      .stream_data(axi_hmac_fifo_dout),
      .stream_data_val(~axi_hmac_fifo_empty),
      .stream_data_rdy(axi_hmac_fifo_rd_en),

      .hmac(hmac_tag),
      .hmac_val(hmac_tag_val),
      .hmac_rdy(cs_hmac_tag_rdy)
    );
  `elsif USE_PMAC
    pmac #(.DATA_WIDTH(PMAC_DATA_WIDTH)) hmac_stream_inst(
      .clk(clk),
      .rst_n(rst_n),

      .req_val(cs_hmac_go),
      .req_len(PMAC_BURST_COUNT),
      .req_rdy(hmac_req_rdy),
      .stream_data(axi_hmac_fifo_dout),
      .stream_data_val(~axi_hmac_fifo_empty),
      .stream_data_rdy(axi_hmac_fifo_rd_en),

      .pmac(hmac_tag),
      .pmac_val(hmac_tag_val),
      .pmac_rdy(cs_hmac_tag_rdy)
    );
  `endif


  assign hmac_tag_match = (hmac_tag[0+:HMAC_TAG_WIDTH] == axi_tag_r);

  //////////////////////////////////////////////////////////////////////////////
  // Control logic
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r <= STATE_IDLE;
    end
    else begin
      state_r <= next_state;
    end
  end

  //State transition
  always_comb begin
    next_state = state_r;
    case (state_r)
      STATE_IDLE: begin //Wait for request
        if(req_val) begin
          //Check if the request matches the current buffer tag
          if(buffer_tag_match && buffer_tag_valid_r && (!req_flush)) begin //match - just read
            next_state = STATE_TXFER;
          end
          else begin //miss
            //Check if we need to evict the current buffer
            if(buffer_tag_valid_r) begin
              next_state = STATE_TAG_CHECK;
            end
            else begin //just init crypto
              next_state = STATE_INIT_CRYPTO;
            end
          end
        end
      end
      STATE_INIT_CRYPTO: begin
        if(cs_crypto_aes_rdy && hmac_req_rdy) begin
          next_state = STATE_RD_DATA_REQ;
        end
      end
      STATE_RD_DATA_REQ: begin //Signal for axi_raddr
        if(m_axi_arready) begin
          next_state = STATE_RD_DATA;
        end
      end
      STATE_RD_DATA: begin //read all data from page
        if(m_axi_rvalid && (!axi_hmac_fifo_full) && (!axi_aes_fifo_full) && m_axi_rlast) begin
        //if(m_axi_rvalid && m_axi_rlast) begin
          next_state = STATE_RD_TAG_REQ; 
        end
      end
      STATE_RD_TAG_REQ: begin //signal for axi_araddr
        if(m_axi_arready) begin
          next_state = STATE_RD_TAG;
        end
      end
      STATE_RD_TAG: begin //read tag from dram
        if(m_axi_rvalid) begin
          next_state = STATE_TXFER;
        end
      end
      STATE_TXFER: begin //allow aes to txfer data to cl
        if(burst_done) begin
          next_state = STATE_IDLE;
        end
      end
      STATE_TAG_CHECK: begin //
        if(hmac_tag_val) begin //if not valid, wait until it is
          `ifdef NO_TAG_CHECK
            next_state = STATE_INIT_CRYPTO;
          `elsif NO_TAG_CHECK_FIRST
            next_state = STATE_INIT_CRYPTO;
          `else
            if(hmac_tag_match) begin
              next_state = STATE_INIT_CRYPTO;
            end
            else begin
              next_state = STATE_FAIL;
            end
          `endif
        end
      end
      STATE_FAIL: begin
        next_state = state_r; //stay here forever
      end
    endcase
  end

  //Output
  always_comb begin
    //default
    cs_req_rdy = 1'b0;
    cs_req_addr_we = 1'b1;
    cs_buffer_tag_we = 1'b0;
    cs_buffer_tag_valid = 1'b0; //write value to buffer tag valid reg
    cs_req_addr_mux_sel = 1'b0;
    cs_m_axi_arvalid = 1'b0;
    cs_axi_fifo_en = 1'b0;
    cs_m_axi_rready = 1'b0;
    cs_axi_tag_reg_we = 1'b0;
    cs_aes_go = 1'b0;
    cs_hmac_go = 1'b0;
    cs_aes_goto_txfer = 1'b0;
    cs_hmac_tag_rdy = 1'b0;
    case (state_r)
      STATE_IDLE: begin
        cs_req_rdy = 1'b1;
        cs_req_addr_we = 1'b1;
        if(req_val) begin //register tag if valid
          cs_buffer_tag_we = 1'b1;
          cs_buffer_tag_valid = 1'b1;
          if(buffer_tag_match && buffer_tag_valid_r && (!req_flush)) begin //match - just read
            cs_aes_goto_txfer = 1'b1;
          end
        end
      end
      STATE_INIT_CRYPTO: begin //synchronous 1 cycle go signal to both crypto fsms
        if(cs_crypto_aes_rdy && hmac_req_rdy) begin
          cs_hmac_go = 1'b1;
          cs_aes_go = 1'b1;
        end
      end
      STATE_RD_DATA_REQ: begin
        cs_req_addr_mux_sel = 1'b0;
        cs_m_axi_arvalid = 1'b1;
      end
      STATE_RD_DATA: begin
        cs_axi_fifo_en = 1'b1;
        //cs_m_axi_rready = 1'b1;
        if((!axi_hmac_fifo_full) && (!axi_aes_fifo_full)) begin
          cs_m_axi_rready = 1'b1;
        end
      end
      STATE_RD_TAG_REQ: begin
        cs_req_addr_mux_sel = 1'b1;
        cs_m_axi_arvalid = 1'b1;
      end
      STATE_RD_TAG: begin
        cs_m_axi_rready = 1'b1;
        cs_axi_tag_reg_we = 1'b1;
      end
      STATE_TXFER: begin
        cs_aes_goto_txfer = 1'b1; //set this just in case aes isn't synced
      end
      STATE_TAG_CHECK: begin
        cs_hmac_tag_rdy = 1'b1;
      end
    endcase
  end

  assign req_rdy = cs_req_rdy;
  assign m_axi_arvalid = cs_m_axi_arvalid;
  assign m_axi_rready = cs_m_axi_rready;


  //FSM for fifo -> AES -> RAM
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      aes_state_r <= STATE_AES_IDLE;
    end
    else begin
      aes_state_r <= next_aes_state;
    end
  end

  always_comb begin
    next_aes_state = aes_state_r;
    case (aes_state_r)
      STATE_AES_IDLE: begin //Wait for go signal from main FSM
        if(cs_aes_go) begin
          next_aes_state = STATE_AES_REQ;
        end
      end
      STATE_AES_REQ: begin //send start signal to aes for pad generation
        if(aes_req_rdy) begin
          next_aes_state = STATE_AES_DECRYPT;
        end
      end
      STATE_AES_DECRYPT: begin
        if ((aes_resp_val) && (!axi_aes_fifo_empty)) begin // AES pad valid and fifo out is valid
          if(pt_ram_write_index == {PLAINTEXT_RAM_INDEX_WIDTH{1'b1}}) begin //last write index
            next_aes_state = STATE_AES_IDLE;
          end
          else begin // Still more to write
            next_aes_state = STATE_AES_REQ;
          end
        end
      end
    endcase
  end
  //      if((&aes_resp_val) && (!axi_aes_fifo_empty)) begin //AES pad is valid and fifo output is valid
  //        if(pt_ram_write_index == {PLAINTEXT_RAM_INDEX_WIDTH{1'b1}}) begin //last write index
  //          if(pt_ram_read_index == {PLAINTEXT_RAM_INDEX_WIDTH{1'b1}}) begin
  //            next_aes_state = STATE_AES_BUFFER;
  //          end
  //          else begin
  //            next_aes_state = STATE_AES_TXFER;
  //          end
  //        end
  //        else begin
  //          next_aes_state = STATE_AES_REQ; 
  //        end
  //      end
  //    end
  //    STATE_AES_TXFER: begin
  //      if(burst_done) begin
  //        next_aes_state = STATE_AES_IDLE;
  //      end
  //      else if(s_axi_rready && last_line_burst) begin
  //        next_aes_state = STATE_AES_RAM_READ;
  //      end
  //    end
  //    STATE_AES_RAM_READ: begin
  //      if(burst_done) begin
  //        next_aes_state = STATE_AES_IDLE;
  //      end
  //      else begin
  //        next_aes_state = STATE_AES_TXFER;
  //      end
  //    end
  //    STATE_AES_BUFFER: begin //One cycle buffer for write->read to last address
  //      next_aes_state = STATE_AES_TXFER;
  //    end
  //  endcase
  //end

  always_comb begin
    cs_aes_req_val = 1'b0;
    cs_pt_ram_write_en = 1'b0;
    cs_crypto_aes_rdy = 1'b0;
    cs_aes_resp_rdy = 1'b0;

    //cs_pt_ram_read_index_incr = 1'b0;
    //cs_s_axi_rvalid = 1'b0;
    //cs_cl_txfer = 1'b0;
    //cs_s_axi_rlast = 1'b0;
    case (aes_state_r)
      //AES_IDLE do nothing
      STATE_AES_IDLE: begin
        cs_crypto_aes_rdy = 1'b1; //signal that AES is ok
      end
      STATE_AES_REQ: begin
        cs_aes_req_val = 1'b1;
      end
      STATE_AES_DECRYPT: begin //load decrypted data into RAM
        if((aes_resp_val) && (!axi_aes_fifo_empty)) begin
          cs_pt_ram_write_en = 1'b1;
          cs_aes_resp_rdy = 1'b1;
        end
      end
    endcase
  end

  //    STATE_AES_TXFER: begin
  //      if(!burst_done) begin
  //        cs_s_axi_rvalid = 1'b1;
  //        //assert rlast if this is the final burst
  //        if((burst_count == 9'd1) && req_last_r) begin
  //          cs_s_axi_rlast = 1'b1;
  //        end
  //        if(s_axi_rready) begin
  //          //increment the select signal
  //          cs_cl_txfer = 1'b1;

  //          //Increment the ram read index if necessary
  //          if(last_line_burst) begin
  //            cs_pt_ram_read_index_incr = 1'b1;
  //          end
  //        end
  //      end
  //    end
  //    //STATE_AES_RAM_READ: begin //read the appropriate ram line idle for data
  //  endcase
  //end

  // FSM to control RAM -> axi slave interface
  //
  assign s_axi_rvalid = cs_s_axi_rvalid;
  assign s_axi_rlast = cs_s_axi_rlast;
 
  // busy only holds for the axi bus - ok if aes fsm is busy
  assign busy = (state_r != STATE_IDLE) || (axi_state_r != STATE_AXI_IDLE);

  // Okay to read if aes FSM is not running OR if read index < write index
  assign ram_read_ok = ((aes_state_r == STATE_AES_IDLE) || (pt_ram_read_index < pt_ram_write_index)) ? 1'b1 : 1'b0;


  always_ff @(posedge clk) begin
    if(!rst_n) begin
      axi_state_r <= STATE_AXI_IDLE;
    end
    else begin
      axi_state_r <= next_axi_state;
    end
  end

  always_comb begin
    next_axi_state = axi_state_r;
    case (axi_state_r)
      STATE_AXI_IDLE: begin
        if (cs_aes_goto_txfer) begin
          next_axi_state = STATE_AXI_TXFER;
        end
      end
      STATE_AXI_TXFER: begin
        if (burst_done) begin
          next_axi_state = STATE_AXI_IDLE;
        end
        else if (s_axi_rready && last_line_burst && ram_read_ok) begin
          next_axi_state = STATE_AXI_RAM_READ;
        end
      end
      STATE_AXI_RAM_READ: begin
        if (burst_done) begin
          next_axi_state = STATE_AXI_IDLE;
        end
        else begin
          next_axi_state = STATE_AXI_TXFER;
        end
      end
    endcase
  end
  
  always_comb begin
    cs_pt_ram_read_index_incr = 1'b0;
    cs_s_axi_rvalid = 1'b0;
    cs_cl_txfer = 1'b0;
    cs_s_axi_rlast = 1'b0;

    case (axi_state_r)
      //STATE_AXI_IDLE: begin
      //end
      STATE_AXI_TXFER: begin
        if ((!burst_done) && ram_read_ok) begin
          cs_s_axi_rvalid = 1'b1;

          //assert rlast if this is the final burst
          if((burst_count == 9'd1) && req_last_r) begin
            cs_s_axi_rlast = 1'b1;
          end
          if(s_axi_rready) begin
            //increment the select signal
            cs_cl_txfer = 1'b1;

            //Increment the ram read index if necessary
            if(last_line_burst) begin
              cs_pt_ram_read_index_incr = 1'b1;
            end
          end
        end
      end
      // STATE_AXI_RAM_READ: one cycle delay to read line from RAM
    endcase
  end
  



endmodule : stream_read
`default_nettype wire
