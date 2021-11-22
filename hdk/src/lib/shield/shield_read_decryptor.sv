//Mark Zhao
//7/21/20
//This module decrypts and authenticates read data

`include "free_common_defines.vh"

`default_nettype none
module shield_read_decryptor #(
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer SHIELD_COUNTER_WIDTH = 32,
  parameter integer LINE_WIDTH = 512,
  parameter integer HMAC_TAG_WIDTH = 128,
  parameter integer NUM_AES = 4
)
(
  input  wire clk,
  input  wire rst_n,

  input  wire [LINE_WIDTH-1:0]               req_data, //ciphertext
  input  wire [SHIELD_ADDR_WIDTH-1:0]        req_addr,
  input  wire [SHIELD_COUNTER_WIDTH-1:0]     req_counter,
  input  wire [63:0]                         req_iv,
  input  wire                                req_val,
  output wire                                req_rdy,

  output wire [LINE_WIDTH-1:0]               resp_pad, //output is pad (master should xor)
  output wire [HMAC_TAG_WIDTH-1:0]           resp_hmac_tag,
  output wire                                resp_val,
  input  wire                                resp_rdy

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE     = 2'd0,
             STATE_REQ      = 2'd1,
             STATE_RESP     = 2'd2;
  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  //State logic
  logic [1:0] state_r;
  logic [1:0] next_state;

  //AES
  logic [63:0] aes_iv;
  logic [LINE_WIDTH-1:0] aes_pad;

  //HMAC
  logic [127:0] hmac_tag;

  //control signals
  logic cs_req_rdy;
  logic [NUM_AES-1:0] cs_aes_req_val;
  logic [NUM_AES-1:0] cs_aes_resp_rdy;
  logic cs_hmac_req_val;
  logic cs_hmac_resp_rdy;
  logic cs_resp_val;

  //Status signasl
  logic [NUM_AES-1:0] aes_req_rdy;
  logic [NUM_AES-1:0] aes_resp_val;
  logic hmac_req_rdy;
  logic hmac_resp_val;

  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  assign aes_iv = req_iv;
  genvar i;
  generate
    for(i = 0; i < NUM_AES; i++) begin
      localparam integer COUNTER_VAL = i;
      aes #(.DATA_WIDTH(128)) aes_inst(
        .clk(clk),
        .rst_n(rst_n),
        .nonce({aes_iv, req_counter}), //IV is IV (64 bits) plus 32-bit counter. 
        .counter(COUNTER_VAL), //32 bit block counter for this chunk
        .req_val(cs_aes_req_val[i]),
        .req_rdy(aes_req_rdy[i]),
        .pad(aes_pad[i*128 +: 128]),
        .pad_val(aes_resp_val[i]),
        .pad_rdy(cs_aes_resp_rdy[i])
      );
    end
  endgenerate

  hmac #(.DATA_WIDTH(LINE_WIDTH), 
    .ADDR_WIDTH(SHIELD_ADDR_WIDTH), 
    .COUNTER_WIDTH(SHIELD_COUNTER_WIDTH)) hmac_inst(
    .clk(clk),
    .rst_n(rst_n),
    .req_data(req_data),
    .req_addr(req_addr),
    .req_counter(req_counter),
    .req_val(cs_hmac_req_val),
    .req_rdy(hmac_req_rdy),
    .hmac(hmac_tag),
    .hmac_val(hmac_resp_val),
    .hmac_rdy(cs_hmac_resp_rdy)
  );

  assign resp_pad = aes_pad;
  assign resp_hmac_tag = hmac_tag[0+:HMAC_TAG_WIDTH];



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
      STATE_IDLE: begin
        //Wait until all modules are ready
        if((&aes_req_rdy) && hmac_req_rdy) begin
          next_state = STATE_REQ;
        end
      end
      STATE_REQ: begin
        if(req_val) begin
          next_state = STATE_RESP;
        end
      end
      STATE_RESP: begin
        if(hmac_resp_val && (&aes_resp_val) && resp_rdy) begin
          next_state = STATE_IDLE;
        end
      end
    endcase
  end

  //Output
  always_comb begin
    cs_req_rdy = 0;
    cs_aes_req_val = 0;
    cs_hmac_req_val = 0;
    cs_aes_resp_rdy = 0;
    cs_hmac_resp_rdy = 0;
    cs_resp_val = 0;
    //Do nothing in idle state
    case (state_r)
      STATE_REQ: begin
        cs_req_rdy = 1'b1;
        if(req_val) begin
          cs_aes_req_val = {NUM_AES{1'b1}};
          cs_hmac_req_val = 1'b1;
        end
      end
      STATE_RESP: begin
        if(hmac_resp_val && (&aes_resp_val)) begin
          cs_resp_val = 1'b1;
          if(resp_rdy) begin
            cs_aes_resp_rdy = {NUM_AES{1'b1}};
            cs_hmac_resp_rdy = 1'b1;
          end
        end
      end
    endcase
  end

  assign req_rdy = cs_req_rdy;
  assign resp_val = cs_resp_val;

endmodule : shield_read_decryptor
`default_nettype wire
