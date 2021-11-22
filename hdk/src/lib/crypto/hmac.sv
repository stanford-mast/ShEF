//Mark Zhao
//7/21/20
//Implements sha-256 hmac
`include "free_common_defines.vh"

`default_nettype none

module hmac #(
  parameter integer DATA_WIDTH = 512,
  parameter integer ADDR_WIDTH = 32,
  parameter integer COUNTER_WIDTH = 32
)
(
  input  wire                       clk,
  input  wire                       rst_n,
  input  wire [DATA_WIDTH-1:0]      req_data,
  input  wire [ADDR_WIDTH-1:0]      req_addr,
  input  wire [COUNTER_WIDTH-1:0]   req_counter,
  input  wire                       req_val,
  output wire                       req_rdy,

  output wire [127:0]               hmac,
  output wire                       hmac_val,
  input  wire                       hmac_rdy
);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_INIT           = 3'd0,
             STATE_REQ            = 3'd1,
             STATE_IPAD_DATA      = 3'd2,
             STATE_IPAD_METADATA  = 3'd3,
             STATE_OPAD           = 3'd4,
             STATE_RESULT         = 3'd5;
  localparam bit [63:0] IPAD_LEN = 512 + DATA_WIDTH + ADDR_WIDTH + COUNTER_WIDTH; //64 bit
  localparam integer ZERO_PAD_LEN = (512 + 448 - ((DATA_WIDTH + ADDR_WIDTH + COUNTER_WIDTH) % 512 + 1)) % 512;
  //(448 - 1 - 512 - DATA_WIDTH - ADDR_WIDTH - COUNTER_WIDTH ) % 512;
  
  //(512 + 448 - (l mod 512 + 1)) mod 512
  //localparam integer ZERO_PAD_LEN = 384; //TODO: Change me if input len changes
  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [2:0] state_r;
  logic [2:0] next_state;

  //Register input
  logic [DATA_WIDTH-1:0]    req_data_r;
  logic [ADDR_WIDTH-1:0]    req_addr_r;
  logic [COUNTER_WIDTH-1:0] req_counter_r;

  //Control signals
  logic cs_req_rdy;
  logic cs_req_reg_we;
  logic cs_ipad_core_init;
  logic cs_ipad_core_next;
  logic cs_opad_core_init;
  logic cs_opad_core_next_en;
  logic [1:0] cs_ipad_core_block_mux_sel;
  logic cs_opad_core_block_mux_sel;
  logic cs_hmac_val_en;

  //STatus signals
  logic ipad_core_rdy;
  logic opad_core_rdy;
  logic [255:0] ipad_core_digest;
  logic [255:0] opad_core_digest;
  logic ipad_core_digest_val;
  logic opad_core_digest_val;

  //HMAC
  logic [127:0] hmac_key;
  logic [511:0] i_key_pad;
  logic [511:0] o_key_pad;

  logic [511:0] ipad_core_block;
  logic [511:0] opad_core_block;

  logic [511:0] metadata_block;

  logic [511:0] opad_block;

  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  assign hmac_key = `HMAC_KEY;

  //expand hmac key to pad
	assign i_key_pad = {hmac_key, {384{1'b0}}} ^ {64{8'h36}}; 
	assign o_key_pad = {hmac_key, {384{1'b0}}} ^ {64{8'h5c}};


  //register request
  shield_enreg #(.WIDTH(DATA_WIDTH)) req_data_reg(
    .clk(clk),
    .q(req_data_r),
    .d(req_data),
    .en(cs_req_reg_we)
  );
  shield_enreg #(.WIDTH(ADDR_WIDTH)) req_addr_reg(
    .clk(clk),
    .q(req_addr_r),
    .d(req_addr),
    .en(cs_req_reg_we)
  );
  shield_enreg #(.WIDTH(COUNTER_WIDTH)) req_counter_reg(
    .clk(clk),
    .q(req_counter_r),
    .d(req_counter),
    .en(cs_req_reg_we)
  );

  //Generate metadata block
  assign metadata_block = {req_addr_r, req_counter_r, 1'b1, {ZERO_PAD_LEN{1'b0}}, IPAD_LEN};
  assign opad_block = {ipad_core_digest, 1'b1, {191{1'b0}}, 64'd768};

  //Mux for sha inputs
  shield_mux4 #(.WIDTH(512)) ipad_core_block_mux(
    .in0(i_key_pad),
    .in1(req_data_r),
    .in2(metadata_block),
    .in3(),
    .sel(cs_ipad_core_block_mux_sel),
    .out(ipad_core_block)
  );

  shield_mux2 #(.WIDTH(512)) opad_core_block_mux(
    .in0(o_key_pad),
    .in1(opad_block),
    .sel(cs_opad_core_block_mux_sel),
    .out(opad_core_block)
  );


  //instantiate SHA cores, one for each hash
  sha256_core ipad_sha_core(
    .clk(clk),
    .reset_n(rst_n),
    .init(cs_ipad_core_init),
    .next(cs_ipad_core_next),
    .mode(1'b1),

    .block(ipad_core_block),

    .ready(ipad_core_rdy),
    .digest(ipad_core_digest),
    .digest_valid(ipad_core_digest_val)
  );
  sha256_core opad_sha_core(
    .clk(clk),
    .reset_n(rst_n),
    .init(cs_opad_core_init),
    .next(cs_opad_core_next_en && ipad_core_digest_val),
    .mode(1'b1),

    .block(opad_core_block),

    .ready(opad_core_rdy),
    .digest(opad_core_digest),
    .digest_valid(opad_core_digest_val)
  );

  assign hmac = opad_core_digest[255:128];
  assign hmac_val = opad_core_digest_val && cs_hmac_val_en;


  //////////////////////////////////////////////////////////////////////////////
  // Control logic
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r <= STATE_INIT;
    end
    else begin
      state_r <= next_state;
    end
  end

  always_comb begin
    next_state = state_r;
    case (state_r)
      STATE_INIT: begin //init ipad and opad
        if(ipad_core_rdy && opad_core_rdy) begin
          next_state = STATE_REQ;
        end
      end
      STATE_REQ: begin
        if(req_val) begin
          next_state = STATE_IPAD_DATA;
        end
      end
      STATE_IPAD_DATA: begin //Load data
        if(ipad_core_rdy) begin
          next_state = STATE_IPAD_METADATA;
        end
      end
      STATE_IPAD_METADATA: begin //load addr+ctr
        if(ipad_core_rdy) begin
          next_state = STATE_OPAD;
        end
      end
      STATE_OPAD: begin
        if(ipad_core_digest_val && opad_core_rdy) begin //if ipad output is valid, and opad is ready
          next_state = STATE_RESULT;
        end
      end
      STATE_RESULT: begin
        if(opad_core_digest_val && hmac_rdy) begin
          next_state = STATE_INIT;
        end
      end
    endcase
  end

  //Output
  always_comb begin
    cs_req_rdy = 1'b0;
    cs_req_reg_we = 1'b0;
    cs_ipad_core_init = 1'b0;
    cs_ipad_core_next = 1'b0;
    cs_opad_core_init = 1'b0;
    cs_opad_core_next_en = 1'b0;
    cs_ipad_core_block_mux_sel = 2'b00;
    cs_opad_core_block_mux_sel = 1'b0;
    cs_hmac_val_en = 1'b0;
    case (state_r)
      STATE_INIT: begin
        cs_ipad_core_init = 1'b1;
        cs_opad_core_init = 1'b1;
        cs_ipad_core_block_mux_sel = 2'b00; //ipad
        cs_opad_core_block_mux_sel = 1'b0; //opad
      end
      STATE_REQ: begin
        cs_req_rdy = 1'b1;
        cs_req_reg_we = 1'b1;
        cs_ipad_core_block_mux_sel = 2'b00; //ipad
        cs_opad_core_block_mux_sel = 1'b0; //opad
      end
      STATE_IPAD_DATA: begin
        cs_ipad_core_next = 1'b1;
        cs_ipad_core_block_mux_sel = 2'b01; //data
        cs_opad_core_block_mux_sel = 1'b0; //opad
      end
      STATE_IPAD_METADATA: begin
        cs_ipad_core_next = 1'b1;
        cs_ipad_core_block_mux_sel = 2'b10; //metadata
        cs_opad_core_block_mux_sel = 1'b0; //opad
      end
      STATE_OPAD: begin
        cs_ipad_core_block_mux_sel = 2'b10; //metadata
        cs_opad_core_block_mux_sel = 1'b1; //output from ipad
        cs_opad_core_next_en = 1'b1; //allow the opad core to be signalled
      end
      STATE_RESULT: begin
        cs_ipad_core_block_mux_sel = 2'b10; //metadata
        cs_opad_core_block_mux_sel = 1'b1; //output from ipad
        cs_hmac_val_en = 1'b1;
      end
    endcase
  end
  
  assign req_rdy = cs_req_rdy;

endmodule : hmac

`default_nettype wire
