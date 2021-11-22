//Mark Zhao
//8/18/20
//Wrapper module for stream
`include "free_common_defines.vh"

`default_nettype none

module stream #(
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
  
  //Request from shield
  input  wire [SHIELD_ADDR_WIDTH-1:0] rd_req_addr,
  input  wire [7:0]                   rd_req_len,
  input  wire                         rd_req_flush,
  input  wire                         rd_req_val,
  output wire                         rd_req_rdy,

  output wire                         rd_busy,

  input  wire [SHIELD_ADDR_WIDTH-1:0] wr_req_addr,
  input  wire [7:0]                   wr_req_len,
  input  wire                         wr_req_flush,
  input  wire                         wr_req_val,
  output wire                         wr_req_rdy,

  output wire                         wr_busy,

  //To CL
  //Read
  output wire [CL_ID_WIDTH-1:0]       s_axi_rid, //SET TO 0
  output wire [CL_DATA_WIDTH-1:0]     s_axi_rdata,
  output wire [1:0]                   s_axi_rresp, //ALWAYS SUCCESS
  output wire                         s_axi_rlast, 
  output wire                         s_axi_rvalid,
  input  wire                         s_axi_rready,
  //Write
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



  //To DRAM
  //Read
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
  //Write
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
  localparam integer CL_DATA_WIDTH_BYTES = CL_DATA_WIDTH / 8;
  localparam integer BURSTS_PER_PAGE = PAGE_SIZE / CL_DATA_WIDTH_BYTES;
  localparam integer BURSTS_PER_PAGE_LOG = $clog2(BURSTS_PER_PAGE);

  localparam RD_STATE_IDLE     = 3'd0,
             RD_STATE_REQ      = 3'd1,
             RD_STATE_NEXT     = 3'd2,
             RD_STATE_FINALIZE = 3'd3;

  localparam WR_STATE_IDLE     = 3'd0,
             WR_STATE_REQ      = 3'd1,
             WR_STATE_NEXT     = 3'd2,
             WR_STATE_FINALIZE = 3'd3;

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  //Read FSM
  logic [2:0] rd_state_r;
  logic [2:0] next_rd_state;


  logic cs_rd_req_rdy;
  logic cs_rd_req_cycle_mux_sel;
  logic cs_rd_req_reg_en;
  logic cs_stream_rd_req_val;
  logic cs_stream_rd_req_flush;
  logic cs_rd_busy;


  logic stream_rd_req_rdy;
  logic stream_rd_busy;


  //Write FSM
  logic [2:0] wr_state_r;
  logic [2:0] next_wr_state;

  logic cs_wr_req_rdy;
  logic cs_wr_req_cycle_mux_sel;
  logic cs_wr_req_reg_en;
  logic cs_stream_wr_req_val;
  logic cs_stream_wr_req_flush;
  logic cs_wr_busy;

  logic stream_wr_req_rdy;
  logic stream_wr_busy;

  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //Read path
  logic [SHIELD_ADDR_WIDTH-1:0] rd_addr_0; //read address muxed b/w input and next
  logic [SHIELD_ADDR_WIDTH-1:0] rd_addr_1; 
  logic [SHIELD_ADDR_WIDTH-1:0] rd_addr_next_0;
  logic [SHIELD_ADDR_WIDTH-1:0] rd_addr_next_1;

  logic [7:0]                   rd_len_0;
  logic [7:0]                   rd_len_next_0;
  logic [7:0]                   rd_len_next_1;

  logic [8:0]                   rd_burst_count_0;
  logic [8:0]                   rd_burst_count_1;

  logic                         rd_last_0;
  logic                         rd_last_1;

  logic                         rd_req_flush_r;

  shield_mux2 #(.WIDTH(SHIELD_ADDR_WIDTH)) rd_req_addr_cycle_mux(
    .in0(rd_req_addr),
    .in1(rd_addr_next_1),
    .sel(cs_rd_req_cycle_mux_sel),
    .out(rd_addr_0)
  );

  shield_mux2 #(.WIDTH(8)) rd_req_len_cycle_mux(
    .in0(rd_req_len),
    .in1(rd_len_next_1), 
    .sel(cs_rd_req_cycle_mux_sel),
    .out(rd_len_0)
  );


  //generate command
  stream_cmd_gen #(
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .PAGE_OFFSET_WIDTH(PAGE_OFFSET_WIDTH),
    .BURSTS_PER_PAGE(BURSTS_PER_PAGE),
    .BURSTS_PER_PAGE_LOG(BURSTS_PER_PAGE_LOG)
  ) stream_read_cmd_generator(
    .axaddr(rd_addr_0),
    .axlen(rd_len_0),
    .burst_count(rd_burst_count_0),
    .axlen_next(rd_len_next_0),
    .axaddr_next(rd_addr_next_0),
    .last(rd_last_0)
  );

  //Register command and request
  shield_enreg #(.WIDTH(9)) rd_burst_count_reg (
    .clk( clk ),
    .q(rd_burst_count_1),
    .d(rd_burst_count_0),
    .en(cs_rd_req_reg_en)
  );
  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) rd_addr_reg (
    .clk( clk ),
    .q(rd_addr_1),
    .d(rd_addr_0),
    .en(cs_rd_req_reg_en)
  );
  shield_enreg #(.WIDTH(8)) rd_len_next_reg (
    .clk( clk ),
    .q(rd_len_next_1),
    .d(rd_len_next_0),
    .en(cs_rd_req_reg_en)
  );
  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) rd_addr_next_reg (
    .clk( clk ),
    .q(rd_addr_next_1),
    .d(rd_addr_next_0),
    .en(cs_rd_req_reg_en)
  );

  shield_enreg #(.WIDTH(1)) rd_last_reg (
    .clk( clk ),
    .q(rd_last_1),
    .d(rd_last_0),
    .en(cs_rd_req_reg_en)
  );

  //Registers of CL request is flush
  shield_enreg #(.WIDTH(1)) rd_flush_reg (
    .clk( clk ),
    .q(rd_req_flush_r),
    .d(rd_req_flush),
    .en(cs_rd_req_rdy)
  );


  stream_read #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH    (CL_ADDR_WIDTH),
    .CL_ID_WIDTH      (CL_ID_WIDTH),
    .CL_DATA_WIDTH    (CL_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .PAGE_OFFSET_WIDTH(PAGE_OFFSET_WIDTH),
    .PAGE_SIZE        (PAGE_SIZE)
  ) stream_read_inst(
    .clk             (clk),
    .rst_n           (rst_n),
    .req_addr        (rd_addr_1),
    .req_burst_count (rd_burst_count_1),
    .req_flush       (cs_stream_rd_req_flush),
    .req_last        (rd_last_1),
    .req_val         (cs_stream_rd_req_val),
    .req_rdy         (stream_rd_req_rdy),
    .busy            (stream_rd_busy),
    .s_axi_rid       (s_axi_rid ),
    .s_axi_rdata     (s_axi_rdata    ),
    .s_axi_rresp     (s_axi_rresp ),
    .s_axi_rlast     (s_axi_rlast ), 
    .s_axi_rvalid    (s_axi_rvalid   ),
    .s_axi_rready    (s_axi_rready   ),
    .m_axi_arid      (m_axi_arid ),
    .m_axi_araddr    (m_axi_araddr   ),
    .m_axi_arlen     (m_axi_arlen    ),
    .m_axi_arsize    (m_axi_arsize  ),
    .m_axi_arburst   (m_axi_arburst ),
    .m_axi_arlock    (m_axi_arlock  ),
    .m_axi_arcache   (m_axi_arcache ),
    .m_axi_arprot    (m_axi_arprot  ),
    .m_axi_arqos     (m_axi_arqos   ),
    .m_axi_arregion  (m_axi_arregion),
    .m_axi_arvalid   (m_axi_arvalid ),
    .m_axi_arready   (m_axi_arready ),
    .m_axi_rid       (m_axi_rid      ),
    .m_axi_rdata     (m_axi_rdata    ),
    .m_axi_rresp     (m_axi_rresp    ),
    .m_axi_rlast     (m_axi_rlast    ),
    .m_axi_rvalid    (m_axi_rvalid   ),
    .m_axi_rready    (m_axi_rready   )
  );



  //Write path
  logic [SHIELD_ADDR_WIDTH-1:0] wr_addr_0; //address muxed b/w input and next
  logic [SHIELD_ADDR_WIDTH-1:0] wr_addr_1; 
  logic [SHIELD_ADDR_WIDTH-1:0] wr_addr_next_0;
  logic [SHIELD_ADDR_WIDTH-1:0] wr_addr_next_1;

  logic [7:0]                   wr_len_0;
  logic [7:0]                   wr_len_next_0;
  logic [7:0]                   wr_len_next_1;

  logic [8:0]                   wr_burst_count_0;
  logic [8:0]                   wr_burst_count_1;

  logic                         wr_last_0;
  logic                         wr_last_1;

  logic                         wr_req_flush_r;

  shield_mux2 #(.WIDTH(SHIELD_ADDR_WIDTH)) wr_req_addr_cycle_mux(
    .in0(wr_req_addr),
    .in1(wr_addr_next_1),
    .sel(cs_wr_req_cycle_mux_sel),
    .out(wr_addr_0)
  );

  shield_mux2 #(.WIDTH(8)) wr_req_len_cycle_mux(
    .in0(wr_req_len),
    .in1(wr_len_next_1), 
    .sel(cs_wr_req_cycle_mux_sel),
    .out(wr_len_0)
  );

  //generate command
  stream_cmd_gen #(
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .PAGE_OFFSET_WIDTH(PAGE_OFFSET_WIDTH),
    .BURSTS_PER_PAGE(BURSTS_PER_PAGE),
    .BURSTS_PER_PAGE_LOG(BURSTS_PER_PAGE_LOG)
  ) stream_write_cmd_generator(
    .axaddr(wr_addr_0),
    .axlen(wr_len_0),
    .burst_count(wr_burst_count_0),
    .axlen_next(wr_len_next_0),
    .axaddr_next(wr_addr_next_0),
    .last(wr_last_0)
  );

  //Register command and request
  shield_enreg #(.WIDTH(9)) wr_burst_count_reg (
    .clk( clk ),
    .q(wr_burst_count_1),
    .d(wr_burst_count_0),
    .en(cs_wr_req_reg_en)
  );
  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) wr_addr_reg (
    .clk( clk ),
    .q(wr_addr_1),
    .d(wr_addr_0),
    .en(cs_wr_req_reg_en)
  );
  shield_enreg #(.WIDTH(8)) wr_len_next_reg (
    .clk( clk ),
    .q(wr_len_next_1),
    .d(wr_len_next_0),
    .en(cs_wr_req_reg_en)
  );
  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) wr_addr_next_reg (
    .clk( clk ),
    .q(wr_addr_next_1),
    .d(wr_addr_next_0),
    .en(cs_wr_req_reg_en)
  );

  shield_enreg #(.WIDTH(1)) wr_last_reg (
    .clk( clk ),
    .q(wr_last_1),
    .d(wr_last_0),
    .en(cs_wr_req_reg_en)
  );

  //Registers of CL request is flush
  shield_enreg #(.WIDTH(1)) wr_flush_reg (
    .clk( clk ),
    .q(wr_req_flush_r),
    .d(wr_req_flush),
    .en(cs_rd_req_rdy)
  );

  stream_write #(
    .AXI_ADDR_WIDTH   (AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH     (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH   (AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH    (CL_ADDR_WIDTH),
    .CL_ID_WIDTH      (CL_ID_WIDTH),
    .CL_DATA_WIDTH    (CL_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .PAGE_OFFSET_WIDTH(PAGE_OFFSET_WIDTH),
    .PAGE_SIZE        (PAGE_SIZE)
  ) stream_write_inst(
    .clk(clk),
    .rst_n(rst_n),
    .req_addr        (wr_addr_1),
    .req_burst_count (wr_burst_count_1),
    .req_flush       (cs_stream_wr_req_flush),
    .req_last        (wr_last_1),
    .req_val         (cs_stream_wr_req_val),
    .req_rdy         (stream_wr_req_rdy),
    .busy            (stream_wr_busy),
    .s_axi_wid       (s_axi_wid),
    .s_axi_wdata     (s_axi_wdata),
    .s_axi_wstrb     (s_axi_wstrb), //IGNORED FOR NOW
    .s_axi_wlast     (s_axi_wlast),
    .s_axi_wvalid    (s_axi_wvalid),
    .s_axi_wready    (s_axi_wready),
    .s_axi_bid       (s_axi_bid),
    .s_axi_bresp     (s_axi_bresp),
    .s_axi_bvalid    (s_axi_bvalid),
    .s_axi_bready    (s_axi_bready),
    .m_axi_awid           (m_axi_awid    ),
    .m_axi_awaddr         (m_axi_awaddr  ),
    .m_axi_awlen          (m_axi_awlen   ),
    .m_axi_awsize         (m_axi_awsize  ),
    .m_axi_awburst        (m_axi_awburst ),
    .m_axi_awlock         (m_axi_awlock  ),
    .m_axi_awcache        (m_axi_awcache ),
    .m_axi_awprot         (m_axi_awprot  ),
    .m_axi_awqos          (m_axi_awqos   ),
    .m_axi_awregion       (m_axi_awregion),
    .m_axi_awvalid        (m_axi_awvalid ),
    .m_axi_awready        (m_axi_awready ),
    .m_axi_wid            (m_axi_wid     ),
    .m_axi_wdata          (m_axi_wdata   ),
    .m_axi_wstrb          (m_axi_wstrb   ),
    .m_axi_wlast          (m_axi_wlast   ),
    .m_axi_wvalid         (m_axi_wvalid  ),
    .m_axi_wready         (m_axi_wready  ),
    .m_axi_bid            (m_axi_bid     ),
    .m_axi_bresp          (m_axi_bresp   ),
    .m_axi_bvalid         (m_axi_bvalid  ),
    .m_axi_bready         (m_axi_bready  )
  );

  //////////////////////////////////////////////////////////////////////////////
  // Control
  //////////////////////////////////////////////////////////////////////////////
  //Read
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      rd_state_r <= RD_STATE_IDLE;
    end
    else begin
      rd_state_r <= next_rd_state;
    end
  end

  always_comb begin
    next_rd_state = rd_state_r;
    case (rd_state_r)
      RD_STATE_IDLE: begin
        if(rd_req_val) begin
          next_rd_state = RD_STATE_REQ;
        end
      end
      RD_STATE_REQ: begin
        if(stream_rd_req_rdy && rd_last_1) begin
          next_rd_state = RD_STATE_FINALIZE;
        end
        else if(stream_rd_req_rdy && (!rd_last_1)) begin
          next_rd_state = RD_STATE_NEXT;
        end
      end
      RD_STATE_NEXT: begin
        next_rd_state = RD_STATE_REQ;
      end
      RD_STATE_FINALIZE: begin
        //Hold here until the the read is done with the axi bus (in both dirs)
        if(!stream_rd_busy) begin //unused when ready 
          next_rd_state = RD_STATE_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_rd_req_rdy = 1'b0;
    cs_rd_req_cycle_mux_sel = 1'b0;
    cs_rd_req_reg_en = 1'b0;
    cs_stream_rd_req_val = 1'b0;
    cs_stream_rd_req_flush = 1'b0;
    cs_rd_busy = 1'b0;
    case (rd_state_r)
      RD_STATE_IDLE: begin
        cs_rd_req_rdy = 1'b1; 
        cs_rd_req_reg_en = 1'b1;
      end
      RD_STATE_REQ: begin
        cs_rd_busy = 1'b1;
        cs_stream_rd_req_val = 1'b1;
        if(rd_req_flush_r) begin
          cs_stream_rd_req_flush = 1'b1;
        end
      end
      RD_STATE_NEXT: begin
        cs_rd_busy = 1'b1;
        cs_rd_req_reg_en = 1'b1; //store next address
        cs_rd_req_cycle_mux_sel = 1'b1;
      end
      RD_STATE_FINALIZE: begin
        cs_rd_busy = 1'b1;
      end
    endcase
  end

  assign rd_req_rdy = cs_rd_req_rdy;
  assign rd_busy = cs_rd_busy;

  //Write
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      wr_state_r <= WR_STATE_IDLE;
    end
    else begin
      wr_state_r <= next_wr_state;
    end
  end

  always_comb begin
    next_wr_state = wr_state_r;
    case (wr_state_r)
      WR_STATE_IDLE: begin
        if(wr_req_val) begin
          next_wr_state = WR_STATE_REQ;
        end
      end
      WR_STATE_REQ: begin
        if(stream_wr_req_rdy && wr_last_1) begin
          next_wr_state = WR_STATE_FINALIZE;
        end
        else if(stream_wr_req_rdy && (!wr_last_1)) begin
          next_wr_state = WR_STATE_NEXT;
        end
      end
      WR_STATE_NEXT: begin
        next_wr_state = WR_STATE_REQ;
      end
      WR_STATE_FINALIZE: begin
        // We can accept a write even though the AXI may be busy
        // However, we need to ensure that the write inst is ready to accept
        // the request
        if (wr_req_val && stream_wr_req_rdy) begin
          next_wr_state = WR_STATE_REQ;
        end
        else if (!stream_wr_busy) begin // otherwise, just go back to idle
          next_wr_state = WR_STATE_IDLE;
        end
      end
    endcase
  end


  always_comb begin
    cs_wr_req_rdy = 1'b0;
    cs_wr_req_cycle_mux_sel = 1'b0;
    cs_wr_req_reg_en = 1'b0;
    cs_stream_wr_req_val = 1'b0;
    cs_stream_wr_req_flush = 1'b0;
    cs_wr_busy = 1'b0;
    case (wr_state_r)
      WR_STATE_IDLE: begin
        cs_wr_req_rdy = 1'b1;
        cs_wr_req_reg_en = 1'b1;
      end
      WR_STATE_REQ: begin
        cs_wr_busy = 1'b1;
        cs_stream_wr_req_val = 1'b1;
        if(wr_req_flush_r) begin
          cs_stream_wr_req_flush = 1'b1;
        end
      end
      WR_STATE_NEXT: begin
        cs_wr_busy = 1'b1;
        cs_wr_req_cycle_mux_sel = 1'b1;
        cs_wr_req_reg_en = 1'b1;
      end
      WR_STATE_FINALIZE: begin
        cs_wr_busy = 1'b1;
        // axi can be busy but ready to accept writes.

        if (stream_wr_req_rdy) begin
          cs_wr_req_rdy = 1'b1;
          cs_wr_req_reg_en = 1'b1;
        end
      end
    endcase
  end

  assign wr_req_rdy = cs_wr_req_rdy;
  assign wr_busy = cs_wr_busy;

endmodule : stream

`default_nettype wire
