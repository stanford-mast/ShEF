//Mark Zhao
//7/20/20
//Wrapper for aes core
`include "free_common_defines.vh"

`default_nettype none

module aes #(
  parameter integer DATA_WIDTH = 128 //datawidth of input and output
)
(
  input  wire                  clk,
  input  wire                  rst_n,

  //input
  input  wire [95:0]           nonce,
  input  wire [31:0]           counter,
  input  wire                  req_val,
  output wire                  req_rdy,

  //output
  output wire [DATA_WIDTH-1:0] pad,
  output wire                  pad_val,
  input  wire                  pad_rdy
);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE        = 3'd0,
             STATE_INIT        = 3'd1,
             STATE_KEYEXP_WAIT = 3'd2,
             STATE_REQ_WAIT    = 3'd3,
             STATE_ENC_NEXT    = 3'd4,
             STATE_RESULT      = 3'd5;


  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [2:0] state_r;
  logic [2:0] next_state;

  //Keys
  logic [255:0] aes_key;

  //Control signals
  logic       cs_aes_init;
  logic       cs_aes_next;
  logic       cs_req_rdy;
  logic       cs_req_reg_we;
  logic       cs_pad_val_en;

  //Status signals
  logic       aes_rdy;
  logic       aes_result_val;

  //Input and output of aes core
  logic [127:0] aes_block;
  logic [127:0] aes_result;


  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //Register request
  shield_enreg #(.WIDTH(128)) req_reg(
    .clk(clk),
    .d({nonce, counter}),
    .q(aes_block),
    .en(cs_req_reg_we)
  );

  assign aes_key = `AES_KEY;


  aes_core aes_core_inst(
    .clk(clk),
    .reset_n(rst_n),
    .encdec(1'b1), //always encrypt
    .init(cs_aes_init),
    .next(cs_aes_next),
    .ready(aes_rdy),
    .key(aes_key),
    `ifdef AES_KEY_256
      .keylen(1'b1),
    `else
      .keylen(1'b0),
    `endif
    .block(aes_block),
    .result(aes_result),
    .result_valid(aes_result_val)
  );

  assign pad = aes_result;

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

  always_comb begin
    next_state = state_r;
    case (state_r)
      STATE_IDLE: begin //Wait for the core to signal ready
        if (aes_rdy) begin
          next_state = STATE_INIT;
        end
      end
      STATE_INIT: begin //Signal core to run key expansion
        next_state = STATE_KEYEXP_WAIT;
      end
      STATE_KEYEXP_WAIT: begin //Wait for key expansion to finish
        if(aes_rdy) begin
          next_state = STATE_REQ_WAIT;
        end
      end
      STATE_REQ_WAIT: begin //register request
        if(req_val) begin
          next_state = STATE_ENC_NEXT;
        end
      end
      STATE_ENC_NEXT: begin //send next signal to core when aes is ready
        if(aes_rdy) begin
          next_state = STATE_RESULT;
        end
      end
      STATE_RESULT: begin //signal output of aes core
        if(aes_result_val && pad_rdy) begin
          next_state = STATE_REQ_WAIT;
        end

      end
    endcase
  end

  //Output
  always_comb begin
    //default
    cs_aes_init = 1'b0;
    cs_aes_next = 1'b0;
    cs_req_rdy = 1'b0;
    cs_req_reg_we = 1'b0;
    cs_pad_val_en = 1'b0;
    case (state_r)
      STATE_IDLE: begin
        //do nothing
        cs_aes_init = 1'b0;
        cs_aes_next = 1'b0;
      end
      STATE_INIT: begin
        //Initialize key expansion
        cs_aes_init = 1'b1;
        cs_aes_next = 1'b0;
      end
      STATE_KEYEXP_WAIT: begin //wait for key expansion to finish
        cs_aes_init = 1'b0;
        cs_aes_next = 1'b0;
      end
      STATE_REQ_WAIT:  begin //Wait for request to be valid
        cs_aes_init = 1'b0;
        cs_aes_next = 1'b0;
        cs_req_rdy = 1'b1;
        cs_req_reg_we = 1'b1;
      end
      STATE_ENC_NEXT: begin //send next signal
        cs_aes_init = 1'b0;
        cs_aes_next = 1'b1;
      end
      STATE_RESULT: begin //wait until response is signaled ready and valid
        cs_aes_init = 1'b0;
        cs_aes_next = 1'b0;
        cs_pad_val_en = 1'b1;
      end
    endcase
  end

  assign pad_val = aes_result_val && cs_pad_val_en;
  assign req_rdy = cs_req_rdy;

endmodule : aes

`default_nettype wire
