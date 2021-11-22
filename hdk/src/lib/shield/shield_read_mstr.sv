//Mark Zhao
//7/15/20
//This module takes in an address, and makes a request to DRAM to fill cache line

`default_nettype none
`timescale 1ns/1ps
module shield_read_mstr #(
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
  input  wire [SHIELD_ADDR_WIDTH-1:0] req_addr,
  input  wire                         req_val,
  output wire                         req_rdy,

  //Output to CL
  output wire [SHIELD_ADDR_WIDTH-1:0] resp_addr,
  output wire [LINE_WIDTH-1:0]        resp_data,
  output wire                         resp_val,
  input  wire                         resp_rdy,

  output wire                         busy,

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
  localparam STATE_RADDR_IDLE     = 2'd0,
             STATE_RADDR_REQ_DATA = 2'd1,
             STATE_RADDR_REQ_TAG  = 2'd2,
             STATE_RADDR_DONE     = 2'd3;

  localparam STATE_RDATA_IDLE           = 3'd0,
             STATE_RDATA_READ_DATA      = 3'd1,
             STATE_RDATA_START_DECRYPT  = 3'd2,
             STATE_RDATA_READ_TAG       = 3'd3,
             STATE_RDATA_DECRYPT_WAIT   = 3'd4,
             STATE_RDATA_TXFER          = 3'd5,
             STATE_RDATA_FAIL           = 3'd6;

  localparam integer HMAC_TAG_WIDTH = 128;
  localparam integer HMAC_TAG_PER_LINE = LINE_WIDTH / HMAC_TAG_WIDTH;
  localparam integer HMAC_TAG_PER_LINE_LOG = $clog2(HMAC_TAG_PER_LINE);



  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  //Registers for request
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_r;
  logic input_rxfer;
  logic load_input;

  //Address variables
  logic [AXI_ADDR_WIDTH-1:0] data_addr;
  logic [AXI_ADDR_WIDTH-1:0] tag_addr;
  logic [HMAC_TAG_PER_LINE_LOG-1:0] tag_offset;
  logic [SHIELD_ADDR_WIDTH-1:0] data_addr_aligned_mask;
  logic [SHIELD_ADDR_WIDTH-1:0] tag_addr_aligned_mask;

  //Registers for response from axi
  logic [AXI_DATA_WIDTH-1:0] axi_data_r;

  logic [HMAC_TAG_WIDTH-1:0] axi_tag;
  logic [HMAC_TAG_WIDTH-1:0] axi_tag_r;

  //State logic
  logic [1:0] raddr_state_r;
  logic [1:0] next_raddr_state;
  logic [2:0] rdata_state_r;
  logic [2:0] next_rdata_state;

  //decrypt signals
  logic [LINE_WIDTH-1:0] decrypt_pad;
  logic [HMAC_TAG_WIDTH-1:0] decrypt_tag;

  //Control signals
  logic cs_req_rdy;
  logic cs_axi_arvalid;
  logic cs_req_addr_mux_sel;

  logic cs_axi_rready;
  logic cs_data_reg_we;
  logic cs_tag_reg_we;
  logic cs_decrypt_req_val;
  logic cs_resp_val;

  logic decrypt_resp_rdy;

  //status signals
  logic decrypt_req_rdy;
  logic decrypt_resp_val;

  logic tag_match;

  //logic cs_axi_rdata_we;
  //logic cs_axi_rready;
  //logic cs_resp_val;


  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //Register input address
  shield_enreg #(.WIDTH(SHIELD_ADDR_WIDTH)) req_addr_reg (
    .clk(clk),
    .q(req_addr_r),
    .d(req_addr),
    .en(load_input)
  );
  assign input_rxfer = (req_val & cs_req_rdy);
  assign load_input = input_rxfer;

  //Assign AXI read addresses
  assign data_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << OFFSET_WIDTH;
  assign data_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, (req_addr_r & data_addr_aligned_mask)}; //Align to cache line
  assign tag_addr_aligned_mask = {SHIELD_ADDR_WIDTH{1'b1}} << (OFFSET_WIDTH + HMAC_TAG_PER_LINE_LOG);
  assign tag_addr = {{(AXI_ADDR_WIDTH-SHIELD_ADDR_WIDTH){1'b0}}, ((req_addr_r & tag_addr_aligned_mask) >> HMAC_TAG_PER_LINE_LOG)} + `TAG_BASE_ADDR;
  assign tag_offset = req_addr_r[OFFSET_WIDTH +: HMAC_TAG_PER_LINE_LOG];

  shield_mux2 #(.WIDTH(AXI_ADDR_WIDTH)) req_addr_mux(
    .in0(data_addr),
    .in1(tag_addr),
    .sel(cs_req_addr_mux_sel),
    .out(m_axi_araddr)
  );

  assign m_axi_arlen = 8'd0; //Read one burst always


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

  shield_enreg #(.WIDTH(AXI_DATA_WIDTH)) axi_data_reg (
    .clk(clk),
    .q(axi_data_r),
    .d(m_axi_rdata),
    .en(cs_data_reg_we)
  );

  //mux the read data to tag
  shield_muxp #(
    .BUS_WIDTH(LINE_WIDTH),
    .OUTPUT_WIDTH(HMAC_TAG_WIDTH),
    .SELECT_WIDTH(HMAC_TAG_PER_LINE_LOG),
    .SELECT_COUNT(HMAC_TAG_PER_LINE)
  ) tag_mux(
    .in_bus(m_axi_rdata),
    .sel(tag_offset),
    .out(axi_tag)
  );

  shield_enreg #(.WIDTH(HMAC_TAG_WIDTH)) axi_tag_reg (
    .clk(clk),
    .q(axi_tag_r),
    .d(axi_tag),
    .en(cs_tag_reg_we)
  );

  //decrypt and authenticate
  shield_read_decryptor #(
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .SHIELD_COUNTER_WIDTH(SHIELD_COUNTER_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .HMAC_TAG_WIDTH(HMAC_TAG_WIDTH),
    .NUM_AES(4)
  ) shield_read_decryptor_inst(
    .clk(clk),
    .rst_n(rst_n),
    .req_data(axi_data_r),
    .req_addr(data_addr[SHIELD_ADDR_WIDTH-1:0]),
    .req_counter(32'd0), //TODO: Add counter
    .req_iv(64'd0), //TODO: Add IV (iv + block offset)
    .req_val(cs_decrypt_req_val),
    .req_rdy(decrypt_req_rdy),
    .resp_pad(decrypt_pad),
    .resp_hmac_tag(decrypt_tag),
    .resp_val(decrypt_resp_val),
    .resp_rdy(decrypt_resp_rdy)
  );
  assign decrypt_resp_rdy = (resp_val && resp_rdy);

  assign resp_addr = req_addr_r;
  
  `ifdef NO_ENCRYPT
    assign resp_data = axi_data_r;
  `else
    assign resp_data = axi_data_r ^ decrypt_pad;
  `endif

  assign tag_match = (decrypt_tag == axi_tag_r);


  //////////////////////////////////////////////////////////////////////////////
  // Control logic
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      raddr_state_r <= STATE_RADDR_IDLE;
    end
    else begin
      raddr_state_r <= next_raddr_state;
    end
  end

  always_comb begin
    next_raddr_state = raddr_state_r;
    case (raddr_state_r)
      STATE_RADDR_IDLE: begin //Wait for request
        if(req_val) begin
          next_raddr_state = STATE_RADDR_REQ_DATA;
        end
      end
      STATE_RADDR_REQ_DATA: begin //send data request
        if(m_axi_arready) begin
          next_raddr_state = STATE_RADDR_REQ_TAG;
        end
      end
      STATE_RADDR_REQ_TAG: begin
        if(m_axi_arready) begin
          next_raddr_state = STATE_RADDR_DONE;
        end
      end
      STATE_RADDR_DONE: begin //wait for decrypted response to be read
        if(resp_val && resp_rdy) begin
          next_raddr_state = STATE_RADDR_IDLE; 
        end
      end
    endcase
  end

  //Output
  always_comb begin
    //default
    cs_req_rdy = 1'b0;
    cs_axi_arvalid = 1'b0;
    cs_req_addr_mux_sel = 1'b0;
    case (raddr_state_r)
      STATE_RADDR_IDLE: begin
        cs_req_rdy = 1'b1;
      end
      STATE_RADDR_REQ_DATA: begin
        cs_axi_arvalid = 1'b1;
        cs_req_addr_mux_sel = 1'b0;
      end
      STATE_RADDR_REQ_TAG: begin
        cs_axi_arvalid = 1'b1;
        cs_req_addr_mux_sel = 1'b1;
      end
      //STATE_RADDR_DONE: do nothing
    endcase
  end

  //FSM for data
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      rdata_state_r <= STATE_RDATA_IDLE;
    end
    else begin
      rdata_state_r <= next_rdata_state;
    end
  end

  always_comb begin
    next_rdata_state = rdata_state_r;
    case (rdata_state_r)
      STATE_RDATA_IDLE: begin
        if(req_rdy && req_val) begin
          next_rdata_state = STATE_RDATA_READ_DATA;
        end
      end
      STATE_RDATA_READ_DATA: begin
        if(m_axi_rvalid) begin
          next_rdata_state = STATE_RDATA_START_DECRYPT;
        end
      end
      STATE_RDATA_START_DECRYPT: begin
        if(decrypt_req_rdy) begin
          next_rdata_state = STATE_RDATA_READ_TAG;
        end
      end
      STATE_RDATA_READ_TAG: begin
        if(m_axi_rvalid) begin
          next_rdata_state = STATE_RDATA_DECRYPT_WAIT;
        end
      end
      STATE_RDATA_DECRYPT_WAIT: begin
        //Wait for decryption to complete
        if(decrypt_resp_val) begin //TODO: Check for tag mismatch
          next_rdata_state = STATE_RDATA_TXFER;
        end
      end
      STATE_RDATA_TXFER: begin
        `ifdef NO_TAG_CHECK
          if(resp_rdy) begin
            next_rdata_state = STATE_RDATA_IDLE;
          end
        `elsif NO_TAG_CHECK_FIRST //ignores first read from DRAM
          if(axi_tag_r == {HMAC_TAG_WIDTH{1'b0}}) begin
            if(resp_rdy) begin
              next_rdata_state = STATE_RDATA_IDLE;
            end
          end
          else begin
            if(tag_match) begin
              if(resp_rdy) begin
                next_rdata_state = STATE_RDATA_IDLE;
              end
            end
            else begin
              next_rdata_state = STATE_RDATA_FAIL;
            end
          end
        `else
          if(tag_match) begin
            if(resp_rdy) begin
              next_rdata_state = STATE_RDATA_IDLE;
            end
          end
          else begin
            next_rdata_state = STATE_RDATA_FAIL;
          end
        `endif
      end
      STATE_RDATA_FAIL: begin
        next_rdata_state = rdata_state_r; //stay here forever
      end
    endcase
  end

  always_comb begin
    //default
    cs_axi_rready = 1'b0;
    cs_data_reg_we = 1'b0;
    cs_tag_reg_we = 1'b0;
    cs_decrypt_req_val = 1'b0;
    cs_resp_val = 1'b0;
    case (rdata_state_r)
      //STATE_RDATA_IDLE: default
      STATE_RDATA_READ_DATA: begin
        cs_axi_rready = 1'b1;
        cs_data_reg_we = 1'b1;
      end
      STATE_RDATA_START_DECRYPT: begin
        cs_decrypt_req_val = 1'b1;
      end
      STATE_RDATA_READ_TAG: begin
        cs_axi_rready = 1'b1;
        cs_tag_reg_we = 1'b1;
      end
      //STATE_RDATA_DECRYPT_WAIT: default
      STATE_RDATA_TXFER: begin
        cs_resp_val = 1'b1;
      end
    endcase
  end

  //Assign ports
  assign req_rdy = cs_req_rdy;
  assign m_axi_arvalid = cs_axi_arvalid;
  assign m_axi_rready = cs_axi_rready;
  assign resp_val = cs_resp_val;

  assign busy = (rdata_state_r != STATE_RDATA_IDLE) || (raddr_state_r != STATE_RADDR_IDLE);

endmodule : shield_read_mstr

`default_nettype wire
