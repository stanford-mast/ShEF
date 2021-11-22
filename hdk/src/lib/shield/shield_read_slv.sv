//Mark Zhao
//7/14/20
//This module takes in a cache line, and replies to the read master with data

`default_nettype none
`timescale 1ns/1ps
module shield_read_slv #(
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64,
  parameter integer LINE_WIDTH = 512,
  parameter integer OFFSET_WIDTH = 6,
  parameter integer BURSTS_PER_LINE = 8,
  parameter integer BURSTS_PER_LINE_LOG = 3
)
(
  input  wire clk,
  input  wire rst_n,
  //Input request from datapath
  input  wire [LINE_WIDTH-1:0]   cache_line, //Data 
  input  wire [7:0]              burst_count,  //How many bursts to send from this line
  input  wire [OFFSET_WIDTH-1:0] burst_start_offset, //At which byte to start the burst
  input  wire                    burst_last, //set when this is the last burst in the request
  input  wire                    input_val,
  output wire                    input_rdy,

  output wire                    busy,


  //Output to CL
  output wire [CL_ID_WIDTH-1:0]            s_axi_rid, //SET TO 0
  output wire [CL_DATA_WIDTH-1:0]          s_axi_rdata,
  output wire [1:0]                        s_axi_rresp, //ALWAYS SUCCESS
  output wire                              s_axi_rlast, 
  output wire                              s_axi_rvalid,
  input  wire                              s_axi_rready

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam INPUT_STATE_IDLE = 2'd0,
             INPUT_STATE_READ = 2'd1;

  localparam integer CL_DATA_WIDTH_BYTES = CL_DATA_WIDTH / 8;
  localparam integer FIFO_BUFFER_DEPTH = 1024 / CL_DATA_WIDTH_BYTES;
  localparam integer FIFO_BUFFER_DEPTH_LOG = $clog2(FIFO_BUFFER_DEPTH);
  localparam integer FIFO_WIDTH = CL_DATA_WIDTH+1;

  //////////////////////////////////////////////////////////////////////////////
  // Internal variables
  //////////////////////////////////////////////////////////////////////////////
  logic [LINE_WIDTH-1:0] cache_line_r;
  logic [CL_DATA_WIDTH-1:0] cache_line_mux_out;

  logic [BURSTS_PER_LINE_LOG-1:0] burst_index_r;
  logic [BURSTS_PER_LINE_LOG-1:0] burst_start_index;
  logic [7:0] burst_count_remaining_r;
  logic burst_done;
  logic burst_last_r;

  logic [1:0] input_state_r;
  logic [1:0] next_input_state;

  //FIFO signals
  logic [FIFO_WIDTH-1:0] fifo_din;
  logic [FIFO_WIDTH-1:0] fifo_dout;
  logic fifo_full;
  logic fifo_empty;
  logic fifo_rd_en;

  logic rlast_in;
  
  logic [31:0] outstanding_count_r;
  logic [31:0] finalized_count_r;
  logic incr_outstanding;
  logic incr_finalized;
  
  //Control
  logic cs_input_rdy;
  logic cs_fifo_wr_en;
  
  //////////////////////////////////////////////////////////////////////////////
  // Datapath
  //////////////////////////////////////////////////////////////////////////////

  shield_enreg #(.WIDTH(LINE_WIDTH)) line_reg (
    .clk(clk),
    .q(cache_line_r),
    .d(cache_line),
    .en(cs_input_rdy)
  );

  shield_enreg #(.WIDTH(1)) last_reg (
    .clk(clk),
    .q(burst_last_r),
    .d(burst_last),
    .en(cs_input_rdy)
  );

  assign burst_start_index = burst_start_offset[OFFSET_WIDTH-1 -: BURSTS_PER_LINE_LOG]; //take the top bits of the addr

  //Counter for select signal
  shield_counter #(
    .C_WIDTH(BURSTS_PER_LINE_LOG)
  ) burst_index_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(cs_input_rdy),
    .incr(cs_fifo_wr_en),
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
    .load(cs_input_rdy),
    .incr(1'b0),
    .decr(cs_fifo_wr_en),
    .load_value(burst_count),
    .count(burst_count_remaining_r),
    .is_zero(burst_done)
  );

  //Connect cache line to fifo
  shield_muxp #(
    .BUS_WIDTH(LINE_WIDTH),
    .OUTPUT_WIDTH(CL_DATA_WIDTH),
    .SELECT_WIDTH(BURSTS_PER_LINE_LOG),
    .SELECT_COUNT(BURSTS_PER_LINE)
  ) cache_line_mux (
    .in_bus(cache_line_r),
    .sel(burst_index_r),
    .out(cache_line_mux_out)
  );

  assign rlast_in = burst_last_r && (burst_count_remaining_r == 8'd1);
  assign fifo_din = {cache_line_mux_out, rlast_in};


	xpm_fifo_sync # (
	  .FIFO_MEMORY_TYPE          ("auto"),           //string; "auto", "block", "distributed", or "ultra";
	  .ECC_MODE                  ("no_ecc"),         //string; "no_ecc" or "en_ecc";
	  .FIFO_WRITE_DEPTH          (FIFO_BUFFER_DEPTH),   //positive integer
	  .WRITE_DATA_WIDTH          (FIFO_WIDTH),               //positive integer
	  .WR_DATA_COUNT_WIDTH       ($clog2(FIFO_BUFFER_DEPTH)),               //positive integer, Not used
	  .PROG_FULL_THRESH          (10),               //positive integer, Not used 
	  .FULL_RESET_VALUE          (1),                //positive integer; 0 or 1
	  .READ_MODE                 ("fwft"),            //string; "std" or "fwft";
	  .FIFO_READ_LATENCY         (0),                //positive integer;
	  .READ_DATA_WIDTH           (FIFO_WIDTH),               //positive integer
	  .RD_DATA_COUNT_WIDTH       ($clog2(FIFO_BUFFER_DEPTH)),               //positive integer, not used
	  .PROG_EMPTY_THRESH         (10),               //positive integer, not used 
	  .DOUT_RESET_VALUE          ("0"),              //string, don't care
	  .WAKEUP_TIME               (0)                 //positive integer; 0 or 2;
	) shield_output_fifo_sync (
  	.sleep         ( 1'b0             ) ,
  	.rst           ( ~rst_n           ) ,
  	.wr_clk        ( clk           ) ,
  	.wr_en         ( cs_fifo_wr_en ) ,
  	.din           ( fifo_din ),
  	.full          ( fifo_full ) ,
  	.prog_full     (                  ) ,
  	.wr_data_count (                  ) ,
  	.overflow      (                  ) ,
  	.wr_rst_busy   (                  ) ,
  	.rd_en         ( fifo_rd_en ) ,
  	.dout          ( fifo_dout ) ,
  	.empty         ( fifo_empty ) ,
  	.prog_empty    (                  ) ,
  	.rd_data_count (                  ) ,
  	.underflow     (                  ) ,
  	.rd_rst_busy   (                  ) ,
  	.injectsbiterr ( 1'b0             ) ,
  	.injectdbiterr ( 1'b0             ) ,
  	.sbiterr       (                  ) ,
  	.dbiterr       (                  ) 
	);

  assign s_axi_rid = 0;
  assign s_axi_rresp = 2'b0;
  assign s_axi_rdata = fifo_dout[1 +: CL_DATA_WIDTH];
  assign s_axi_rlast = fifo_dout[0];
  assign s_axi_rvalid = (~fifo_empty); //output valid if not empty
  assign fifo_rd_en = s_axi_rready; //read enabled if master is ready - no effect if empty
  
  assign incr_outstanding = (cs_fifo_wr_en && (!fifo_full));
  shield_counter #(
    .C_WIDTH(32)
  ) outstanding_read_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(1'b0),
    .incr(incr_outstanding),
    .decr(1'b0),
    .load_value(32'd0),
    .count(outstanding_count_r),
    .is_zero()
  );
  
  assign incr_finalized = (fifo_rd_en && (!fifo_empty));
  shield_counter #(
    .C_WIDTH(32)
  ) finalized_read_counter (
    .clk(clk),
    .clken(1'b1),
    .rst(~rst_n),
    .load(1'b0),
    .incr(incr_finalized),
    .decr(1'b0),
    .load_value(32'd0),
    .count(finalized_count_r),
    .is_zero()
  );

  assign busy = (input_state_r != INPUT_STATE_IDLE) || (outstanding_count_r != finalized_count_r);

  //////////////////////////////////////////////////////////////////////////////
  // Control logic
  //////////////////////////////////////////////////////////////////////////////
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      input_state_r <= INPUT_STATE_IDLE;
    end
    else begin
      input_state_r <= next_input_state;
    end
  end

  //State transition
  always_comb begin
    next_input_state = input_state_r;
    case (input_state_r)
      INPUT_STATE_IDLE: begin //Wait for request
        if(input_val) begin
          next_input_state = INPUT_STATE_READ;
        end
      end
      INPUT_STATE_READ: begin
        if(burst_count_remaining_r == 8'd1 && !fifo_full) begin
          next_input_state = INPUT_STATE_IDLE;
        end
      end
    endcase
  end

  always_comb begin
    cs_input_rdy = 1'b0;
    cs_fifo_wr_en = 1'b0;
    case(input_state_r)
      INPUT_STATE_IDLE: begin
        cs_input_rdy = 1'b1;
      end
      INPUT_STATE_READ: begin
        if(!burst_done && !fifo_full) begin
          cs_fifo_wr_en = 1'b1;
        end
      end
    endcase
  end

  assign input_rdy = cs_input_rdy;

  
endmodule : shield_read_slv

`default_nettype wire
