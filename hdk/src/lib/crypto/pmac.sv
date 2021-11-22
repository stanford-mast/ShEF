//Mark Zhao
//8/6/20
//Wrapper for pmac
//
`include "free_common_defines.vh"

`default_nettype none

module pmac #(
  parameter integer DATA_WIDTH = 512, //Needs to be equal to num_aes * 128
  parameter integer PRE_COMP_BLOCKS = 8 //should be clog2 of the max. number of 16-byte blocks we expect
)
(
  input  wire                       clk,
  input  wire                       rst_n,

  input  wire                       req_val, //basically init signal
  input  wire [15:0]                req_len, //length of request
  output wire                       req_rdy, //basically ready signal

  //FIFO Interface to data
  input  wire [DATA_WIDTH-1:0]      stream_data,
  input  wire                       stream_data_val,
  output wire                       stream_data_rdy,

  output wire [127:0]               pmac,
  output wire                       pmac_val,
  input  wire                       pmac_rdy

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_INIT         = 4'd0,
             STATE_KEYEXP       = 4'd1,
             STATE_L0           = 4'd2,
             STATE_PRECOMP      = 4'd3,
             STATE_REQ          = 4'd4,
             STATE_CALC_NTZ     = 4'd5,
             STATE_DATA_REQ     = 4'd6,
             STATE_ACCUM        = 4'd7,
             STATE_RESULT       = 4'd8,
             STATE_DATA_ENC     = 4'd9,
             STATE_FINAL        = 4'd10;

  //Precompute as many L values as we're ever  going to see.
  //This is equal to the largest number of trailing zeros we expect
  //localparam integer PRE_COMP_BLOCKS = $clog2(BURST_SIZE_BLOCKS);
  localparam integer NTZ_WIDTH = $clog2(PRE_COMP_BLOCKS);

  localparam integer BURST_SIZE_BLOCKS = DATA_WIDTH / 128; //How many AES blocks per burst

  localparam integer NUM_AES = DATA_WIDTH / 128;

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [3:0] state_r;
  logic [3:0] next_state;

  logic [127:0] l0_r;
  logic [127:0] lprev_r;
  logic [127:0] lprev_muxed;
  logic [127:0] lcurr;
  logic [127:0] linv;

  logic [255:0] pmac_key;


  logic [NUM_AES-1:0]   cs_aes_init;
  logic [NUM_AES-1:0]   cs_aes_next;
  logic [1:0]           cs_aes0_block_mux_sel;
  logic                 cs_l0_reg_we;
  logic                 cs_lcurr_we;
  logic                 cs_req_rdy;
  logic                 cs_block_ctr_inc;
  logic                 cs_stream_data_rdy;
  logic                 cs_message_burst_rxfer;
  logic                 cs_accum_we;
  logic                 cs_pmac_val;
  logic                 cs_last_aes0_reg_we;


  logic                 lprev_mux_sel;


  logic [NUM_AES-1:0]   aes_rdy;
  logic [127:0]         aes_block [NUM_AES-1:0];
  logic [127:0]         aes_result [NUM_AES-1:0];
  logic [NUM_AES-1:0]   aes_result_val;
  logic [NTZ_WIDTH-1:0] precomp_block_idx;

  logic                 message_burst_done;
  logic [15:0]          block_idx_base;
  logic [15:0]          block_idx [NUM_AES-1:0];

  logic [3:0]           ntz [NUM_AES-1:0];
  logic [NTZ_WIDTH-1:0] lram_raddr [NUM_AES-1:0];          
  logic [127:0]         lntz [NUM_AES-1:0];
  logic [127:0]         lram_rdata [NUM_AES-1:0];
  logic [127:0]         offset [NUM_AES-1:0];
  logic [127:0]         sum [NUM_AES-1:0];

  logic [127:0]         offset_accum;
  logic [127:0]         sum_accum;


  logic [127:0]         last_aes0_r;
  logic [127:0]         last_aes0;
  
  logic [DATA_WIDTH-1:0] stream_data_r;




  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  assign pmac_key = `PMAC_KEY;

  genvar i;
  generate
    for(i = 0; i < NUM_AES; i++) begin
      aes_core aes_core_inst(
        .clk(clk),
        .reset_n(rst_n),
        .encdec(1'b1), //always encrypt
        .init(cs_aes_init[i]),
        .next(cs_aes_next[i]),
        .ready(aes_rdy[i]),
        .key(pmac_key),
        `ifdef PMAC_KEY_256
          .keylen(1'b1),
        `else
          .keylen(1'b0),
        `endif
        .block(aes_block[i]),
        .result(aes_result[i]),
        .result_valid(aes_result_val[i])
      );

      assign block_idx[i] = block_idx_base + i;

      pmac_ntz pmac_ntz_inst(
        .index(block_idx[i]),
        .ntz(ntz[i])
      );
      
      assign lram_raddr[i] = ntz[i] - 1;

      //RAM to store L(ntz(i)) values
      shield_ram #(.DATA_WIDTH(128), .ADDR_WIDTH(NTZ_WIDTH)) l_ram_inst(
        .clk(clk),
        .wr_addr(precomp_block_idx),
        .wr_en(cs_lcurr_we),
        .wr_data(lcurr),
        .rd_addr(lram_raddr[i]),
        .rd_data(lram_rdata[i])
      );
      
      assign lntz[i] = (ntz[i] == 0) ? l0_r : lram_rdata[i];
    end
  endgenerate

  //Assign block0 and offset0
  assign offset[0] = offset_accum ^ lntz[0];
  shield_mux4 #(.WIDTH(128)) aes0_block_mux(
    .in0(offset[0] ^ stream_data_r[(DATA_WIDTH-1)-:128]),
    .in1(128'd0),
    .in2(last_aes0_r),
    .in3(),
    .sel(cs_aes0_block_mux_sel),
    .out(aes_block[0])
  );
  assign sum[0] = sum_accum ^ aes_result[0];

  //Assign remaining aes modules
  genvar j;
  generate
    for(j = 1; j < NUM_AES; j++) begin
      assign offset[j] = offset[j-1] ^ lntz[j];
      assign aes_block[j] = offset[j] ^ stream_data_r[(DATA_WIDTH-1) - j*128 -: 128];
      assign sum[j] = sum[j-1] ^ aes_result[j];
    end
  endgenerate

  //Register for L(0)
  shield_enreg #(.WIDTH(128)) l0_reg(
    .clk(clk),
    .q(l0_r),
    .d(aes_result[0]),
    .en(cs_l0_reg_we)
  );

  //Register for L(i-1)
  shield_enreg #(.WIDTH(128)) lprev_reg(
    .clk(clk),
    .q(lprev_r),
    .d(lcurr),
    .en(cs_lcurr_we)
  );

  //Mux for lprev to select between l0 and l(i-1)
  shield_mux2 #(.WIDTH(128)) lprev_mux(
    .in0(l0_r),
    .in1(lprev_r),
    .sel(lprev_mux_sel),
    .out(lprev_muxed)
  );

  assign lprev_mux_sel = (precomp_block_idx == {NTZ_WIDTH{1'b0}}) ? 1'b0 : 1'b1;

  assign lcurr = lprev_muxed[127] ?
                 ((lprev_muxed << 1) ^ 128'h00000000000000000000000000000087) :
                 (lprev_muxed << 1);

  assign linv = l0_r[0] ? 
                ((l0_r >> 1) ^ 128'h80000000000000000000000000000043) :
                (l0_r >> 1);



  shield_counter #(.C_WIDTH(NTZ_WIDTH)) precomp_block_ctr(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_l0_reg_we), //Load when there's a new L0
    .incr(cs_lcurr_we),
    .decr(1'b0),
    .load_value({NTZ_WIDTH{1'b0}}),
    .count(precomp_block_idx),
    .is_zero()
  );

  //Register request length in bursts
  shield_counter #(.C_WIDTH(16)) message_burst_ctr(
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_req_rdy),
    .incr(1'b0),
    .decr(cs_message_burst_rxfer),
    .load_value(req_len),
    .count(),
    .is_zero(message_burst_done)
  );

  //Counter for which block we're at (i)
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      block_idx_base <= 16'd1;
    end
    else begin
      if(cs_req_rdy) begin
        block_idx_base <= 16'd1;
      end
      else if(cs_block_ctr_inc) begin
        block_idx_base <= block_idx_base + NUM_AES;
      end
    end
  end

  //Registers for accumulated offset/sum
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      offset_accum <= 128'd0;
      sum_accum <= 128'd0;
    end
    else begin
      if(cs_req_rdy) begin
        offset_accum <= 128'd0;
        sum_accum <= 128'd0;
      end
      else if(cs_accum_we) begin
        offset_accum <= offset[NUM_AES-1];
        sum_accum <= sum[NUM_AES-1];
      end
    end
  end

  //Register for the last block in the message
//  shield_enreg #(.WIDTH(128)) last_block_reg(
//    .clk(clk),
//    .q(last_block_r),
//    .d(stream_data[127:0]),
//    .en(cs_message_burst_rxfer)
//  );
  
  shield_enreg #(.WIDTH(DATA_WIDTH)) req_data_reg(
    .clk(clk),
    .q(stream_data_r),
    .d(stream_data),
    .en(cs_message_burst_rxfer)
  );
  
  shield_enreg #(.WIDTH(128)) last_aes0_reg(
    .clk(clk),
    .q(last_aes0_r),
    .d(last_aes0),
    .en(cs_last_aes0_reg_we)
  );


  //Last block
  assign last_aes0 = sum[NUM_AES - 2] ^ stream_data_r[127:0] ^ linv;

  assign pmac = aes_result[0];
  
  //////////////////////////////////////////////////////////////////////////////
  // Control
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
      STATE_INIT: begin //Wait for AES to be ready
        if (&aes_rdy) begin //Trigger keyexp
          next_state = STATE_KEYEXP;
        end
      end
      STATE_KEYEXP: begin //wait for key expansion to finish
        if (&aes_rdy) begin
          next_state = STATE_L0;
        end
      end
      STATE_L0: begin
        if(aes_result_val[0]) begin
          next_state = STATE_PRECOMP;
        end
      end
      STATE_PRECOMP: begin //Precompute L values until we've reached pre_comp_blocks
        if (precomp_block_idx == (PRE_COMP_BLOCKS - 1)) begin //indexed by 0
          next_state = STATE_REQ;
        end
      end
      STATE_REQ: begin
        if(req_val) begin
          next_state = STATE_CALC_NTZ;
        end
      end
      STATE_CALC_NTZ: begin //one cycle buffer to read from RAM using ntz as index
        next_state = STATE_DATA_REQ;
      end
      STATE_DATA_REQ: begin
        if(stream_data_val) begin
          next_state = STATE_DATA_ENC;
        end
      end
      STATE_DATA_ENC: begin
        if(&aes_rdy) begin
          next_state = STATE_ACCUM;
        end
      end
      STATE_ACCUM: begin
        if(&aes_result_val) begin
          if(message_burst_done) begin
            next_state = STATE_FINAL;
          end
          else begin
            next_state = STATE_CALC_NTZ;
          end
        end
      end
      STATE_FINAL: begin
        if(aes_rdy[0]) begin
          next_state = STATE_RESULT;
        end
      end
      STATE_RESULT: begin
        if(aes_result_val[0] && pmac_rdy) begin
          next_state = STATE_REQ;
        end
      end
    endcase
  end

  always_comb begin
    cs_aes_init = {NUM_AES{1'b0}};
    cs_aes_next = {NUM_AES{1'b0}};
    cs_aes0_block_mux_sel = 2'b00; //Use aes0 for non-data compute
    cs_l0_reg_we = 1'b0; 
    cs_lcurr_we = 1'b0;
    cs_req_rdy = 1'b0;
    cs_block_ctr_inc = 1'b0;
    cs_message_burst_rxfer = 1'b0;
    cs_accum_we = 1'b0;
    cs_pmac_val = 1'b0;
    cs_stream_data_rdy = 1'b0;
    cs_last_aes0_reg_we = 1'b0;
    case (state_r)
      STATE_INIT: begin
        if (&aes_rdy) begin //trigger key exp
          cs_aes_init = {NUM_AES{1'b1}};
        end
      end
      STATE_KEYEXP: begin
        cs_aes0_block_mux_sel = 2'd1; //input 0
        if (&aes_rdy) begin
          cs_aes_next = {{(NUM_AES-1){1'b0}}, 1'b1}; //compute AES(K, ZERO)
        end
      end
      STATE_L0: begin //Wait for AES(K, ZERO) and register it
        cs_aes0_block_mux_sel = 2'd1; //input 0
        cs_l0_reg_we = 1'b1;
      end
      STATE_PRECOMP: begin
        cs_lcurr_we = 1'b1;
      end
      STATE_REQ: begin //signal ready for request
        cs_req_rdy = 1'b1;
      end
      //STATE_CALC_NTZ //do nothing
      STATE_DATA_REQ: begin //read input bursts
        cs_stream_data_rdy = 1'b1;
        if(stream_data_val) begin
          cs_message_burst_rxfer = 1'b1;
        end
      end
      STATE_DATA_ENC: begin
        if(&aes_rdy) begin
          cs_aes_next = {NUM_AES{1'b1}};
        end
      end
      STATE_ACCUM: begin //accumulate loop values
        if(&aes_result_val) begin
          if(message_burst_done) begin
            cs_last_aes0_reg_we = 1'b1;
          end
          else begin
            cs_block_ctr_inc = 1'b1;
            cs_accum_we = 1'b1;
          end
        end
      end
      STATE_FINAL: begin
        cs_aes0_block_mux_sel = 2'd2; //select final aes block
        if(aes_rdy[0]) begin
          cs_aes_next = {{(NUM_AES-1){1'b0}}, 1'b1}; //compute tag
        end
      end
      STATE_RESULT: begin
        cs_aes0_block_mux_sel = 2'd2; //select final aes block
        if(aes_result_val[0]) begin
          cs_pmac_val = 1'b1;
        end
      end
    endcase
  end

  assign req_rdy = cs_req_rdy;
  assign stream_data_rdy = cs_stream_data_rdy;
  assign pmac_val = cs_pmac_val;


endmodule : pmac
`default_nettype wire
