`timescale 1ns/1ps
`include "dw_params.vh"
`include "common.vh"
module PU_controller
#(  // PARAMETERS
  parameter integer PE_BUF_ADDR_WIDTH       = 10,
  parameter integer PU_BUF_DATA_W           = 64,
  parameter integer NUM_PE                  = 4,
  parameter integer WEIGHT_ADDR_WIDTH       = 8,
  parameter integer WEIGHT_OFFSET_WIDTH     = 5,
  parameter integer PE_CTRL_W               = 10+2*PE_BUF_ADDR_WIDTH,
  parameter integer PE_OP_CODE_WIDTH        = 3,
  parameter integer LAYER_PARAM_WIDTH       = 10,
  parameter integer PARAM_C_WIDTH           = 32,
  parameter integer MAX_LAYERS              = 64,
  parameter integer VECGEN_CTRL_W           = 9,
  parameter integer TID_WIDTH               = 8,
  parameter integer PAD_WIDTH               = 3,
  parameter integer STRIDE_SIZE_W           = 3,
  parameter integer VECGEN_CFG_W            = STRIDE_SIZE_W + PAD_WIDTH,
  parameter integer POOL_CTRL_W             = 7,
  parameter integer POOL_CFG_W              = 3,
  parameter integer KERNEL_SIZE_W           = 3,
  parameter integer SERDES_COUNT_W          = `C_LOG_2(NUM_PE+1),
  parameter integer PE_SEL_W                = `C_LOG_2(NUM_PE)
)
( // PORTS
  // -- clk and reset
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         start,
  output wire                                         done,
  output wire  [ L_TYPE_WIDTH         -1 : 0 ]        l_type,
  output reg                                          lrn_enable,
  output wire  [ SERDES_COUNT_W       -1 : 0 ]        pu_serdes_count,
  output wire  [ PE_SEL_W             -1 : 0 ]        pe_neuron_sel,
  output wire                                         pe_neuron_bias,
  output wire                                         pe_neuron_read_req,
  input  wire                                         buffer_read_empty,
  output wire                                         buffer_read_req,
  input  wire                                         buffer_read_last,
  input  wire                                         vectorgen_ready,
  input  wire                                         pu_vecgen_ready,
  output wire  [ VECGEN_CTRL_W        -1 : 0 ]        vectorgen_ctrl,
  output wire  [ PE_CTRL_W            -1 : 0 ]        pe_ctrl,
  output wire  [ VECGEN_CFG_W         -1 : 0 ]        vectorgen_cfg,
  output wire  [ WEIGHT_ADDR_WIDTH    -1 : 0 ]        wb_read_addr,
  output wire                                         wb_read_req,
  output wire                                         pe_piso_read_req,
  output wire  [ NUM_PE               -1 : 0 ]        pe_write_mask,

  output wire  [ POOL_CTRL_W          -1 : 0 ]        pool_ctrl,
  output wire  [ POOL_CFG_W           -1 : 0 ]        pool_cfg,

  output reg   [ 3                    -1 : 0 ]        state,

  output wire  [ `OUT_SEL_WIDTH       -1 : 0 ]        out_sel,
  output wire  [ `DST_SEL_WIDTH       -1 : 0 ]        dst_sel,
  output wire  [ `SRC_0_SEL_WIDTH     -1 : 0 ]        src_0_sel,
  output wire  [ `SRC_1_SEL_WIDTH     -1 : 0 ]        src_1_sel,
  output wire  [ `SRC_2_SEL_WIDTH     -1 : 0 ]        src_2_sel,
  output wire                                         bias_read_req,

  // Debug
  output wire  [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_kw,
  output wire  [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_kh,
  output wire  [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_iw,
  output wire  [ LAYER_PARAM_WIDTH    -1 : 0 ]        dbg_ih,
  output wire  [ PARAM_C_WIDTH        -1 : 0 ]        dbg_ic,
  output wire  [ PARAM_C_WIDTH        -1 : 0 ]        dbg_oc
);
// ******************************************************************
// Local params
// ******************************************************************
  // FSM states
  localparam IDLE       = 0,
             WAIT       = 1,
             RD_CFG_1   = 2,
             RD_CFG_2   = 3,
             BUSY       = 4;
  // PE OP codes
  localparam OP_MUL     = 0,
             OP_MUL_ACC = 2,
             OP_MUL_ADD = 4,
             OP_SQ      = 1,
             OP_SQ_ACC  = 3,
             OP_SQ_ADD  = 5;
// ******************************************************************
// ******************************************************************
// Local regs & wires
// ******************************************************************

// Pool signals - begin
  wire                                        _pool_pad_row;
  wire                                        pool_pad_row;
  wire                                        pool_done;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_ih_count;
  wire                                        pool_ih_inc;
  wire                                        pool_ih_stall;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_ih_default;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_ih_min;
  reg  [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_ih_max;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_iw_count;
  wire                                        pool_iw_inc;
  wire                                        next_pool_ih;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_iw_default;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_iw_min;
  reg  [ LAYER_PARAM_WIDTH    -1 : 0 ]        pool_iw_max;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        stride_count;
  wire                                        stride_inc;
  wire                                        next_pool_iw;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        stride_default;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        stride_min;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        stride_max;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        p_count;
  wire                                        p_inc;
  wire                                        p_stall;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        p_min;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        p_default;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        p_max;

  wire                                        pool_in_pop;
  wire                                        _pool_in_pop;
  wire                                        pool_in_shift;
  wire                                        _pool_in_shift;
  // Pool signals - end


  wire                                        kw_inc;
  wire                                        next_kh;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        kw;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        kw_max;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        kw_default;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        kw_min;

  reg  [ KERNEL_SIZE_W        -1 : 0 ]        kh;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        kh_default;
  reg  [ KERNEL_SIZE_W        -1 : 0 ]        kh_max;
  reg  [ KERNEL_SIZE_W        -1 : 0 ]        kh_min;
  reg  [ KERNEL_SIZE_W        -1 : 0 ]        kh_min_d;
  wire                                        kh_clear;
  wire                                        kh_dec;
  wire                                        kh_max_dec;
  wire                                        kh_min_dec;
  reg                                         kh_min_dec_d;

  wire [ STRIDE_SIZE_W        -1 : 0 ]        conv_stride_count;
  wire [ STRIDE_SIZE_W        -1 : 0 ]        conv_stride_default;
  wire [ STRIDE_SIZE_W        -1 : 0 ]        conv_stride_max;
  wire [ STRIDE_SIZE_W        -1 : 0 ]        conv_stride_min;
  reg  [ STRIDE_SIZE_W        -1 : 0 ]        conv_stride_min_d;
  wire                                        conv_stride_clear;
  wire                                        conv_stride_dec;
  wire                                        conv_stride_max_dec;
  wire                                        conv_stride_min_dec;
  reg                                         conv_stride_min_dec_d;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        iw;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        iw_max;
  wire                                        iw_inc, iw_inc_d;
  wire                                        next_ih;
  wire                                        ih_underflow;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        ih, ih_max, ih_max_pad;
  wire                                        ih_inc, ih_inc_d;

  wire [ PARAM_C_WIDTH        -1 : 0 ]        ic, ic_max;
  wire                                        ic_inc, ic_inc_d;

  wire [ PARAM_C_WIDTH        -1 : 0 ]        oc_min;
  wire [ PARAM_C_WIDTH        -1 : 0 ]        oc_max;
  wire [ PARAM_C_WIDTH        -1 : 0 ]        oc;
  wire                                        oc_inc, oc_inc_d;

  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]          l, l_max;
  wire                                        l_inc, l_inc_d, l_clear;

  wire                                        next_fm;

  wire                                        vectorgen_pop;
  wire                                        vectorgen_pop_dd;
  wire                                        vectorgen_shift;
  wire                                        vectorgen_shift_dd;
  wire                                        vectorgen_nextrow;
  wire                                        vectorgen_start;
  wire                                        vectorgen_nextfm;
  wire                                        vectorgen_nextfm_dd;
  wire                                        vectorgen_endrow;
  wire                                        vectorgen_skip;
  wire                                        vectorgen_skip_dd;
  wire                                        vectorgen_readData;
  wire                                        vectorgen_nextData;
  wire                                        skip;

  // Both stream vecgen and pu_vecgen
  wire vecgen_ready;

  wire [ TID_WIDTH            -1 : 0 ]        max_threads;
  wire [ PAD_WIDTH            -1 : 0 ]        pad_w;
  wire [ PAD_WIDTH            -1 : 0 ]        pad_r_s;
  wire [ PAD_WIDTH            -1 : 0 ]        pad_r_e;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        endrow_iw;

  //reg  [ 3                    -1 : 0 ]        state;
  reg  [ 3                    -1 : 0 ]        state_d;
  reg  [ 3                    -1 : 0 ]        state_dd;
  reg  [ 3                    -1 : 0 ]        state_ddd;
  reg  [ 3                    -1 : 0 ]        next_state;
  reg  [ CFG_WIDTH            -1 : 0 ]        cfg_rom[0:CFG_DEPTH-1];
  reg  [ CFG_WIDTH            -1 : 0 ]        layer_params;

  wire [ SERDES_COUNT_W       -1 : 0 ]        serdes_count;
  wire [ PARAM_C_WIDTH        -1 : 0 ]        param_ic;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        param_ih;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        param_oh;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        param_iw;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        param_pool_iw;
  wire [ PARAM_C_WIDTH        -1 : 0 ]        param_oc;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        param_kh;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        param_kh_reduced;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        param_kw;
  wire [ KERNEL_SIZE_W        -1 : 0 ]        param_kw_reduced;
  //wire [ L_TYPE_WIDTH       -1 : 0 ]        l_type;
  wire                                        param_pool_enable;
  reg                                         pool_enable;
  wire [ 1                       : 0 ]        pool_kernel;

  reg  [ LAYER_PARAM_WIDTH    -1 : 0 ]        max_layers;

  wire [ PE_OP_CODE_WIDTH     -1 : 0 ]        pe_op_code;
  reg  [ PE_OP_CODE_WIDTH     -1 : 0 ]        _pe_op_code;
  wire [ PE_OP_CODE_WIDTH     -1 : 0 ]        conv_op_code;
  wire [ PE_OP_CODE_WIDTH     -1 : 0 ]        ip_op_code;
  wire [ PE_OP_CODE_WIDTH     -1 : 0 ]        norm_op_code;
  wire                                        pe_enable;
  wire                                        _pe_enable;

  wire                                        _pe_fifo_push;
  wire                                        pe_fifo_push;
  wire                                        _pe_fifo_pop;
  wire                                        pe_fifo_pop;

  wire                                        _pe_write_valid;
  wire                                        pe_write_valid;

  wire [ PE_BUF_ADDR_WIDTH  -1 : 0 ]  _pe_buf_rd_addr, pe_buf_rd_addr,
                                      _pe_buf_wr_addr, pe_buf_wr_addr,
                                      pe_buf_rd_addr_tmp, pe_buf_wr_addr_tmp;

  // Write Mask Logic
  wire [ NUM_PE               -1 : 0 ]        _pe_write_mask;
  reg  [TID_WIDTH             -1 : 0 ]        tid  [0:NUM_PE-1];
  reg  [ NUM_PE               -1 : 0 ]        mask;

  wire                                        tid_reset;
  wire                                        tid_inc;

  wire                                        pool_ready;
  wire                                        row_fifo_push;
  wire                                        _row_fifo_push;
  wire                                        row_fifo_pop;
  wire                                        _row_fifo_pop;
  wire                                        row_fifo_mux_sel;
  wire                                        _row_fifo_mux_sel;
  wire                                        pool_valid;
  wire                                        _pool_valid;
  wire [ 1                       : 0 ]        pool_stride;
  wire                                        _kernel_size_switch;
  wire                                        kernel_size_switch;
  wire                                        pool_endrow;


  reg  [ LAYER_PARAM_WIDTH    -1 : 0 ]        pe_iw_max;

  wire [ 256                  -1 : 0 ]        GND;

// ==================================================================
// ROM
// ==================================================================
  localparam CFG_DEPTH = MAX_LAYERS;
  localparam L_TYPE_WIDTH = 2;
  localparam CFG_WIDTH =
    SERDES_COUNT_W +
    2*PARAM_C_WIDTH +
    7*LAYER_PARAM_WIDTH +
    TID_WIDTH +
    3*PAD_WIDTH +
    L_TYPE_WIDTH +
    2+2+
    STRIDE_SIZE_W;

  localparam L_CONV = 0;
  localparam L_IP = 1;
  localparam L_NORM = 2;

  assign GND = 256'd0;

  initial begin
    max_layers = `max_layers;
    `ifdef VIVADO_SIM
      $readmemb("/home/centos/src/project_data/free/apps/dnnweaver/design/include/pu_controller_bin.vh", cfg_rom);
    `else
      $readmemb("pu_controller_bin.dat", cfg_rom);
    `endif
  end

  always @(posedge clk)
  begin
    if (state != RD_CFG_1)
      layer_params <= cfg_rom[l];
  end

  wire [ STRIDE_SIZE_W        -1 : 0 ]        param_conv_stride;
  reg  [STRIDE_SIZE_W-1:0] param_conv_stride_d;
  always @(posedge clk)
    if (reset)
      param_conv_stride_d <= 1;
    else
      param_conv_stride_d <= param_conv_stride;

  assign {
    serdes_count,
    param_conv_stride,
    param_pool_iw,
    param_oh,
    pool_kernel,
    param_pool_enable,
    l_type,
    max_threads,
    pad_w,
    pad_r_s,
    pad_r_e,
    skip,
    endrow_iw,
    param_ic,
    param_ih,
    param_iw,
    param_oc,
    param_kh,
    param_kw} = layer_params;

  always @(posedge clk)
    if (reset)
      pool_enable <= 1'b0;
    else if (pool_ih_count == 0)
      pool_enable <= param_pool_enable;

  assign kh_default = param_kh;

  wire [LAYER_PARAM_WIDTH-1:0] dbg = ih_max - param_kh + pad_r_e;
  assign kh_max_dec = (ih > (ih_max - param_kh+pad_r_e-param_conv_stride) &&
    iw_inc_d && (iw == iw_min) && kh_max != (param_conv_stride-1)) && (conv_stride_count == conv_stride_max);

  always @(posedge clk)
  begin
    if (reset)
      kh_max <= 0;
    else if (state == RD_CFG_2 || ic_inc)
      kh_max <= param_kh;
    else if (ih == param_ih && iw == iw_max && iw_inc)
      kh_max <= pad_r_e-1;
    else if (kh_max_dec)
      kh_max <= kh_max - param_conv_stride;
  end

  assign kh_min_dec = (iw == iw_max && kw == 0 && kh == kh_min_stride && kw_inc) && (kh_min != param_conv_stride && kh_min != 0) && (conv_stride_count == conv_stride_max);
  // Update KH_MIN at the first KW of the last convolution of a row (kh is max
  // and iw is max

  always @(posedge clk)
    kh_min_dec_d <= kh_min_dec;
  always @(posedge clk)
    kh_min_d<= kh_min;

  always @(posedge clk)
  begin
    if (reset)
      kh_min <= 0;
    else if (state == RD_CFG_2 || ic_inc)
      kh_min <= param_kh - pad_r_s;
    else if (kh_min_dec_d)
      kh_min <= kh_min - param_conv_stride;
  end

// ==================================================================

reg [6:0] wait_timer;
wire [6:0] max_wait_time = 8;
wire wait_complete = wait_timer == max_wait_time;


always @(posedge clk)
  if (reset || state != WAIT)
    wait_timer <= 0;
  else if (!wait_complete)
    wait_timer <= wait_timer + 1'b1;

assign buffer_read_req = wait_complete && state == WAIT && !(buffer_read_last_sticky);

reg buffer_read_last_sticky;

always @(posedge clk)
begin
  if (reset)
    buffer_read_last_sticky <= 1'b0;
  else begin
    if (buffer_read_last)
      buffer_read_last_sticky <= 1'b1;
    else if (state == RD_CFG_1)
      buffer_read_last_sticky <= 1'b0;
  end
end

wire buffer_read_done = buffer_read_last || buffer_read_last_sticky || l_type == 2;

  // Ready signal for PER-PU vecgen
  //assign vecgen_ready = (l_type == L_NORM) ? pu_vecgen_ready : vectorgen_ready;
  assign vecgen_ready = vectorgen_ready;

always @*
begin: FSM
  next_state = state;
  case (state)
    IDLE: begin
      if (start)
        next_state = WAIT;
    end
    WAIT: begin
      if (vecgen_ready && wait_complete && buffer_read_done)
        next_state = RD_CFG_1;
    end
    RD_CFG_1: begin
        next_state = RD_CFG_2;
    end
    RD_CFG_2: begin
        next_state = BUSY;
    end
    BUSY: begin
      if (done)
        next_state = IDLE;
      else if (vectorgen_nextfm)
        next_state = WAIT;
    end
  endcase
end

always @(posedge clk)
begin
  if (reset)
    state <= IDLE;
  else
    state <= next_state;
end

// ==================================================================
// Data Wait Logic
// ==================================================================
  wire                                        data_stall;
  reg data_stall_d;
  always @(posedge clk)
    data_stall_d <= data_stall;
  // PU-vecgen for Normalization
assign data_stall = !vecgen_ready && (vectorgen_pop);
  wire flush_stall = flush && (pe_buf_rd_addr == pe_buf_wr_addr && pe_fifo_pop && pe_fifo_push);
// ==================================================================


// ==================================================================
// Kernel Width
// ==================================================================
  assign kw_inc = state == BUSY && !data_stall;


  //assign kw_max = (!flush) ? param_kw : 0;
  // Changed FLUSH KW_MAX to param_kw.
  // Can change back if input feature map is large enough
  assign kw_max = param_kw;


  assign kw_default = GND[LAYER_PARAM_WIDTH-1:0];
  assign kw_min = GND[LAYER_PARAM_WIDTH-1:0];
  counter #(
    .COUNT_WIDTH              ( KERNEL_SIZE_W            )
  )
  kw_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( kw_default               ),  //input
    .INC                      ( kw_inc                   ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( kw_min                   ),  //input
    .MAX_COUNT                ( kw_max                   ),  //input
    .OVERFLOW                 ( next_kh                  ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( kw                       )   //output
  );
// ==================================================================

// ==================================================================
// Kernel Height
// ==================================================================
  assign kh_dec = kw_inc && next_kh && state == BUSY;
  always @(posedge clk)
    state_d <= state;
  always @(posedge clk)
    state_dd <= state_d;
  always @(posedge clk)
    state_ddd <= state_dd;
  assign kh_clear = state_d == RD_CFG_1 || ic_inc;

  reg  [KERNEL_SIZE_W-1:0] kh_max_stride;
  reg  [KERNEL_SIZE_W-1:0] _kh_max_stride;
  reg  [KERNEL_SIZE_W-1:0] _kh_min_stride;
  reg  [KERNEL_SIZE_W-1:0] kh_min_stride;

  always @(posedge clk)
  begin
    if (reset)
      _kh_max_stride <= 0;
    else if (state == RD_CFG_2)
      _kh_max_stride <= param_kh;
    else if (iw == iw_max && iw_inc_d)
    begin
      if (conv_stride_count == conv_stride_max)
        _kh_max_stride <= kh_min;
      else
        _kh_max_stride <= kh_min - conv_stride_count;
    end
  end

  wire                                        update__kh_min_stride;
  assign update__kh_min_stride = (iw == iw_max && iw_inc_d);

  always @(posedge clk)
  begin
    if (reset)
      _kh_min_stride <= 0;
    else if (state == RD_CFG_2)
      _kh_min_stride <= param_kh;
    else if (iw_is_max && kw == 0 && kh == kh_max_stride && param_kh != 0)
    begin
        _kh_min_stride <= kh_min - conv_stride_count;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      kh_max_stride <= 0;
    else if (state == RD_CFG_2)
      kh_max_stride <= param_kh;
    else if (iw == iw_max && iw_inc_d)
    begin
      if (conv_stride_count == conv_stride_max)
        kh_max_stride <= kh_max;
      else
        kh_max_stride <= kh_max - conv_stride_count;
    end
  end

  always @(posedge clk)
    if (reset)
      kh_min_stride <= 0;
    else if (state == RD_CFG_2 || ic_inc)
      kh_min_stride <= param_kh - pad_r_s;
    else if (ih_inc)
      kh_min_stride <= _kh_min_stride;

  always @(posedge clk)
  begin
    if (reset)
      kh <= 0;
    else begin
      if (kh_clear)
        kh <= kh_default;
      else if (kh_dec && next_iw)
        kh <= kh_max_stride;
      else if (kh_dec)
        kh <= kh - param_conv_stride;
    end
  end
  assign next_iw = kh == kh_min_stride;

  // counter #(
  //   .COUNT_WIDTH              ( KERNEL_SIZE_W            )
  // )
  // kh_counter (
  //   .CLK                      ( clk                      ),  //input
  //   .RESET                    ( reset                    ),  //input
  //   .CLEAR                    ( kh_clear                 ),  //input
  //   .DEFAULT                  ( kh_default               ),  //input
  //   .INC                      ( 1'b0                     ),  //input
  //   .DEC                      ( kh_dec                   ),  //input
  //   .MIN_COUNT                ( kh_min                   ),  //input
  //   .MAX_COUNT                ( kh_max                   ),  //input
  //   .OVERFLOW                 (                          ),  //output
  //   .UNDERFLOW                ( next_iw                  ),  //output
  //   .COUNT                    ( kh                       )   //output
  // );
// ==================================================================

// ==================================================================
// Convolution stride count
// ==================================================================
  assign conv_stride_inc = ih_inc && !data_stall;
  assign conv_stride_clear = state_d == RD_CFG_1 || ic_inc;
  assign conv_stride_default = 1'b1;
  assign conv_stride_min = 1'b1;
  assign conv_stride_max = param_conv_stride;

  counter #(
    .COUNT_WIDTH              ( STRIDE_SIZE_W            )
  )
  conv_stride_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( conv_stride_clear        ),  //input
    .DEFAULT                  ( conv_stride_default      ),  //input
    .INC                      ( conv_stride_inc          ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( conv_stride_min          ),  //input
    .MAX_COUNT                ( conv_stride_max          ),  //input
    .OVERFLOW                 (                          ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( conv_stride_count        )   //output
  );
// ==================================================================

// ==================================================================
// Input FM width
// ==================================================================
  assign iw_inc = next_iw && kh_dec && state == BUSY;
  assign iw_max = param_iw;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        iw_min;
  assign iw_min = GND[LAYER_PARAM_WIDTH-1:0];
  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  iw_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( iw_max                   ),  //input
    .INC                      ( iw_inc                   ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( iw_min                   ),  //input
    .MAX_COUNT                ( iw_max                   ),  //input
    .OVERFLOW                 ( next_ih                  ),  //output
    .UNDERFLOW                ( ih_underflow             ),  //output
    .COUNT                    ( iw                       )   //output
  );
// ==================================================================

// ==================================================================
// Input FM height
// ==================================================================
  assign ih_inc = next_ih && iw_inc && state == BUSY;
  assign ih_max = param_ih;
  assign ih_max_pad = param_ih+pad_r_e;
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        ih_min;
  assign ih_min = GND[LAYER_PARAM_WIDTH-1:0];


  reg                                         flush;
  always @(posedge clk)
  begin
    if (reset || ic_inc)
      flush <= 1'b0;
    else if (state == BUSY && ih == param_ih && ih_inc)
      flush <= 1'b1;
  end

  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  ih_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( ih_max                   ),  //input
    .INC                      ( ih_inc                   ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( ih_min                   ),  //input
    .MAX_COUNT                ( ih_max_pad               ),  //input
    .OVERFLOW                 ( next_ic                  ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( ih                       )   //output
  );
// ==================================================================

// ==================================================================
// Input FM channels
// ==================================================================
  assign ic_inc = next_ic && ih_inc && state == BUSY;
  assign ic_max = param_ic;
  wire [ PARAM_C_WIDTH    -1 : 0 ]        ic_min;
  assign ic_min = GND[PARAM_C_WIDTH-1:0];
  counter #(
    .COUNT_WIDTH              ( PARAM_C_WIDTH        )
  )
  ic_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( ic_max                   ),  //input
    .INC                      ( ic_inc                   ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( ic_min                   ),  //input
    .MAX_COUNT                ( ic_max                   ),  //input
    .OVERFLOW                 ( next_oc                  ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( ic                       )   //output
  );
// ==================================================================

// ==================================================================
// Output FM channels
// ==================================================================
  assign oc_inc = next_oc && ic_inc && state == BUSY;
  assign oc_max = param_oc;
  assign oc_min = GND[PARAM_C_WIDTH-1:0];
  counter #(
    .COUNT_WIDTH              ( PARAM_C_WIDTH        )
  )
  oc_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( oc_max                   ),  //input
    .INC                      ( oc_inc                   ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( oc_min                   ),  //input
    .MAX_COUNT                ( oc_max                   ),  //input
    .OVERFLOW                 ( next_l                   ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( oc                       )   //output
  );
// ==================================================================

// ==================================================================
// Layer count
// ==================================================================
  assign l_inc = next_l && oc_inc && state == BUSY;
  assign l_max = max_layers;
  assign l_clear = state == IDLE;
  wire [LAYER_PARAM_WIDTH-1:0] l_min, l_default;
  assign l_default = GND[LAYER_PARAM_WIDTH-1:0];
  assign l_min = GND[LAYER_PARAM_WIDTH-1:0];
  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  l_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( l_clear                  ),  //input
    .DEFAULT                  ( l_default                ),  //input
    .INC                      ( l_inc                    ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( l_min                    ),  //input
    .MAX_COUNT                ( l_max                    ),  //input
    .OVERFLOW                 ( next_fm                  ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( l                        )   //output
  );

  assign done = next_fm && l_inc;
// ==================================================================

// ==================================================================
  assign vectorgen_cfg  = {param_conv_stride_d, pad_w};
// ==================================================================

// ==================================================================
// Vectorgen Ctrl Logic
// ==================================================================


  // Pipeline register to improve timing - BEGIN
  reg [LAYER_PARAM_WIDTH-1:0] iw_max_minus_one;
  reg [LAYER_PARAM_WIDTH-1:0] ih_max_minus_one;
  reg param_iw_is_zero;
  reg [PARAM_C_WIDTH-1:0] param_ic_d;

  always @(posedge clk)
    if (reset)
      param_iw_is_zero <= 1'b0;
    else
      param_iw_is_zero <= param_iw == 0;

  always @(posedge clk)
    if (reset)
      param_ic_d <= 1'b0;
    else
      param_ic_d <= param_ic;

  always @(posedge clk)
    if (reset)
      iw_max_minus_one <= 0;
    else if (state == RD_CFG_2)
      iw_max_minus_one <= param_iw - 1;

  always @(posedge clk)
    if (reset)
      ih_max_minus_one <= 0;
    else if (state == RD_CFG_2)
      ih_max_minus_one <= param_ih - 1;

  reg iw_is_max;
  reg ih_is_max;
  always @(posedge clk)
    if (reset)
      iw_is_max <= 0;
    else if (state == RD_CFG_2)
      iw_is_max <= (iw_max == 0);
    else if (iw_inc || state_d == RD_CFG_2)
      iw_is_max <= (iw == iw_max_minus_one) || (iw_max == 0);

  always @(posedge clk)
    if (reset)
      ih_is_max <= 0;
    else if (state == RD_CFG_2)
      ih_is_max <= (ih_max == 0);
    else if (ih_inc || state_d == RD_CFG_2)
      ih_is_max <= (ih == ih_max_minus_one) || (ih_max == 0);

  reg [PARAM_C_WIDTH-1:0] param_ic_minus_2;
  reg [PARAM_C_WIDTH-1:0] param_ic_minus_1;
  reg [PARAM_C_WIDTH-1:0] param_oc_minus_1;
  reg ic_is_zero;
  always @(posedge clk)
    if (reset)
      param_ic_minus_2 <= 'b0;
    else
      param_ic_minus_2 <= param_ic - 2;

  always @(posedge clk)
    if (reset)
      param_oc_minus_1 <= 'b0;
    else
      param_oc_minus_1 <= param_oc - 1;

  always @(posedge clk)
    if (reset)
      param_ic_minus_1 <= 'b0;
    else
      param_ic_minus_1 <= param_ic - 1;

  reg ic_is_max_minus_1;
  reg oc_is_max;
  reg ic_is_max;

  always @(posedge clk)
    if (reset)
      ic_is_max_minus_1 <= 1'b0;
    else if (ic_inc)
      ic_is_max_minus_1 <= (ic == param_ic_minus_2);

  always @(posedge clk)
    if (reset)
      ic_is_max <= 0;
    else if (state == RD_CFG_2)
      ic_is_max <= ic == param_ic;
    else if (ic_inc)
      ic_is_max <= ic == param_ic_minus_1;

  always @(posedge clk)
    if (reset)
      ic_is_zero <= 0;
    else if (state == RD_CFG_2 && param_ic == 0)
      ic_is_zero <= 1;
    else if (ic_inc)
      ic_is_zero <= (ic_is_max) || (param_ic == 0);

  always @(posedge clk)
    if (reset)
      oc_is_max <= 0;
    else if (state == RD_CFG_2)
      oc_is_max <= (param_oc == 0);
    // else if (oc_inc || state_d == RD_CFG_2)
    else if (oc_inc)
      oc_is_max <= (oc == param_oc_minus_1);


  always @(posedge clk)
    if (reset)
      iw_is_max <= 0;
    else if (state == RD_CFG_2)
      iw_is_max <= (iw_max == 0);
    else if (iw_inc || state_d == RD_CFG_2)
      iw_is_max <= (iw == iw_max_minus_one) || (iw_max == 0);

  // Pipeline register to improve timing - BEGIN



  assign vectorgen_nextfm     = l_inc || (ic_inc && l_type != L_IP);
  assign vectorgen_start      = start || ((l_inc_d || ic_inc_d && l_type != L_IP) && state != IDLE);
  assign vectorgen_endrow     = vectorgen_pop && (iw == endrow_iw) && !skip;
  assign vectorgen_skip       = !(flush) && (state == BUSY) &&
                                skip &&
                                (kw == 0) &&
                                (kh == kh_min_stride && !kh_min_dec_d) &&
                                (iw_is_max) &&
                                !(ih_is_max);// && !data_stall_d;
  assign vectorgen_nextrow    = !(flush) && (vectorgen_pop && iw == 0);
  assign vectorgen_pop        = !(flush) && (kw == 0) && state == BUSY;
  assign vectorgen_shift      = !(flush) && (kw != 0) && state == BUSY;
  //assign vectorgen_readData   = !(flush) && !((iw == 0) && (ih == 0) && !(l_type == L_IP)) && iw_inc_d;
  assign vectorgen_readData   = ((!(flush) && (kw == 0 && kh == kh_min_stride && !kh_min_dec_d) && !(iw_is_max && ih_is_max)) || l_type == L_IP) && state == BUSY;// && !data_stall_d;
  assign vectorgen_nextData   = !(flush) && vectorgen_readData &&
                                (!ih_is_max || iw != endrow_iw || skip);

  wire                                        vectorgen_lastData;
  assign vectorgen_lastData   = vectorgen_nextData &&
    (l_type == L_CONV || l_type == L_NORM) && ((ih_is_max && iw == endrow_iw - 1) || (param_iw_is_zero && ih == param_ih - 1) && !skip) ||
    l_type == L_IP && (ic_is_max_minus_1 && oc_is_max);

  reg vectorgen_lastData_d;
  always @(posedge clk)
    vectorgen_lastData_d <= vectorgen_lastData;

  register #(
    .NUM_STAGES               ( 0                        ),
    .DATA_WIDTH               ( 1                        )
  ) pop_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( vectorgen_pop            ),
    .DOUT                     ( vectorgen_pop_dd         )
  );

  register #(
    .NUM_STAGES               ( 0                        ),
    .DATA_WIDTH               ( 1                        )
  ) shift_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( vectorgen_shift          ),
    .DOUT                     ( vectorgen_shift_dd       )
  );

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( 1                        )
  ) nextfm_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( vectorgen_nextfm         ),
    .DOUT                     ( vectorgen_nextfm_dd      )
  );

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( 1                        )
  ) ih_inc_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( ih_inc                   ),
    .DOUT                     ( ih_inc_d                 )
  );

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( 1                        )
  ) iw_inc_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( iw_inc                   ),
    .DOUT                     ( iw_inc_d                 )
  );

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( 1                        )
  ) iw_inc_delay2 (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( iw_inc_d                 ),
    .DOUT                     ( iw_inc_dd                )
  );

  register #(
    .NUM_STAGES               ( 0                        ),
    .DATA_WIDTH               ( 1                        )
  ) skip_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( vectorgen_skip ),
    .DOUT                     ( vectorgen_skip_dd        )
  );

  register #(
    .NUM_STAGES               ( 8                        ),
    .DATA_WIDTH               ( 1                        )
  ) l_inc_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( l_inc                    ),
    .DOUT                     ( l_inc_d                  )
  );

  register #(
    .NUM_STAGES               ( 8                        ),
    .DATA_WIDTH               ( 1                        )
  ) ic_inc_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( ic_inc                   ),
    .DOUT                     ( ic_inc_d                 )
  );

  assign vectorgen_ctrl = {
    vectorgen_nextData,
    vectorgen_lastData,
    vectorgen_pop_dd,
    vectorgen_shift_dd,
    vectorgen_nextrow,
    vectorgen_skip_dd,
    vectorgen_endrow,
    vectorgen_start,
    vectorgen_nextfm_dd};
// ==================================================================


// ==================================================================
// PE Ctrl logic
// ==================================================================

  assign _pe_enable = state == BUSY && !flush && !data_stall;

  //assign _pe_op_code = (kw != 0 || (l_type == L_IP && ic != 0)) ? OP_MUL_ACC: (l_type == L_CONV) ? OP_MUL_ADD : OP_MUL;

  always @(*)
  begin
    case (l_type)
      L_CONV: _pe_op_code = conv_op_code;
      L_IP: _pe_op_code = ip_op_code;
      L_NORM: _pe_op_code = norm_op_code;
    endcase
  end

  assign conv_op_code = (kw != 0) ? OP_MUL_ACC : OP_MUL_ADD;
  assign ip_op_code = (!ic_is_zero) ? OP_MUL_ACC : OP_MUL;
  assign norm_op_code = (kw != 0) ? OP_SQ_ACC : (kh == param_kh || ih == 0) ? OP_SQ : OP_SQ_ADD;


  assign _pe_fifo_push = (l_type != L_IP) && (kh_dec && (kh != 0 || !ic_is_max) ||
    (dst_sel == `DST_PE_BUFFER && out_sel == `OUT_PE && _pe_write_valid));
  // -- assign _pe_fifo_pop = ((kw == kw_max && kw_inc &&
  // --   (kh != kh_min || kh_max != param_kh)) &&
  // --   (ih != 0)) || (state == RD_CFG_1);
  // TODO: Change this. Too complex
  assign _pe_fifo_pop = ((kw == 0 && kw_inc &&
    (kh != param_kh || !ic_is_zero)) &&
    (ih != 0 || !ic_is_zero)) || (state == RD_CFG_1 && !ic_is_zero);
  assign _pe_write_valid = kh_dec && (kh == 0) && ic_is_max;

  register #(
    .NUM_STAGES               ( 6                        ),
    .DATA_WIDTH               ( 1                        )
  ) pe_fifo_push_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_fifo_push            ),
    .DOUT                     ( pe_fifo_push             )
  );

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( 1                        )
  ) pe_fifo_pop_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_fifo_pop             ),
    .DOUT                     ( pe_fifo_pop              )
  );

  register #(
    .NUM_STAGES               ( 7                        ),
    .DATA_WIDTH               ( 1                        )
  ) pe_write_valid_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_write_valid          ),
    .DOUT                     ( pe_write_valid           )
  );

  register #(
    .NUM_STAGES               ( 3                        ),
    .DATA_WIDTH               ( 1                        )
  ) pe_enable_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_enable               ),
    .DOUT                     ( pe_enable                )
  );

  register #(
    .NUM_STAGES               ( 3                        ),
    .DATA_WIDTH               ( PE_OP_CODE_WIDTH         )
  ) pe_op_code_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_op_code              ),
    .DOUT                     ( pe_op_code               )
  );

  wire _pe_flush, pe_flush;
  assign _pe_flush = flush;

  register #(
    .NUM_STAGES               ( 3                        ),
    .DATA_WIDTH               ( 1                        )
  ) pe_flush_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_flush                ),
    .DOUT                     ( pe_flush                 )
  );

  assign pe_ctrl = {
    pe_norm_fifo_push,
    pe_norm_fifo_pop,
    pe_buf_rd_addr,
    pe_buf_wr_addr,
    pe_flush,
    pe_write_valid,
    pe_fifo_push,
    pe_fifo_pop||pe_piso_read_req,
    pe_enable,
    pe_op_code
  };

  wire [ SERDES_COUNT_W       -1 : 0 ]        _pu_serdes_count;
  assign _pu_serdes_count =
    (l_type == L_CONV || l_type == L_NORM) && iw_is_max ? serdes_count : NUM_PE;
  reg [SERDES_COUNT_W-1:0] _pu_serdes_count_d;

  always @(posedge clk)
    if (reset)
      _pu_serdes_count_d <= NUM_PE;
    else if (state == BUSY && iw_is_max)
      _pu_serdes_count_d <= _pu_serdes_count;

  register #(
    .NUM_STAGES               ( 7                        ),
    .DATA_WIDTH               ( SERDES_COUNT_W           )
  ) pu_serdes_count_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pu_serdes_count_d       ),
    .DOUT                     ( pu_serdes_count          )
  );
// ==================================================================


// ==================================================================
// PE Normalization FIFO
// ==================================================================

  wire pe_norm_fifo_push;
  wire _pe_norm_fifo_push;
  wire pe_norm_fifo_pop;
  wire _pe_norm_fifo_pop;

  reg [1:0] curr_layer_type;
  always @(posedge clk)
    if (state == RD_CFG_2)
      curr_layer_type <= l_type;

  wire _lrn_enable;
  assign _lrn_enable = curr_layer_type == L_NORM;
  always @(posedge clk)
    if (reset)
      lrn_enable <= 1'b0;
    else if (pe_write_valid)
      lrn_enable <= curr_layer_type == L_NORM;
  //assign lrn_enable = curr_layer_type == L_NORM;

  assign _pe_norm_fifo_push = (!flush) && (curr_layer_type == L_NORM) && kw_inc && (kw == (param_kw >> 1)) && (kh == (param_kh) >> 1);
  assign _pe_norm_fifo_pop = (curr_layer_type == L_NORM) && _pe_write_valid;

  register #(
    .NUM_STAGES               ( 3                        ),
    .DATA_WIDTH               ( 1                        )
  ) norm_fifo_push_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_norm_fifo_push       ),
    .DOUT                     ( pe_norm_fifo_push        )
  );

  register #(
    .NUM_STAGES               ( 6                        ),
    .DATA_WIDTH               ( 1                        )
  ) norm_fifo_pop_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_norm_fifo_pop        ),
    .DOUT                     ( pe_norm_fifo_pop         )
  );

`ifdef simulation
  integer norm_fifo_push_count;
  integer norm_fifo_pop_count;
  always @(posedge clk)
    if (reset)
      norm_fifo_push_count <= 0;
    else if (pe_norm_fifo_push)
      norm_fifo_push_count <= norm_fifo_push_count + 1;
  always @(posedge clk)
    if (reset)
      norm_fifo_pop_count <= 0;
    else if (pe_norm_fifo_pop)
      norm_fifo_pop_count <= norm_fifo_pop_count + 1;
`endif

// ==================================================================


// ==================================================================
// Weight Address calculation
// ==================================================================

  wire [ WEIGHT_ADDR_WIDTH    -1 : 0 ]        _wb_read_addr;
  wire                                        _wb_read_req;

  register #(
    .NUM_STAGES               ( 0                        ),
    .DATA_WIDTH               ( 1                        )
  ) wb_req_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _wb_read_req             ),
    .DOUT                     ( wb_read_req              )
  );

  assign param_kw_reduced = param_kw;
  assign param_kh_reduced = param_kh;
  assign _wb_read_addr = (l_type == L_CONV) ?
    (param_kh-kh) * (param_kw+1) + kw + 0 :
    ic+0;

  reg  [ WEIGHT_ADDR_WIDTH    -1 : 0 ]        wb_addr;
  always @(posedge clk)
  begin: ADDRGEN_WB
    if (reset)
      wb_addr <= 0;
    else if (state == RD_CFG_2)
      wb_addr <= 0;
    else if (iw_inc)
      wb_addr <= (param_kh_reduced - kh_max_stride) * (param_kw_reduced+1);
    else if (kh_dec)
      wb_addr <= wb_addr + (param_kw_reduced+1) * (conv_stride_max-1) + 1;
    else if (kw_inc)
      wb_addr <= wb_addr + 1;
  end

  wire [ PARAM_C_WIDTH    -1 : 0 ]        FC_layer_neuron_idx;

  wire [ WEIGHT_ADDR_WIDTH    -1 : 0 ]        dbg_addr;
  reg  [ WEIGHT_ADDR_WIDTH    -1 : 0 ]        dbg_addr_d;
  assign dbg_addr = (l_type == L_CONV) ? wb_addr : FC_layer_neuron_idx;
  always @(posedge clk)
    if (reset)
      dbg_addr_d <= 0;
    else if (state == RD_CFG_2)
      dbg_addr_d <= 0;
    else
      dbg_addr_d <= dbg_addr;

  assign wb_read_addr = dbg_addr;


  assign _wb_read_req = (state == BUSY || state == RD_CFG_1) && src_1_sel == `SRC_1_WEIGHT_BUFFER;
  assign pe_piso_read_req = 1'b0;

// ==================================================================
// PE Buffer neuron Index
// ==================================================================
/* Using a counter to generate the PE buffer index; */

  //assign FC_layer_neuron_idx = ic+0;

  wire [ PE_SEL_W-1:0] pe_sel_default;
  wire  pe_sel_inc;
  wire  pe_sel_clear;
  wire [ PE_SEL_W-1:0] pe_sel_min;
  wire [ PE_SEL_W-1:0] pe_sel_max;
  wire next_neuron_idx;
  wire [ PE_SEL_W-1:0] pe_sel_count;

  assign pe_sel_default = 'b0;
  assign pe_sel_inc = kw_inc && !data_stall && l_type == L_IP && (ic!=0);
  assign pe_sel_min = 'b0;
  assign pe_sel_max = NUM_PE-1;
  assign pe_sel_clear = oc_inc;

  wire  [ PE_SEL_W             -1 : 0 ]        _pe_neuron_sel;
  assign _pe_neuron_sel = pe_sel_count;

  assign pe_neuron_read_req = (src_1_sel == `SRC_1_PE_BUFFER) && (state == BUSY);

  wire _pe_neuron_bias;
  assign _pe_neuron_bias = (l_type == L_IP) && ic == 0;

   register #(
    .NUM_STAGES               ( 4                        ),
    .DATA_WIDTH               ( PE_SEL_W                 )
  ) pe_neuron_sel_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_neuron_sel           ),
    .DOUT                     ( pe_neuron_sel            )
  );

   register #(
    .NUM_STAGES               ( 4                        ),
    .DATA_WIDTH               ( 1                        )
  ) pe_neuron_bias_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_neuron_bias           ),
    .DOUT                     ( pe_neuron_bias            )
  );

  counter #(
    .COUNT_WIDTH              ( PE_SEL_W                 )
  )
  pe_sel_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( pe_sel_clear             ),  //input
    .DEFAULT                  ( pe_sel_default           ),  //input
    .INC                      ( pe_sel_inc               ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( pe_sel_min               ),  //input
    .MAX_COUNT                ( pe_sel_max               ),  //input
    .OVERFLOW                 ( next_neuron_idx          ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( pe_sel_count             )   //output
  );

  wire [ PE_BUF_ADDR_WIDTH-1:0] neuron_idx_default;
  wire  neuron_idx_inc;
  wire  neuron_idx_clear;
  wire [ PE_BUF_ADDR_WIDTH-1:0] neuron_idx_min;
  wire [ PE_BUF_ADDR_WIDTH-1:0] neuron_idx_max;
  wire [ PE_BUF_ADDR_WIDTH-1:0] neuron_idx_count;

  assign neuron_idx_default = 'b0;
  assign neuron_idx_inc = next_neuron_idx && pe_sel_inc;
  assign neuron_idx_min = 'b0;
  assign neuron_idx_max = 1<<PE_BUF_ADDR_WIDTH-1;
  assign neuron_idx_clear = oc_inc;

  assign FC_layer_neuron_idx = neuron_idx_count;

  counter #(
    .COUNT_WIDTH              ( PE_BUF_ADDR_WIDTH        )
  )
  FC_neuron_idx_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( neuron_idx_clear         ),  //input
    .DEFAULT                  ( neuron_idx_default       ),  //input
    .INC                      ( neuron_idx_inc           ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( neuron_idx_min           ),  //input
    .MAX_COUNT                ( neuron_idx_max           ),  //input
    .OVERFLOW                 (                          ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( neuron_idx_count         )   //output
  );

// ==================================================================

// ==================================================================
// PE Buffer Address
// ==================================================================

  wire [ PE_BUF_ADDR_WIDTH    -1 : 0 ]        scratch_space;
  assign scratch_space = 10'd896;
  reg  [ 7                    -1 : 0 ]        scratch_read_addr;
  reg  [ 7                    -1 : 0 ]        scratch_write_addr;

  reg  [ PE_BUF_ADDR_WIDTH    -1 : 0 ]        result_write_addr;
  reg  [ PE_BUF_ADDR_WIDTH    -1 : 0 ]        result_read_addr;

  always @(posedge clk)
  begin
    if(reset || state_dd == RD_CFG_1)
      scratch_read_addr <= 0;
    else if (pe_fifo_pop && ! scratch_switch_read && state_dd == BUSY)
      scratch_read_addr <= scratch_read_addr + 1;
  end

  always @(posedge clk)
  begin
    if(reset || state_dd == RD_CFG_1)
      scratch_write_addr <= 0;
    else if (pe_fifo_push && !scratch_switch_write && state == BUSY)
      scratch_write_addr <= scratch_write_addr + 1;
  end

  wire                                        _scratch_switch_write;
  wire                                        _scratch_switch_read;
  wire                                        scratch_switch_write;
  wire                                        scratch_switch_read;

  assign _scratch_switch_write = kh_dec && (kh == 0); // 1: buffer, 0:scratch

  assign _scratch_switch_read = (!ic_is_zero) && ((kw == 0 && kw_inc &&
    (kh == param_kh || ih == 0))) || (l_type == L_IP);

  wire                                        wr_addr_clear;
  wire                                        _wr_addr_clear;
   register #(
    .NUM_STAGES               ( 7                        ),
    .DATA_WIDTH               ( 1                        )
  ) wr_addr_clear_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _wr_addr_clear           ),
    .DOUT                     ( wr_addr_clear            )
  );

  assign _wr_addr_clear = state == RD_CFG_1;

  always @(posedge clk)
  begin
    if(reset)
      result_write_addr <= 0;
    else if (wr_addr_clear)
      result_write_addr <= 0;
    else if (scratch_switch_write)
      result_write_addr <= result_write_addr + 1;
  end

  reg [LAYER_PARAM_WIDTH-1:0] param_iw_plus_one;
  always @(posedge clk)
    if (reset)
      param_iw_plus_one <= 'b0;
    else if (state == RD_CFG_2)
      param_iw_plus_one <= (param_iw + 1);

  always @(posedge clk)
  begin
    if(reset)
      result_read_addr <= 0;
    else if (state_d == RD_CFG_2)
      result_read_addr <= result_read_pad_offset;
    else if (scratch_switch_read && pe_fifo_pop && ih != 0)
      result_read_addr <= result_read_addr + 1;
    else if (scratch_switch_read && pe_fifo_pop && kh == kh_min_stride && ih == 0)
      result_read_addr <= result_read_pad_offset;
    else if (scratch_switch_read && pe_fifo_pop)
      result_read_addr <= result_read_addr - param_iw_plus_one;
  end

  reg [LAYER_PARAM_WIDTH-1:0] result_read_pad_offset;
  wire                                        pad_offset_inc;
  assign pad_offset_inc = ih == 0 && kw == 0 && kh == kh_min_stride && kw_inc;
  always @(posedge clk)
    if (reset)
      result_read_pad_offset <= 0;
    else if (state == RD_CFG_1)
      result_read_pad_offset <= (param_iw+1) * pad_r_s;
    else if (pad_offset_inc)
      result_read_pad_offset <= result_read_pad_offset + 1;

  //always @(posedge clk)
  //begin: MACC_RESULT_READ_ADDR
  //  if (reset)
  //    result_read_addr <= 0;
  //  else
  //    result_read_addr <= iw + (ih + kh - param_kh + pad_r_s) * param_iw_plus_one;
  //end

  register #(
    .NUM_STAGES               ( 6                        ),
    .DATA_WIDTH               ( 1                        )
  ) scratch_sw_rd_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _scratch_switch_write    ),
    .DOUT                     ( scratch_switch_write     )
  );

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( 1                        )
  ) scratch_sw_wr_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _scratch_switch_read     ),
    .DOUT                     ( scratch_switch_read      )
  );

  assign pe_buf_rd_addr = (l_type == L_CONV || l_type == L_NORM) ? scratch_switch_read ? result_read_addr : scratch_space + scratch_read_addr :
    wb_read_addr;
  assign pe_buf_wr_addr = scratch_switch_write ? result_write_addr :
    scratch_space + scratch_write_addr;
// ==================================================================

// ==================================================================
// Operand select
// ==================================================================

  wire  [ `SRC_1_SEL_WIDTH     -1 : 0 ]        _src_1_sel;

  reg[`OUT_SEL_WIDTH-1:0]_out_sel;
// Modifying so we don't skip normalization outputs
  always @(posedge clk)
  begin
    if (reset)
      _out_sel <= `OUT_POOL;
    else if (_pe_write_valid) begin
      if (_out_sel == `OUT_POOL && !param_pool_enable)
        _out_sel <= `OUT_PE;
      else if (_out_sel == `OUT_PE && param_pool_enable)
        _out_sel <= `OUT_POOL;
    end
  end

  assign src_0_sel = `SRC_0_DDR;
  assign _src_1_sel = (l_type == L_CONV || l_type == L_NORM) ? `SRC_1_WEIGHT_BUFFER : `SRC_2_PE_BUFFER;
  assign src_2_sel = (((kh == param_kh || (ih == 0)) && ic_is_zero) || l_type == L_IP) && state ==BUSY ? `SRC_2_BIAS : `SRC_2_PE_BUFFER;
  assign dst_sel   = `DST_PE_BUFFER;//DST_DDR;

  assign bias_read_req = (state == WAIT) && (state_d != WAIT);

  //assign _out_sel = pool_enable && state==BUSY ? 1'b1 : 1'b0;
  register #(
    .NUM_STAGES               ( 6                        ),
    .DATA_WIDTH               ( 1                        )
  ) out_sel_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _out_sel                 ),
    .DOUT                     ( out_sel                  )
  );

  register #(
    .NUM_STAGES               ( 6                        ),
    .DATA_WIDTH               ( 1                        )
  ) src_1_sel_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _src_1_sel               ),
    .DOUT                     ( src_1_sel                )
  );

// ==================================================================

// ==================================================================
  /** Masking logic
    * Each PE has a thread ID.
    * When thread ID exceeds input width,
    * set valid for that PE to be 0. */
// ==================================================================

  reg                                         vectorgen_nextfm_d;

  assign tid_reset  = (ih!=0 && ih_inc_d) || vectorgen_nextfm_d;
  assign tid_inc    = (l_type == L_IP) ? oc_inc : iw_inc;

  reg                                         tid_inc_d;
  always @(posedge clk)
    tid_inc_d <= tid_inc;

  always @(posedge clk)
    vectorgen_nextfm_d <= vectorgen_nextfm;

  genvar gen;
  generate
  for (gen=0; gen<NUM_PE; gen=gen+1)
  begin: THREAD_LOGIC

    always @(posedge clk)
    begin
      if (reset || tid_reset)
        tid[gen] <= gen;
      else if (tid_inc_d)
        tid[gen] <= tid[gen] + NUM_PE;
    end

    always @(posedge clk)
    begin
      //mask[gen] <= 1'b1; //tid[gen] < max_threads;
      mask[gen] <= tid[gen] < max_threads;
    end

  end
  endgenerate

  assign _pe_write_mask = mask;

  register #(
    .NUM_STAGES               ( 1                        ),
    .DATA_WIDTH               ( NUM_PE                   )
  ) pe_write_mask_delay (
    .CLK                      ( clk                      ),
    .RESET                    ( reset                    ),
    .DIN                      ( _pe_write_mask           ),
    .DOUT                     ( pe_write_mask            )
  );

  // Debug
  wire [TID_WIDTH-1:0]      pe0_tid = tid[0];
  wire [TID_WIDTH-1:0]      pe1_tid = tid[1];
  wire [TID_WIDTH-1:0]      pe2_tid = tid[2];
  wire [TID_WIDTH-1:0]      pe3_tid = tid[3];
// ==================================================================

// ==================================================================
// Pooling control logic
// ==================================================================

  assign p_min = 'b0;
  assign p_max = (1<<4)-1;
  assign p_inc = pe_write_valid && out_sel;
  assign p_dec = _pool_in_pop && !pool_pad_row;
  assign p_default = GND[LAYER_PARAM_WIDTH-1:0];

  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  p_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( p_default                ),  //input
    .INC                      ( p_inc                    ),  //input
    .DEC                      ( p_dec                    ),  //input
    .MIN_COUNT                ( p_min                    ),  //input
    .MAX_COUNT                ( p_max                    ),  //input
    .OVERFLOW                 ( p_stall                  ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( p_count                  )   //output
  );

  reg stride_state, next_stride_state;
  always @(posedge clk)
    if(reset)
      stride_state <= 1'b0;
    else
      stride_state <= next_stride_state;
  always @(*)
  begin
    next_stride_state = stride_state;
    case (stride_state)
      0: if (pool_in_pop)
        next_stride_state = 1;
      1: if (pool_iw_inc)
        next_stride_state = 0;
    endcase
  end

  assign stride_inc = pool_enable && (stride_state ? (pool_ready || pool_iw_count == pool_iw_max) : pool_in_pop);
  assign stride_min = 0;
  assign stride_max = ceil_a_by_b(NUM_PE, 2) - 1;
  assign stride_default = GND[LAYER_PARAM_WIDTH];

  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  stride_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( stride_default           ),  //input
    .INC                      ( stride_inc               ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( stride_min               ),  //input
    .MAX_COUNT                ( stride_max               ),  //input
    .OVERFLOW                 ( next_pool_iw             ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( stride_count             )   //output
  );

  register#(0, 1) pool_in_pop_delay (clk, reset, _pool_in_pop, pool_in_pop);
  register#(2, 1) pool_in_shift_delay (clk, reset, _pool_in_shift, pool_in_shift);

  assign pool_iw_inc = next_pool_iw && stride_inc;
  assign pool_iw_min = 0;
  //assign pool_iw_max = param_pool_iw;
  always @(posedge clk)
    if (reset)
      pool_iw_max <= 0;
    else if (pool_ih_count == 0)
      pool_iw_max <= param_pool_iw;
  always @(posedge clk)
    if (reset)
      pe_iw_max <= 0;
    else if (pool_ih_count == 0)
      pe_iw_max <= param_iw;

  assign pool_iw_default = GND[LAYER_PARAM_WIDTH-1:0];

  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  pool_iw_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( pool_iw_default          ),  //input
    .INC                      ( pool_iw_inc              ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( pool_iw_min              ),  //input
    .MAX_COUNT                ( pool_iw_max              ),  //input
    .OVERFLOW                 ( next_pool_ih             ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( pool_iw_count            )   //output
  );

  assign pool_ih_inc = next_pool_ih && pool_iw_inc;
  assign pool_ih_min = 0;
  assign pool_ih_default = 0;
  //assign pool_ih_max = param_oh;
  always@(posedge clk)
  begin
    if (reset) pool_ih_max <= 0;
    else if (pool_ih_count == 0) pool_ih_max <= param_oh;
  end

  counter #(
    .COUNT_WIDTH              ( LAYER_PARAM_WIDTH        )
  )
  pool_ih_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( pool_ih_default          ),  //input
    .INC                      ( pool_ih_inc              ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( pool_ih_min              ),  //input
    .MAX_COUNT                ( pool_ih_max              ),  //input
    .OVERFLOW                 ( pool_ih_stall            ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( pool_ih_count            )   //output
  );

  register#(5, 1)
  row_fifo_push_delay (clk, reset, _row_fifo_push, row_fifo_push);
  register#(2, 1)
  row_fifo_pop_delay (clk, reset, _row_fifo_pop, row_fifo_pop);
  register#(5, 1)
  row_fifo_mux_sel_delay (clk, reset, _row_fifo_mux_sel, row_fifo_mux_sel);
  register#(5, 1)
  pool_valid_delay (clk, reset, _pool_valid, pool_valid);
  register#(3, 1)
  ks_sw_delay (clk, reset, _kernel_size_switch, kernel_size_switch);

  assign pool_ready = (p_count != 0) || pad_iw || pool_ready_last;
  assign pad_iw = pool_iw_count == pool_iw_max && pool_iw_count!=pe_iw_max;

  reg                                         pool_ready_last;
  always @(posedge clk)
    if (reset)
      pool_ready_last <= 0;
    else if (pool_iw_inc || pool_in_pop)
      pool_ready_last <= p_count != 0;

  assign _pool_in_pop = stride_count == 0 && pool_ready && pool_enable;
  assign _pool_in_shift = !_pool_in_pop && stride_inc;
  assign row_fifo_en =
    (_pool_in_shift || _pool_in_pop) &&
    (pool_ready || pool_iw_count == pool_iw_max);
  assign _row_fifo_push = row_fifo_en && !(pool_ih_count == pool_ih_max);
  assign _row_fifo_pop = row_fifo_en && pool_ih_count != 0;
  assign _row_fifo_mux_sel = (pool_ih_count[0] == 0);
  assign _pool_valid =
    (_pool_in_shift || _pool_in_pop) &&
    ((pool_ih_count == pool_ih_max) ||
    ((pool_kernel == 3) ?
    (pool_ih_count[0] == 0 && pool_ih_count != 0) :
    (pool_ih_count[0] == 1)));

  assign pool_endrow = ((pool_iw_count == pool_iw_max) ||
                       (pool_iw_count == pe_iw_max)) &&
                       (stride_count == stride_max);
  assign _kernel_size_switch = pool_kernel == 3 && !pool_endrow;
  assign pool_stride = 2'd2;
  assign pool_cfg = {kernel_size_switch, pool_stride};

  assign _pool_pad_row = (stride_count == stride_max) &&
                         (pool_iw_count == pe_iw_max) &&
                         (pe_iw_max != pool_iw_max);
  register#(1, 1)
  pool_pad_row_delay (clk, reset, _pool_pad_row, pool_pad_row);
  wire                                        pool_pad_d;
  register#(1, 1)
  pool_pad_delay (clk, reset, _pool_pad_row && stride_inc, pool_pad_d);

  assign pool_ctrl = {
    pool_pad_d,
    pool_valid,
    row_fifo_mux_sel,
    row_fifo_pop,
    row_fifo_push,
    pool_in_pop,
    pool_in_shift};

  assign pool_done =
    (pool_ih_count == pool_ih_max)
    && (pool_iw_count == pool_iw_max);

// ==================================================================


`ifdef simulation
  wire [ LAYER_PARAM_WIDTH    -1 : 0 ]        layer_count;
  assign layer_count = l;
`endif

reg [16-1:0] kw_inc_count;
always @(posedge clk)
  if (reset)
    kw_inc_count <= 0;
  else if (kw_inc)
    kw_inc_count <= kw_inc_count + 1'b1;

assign dbg_kw = param_kw;
assign dbg_kh = param_kh;
assign dbg_iw = param_iw;
assign dbg_ih = param_ih;
assign dbg_ic = param_ic;
assign dbg_oc = param_oc;


// ==================================================================
// DEBUG
// ==================================================================
//register #(2, LAYER_PARAM_WIDTH)
//dbg_reg_kw (clk, reset, kw, dbg_kw);
// register #(2, LAYER_PARAM_WIDTH)
// dbg_reg_kh (clk, reset, kh, dbg_kh);
// register #(2, LAYER_PARAM_WIDTH)
// dbg_reg_iw (clk, reset, iw, dbg_iw);
// register #(2, LAYER_PARAM_WIDTH)
// dbg_reg_ih (clk, reset, ih, dbg_ih);
// register #(2, LAYER_PARAM_WIDTH)
// dbg_reg_ic (clk, reset, ic, dbg_ic);
// register #(2, LAYER_PARAM_WIDTH)
// dbg_reg_oc (clk, reset, oc, dbg_oc);
// ==================================================================

endmodule
