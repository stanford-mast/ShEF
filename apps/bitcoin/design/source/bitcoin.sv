//Mark Zhao
//7/24/20
//Basic bitcoin demo

`default_nettype none
`timescale 1ns/1ps
module bitcoin #(
  parameter integer HEADER_WIDTH = 608, //Block header width, without nonce
  parameter integer NONCE_WIDTH = 32
)
(
  input  wire clk,
  input  wire rst_n,
  
  input  wire [HEADER_WIDTH-1:0] block_header,
  input  wire [7:0]              hash_target, //How many zeros in hash
  input  wire                    req_val,
  output wire                    req_rdy,

  output wire [NONCE_WIDTH-1:0]  golden_nonce,
  output wire [255:0]            golden_digest,
  output wire                    golden_nonce_val,
  input  wire                    golden_nonce_rdy
);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam integer ZERO_PAD_LEN = 319;
  
  localparam STATE_IDLE = 4'd0,
             STATE_HASH_HEADER_REQ = 4'd1,
             STATE_HASH_HEADER_WAIT = 4'd2,
             STATE_HASH_NONCE_REQ = 4'd3,
             STATE_HASH_NONCE_WAIT = 4'd4,
             STATE_HASH_DIGEST_REQ = 4'd5,
             STATE_COMPARE = 4'd6,
             STATE_DONE = 4'd7,
             STATE_NONCE_INCR = 4'd8;
  
  

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [3:0] state_r;
  logic [3:0] next_state;

  //Registers
  logic [HEADER_WIDTH-1:0] block_header_r;
  logic [7:0]              hash_target_r;

  //Hash signals
  logic [511:0] hash_core_block;
  logic [255:0] hash_core_digest;
  logic [511:0] nonce_block;
  logic [511:0] digest_block;

  logic [31:0] nonce;
  logic [255:0] digest_r;

  logic [255:0] digest_target;

  //Control
  logic cs_req_rdy;
  logic cs_hash_core_init;
  logic cs_hash_core_next;
  logic [1:0] cs_hash_core_block_mux_sel;
  logic cs_digest_reg_we;
  logic cs_nonce_incr;
  logic cs_golden_nonce_val;

  //Status
  logic hash_core_rdy;
  logic hash_core_digest_val;
  logic target_hit;


  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  //Register inputs
  shield_enreg #(.WIDTH(HEADER_WIDTH)) block_header_reg(
    .clk(clk),
    .q(block_header_r),
    .d(block_header),
    .en(cs_req_rdy)
  );

  shield_enreg #(.WIDTH(8)) hash_target_reg(
    .clk(clk),
    .q(hash_target_r),
    .d(hash_target),
    .en(cs_req_rdy)
  );

  shield_enreg #(.WIDTH(256)) digest_reg(
    .clk(clk),
    .q(digest_r),
    .d(hash_core_digest),
    .en(cs_digest_reg_we)
  );

  //Nonce counter
  shield_counter #(.C_WIDTH(32)) nonce_counter(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy),
    .incr(cs_nonce_incr),
    .decr(1'b0),
    .load_value(32'd0),
    .count(nonce),
    .is_zero()
  );

  //Input to hash core - muxed
  assign nonce_block = {block_header_r[95:0], nonce, 1'b1, {ZERO_PAD_LEN{1'b0}}, 64'd640}; //block is 640 bits long
  assign digest_block = {digest_r, 1'b1, {191{1'b0}}, 64'd256};
  shield_mux4 #(.WIDTH(512)) hash_core_block_mux(
    .in0(block_header_r[HEADER_WIDTH-1 -: 512]),
    .in1(nonce_block),
    .in2(digest_block),
    .in3(512'd0),
    .sel(cs_hash_core_block_mux_sel),
    .out(hash_core_block)
  );


  sha256_core hash_core(
    .clk(clk),
    .reset_n(rst_n),
    .init(cs_hash_core_init),
    .next(cs_hash_core_next),
    .mode(1'b1),

    .block(hash_core_block),

    .ready(hash_core_rdy),
    .digest(hash_core_digest),
    .digest_valid(hash_core_digest_val)
  );

  assign digest_target = {256{1'b1}} >> hash_target_r;
  assign target_hit = hash_core_digest <= digest_target;

  assign golden_digest = hash_core_digest;
  assign golden_nonce = nonce;

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
      STATE_IDLE: begin
        if(req_val && hash_core_rdy) begin
          next_state = STATE_HASH_HEADER_REQ;
        end
      end
      STATE_HASH_HEADER_REQ: begin
        next_state = STATE_HASH_HEADER_WAIT;
      end
      STATE_HASH_HEADER_WAIT: begin
        if(hash_core_rdy) begin
          next_state = STATE_HASH_NONCE_REQ;
        end
      end
      STATE_HASH_NONCE_REQ: begin
        next_state = STATE_HASH_NONCE_WAIT;
      end
      STATE_HASH_NONCE_WAIT: begin
        if(hash_core_digest_val && hash_core_rdy) begin
          next_state = STATE_HASH_DIGEST_REQ;
        end
      end
      STATE_HASH_DIGEST_REQ: begin
        next_state = STATE_COMPARE;
      end
      STATE_COMPARE: begin
        if(hash_core_digest_val && hash_core_rdy) begin
          if(target_hit) begin
            next_state = STATE_DONE;
          end
          else begin
            if(nonce == {32{1'b1}}) begin
              next_state = STATE_DONE; //can't find a match, just send done
            end
            else begin
              next_state = STATE_NONCE_INCR;
            end
          end
        end
      end
      STATE_NONCE_INCR: begin
        next_state = STATE_HASH_HEADER_REQ;
      end
      STATE_DONE: begin
        if(golden_nonce_rdy) begin
          next_state = STATE_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_req_rdy = 1'b0;
    cs_hash_core_init = 1'b0;
    cs_hash_core_next = 1'b0;
    cs_hash_core_block_mux_sel = 2'd0;
    cs_digest_reg_we = 1'b0;
    cs_nonce_incr = 1'b0;
    cs_golden_nonce_val = 1'b0;
    case(state_r)
      STATE_IDLE: begin
        if(hash_core_rdy) begin
          cs_req_rdy = 1'b1;
        end
      end
      STATE_HASH_HEADER_REQ: begin //send init signal
        cs_hash_core_init = 1'b1;
        cs_hash_core_block_mux_sel = 2'd0;
      end
      STATE_HASH_HEADER_WAIT: begin
        cs_hash_core_block_mux_sel = 2'd0;
      end
      STATE_HASH_NONCE_REQ: begin
        cs_hash_core_next = 1'b1;
        cs_hash_core_block_mux_sel = 2'd1;
      end
      STATE_HASH_NONCE_WAIT: begin
        cs_hash_core_block_mux_sel = 2'd1;
        cs_digest_reg_we = 1'b1;
      end
      STATE_HASH_DIGEST_REQ: begin
        cs_hash_core_block_mux_sel = 2'd2;
        cs_hash_core_init = 1'b1;
      end
      //STATE_HASH_COMPARE: do nothing
      STATE_NONCE_INCR: begin
        cs_nonce_incr = 1'b1;
      end
      STATE_DONE: begin
        cs_golden_nonce_val = 1'b1;
      end
    endcase
  end

  assign req_rdy = cs_req_rdy;
  assign golden_nonce_val = cs_golden_nonce_val;

endmodule : bitcoin
`default_nettype wire
