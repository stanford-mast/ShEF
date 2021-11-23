`timescale 1ns/1ps
`include "common.vh"
module vectorgen # (
  parameter integer OP_WIDTH        = 16,
  parameter integer NUM_PE          = 4,
  parameter integer VECGEN_CTRL_W   = 9,
  parameter integer TID_WIDTH       = 8,
  parameter integer PAD_WIDTH       = 3,
  parameter integer STRIDE_WIDTH    = 3,
  parameter integer MAX_KERNEL_SIZE = 11,
  parameter integer MAX_STRIDE      = 4,
  parameter integer STRIDE_SIZE_W   = 3,
  parameter integer VECGEN_CFG_W    = STRIDE_SIZE_W + PAD_WIDTH,
  parameter integer MAX_PADDING     = 2
) (
  input  wire                         clk,
  input  wire                         reset,

  input  wire [VECGEN_CTRL_W - 1:0]   ctrl,
  input  wire [VECGEN_CFG_W  - 1:0]   cfg,

  output wire                         ready,
  output reg  [2 -1:0]                state,

  input  wire                         read_ready,
  input  wire [INPUT_WIDTH   - 1 :0]  read_data,
  output wire                         read_req,

  output reg                          write_valid, // TODO generate this
  output reg  [OUTPUT_WIDTH   - 1:0]  write_data
);

//*********************************************************************
// LOCAL PARAMS
//*********************************************************************
  localparam  INPUT_WIDTH  = NUM_PE*OP_WIDTH;
  localparam  OUTPUT_WIDTH = NUM_PE*OP_WIDTH;
  localparam  NUM_CURR_DATA = ceil_a_by_b((NUM_PE)*(MAX_STRIDE-1)+MAX_KERNEL_SIZE, NUM_PE)-1;
  localparam  CURR_DATA_WIDTH = NUM_CURR_DATA * OP_WIDTH * NUM_PE;
  localparam  PADDED_DATA_WIDTH = INPUT_WIDTH + CURR_DATA_WIDTH;

  localparam integer IDLE = 0, READ = 1, READY=2, LAST=3;
//*********************************************************************
// LOCAL WIRES AND REGS
//*********************************************************************

    // Vectorgen Control Signals
  wire                                        vectorgen_pop;
  wire                                        vectorgen_nextrow;
  wire                                        vectorgen_start;
  wire                                        vectorgen_nextfm;
  wire                                        vectorgen_endrow;
  wire                                        vectorgen_shift;
  wire                                        vectorgen_lastData;
  wire                                        vectorgen_nextData;

    // Vectorgen Control Signals - registered
  reg                                         vectorgen_pop_d;
  reg                                         vectorgen_shift_d;
  reg                                         vectorgen_nextrow_d;
  reg                                         vectorgen_endrow_d;

  reg                                         vectorgen_pop_dd;
  reg                                         vectorgen_shift_dd;
  reg                                         vectorgen_nextrow_dd;
  reg                                         vectorgen_endrow_dd;

  reg                                         next_write_valid;
  reg  [ INPUT_WIDTH          -1 : 0 ]        curr_data;
  wire [ INPUT_WIDTH          -1 : 0 ]        next_data;
  reg  [ INPUT_WIDTH          -1 : 0 ]        next_data_d;
  reg                                         curr_data_v;
  reg                                         curr_data_v_d;
  reg                                         next_data_v;

  reg  [INPUT_WIDTH+CURR_DATA_WIDTH-1:0]      out_data;

  wire [2:0] stride_size;
  reg  [PADDED_DATA_WIDTH-1:0]  padded_data;
  reg  [ INPUT_WIDTH          -1 : 0 ]        next_padded_data;
  reg  [ INPUT_WIDTH          -1 : 0 ]        next_padded_data_d;
  reg                                         padded_data_v;
  reg                                         padded_pop;
  reg                                         padded_shift;
  wire [ PAD_WIDTH            -1 : 0 ]        padding;

  reg  [ PAD_WIDTH            -1 : 0 ]        padding_d;
  always @(posedge clk)
    padding_d <= padding;

  // State machine
  //reg [1:0] state;
  reg [1:0] next_state;

  wire                                        read_req_w;

  wire last_data;
  reg last_data_sticky;



  reg [4:0] reads_remaining;
  wire test_remaining;

    reg                                         read_req_d;
  reg end_row_d, end_row_dd;
  reg next_row_d, next_row_dd;


    reg  [PADDED_DATA_WIDTH-1:0]  padded_data_endrow;
    reg  [PADDED_DATA_WIDTH-1:0]  padded_data_nextrow;
    reg  [PADDED_DATA_WIDTH-1:0]  padded_data_pop;

//*********************************************************************
// ASSIGN STATEMENTS
//*********************************************************************

  assign {
    vectorgen_nextData,
    vectorgen_lastData,
    vectorgen_pop,
    vectorgen_shift,
    vectorgen_nextrow,
    vectorgen_skip,
    vectorgen_endrow,
    vectorgen_start,
    vectorgen_nextfm
    } = ctrl;
  assign {stride_size, padding} = cfg;

  always @(posedge clk)
    if (reset)
      {vectorgen_pop_d, vectorgen_endrow_d, vectorgen_nextrow_d, vectorgen_shift_d} <= 0;
    else
      {vectorgen_pop_d, vectorgen_endrow_d, vectorgen_nextrow_d, vectorgen_shift_d} <= {vectorgen_pop, vectorgen_endrow, vectorgen_nextrow, vectorgen_shift};

  always @(posedge clk)
    if (reset)
      {vectorgen_pop_dd, vectorgen_endrow_dd, vectorgen_nextrow_dd, vectorgen_shift_dd} <= 0;
    else
      {vectorgen_pop_dd, vectorgen_endrow_dd, vectorgen_nextrow_dd, vectorgen_shift_dd} <= {vectorgen_pop_d, vectorgen_endrow_d, vectorgen_nextrow_d, vectorgen_shift_d};

//*********************************************************************
// LOGIC
//*********************************************************************

//====================================================
/** State machine
 * valid states: IDLE(Default), BUSY */


  assign test_ready = state == READY || state == LAST;//reads_remaining == 0;
  //assign test_ready = reads_remaining == 0;

  always @(posedge clk)
  begin
    if (reset)
      reads_remaining <= 0;
    else if (state == LAST)
      reads_remaining <= 0;
    else if (vectorgen_start)
    begin
      if (!(read_ready && read_ready))
        reads_remaining <= stride_size + 1;
      else
        reads_remaining <= stride_size;
    end
    else if (vectorgen_skip && state == READY)
    begin
      if (!(read_ready && read_ready))
        reads_remaining <= stride_size + 1;
      else
        reads_remaining <= stride_size;
    end
    else if (vectorgen_nextData && state == READY)
    begin
      if (!(read_ready && read_ready))
        reads_remaining <= stride_size + 0;
      else
        reads_remaining <= stride_size - 1;
    end
    else if (read_req && read_ready)
    begin
      reads_remaining <= reads_remaining - 1;
    end
  end

  always @*
  begin: VECGEN_FSM
    next_state = state;
    case (state)
      IDLE: begin
        if (vectorgen_start)
          next_state = READ;
      end
      READ: begin
        if ((reads_remaining == 1) && read_req && read_ready || (reads_remaining == 0))
          next_state = READY;
      end
      READY: begin
        if (vectorgen_lastData)
          next_state = LAST;
        else if (((vectorgen_nextData) && !((stride_size == 1) && read_ready && read_req && (reads_remaining == 0)) || vectorgen_skip))
          next_state = READ;
        else if (vectorgen_nextfm)
          next_state = IDLE;
      end
      LAST: begin
        if (vectorgen_nextfm)
          next_state = IDLE;
      end
    endcase
  end

  always@(posedge clk)
  begin
    if (reset)
      state <= 1'b0;
    else
      state <= next_state;
  end

//====================================================
/** Padding logic
  * Use a shifter to pad the inputs */


  always @(posedge clk)
  begin
    read_req_d <= read_req && read_ready;
    end_row_d <= vectorgen_endrow;
    end_row_dd <= end_row_d;
    next_row_d <= vectorgen_nextrow;
    next_row_dd <= next_row_d;
  end

  always @(posedge clk)
    if (reset)
      next_padded_data <= 0;
    else
      next_padded_data <= padded_data >> padding*OP_WIDTH;

  always @(posedge clk)
    if (reset)
      next_padded_data_d <= 0;
    else
      next_padded_data_d <= next_padded_data;

  always @(posedge clk)
    padded_data_endrow <= {{INPUT_WIDTH{1'b0}}, stride_data_d, next_padded_data_d} >> (INPUT_WIDTH-padding_d*OP_WIDTH);
  always @(posedge clk)
    padded_data_nextrow <= {next_data_d, stride_data_d, {INPUT_WIDTH{1'b0}}} >> (INPUT_WIDTH-padding_d*OP_WIDTH);

  always @(posedge clk)
    padded_data_pop <= {next_data_d, stride_data_d, next_padded_data_d} >>
                      (INPUT_WIDTH-padding_d*OP_WIDTH);

  always @(posedge clk)
  begin
    if (reset)
      padded_data <= 'b0;
    else if (vectorgen_endrow_dd)
      padded_data <= padded_data_endrow;
    else if (vectorgen_nextrow_dd)
      padded_data <= padded_data_nextrow;
    else if (vectorgen_pop_dd)
      padded_data <= padded_data_pop;
  end

  always @(posedge clk)
    if (reset || vectorgen_nextfm)
      padded_data_v <= 1'b0;
    else
      padded_data_v <= reads_remaining == 0;

  //assign padded_data_v = 1'b1;

  always @(posedge clk)
  begin: PAD_DELAY
    if (reset) begin
      padded_pop <= 1'b0;
      padded_shift <= 1'b0;
    end else begin
      padded_pop <= vectorgen_pop_dd;
      padded_shift <= vectorgen_shift_dd;
    end
  end
//====================================================

  //assign ready = next_data_v;
  assign next_data = read_data;
  always @(posedge clk)
    if (reset)
      next_data_d <= 0;
    else
      next_data_d <= next_data;


                         
  wire [INPUT_WIDTH+CURR_DATA_WIDTH-1:0] next_out_data_stride1;
  wire [INPUT_WIDTH+CURR_DATA_WIDTH-1:0] next_out_data_stride2;
  wire [INPUT_WIDTH+CURR_DATA_WIDTH-1:0] next_out_data_stride4;
  
  generate
    assign next_out_data_stride1 = padded_data[PADDED_DATA_WIDTH-1:PADDED_DATA_WIDTH-2*INPUT_WIDTH];
    if (MAX_STRIDE > 1)
        assign next_out_data_stride2 = padded_data[PADDED_DATA_WIDTH-1:PADDED_DATA_WIDTH-2*INPUT_WIDTH];
    else
        assign next_out_data_stride2 = 0;
    if (MAX_STRIDE == 4)
        assign next_out_data_stride4 = padded_data[PADDED_DATA_WIDTH-1:PADDED_DATA_WIDTH-2*INPUT_WIDTH];
    else
        assign next_out_data_stride4 = 0;
  endgenerate
  
  wire [INPUT_WIDTH+CURR_DATA_WIDTH-1:0] next_out_data;
  assign next_out_data = stride_size == 1 ? next_out_data_stride1 :
                         stride_size == 2 ? next_out_data_stride2 :
                         next_out_data_stride4;
  
  
  
  always@(posedge clk)
  begin
    if (reset)
      out_data <= 'b0;
    else begin
      if (padded_pop)
        out_data <= next_out_data;
      else if (padded_shift)
        out_data <= out_data >> OP_WIDTH;
    end
  end

  //assign write_data = out_data;
  always @(posedge clk)
    write_data <= stride_size == 1 ? write_data_stride_1 : stride_size == 2 ? write_data_stride_2 : write_data_stride_4;

  wire [OUTPUT_WIDTH-1:0] write_data_stride_1;
  wire [OUTPUT_WIDTH-1:0] write_data_stride_2;
  wire [OUTPUT_WIDTH-1:0] write_data_stride_4;

  genvar g;
  generate
  for (g=0; g<OUTPUT_WIDTH/OP_WIDTH; g=g+1)
  begin: stride_gen
    assign write_data_stride_1[g*OP_WIDTH+:OP_WIDTH] = out_data[1*g*OP_WIDTH+:OP_WIDTH];
    if (MAX_STRIDE > 1)
        assign write_data_stride_2[g*OP_WIDTH+:OP_WIDTH] = out_data[2*g*OP_WIDTH+:OP_WIDTH];
    if (MAX_STRIDE == 4)
        assign write_data_stride_4[g*OP_WIDTH+:OP_WIDTH] = out_data[4*g*OP_WIDTH+:OP_WIDTH];
  end
  endgenerate

  // -- always @(posedge clk)
  // -- begin
  // --   if (reset || vectorgen_nextfm)
  // --     curr_data_v <= 1'b0;
  // --   else if (read_req && read_ready && state == BUSY)
  // --     curr_data_v <= 1'b1;
  // -- end

  always @(posedge clk)
  begin
    if (reset || (read_req && !read_ready))
      next_data_v <= 1'b0;
    else if (read_req && read_ready)
      next_data_v <= 1'b1;
  end

  always @(posedge clk)
  begin: OUTPUT_VALID
    if (reset)
      write_valid <= 1'b0;
    else if (next_data_v && (padded_shift||padded_pop))
      write_valid <= 1'b1;
    else
      write_valid <= 1'b0;
  end

  //assign read_req_w = read_ready && (!curr_data_v || (!next_data_v && !read_req)
  //      || vectorgen_nextData || vectorgen_skip) && (state == BUSY) && !vectorgen_nextfm;

  //always @(posedge clk)
  //begin: INPUT_READ_REQUEST
  //  if (reset)
  //    read_req <= 0;
  //  else
  //    read_req <= read_req_w;
  //end

  //assign read_req = (read_ready && (!stride_v || !next_data_v)) ||
    //vectorgen_nextData || vectorgen_skip || vectorgen_nextfm;
  assign read_req = ((state != LAST && !(state == READY && vectorgen_lastData)) && (read_ready && ((vectorgen_nextData || vectorgen_skip || vectorgen_start) ||
    reads_remaining != 0))) && read_ready;

//*********************************************************************
// Stride Logic
//*********************************************************************

  reg  [ CURR_DATA_WIDTH      -1 : 0 ]        stride_data;
  reg  [ CURR_DATA_WIDTH      -1 : 0 ]        stride_data_d;
  reg  [ NUM_CURR_DATA        -1 : 0 ]        stride_data_v;

//=====================================================================
  reg [ CURR_DATA_WIDTH      -1 : 0 ]         nextrow_stride_data_d;
  wire [ CURR_DATA_WIDTH      -1 : 0 ]        nextrow_stride_data;

  generate
    if (MAX_STRIDE == 1)
      assign nextrow_stride_data = {stride_data[CURR_DATA_WIDTH-1:CURR_DATA_WIDTH-1*INPUT_WIDTH], {CURR_DATA_WIDTH-1*INPUT_WIDTH{1'b0}}};
    else if (MAX_STRIDE == 2)
      assign nextrow_stride_data = stride_size == 1 ?
                                   {stride_data[CURR_DATA_WIDTH-1:CURR_DATA_WIDTH-1*INPUT_WIDTH], {CURR_DATA_WIDTH-1*INPUT_WIDTH{1'b0}}} : {stride_data[CURR_DATA_WIDTH-1:CURR_DATA_WIDTH-2*INPUT_WIDTH], {CURR_DATA_WIDTH-2*INPUT_WIDTH{1'b0}}};
    else if (MAX_STRIDE == 4)
      assign nextrow_stride_data =
        stride_size == 1 ? {stride_data[CURR_DATA_WIDTH-1:CURR_DATA_WIDTH-1*INPUT_WIDTH], {CURR_DATA_WIDTH-1*INPUT_WIDTH{1'b0}}} :
        stride_size == 2 ? {stride_data[CURR_DATA_WIDTH-1:CURR_DATA_WIDTH-2*INPUT_WIDTH], {CURR_DATA_WIDTH-2*INPUT_WIDTH{1'b0}}} :
        {stride_data[CURR_DATA_WIDTH-1:CURR_DATA_WIDTH-4*INPUT_WIDTH], {CURR_DATA_WIDTH-4*INPUT_WIDTH{1'b0}}};
  endgenerate

  always @(posedge clk)
    if (reset)
      nextrow_stride_data_d <= 0;
    else
      nextrow_stride_data_d <= nextrow_stride_data;
//=====================================================================


  wire                                        stride_v;
    wire stride_v_max_stride_1;
  wire stride_v_max_stride_2;
  wire stride_v_max_stride_4; 
  
  
  assign stride_v = stride_size == 1 ? stride_v_max_stride_1 :
                    stride_size == 2 ? stride_v_max_stride_2 :
                    stride_size == 4 ? stride_v_max_stride_4 : 1'b0;
                 
  generate
    assign stride_v_max_stride_1 = stride_data_v[NUM_CURR_DATA-1];
    if (MAX_STRIDE > 2) assign stride_v_max_stride_2 = &stride_data_v[NUM_CURR_DATA-1:NUM_CURR_DATA-2];
    else assign stride_v_max_stride_2 = 1'b0;
    if (MAX_STRIDE == 4) assign stride_v_max_stride_4 = &stride_data_v[NUM_CURR_DATA-1:NUM_CURR_DATA-4];
    else assign stride_v_max_stride_4 = 1'b0;
  endgenerate
    

  generate
    for (g=0; g<NUM_CURR_DATA; g=g+1)
    begin: STRIDE_DATA_GEN

      wire [ INPUT_WIDTH          -1 : 0 ]        next_stride_data;

      if (g==NUM_CURR_DATA-1)
      begin
        assign next_stride_data = next_data;
      end else
      begin
        assign next_stride_data = stride_data[(g+1)*INPUT_WIDTH+:INPUT_WIDTH];
      end

      always @(posedge clk)
      begin
        if (reset)
          stride_data[g*INPUT_WIDTH+:INPUT_WIDTH] <= 0;
        else if (read_req || (vectorgen_lastData || last_data_sticky) && state == READY)
          stride_data[g*INPUT_WIDTH+:INPUT_WIDTH] <= next_stride_data;
      end

    end
  endgenerate

  always @(posedge clk)
  begin
    if (reset)
      stride_data_d <= 0;
    else if (vectorgen_nextrow)
      stride_data_d <= nextrow_stride_data;
    else
      stride_data_d <= stride_data;
  end

  ///  assign ready = curr_data_v;
  //assign ready = padded_data_v;
  assign ready = test_ready;


`ifdef simulation
  integer vecgen_rd_count;
  always @(posedge clk)
    if (reset)
      vecgen_rd_count <= 0;
    else if (read_req && read_ready)
      vecgen_rd_count <= vecgen_rd_count + 1;
`endif

// This makes sure that the last data is read

  assign last_data = last_data_sticky || vectorgen_lastData;

  always @(posedge clk)
    if (reset)
      last_data_sticky <= 1'b0;
    else if (vectorgen_lastData && state != READY)
      last_data_sticky <= 1'b1;
    else if (state == READY)
      last_data_sticky <= 1'b0;

endmodule
