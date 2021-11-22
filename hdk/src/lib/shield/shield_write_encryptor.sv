//Mark Zhao
//7/21/20
//This module encrypts and generates tag for write data
`include "free_common_defines.vh"

`default_nettype none
module shield_write_encryptor #(
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer SHIELD_COUNTER_WIDTH = 32,
  parameter integer LINE_WIDTH = 512,
  parameter integer HMAC_TAG_WIDTH = 128,
  parameter integer NUM_AES = 4
)
(
  input  wire clk,
  input  wire rst_n,
  //encryption
  input  wire [LINE_WIDTH-1:0]               enc_req_data, //plaintext
  input  wire [SHIELD_COUNTER_WIDTH-1:0]     enc_req_counter,
  input  wire [63:0]                         enc_req_iv,
  input  wire                                enc_req_val,
  output wire                                enc_req_rdy,

  output wire [LINE_WIDTH-1:0]               enc_resp_data,
  output wire                                enc_resp_val,

  input  wire                                auth_start, //signal to start auth. req_counter and req_addr must be valid

  //authentication (uses generated ciphertext)
  input  wire [SHIELD_COUNTER_WIDTH-1:0]     auth_req_counter,
  input  wire [SHIELD_ADDR_WIDTH-1:0]        auth_req_addr,
  output wire [HMAC_TAG_WIDTH-1:0]           auth_resp_tag,
  output wire                                auth_resp_val,
  input  wire                                auth_resp_rdy

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE         = 3'd0,
             STATE_ENC_REQ      = 3'd1,
             STATE_ENC_RESP     = 3'd2,
             STATE_AUTH_RESP    = 3'd3;

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  //State logic
  logic [2:0] state_r;
  logic [2:0] next_state;

  //AES signals
  logic [LINE_WIDTH-1:0] aes_pad;
  logic [LINE_WIDTH-1:0] ciphertext;

  //HMAC
  logic [127:0] hmac_tag;

  //control signals
  logic cs_enc_req_rdy;
  logic [NUM_AES-1:0] cs_aes_req_val;
  logic [NUM_AES-1:0] cs_aes_resp_rdy;
  logic cs_enc_resp_val;
  logic cs_hmac_req_val;
  logic cs_hmac_resp_rdy;
  logic cs_auth_resp_val;

  //Status signasl
  logic [NUM_AES-1:0] aes_req_rdy;
  logic [NUM_AES-1:0] aes_resp_val;
  logic hmac_req_rdy;
  logic hmac_resp_val;

  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //encrypt then mac
  genvar i;
  generate
    for(i = 0; i < NUM_AES; i++) begin
      localparam integer COUNTER_VAL = i;
      aes #(.DATA_WIDTH(128)) aes_inst(
        .clk(clk),
        .rst_n(rst_n),
        .nonce({enc_req_iv, enc_req_counter}), //IV is IV (64 bits) plus 32-bit counter. 
        .counter(COUNTER_VAL), //32 bit block counter for this chunk
        .req_val(cs_aes_req_val[i]),
        .req_rdy(aes_req_rdy[i]),
        .pad(aes_pad[i*128 +: 128]),
        .pad_val(aes_resp_val[i]),
        .pad_rdy(cs_aes_resp_rdy[i])
      );
    end
  endgenerate

  `ifdef NO_ENCRYPT
    assign ciphertext = enc_req_data;
  `else
    assign ciphertext = aes_pad ^ enc_req_data;
  `endif
  //assign ciphertext = req_data;
  assign enc_resp_data = ciphertext;

  hmac #(.DATA_WIDTH(LINE_WIDTH), 
    .ADDR_WIDTH(SHIELD_ADDR_WIDTH), 
    .COUNTER_WIDTH(SHIELD_COUNTER_WIDTH)) hmac_inst(
    .clk(clk),
    .rst_n(rst_n),
    .req_data(ciphertext),
    .req_addr(auth_req_addr),
    .req_counter(auth_req_counter),
    .req_val(cs_hmac_req_val),
    .req_rdy(hmac_req_rdy),
    .hmac(hmac_tag),
    .hmac_val(hmac_resp_val),
    .hmac_rdy(cs_hmac_resp_rdy)
  );
  assign auth_resp_tag = hmac_tag[0+:HMAC_TAG_WIDTH];

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
      STATE_IDLE: begin //Wait until AES is ready
        if(&aes_req_rdy) begin
          next_state = STATE_ENC_REQ;
        end
      end 
      STATE_ENC_REQ: begin //Wait for encryption req
        if(enc_req_val) begin
          next_state = STATE_ENC_RESP;
        end
      end
      STATE_ENC_RESP: begin //respond with ciphertext
        if((&aes_resp_val) && auth_start && hmac_req_rdy) begin
          next_state = STATE_AUTH_RESP;
        end
      end
      STATE_AUTH_RESP: begin //Wait for hmac val and auth rdy
        if(hmac_resp_val && auth_resp_rdy) begin
          next_state = STATE_IDLE;
        end
      end
    endcase
  end

  //Output
  always_comb begin
    cs_enc_req_rdy = 1'b0;
    cs_aes_req_val = {NUM_AES{1'b0}};
    cs_aes_resp_rdy = {NUM_AES{1'b0}};
    cs_enc_resp_val = 1'b0;
    cs_hmac_req_val = 1'b0;
    cs_hmac_resp_rdy = 1'b0;
    cs_auth_resp_val = 1'b0;
    case (state_r)
      //STATE_IDLE: do nothing
      STATE_ENC_REQ: begin
        cs_enc_req_rdy = 1'b1;
        if(enc_req_val) begin
          cs_aes_req_val = {NUM_AES{1'b1}};
        end
      end
      STATE_ENC_RESP: begin
        if(&aes_resp_val) begin
          cs_enc_resp_val = 1'b1;
          if(auth_start && hmac_req_rdy) begin
            cs_hmac_req_val = 1'b1;
          end
        end
      end
      STATE_AUTH_RESP: begin
        if(hmac_resp_val) begin
          cs_auth_resp_val = 1'b1;
          if(auth_resp_rdy) begin //transition to idle, clear all crypto cores
            cs_aes_resp_rdy = {NUM_AES{1'b1}};
            cs_hmac_resp_rdy = 1'b1;
          end
        end
      end
    endcase
  end

  assign enc_req_rdy = cs_enc_req_rdy;
  assign enc_resp_val = cs_enc_resp_val;
  assign auth_resp_val = cs_auth_resp_val;


endmodule : shield_write_encryptor
`default_nettype wire
