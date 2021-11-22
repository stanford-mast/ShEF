//Mark Zhao
//7/22/20
//Top level module for stream
`include "free_common_defines.vh"

`default_nettype none

module light_encryptor #(
  parameter integer CT_WIDTH = 640 //bit width of cipehrtext
)(
  input  wire clk,
  input  wire rst_n,

  //input ciphertext
  input  wire [CT_WIDTH-1:0] req_plaintext,
  input  wire                req_val,
  output wire                req_rdy,

  //Output to CL
  output wire [CT_WIDTH-1:0] resp_ciphertext,
  output wire [127:0]        resp_hmac,
  output wire                resp_val,
  input  wire                resp_rdy
);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam integer NUM_AES_BLOCKS = 5; //number of aes blocks for CT
  localparam integer NUM_HMAC_BLOCKS = 2; //number of hmac blocks
  
  localparam STATE_AES_IDLE = 3'd0,
             STATE_AES_REQ = 3'd1,
             STATE_AES_PAD = 3'd2,
             STATE_AES_DONE = 3'd3;
  
  localparam STATE_HMAC_IDLE = 3'd0,
             STATE_HMAC_REQ_0 = 3'd1,
             STATE_HMAC_REQ_1 = 3'd2,
             STATE_DIGEST_WAIT = 3'd3,
             STATE_HMAC_DONE = 3'd4,
             STATE_HMAC_WAIT = 3'd5;
       

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [2:0] aes_state_r;
  logic [2:0] next_aes_state;

  logic [2:0] hmac_state_r;
  logic [2:0] next_hmac_state;

  //AES
  logic [95:0] aes_iv;
  logic [127:0] aes_pad;
  logic [CT_WIDTH-1:0] ct_pad_r;
  logic [CT_WIDTH-1:0] next_ct_pad;

  logic [7:0] ct_pad_write_index;

  //HMAC
  logic [511:0] hmac_block_0;
  logic [511:0] hmac_block_1;
  logic [511:0] hmac_block;
  logic [127:0] hmac_digest;
  //

  //Control
  logic cs_aes_rdy;
  logic cs_aes_req_val;
  logic cs_aes_resp_rdy;
  logic cs_ct_pad_index_incr;
  logic cs_ct_pad_we;
  logic cs_aes_done;
  logic cs_hmac_rdy;
  logic cs_hmac_req_val;
  logic cs_hmac_block_val;
  logic cs_hmac_digest_rdy;
  logic cs_hmac_block_mux_sel;
  logic cs_hmac_done;
  
  

  //Status
  logic aes_req_rdy;
  logic aes_resp_val;
  logic hmac_req_rdy;
  logic hmac_block_rdy;
  logic hmac_digest_val;



  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  assign aes_iv = 96'd0;
  
  aes #(.DATA_WIDTH(128)) aes_inst(
    .clk(clk),
    .rst_n(rst_n),
    .nonce(aes_iv), //TODO: Set to IV plus chunk count
    .counter(32'd0), //TODO: 32 bit block counter for this chunk
    .req_val(cs_aes_req_val),
    .req_rdy(aes_req_rdy),
    .pad(aes_pad),
    .pad_val(aes_resp_val),
    .pad_rdy(cs_aes_resp_rdy)
  );

  //Counter for AES
  shield_counter #(.C_WIDTH(8)) ct_pad_index_counter(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_aes_rdy), //load when idling
    .incr(cs_ct_pad_index_incr),
    .decr(1'b0),
    .load_value(0),
    .count(ct_pad_write_index),
    .is_zero()
  );

  integer i;
  always_comb begin
    for(i = 0; i < NUM_AES_BLOCKS; i++) begin
      if(i == ct_pad_write_index) begin
        next_ct_pad[i*128 +: 128] = aes_pad;
      end
      else begin
        next_ct_pad[i*128 +: 128] = ct_pad_r[i*128 +: 128];
      end
    end
  end

  //Register for the ct pad
  shield_enrstreg #(.WIDTH(CT_WIDTH)) ct_pad_reg(
    .clk(clk),
    .rst_n(rst_n),
    .q(ct_pad_r),
    .d(next_ct_pad),
    .en(cs_ct_pad_we)
  );

  //Mux for hmac block
  //assign hmac_block_0 = req_ciphertext[639:128];
  //assign hmac_block_1 = {req_ciphertext[127:0], {384{1'b0}}};
  assign hmac_block_0 = resp_ciphertext[639:128];
  assign hmac_block_1 = {resp_ciphertext[127:0], {384{1'b0}}};
  shield_mux2 #(.WIDTH(512)) hmac_block_mux(
    .in0(hmac_block_0),
    .in1(hmac_block_1),
    .sel(cs_hmac_block_mux_sel),
    .out(hmac_block)
  );


  hmac_light #(.DATA_COUNT_BURSTS(2)) hmac_inst(
    .clk(clk),
    .rst_n(rst_n),
    .req_val(cs_hmac_req_val),
    .req_rdy(hmac_req_rdy),
    .stream_data(hmac_block),
    .stream_data_val(cs_hmac_block_val),
    .stream_data_rdy(hmac_block_rdy),
    .hmac(hmac_digest),
    .hmac_val(hmac_digest_val),
    .hmac_rdy(cs_hmac_digest_rdy)
  );
 
  `ifdef NO_ENCRYPT
    assign resp_ciphertext = req_plaintext;
  `else
    assign resp_ciphertext = req_plaintext ^ ct_pad_r;
  `endif

  assign resp_hmac = hmac_digest;

  //////////////////////////////////////////////////////////////////////////////
  // Control
  //////////////////////////////////////////////////////////////////////////////
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
      STATE_AES_IDLE: begin
        if(cs_hmac_rdy && aes_req_rdy && req_val) begin
          next_aes_state = STATE_AES_REQ;
        end
      end
      STATE_AES_REQ: begin
        next_aes_state = STATE_AES_PAD;
      end
      STATE_AES_PAD: begin
        if(aes_resp_val) begin
          if(ct_pad_write_index == (NUM_AES_BLOCKS - 1)) begin
            next_aes_state = STATE_AES_DONE;
          end
          else begin
            next_aes_state = STATE_AES_REQ;
          end
        end
      end
      STATE_AES_DONE: begin
        if(cs_hmac_done && resp_rdy) begin
          next_aes_state = STATE_AES_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_aes_rdy = 0;
    cs_aes_req_val= 0;
    cs_aes_resp_rdy = 0;
    cs_ct_pad_index_incr = 0;
    cs_ct_pad_we = 0;
    cs_aes_done = 0;
    case (aes_state_r)
      STATE_AES_IDLE: begin
        if(aes_req_rdy) begin
          cs_aes_rdy = 1'b1;
        end
      end
      STATE_AES_REQ: begin
        cs_aes_req_val = 1'b1;
      end
      STATE_AES_PAD: begin
        if(aes_resp_val) begin
          cs_ct_pad_index_incr = 1'b1;
          cs_ct_pad_we = 1'b1;
          cs_aes_resp_rdy = 1'b1;
        end
      end
      STATE_AES_DONE: begin
        cs_aes_done = 1'b1;
        //if(cs_hmac_done && resp_rdy) begin //Reset AES
        //end
      end
    endcase
  end

  //HMAC FSM
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      hmac_state_r <= STATE_HMAC_IDLE;
    end
    else begin
      hmac_state_r <= next_hmac_state;
    end
  end

  always_comb begin
    next_hmac_state = hmac_state_r;
    case(hmac_state_r)
      STATE_HMAC_IDLE: begin
        if(cs_aes_rdy && hmac_req_rdy && req_val) begin
          next_hmac_state = STATE_HMAC_WAIT;
        end
      end
      STATE_HMAC_WAIT: begin //Wait for ct to be generated
        if(cs_aes_done) begin
          next_hmac_state = STATE_HMAC_REQ_0;
        end
      end
      STATE_HMAC_REQ_0: begin
        if(hmac_block_rdy) begin
          next_hmac_state = STATE_HMAC_REQ_1;
        end
      end
      STATE_HMAC_REQ_1: begin
        if(hmac_block_rdy) begin
          next_hmac_state = STATE_DIGEST_WAIT;
        end
      end
      STATE_DIGEST_WAIT: begin
        if(hmac_digest_val) begin
          next_hmac_state = STATE_HMAC_DONE;
        end
      end
      STATE_HMAC_DONE: begin
        if(cs_aes_done && resp_rdy) begin
          next_hmac_state = STATE_HMAC_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_hmac_rdy = 0;
    cs_hmac_req_val = 0;
    cs_hmac_block_val = 0;
    cs_hmac_digest_rdy = 0;
    cs_hmac_block_mux_sel = 0;
    cs_hmac_done = 0;
    case(hmac_state_r)
      STATE_HMAC_IDLE: begin
        if(hmac_req_rdy) begin
            cs_hmac_rdy = 1'b1;
            if(cs_aes_rdy && req_val) begin
              cs_hmac_req_val = 1'b1;
            end
        end
      end
      STATE_HMAC_REQ_0: begin
        cs_hmac_block_mux_sel = 1'b0;
        cs_hmac_block_val = 1'b1;
      end
      STATE_HMAC_REQ_1: begin
        cs_hmac_block_mux_sel = 1'b1;
        cs_hmac_block_val = 1'b1;
      end
      STATE_HMAC_DONE: begin
        cs_hmac_done = 1'b1;
        if(cs_aes_done && resp_rdy) begin
          cs_hmac_digest_rdy = 1'b1;
        end
      end
    endcase
  end

  assign req_rdy = cs_aes_rdy && cs_hmac_rdy;
  assign resp_val = cs_hmac_done && cs_aes_done;

endmodule : light_encryptor

`default_nettype wire
