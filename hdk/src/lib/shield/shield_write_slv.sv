//Mark Zhao
//7/14/20
//This module takes in the write data channel from the CL and generates
//a cache line output
`default_nettype none
`timescale 1ns/1ps
module shield_write_slv #(
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64,
  parameter integer LINE_WIDTH = 512,
  parameter integer OFFSET_WIDTH = 6,
  parameter integer BURSTS_PER_LINE = 8,
  parameter integer BURSTS_PER_LINE_LOG = 3
)
(
  input  wire                         clk,
  input  wire                         rst_n,

  //Input request from CL
  input  wire [CL_ID_WIDTH-1:0]       s_axi_wid,
  input  wire [CL_DATA_WIDTH-1:0]     s_axi_wdata,
  input  wire [CL_DATA_WIDTH/8-1:0]   s_axi_wstrb, //IGNORED FOR NOW
  input  wire                         s_axi_wlast,
  input  wire                         s_axi_wvalid,
  output wire                         s_axi_wready,

  output wire                         busy,

  //Control signals
  input  wire [7:0]                   burst_count,  //How many bursts to send from this line
  input  wire [OFFSET_WIDTH-1:0]      burst_start_offset, //At which byte to start the burst
  input  wire                         req_val,
  output wire                         req_rdy,
  
  //Output to datapath
  output wire [LINE_WIDTH-1:0]        cache_line,
  output wire [BURSTS_PER_LINE-1:0]   cache_line_burst_en,
  output wire                         cache_line_val,
  input  wire                         cache_line_rdy
);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE = 2'd0,
             STATE_READ = 2'd1,
             STATE_WRITE = 2'd2;

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [LINE_WIDTH-1:0]      cache_line_r;
  logic [BURSTS_PER_LINE-1:0] cache_line_burst_en_r;

  logic [1:0] state_r;
  logic [1:0] next_state;

  logic [BURSTS_PER_LINE_LOG-1:0] burst_start_index;
  logic [BURSTS_PER_LINE_LOG-1:0] burst_index_r;
  logic [7:0] burst_count_remaining_r;
  logic burst_done;

  logic [BURSTS_PER_LINE-1:0] burst_index_onehot;

  logic cache_line_rxfer;

  //Control signals
  logic cs_wready; //enable writes
  logic cs_cache_line_val;
  logic cs_req_rdy;

  logic load;




  //////////////////////////////////////////////////////////////////////////////
  // datapath
  //////////////////////////////////////////////////////////////////////////////
  assign burst_start_index = burst_start_offset[OFFSET_WIDTH-1 -: BURSTS_PER_LINE_LOG]; //take the top bits of the addr

  assign cache_line_rxfer = (cs_wready && s_axi_wvalid);

  assign load = req_val && req_rdy;

  //Counter for select signal
  shield_counter #(
    .C_WIDTH(BURSTS_PER_LINE_LOG)
  ) burst_index_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(load),
    .incr(cache_line_rxfer),
    .decr(1'b0),
    .load_value(burst_start_index),
    .count(burst_index_r),
    .is_zero()
  );
  //counter for remaining bursts
  shield_counter #(
    .C_WIDTH(8)
  ) burst_count_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(load),
    .incr(1'b0),
    .decr(cache_line_rxfer),
    .load_value(burst_count),
    .count(burst_count_remaining_r),
    .is_zero(burst_done)
  );

  //Generate a one-hot signal from the burst index
  assign burst_index_onehot = 1 << burst_index_r;

  //Write to cache line register
  genvar i;
  generate
    for( i = 0; i < BURSTS_PER_LINE; i++ ) begin
      always_ff @(posedge clk) begin
        if(load) begin
          cache_line_r[i*CL_DATA_WIDTH +: CL_DATA_WIDTH] <= {CL_DATA_WIDTH{1'b0}};
          cache_line_burst_en_r[i] <= 0;
        end
        else begin
          if(cache_line_rxfer && burst_index_onehot[i]) begin
            cache_line_r[i*CL_DATA_WIDTH +: CL_DATA_WIDTH] <= s_axi_wdata;
            cache_line_burst_en_r[i] <= 1'b1;
          end
        end
      end
    end
  endgenerate

  assign cache_line = cache_line_r;
  assign cache_line_burst_en = cache_line_burst_en_r;


  //////////////////////////////////////////////////////////////////////////////
  // Control Logic
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
      STATE_IDLE: begin //Wait for load signal
        if(load) begin
          next_state = STATE_READ;
        end
      end
      STATE_READ: begin //Read the written data
        if(burst_count_remaining_r <= 8'd1 && cache_line_rxfer) begin
          next_state = STATE_WRITE;
        end
      end
      STATE_WRITE: begin //transmit the data to datapath
        if(cache_line_rdy) begin
          next_state = STATE_IDLE;
        end
      end
    endcase
  end

  //Output
  always_comb begin
    //default
    cs_wready = 1'b0;
    cs_cache_line_val = 1'b0;
    cs_req_rdy = 1'b0;
    case (state_r)
      STATE_IDLE: begin
        cs_wready = 1'b0;
        cs_req_rdy = 1'b1;
      end
      STATE_READ: begin
        cs_wready = 1'b1; //signal ready to read
      end
      STATE_WRITE: begin
        cs_cache_line_val = 1'b1;
      end
    endcase
  end

  assign s_axi_wready = cs_wready;
  assign cache_line_val = cs_cache_line_val;
  assign req_rdy = cs_req_rdy;

  assign busy = (state_r != STATE_IDLE);


endmodule : shield_write_slv
`default_nettype none
