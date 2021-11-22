//Mark Zhao
//7/15/20
//This module writes a cache line to DRAM (evict path)
`default_nettype none
`timescale 1ns/1ps
module shield_write_mstr #(
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer AXI_ID_WIDTH = 16,
  parameter integer AXI_DATA_WIDTH = 512,
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer SHIELD_COUNTER_WIDTH = 32,
  parameter integer LINE_WIDTH = 512,
  parameter integer OFFSET_WIDTH = 6
)
(
  input  wire clk,
  input  wire rst_n,

  //Input request from datapath
  input  wire [LINE_WIDTH-1:0]             req_data,
  input  wire [SHIELD_ADDR_WIDTH-1:0]      req_addr,
  input  wire                              req_val,
  output wire                              req_rdy,

  output wire                              busy,


  //Output to datapath - not needed??

  //Output to DRAM
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
  output wire                              m_axi_bready
);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE     = 3'd0,
             STATE_ENC_REQ = 3'd1,
             STATE_ENC_WAIT = 3'd2,
             STATE_WRITE_CT    = 3'd3,
             STATE_WRITE_CT_RESP    = 3'd4,
             STATE_AUTH_WAIT = 3'd5,
             STATE_WRITE_TAG = 3'd6,
             STATE_WRITE_TAG_RESP = 3'd7;
             
    

  localparam WSTRB_WIDTH = AXI_DATA_WIDTH/8;

  localparam integer HMAC_TAG_WIDTH = 128;
  localparam integer HMAC_TAG_WIDTH_BYTES = HMAC_TAG_WIDTH / 8;
  localparam integer HMAC_TAG_PER_LINE = LINE_WIDTH / HMAC_TAG_WIDTH;
  localparam integer HMAC_TAG_PER_LINE_LOG = $clog2(HMAC_TAG_PER_LINE);

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  //Registers for request
  logic [LINE_WIDTH-1:0]        req_data_r;
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_r;

  logic [AXI_ADDR_WIDTH-1:0] data_addr;
  logic [AXI_ADDR_WIDTH-1:0] tag_addr;
  logic [HMAC_TAG_PER_LINE_LOG-1:0] tag_offset;
  logic [SHIELD_ADDR_WIDTH-1:0] data_addr_aligned_mask;
  logic [SHIELD_ADDR_WIDTH-1:0] tag_addr_aligned_mask;

  logic [LINE_WIDTH-1:0] ciphertext;
  logic [HMAC_TAG_WIDTH-1:0] tag;
  logic [LINE_WIDTH-1:0] tag_line;

  logic [WSTRB_WIDTH-1:0] tag_line_wstrb;

  
 
  //State logic
  logic [2:0] state_r;
  logic [2:0] next_state;

  //Control signals
  logic cs_req_reg_we;
  logic cs_req_rdy;
  logic cs_enc_req_val;
  logic cs_auth_start;
  logic cs_auth_resp_rdy;
  logic cs_req_addr_mux_sel;
  logic cs_write_data_mux_sel;
  logic cs_axi_awvalid;
  logic cs_axi_wvalid;
  logic cs_axi_wlast;
  logic cs_axi_bready;
  

  //Status
  logic enc_req_rdy;
  logic enc_resp_val;
  logic auth_resp_val;


  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //Tie off unused axi signals
  assign m_axi_awid     = {AXI_ID_WIDTH{1'b0}};
  assign m_axi_awsize   = 3'b110;  //write 64B
  assign m_axi_awburst  = 2'b01;
  assign m_axi_awlock   = 2'b00;
  assign m_axi_awcache  = 4'b0011;
  assign m_axi_awprot   = 3'b000;
  assign m_axi_awqos    = 4'b0000;
  assign m_axi_awregion = 4'b0000;
  assign m_axi_wid      = {AXI_ID_WIDTH{1'b0}};
  
  
  //Register write data and address
  shield_enreg #(.WIDTH(LINE_WIDTH)) req_data_reg(
    .clk(clk),
    .q(req_data_r),
    .d(req_data),
    .en(cs_req_reg_we)
  );

  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) req_addr_reg(
    .clk(clk),
    .q(req_addr_r),
    .d(req_addr),
    .en(cs_req_reg_we)
  );

  shield_write_encryptor #(
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .SHIELD_COUNTER_WIDTH(SHIELD_COUNTER_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .HMAC_TAG_WIDTH(HMAC_TAG_WIDTH),
    .NUM_AES(4)
  ) shield_write_encryptor_inst(
    .clk(clk),
    .rst_n(rst_n),
    .enc_req_data(req_data_r),
    .enc_req_counter(32'd0), //TODO: add counter
    .enc_req_iv(64'd0), //TODO: Add IV (iv + block offset)
    .enc_req_val(cs_enc_req_val),
    .enc_req_rdy(enc_req_rdy),
    .enc_resp_data(ciphertext),
    .enc_resp_val(enc_resp_val),
    .auth_start(cs_auth_start),
    .auth_req_counter(32'd0), //TODO: add counter
    .auth_req_addr(data_addr[SHIELD_ADDR_WIDTH-1:0]),
    .auth_resp_tag(tag),
    .auth_resp_val(auth_resp_val),
    .auth_resp_rdy(cs_auth_resp_rdy)
  );




  //Assign write address and data
  assign data_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << OFFSET_WIDTH;
  assign data_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, (req_addr_r & data_addr_aligned_mask)}; //Align to cache line
  assign tag_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << (OFFSET_WIDTH + HMAC_TAG_PER_LINE_LOG);
  assign tag_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, ((req_addr_r & tag_addr_aligned_mask) >> HMAC_TAG_PER_LINE_LOG)} + `TAG_BASE_ADDR;
  assign tag_offset = req_addr_r[OFFSET_WIDTH +: HMAC_TAG_PER_LINE_LOG];

  shield_mux2 #(.WIDTH(AXI_ADDR_WIDTH)) req_addr_mux(
    .in0(data_addr),
    .in1(tag_addr),
    .sel(cs_req_addr_mux_sel),
    .out(m_axi_awaddr)
  );
  assign m_axi_awlen = 8'd0; //write one burst

  //Data
  //Write the tag to the appropriate section of the cache line
  integer i;
  always_comb begin
    for(i = 0; i < HMAC_TAG_PER_LINE; i++) begin
      if(i == tag_offset) begin
        tag_line[(i*HMAC_TAG_WIDTH) +: HMAC_TAG_WIDTH] = tag;
        tag_line_wstrb[(i*HMAC_TAG_WIDTH_BYTES) +: HMAC_TAG_WIDTH_BYTES] = {HMAC_TAG_WIDTH_BYTES{1'b1}};
      end
      else begin
        tag_line[(i*HMAC_TAG_WIDTH) +: HMAC_TAG_WIDTH] = {HMAC_TAG_WIDTH{1'b0}};
        tag_line_wstrb[(i*HMAC_TAG_WIDTH_BYTES) +: HMAC_TAG_WIDTH_BYTES] = {HMAC_TAG_WIDTH_BYTES{1'b0}};
      end
    end
  end

  shield_mux2 #(.WIDTH(LINE_WIDTH)) write_data_mux(
    .in0(ciphertext),
    .in1(tag_line),
    .sel(cs_write_data_mux_sel),
    .out(m_axi_wdata)
  );

  shield_mux2 #(.WIDTH(WSTRB_WIDTH)) write_wstrb_mux(
    .in0({WSTRB_WIDTH{1'b1}}),
    .in1(tag_line_wstrb),
    .sel(cs_write_data_mux_sel),
    .out(m_axi_wstrb)
  );

  //////////////////////////////////////////////////////////////////////////////
  // Control logic
  //////////////////////////////////////////////////////////////////////////////
  //FSM for address
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r <= STATE_IDLE;  
    end
    else begin
      state_r <= next_state;
    end
  end


  always_comb begin
    next_state = state_r;
    case(state_r)
      STATE_IDLE: begin //wait for write request
        if(req_val) begin
          next_state = STATE_ENC_REQ;
        end
      end
      STATE_ENC_REQ: begin
        if(enc_req_rdy) begin
          next_state = STATE_ENC_WAIT;
        end
      end
      STATE_ENC_WAIT: begin //wait for encryption to finish
        if(enc_resp_val && m_axi_awready) begin //also signal aw in this state
          next_state = STATE_WRITE_CT;
        end
      end
      STATE_WRITE_CT: begin
        if(m_axi_wready) begin
          next_state = STATE_WRITE_CT_RESP;
        end
      end
      STATE_WRITE_CT_RESP: begin //write bready
        if(m_axi_bvalid) begin
          next_state = STATE_AUTH_WAIT;
        end
      end
      STATE_AUTH_WAIT: begin
        if(auth_resp_val && m_axi_awready) begin
          next_state = STATE_WRITE_TAG;
        end
      end
      STATE_WRITE_TAG: begin
        if(m_axi_wready) begin
          next_state = STATE_WRITE_TAG_RESP;
        end
      end
      STATE_WRITE_TAG_RESP: begin
        if(m_axi_bvalid) begin
          next_state = STATE_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_req_reg_we = 1'b0;
    cs_req_rdy = 1'b0;
    cs_enc_req_val = 1'b0;
    cs_auth_start = 1'b0;
    cs_auth_resp_rdy = 1'b0;
    cs_req_addr_mux_sel = 1'b0;
    cs_write_data_mux_sel = 1'b0;
    cs_axi_awvalid = 1'b0;
    cs_axi_wvalid = 1'b0;
    cs_axi_wlast = 1'b0;
    cs_axi_bready = 1'b0;
    case(state_r)
      STATE_IDLE: begin
        cs_req_reg_we = 1'b1;
        cs_req_rdy = 1'b1;
      end
      STATE_ENC_REQ: begin
        cs_enc_req_val = 1'b1;
      end
      STATE_ENC_WAIT: begin
        cs_req_addr_mux_sel = 1'b0; //use data addr
        if(enc_resp_val) begin
          cs_axi_awvalid = 1'b1; //signal valid when enc resp is done
        end
      end
      STATE_WRITE_CT: begin
        cs_write_data_mux_sel = 1'b0;
        cs_axi_wvalid = 1'b1;
        cs_axi_wlast = 1'b1;
        //Trigger auth once ciphertext is written
        if(m_axi_wready) begin
          cs_auth_start = 1'b1;
        end
      end
      STATE_WRITE_CT_RESP: begin
        cs_axi_bready = 1'b1;
      end
      STATE_AUTH_WAIT: begin
        cs_req_addr_mux_sel = 1'b1; //use tag addr
        if(auth_resp_val) begin
          cs_axi_awvalid = 1'b1;
        end
      end
      STATE_WRITE_TAG: begin
        cs_write_data_mux_sel = 1'b1;
        cs_axi_wvalid = 1'b1;
        cs_axi_wlast = 1'b1;
        if(m_axi_wready) begin //clear encryptor once tag is written
          cs_auth_resp_rdy = 1'b1;
        end
      end
      STATE_WRITE_TAG_RESP: begin
        cs_axi_bready = 1'b1;
      end
    endcase
  end



  assign req_rdy = cs_req_rdy;
  assign m_axi_awvalid = cs_axi_awvalid;
  assign m_axi_wvalid = cs_axi_wvalid;
  assign m_axi_wlast = cs_axi_wlast;
  assign m_axi_bready = cs_axi_bready;


  assign busy = (state_r != STATE_IDLE);




endmodule : shield_write_mstr
`default_nettype wire
