// Mark Zhao
// Wrapper module that enables parallel AES cores

// Always exposes a 512 bit interface, but parallelizes generating 
// pad
//

`include "free_common_defines.vh"

`default_nettype none

module aes_parallel (
  input wire clk,
  input wire rst_n,

  // control
  input wire [95:0] nonce,
  input wire [31:0] counter,
  input wire        req_val,
  output wire       req_rdy,

  // output
  output wire [511:0] pad,
  output wire         pad_val,
  input  wire         pad_rdy
);

  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE = 3'd0,
             STATE_COMPUTE = 3'd1,
             STATE_NEXT_PAD = 3'd2;

  // per-aes parallelism total pad length
  `ifdef NUM_AES_PARALLEL_4
    localparam integer TOTAL_PAD_LENGTH = 4 * 128;
    localparam integer NUM_AES = 4;
  `elsif NUM_AES_PARALLEL_8
    localparam integer TOTAL_PAD_LENGTH = 8 * 128;
    localparam integer NUM_AES = 8;
  `elsif NUM_AES_PARALLEL_16
    localparam integer TOTAL_PAD_LENGTH = 16 * 128;
    localparam integer NUM_AES = 16;
  `endif

  localparam integer TOTAL_PAD_LENGTH_BYTES = TOTAL_PAD_LENGTH / 8;


  // Number of 512-bit bursts in the total pad
  // NOTE: num_aes cannot be less than 4
  localparam integer NUM_PAD_BURSTS = TOTAL_PAD_LENGTH / 512;


  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [2:0] state_r;
  logic [2:0] next_state;

  `ifdef NUM_AES_PARALLEL_4
    logic [3:0] aes_req_rdy;
    logic [3:0] aes_resp_val;
  `elsif NUM_AES_PARALLEL_8
    logic [7:0] aes_req_rdy;
    logic [7:0] aes_resp_val;
  `elsif NUM_AES_PARALLEL_16
    logic [15:0] aes_req_rdy;
    logic [15:0] aes_resp_val;
  `endif
  
  logic [TOTAL_PAD_LENGTH-1:0] aes_pad;
  // Maximum of 64 (4096 / 64) shifts
  logic [6:0] pad_index_count;
  logic pad_burst_last;

  logic pad_txfer;

  logic aes_req_rdy_all;
  logic aes_resp_val_all;

  logic cs_req_rdy;
  logic cs_pad_val;
  logic cs_aes_req_val;
  logic cs_aes_resp_rdy;

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
      STATE_IDLE: begin // wait for request / aes to be valid
        if (aes_req_rdy_all && req_val) begin
          next_state = STATE_COMPUTE;
        end
      end
      STATE_COMPUTE: begin // Compute the required pad
        if (pad_txfer) begin
          if (pad_burst_last) begin
            next_state = STATE_IDLE;
          end
          else begin
            next_state = STATE_NEXT_PAD;
          end
        end
      end
      STATE_NEXT_PAD: begin // If there are unused pad bits
        if (req_val) begin
          next_state = STATE_COMPUTE;
        end
      end
    endcase
  end

  always_comb begin
    cs_req_rdy = 1'b0;
    cs_pad_val = 1'b0;
    cs_aes_req_val = 1'b0;
    cs_aes_resp_rdy = 1'b0;
    case (state_r)
      STATE_IDLE: begin
        if (aes_req_rdy_all) begin
          cs_req_rdy = 1'b1; // signal ready for req
          if (req_val) begin
            cs_aes_req_val = 1'b1;
          end
        end
      end
      STATE_COMPUTE: begin
        if(aes_resp_val_all) begin
          cs_pad_val = 1'b1;

          if(pad_burst_last && pad_txfer) begin
            cs_aes_resp_rdy = 1'b1;
          end
        end
      end
      STATE_NEXT_PAD: begin
        cs_req_rdy = 1'b1;
      end
    endcase
  end

  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////
  genvar i;
  generate
    for(i = 0; i < NUM_AES; i++) begin
      aes #(.DATA_WIDTH(128)) aes_inst(
        .clk(clk),
        .rst_n(rst_n),
        .nonce(nonce), //TODO: Set to IV plus chunk count
        .counter(32'd0), //TODO: 32 bit block counter for this chunk
        .req_val(cs_aes_req_val),
        .req_rdy(aes_req_rdy[i]),
        .pad(aes_pad[i*128 +: 128]),
        .pad_val(aes_resp_val[i]),
        .pad_rdy(cs_aes_resp_rdy)
      );
    end
  endgenerate

  `ifdef NUM_AES_PARALLEL_4
    // mux to select pad
    assign pad = aes_pad;
  `elsif NUM_AES_PARALLEL_8
    shield_muxp #(
      .BUS_WIDTH(TOTAL_PAD_LENGTH),
      .OUTPUT_WIDTH(512),
      .SELECT_WIDTH(1),
      .SELECT_COUNT(2)
    ) pad_mux (
      .in_bus(aes_pad),
      .sel(pad_index_count[0]),
      .out(pad)
    );
  `elsif NUM_AES_PARALLEL_16
    shield_muxp #(
      .BUS_WIDTH(TOTAL_PAD_LENGTH),
      .OUTPUT_WIDTH(512),
      .SELECT_WIDTH(2),
      .SELECT_COUNT(4)
    ) pad_mux (
      .in_bus(aes_pad),
      .sel(pad_index_count[1:0]),
      .out(pad)
    );
  `endif


   // Counter to count pad offsets
   shield_counter #(
     .C_WIDTH(7)
   ) pad_index_counter (
     .clk(clk),
     .clken(1'b1),
     .rst(~rst_n),
     .load(cs_aes_req_val),
     .incr(pad_txfer),
     .decr(1'b0),
     .load_value(0),
     .count(pad_index_count),
     .is_zero()
   );

  // Assign done signal based on number of bursts per pad
  assign pad_burst_last = (pad_index_count == (NUM_PAD_BURSTS - 1)) ? 1'b1 : 1'b0;

  assign aes_req_rdy_all = &aes_req_rdy;
  assign aes_resp_val_all = &aes_resp_val;

  assign req_rdy = cs_req_rdy;
  assign pad_val = cs_pad_val;

  assign pad_txfer = (cs_pad_val && pad_rdy) ? 1'b1 : 1'b0;

endmodule : aes_parallel
`default_nettype wire
