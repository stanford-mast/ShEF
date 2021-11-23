`timescale 1ns/1ps
`include "common.vh"
`include "dw_params.vh"
module mem_controller
#( // INPUT PARAMETERS
  parameter integer NUM_PE            = 4,
  parameter integer NUM_PU            = 2,
  parameter integer ADDR_W            = 32,
  parameter integer BASE_ADDR_W       = ADDR_W,
  parameter integer OFFSET_ADDR_W     = ADDR_W,
  parameter integer RD_LOOP_W         = 32,
  parameter integer TX_SIZE_WIDTH     = 20,
  parameter integer D_TYPE_W          = 2,
  parameter integer RD_ROM_ADDR_W     = `C_LOG_2(`max_rd_mem_idx+2),
  parameter integer WR_ROM_ADDR_W     = `C_LOG_2(`max_wr_mem_idx+2)
)( // PORTS
  input   wire                          clk,
  input   wire                          reset,

  input   wire                          start,
  output  wire                          done,

  // Memory Controller Interface
  output wire                           rd_req,
  input  wire                           rd_ready,
  output reg  [ TX_SIZE_WIDTH  -1 : 0 ] rd_req_size,
  output reg  [ TX_SIZE_WIDTH  -1 : 0 ] rd_rvalid_size,
  output reg  [ ADDR_W         -1 : 0 ] rd_addr,

  output wire [ PU_ID_W        -1 : 0 ] pu_id,
  output wire [ D_TYPE_W       -1 : 0 ] d_type,

  output wire                           wr_req,
  output wire [ PU_ID_W        -1 : 0 ] wr_pu_id,
  input  wire                           wr_ready,
  output reg  [ ADDR_W         -1 : 0 ] wr_addr,
  output wire [ TX_SIZE_WIDTH  -1 : 0 ] wr_req_size,
  input  wire                           wr_done,

  // Debug
  output wire [ WR_ROM_ADDR_W           -1 : 0 ]        wr_cfg_idx,
  output wire [ RD_ROM_ADDR_W           -1 : 0 ]        rd_cfg_idx
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam PU_ID_W = `C_LOG_2(NUM_PU)+1;
  localparam integer STATE_W  = 3;
  localparam integer LTYPE_W = 2;
  localparam integer RD_ROM_WIDTH = LTYPE_W + 4 * TX_SIZE_WIDTH + 7 * ADDR_W + 3 * RD_LOOP_W;
  localparam integer WR_ROM_WIDTH = LTYPE_W + (BASE_ADDR_W + OFFSET_ADDR_W + TX_SIZE_WIDTH +
                                    RD_LOOP_W);
  localparam integer RD_ROM_DEPTH = 1<<RD_ROM_ADDR_W;
  localparam integer WR_ROM_DEPTH = 1<<WR_ROM_ADDR_W;
  localparam integer IDLE = 0, RD_CFG_BUFFER = 1, RD_CFG_STREAM = 2,
  BUSY_BUFFER = 3, BUSY_STREAM = 4;
// ******************************************************************
// WIRES
// ******************************************************************
  genvar i;
  wire [ 1024                 -1 : 0 ]        GND;
  reg  [ STATE_W              -1 : 0 ]        rd_state;
  reg  [ STATE_W              -1 : 0 ]        rd_state_d;
  reg  [ STATE_W              -1 : 0 ]        next_rd_state;

  wire all_writes_done;
  wire all_reads_done;
  reg  [ STATE_W              -1 : 0 ]        wr_state;
  reg  [ STATE_W              -1 : 0 ]        wr_state_d;
  reg  [ STATE_W              -1 : 0 ]        next_wr_state;

  reg  [ RD_ROM_WIDTH         -1 : 0 ]        rd_cfg_rom [0 : RD_ROM_DEPTH - 1];
  reg  [ WR_ROM_WIDTH         -1 : 0 ]        wr_cfg_rom [0 : WR_ROM_DEPTH - 1];
  reg  [ RD_ROM_ADDR_W        -1 : 0 ]        rd_cfg_idx_max;
  reg  [ WR_ROM_ADDR_W        -1 : 0 ]        wr_cfg_idx_max;

  wire [ LTYPE_W              -1 : 0 ]        rd_l_type;
  wire [ LTYPE_W              -1 : 0 ]        wr_l_type;

  wire [ BASE_ADDR_W          -1 : 0 ]        stream_write_base_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        stream_write_size;
  wire [ OFFSET_ADDR_W        -1 : 0 ]        stream_write_offset;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_write_loop_max;

  /* Read config
  * stream_read_loop_0, 1, 2 loop over the stream data.
  * For convolution:
  * loop_0 loops over all the input feature maps
  * loop_1 then re-reads the input feature maps to generate the
  * next set of output features.
  * For normalization,
  * loop_0 reads one row of each input feature map
  * loop_1 loops over all the rows of feature maps (NUM_PU)
  * loop_2 then repeats the loop_0 and loop_1 until all the
  * feature maps are read and normalized. */
  wire [ BASE_ADDR_W          -1 : 0 ]        stream_read_base_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        stream_read_size;
  wire [ OFFSET_ADDR_W        -1 : 0 ]        stream_read_loop_0_offset;
  wire [ OFFSET_ADDR_W        -1 : 0 ]        stream_read_loop_1_offset;
  wire [ OFFSET_ADDR_W        -1 : 0 ]        stream_read_loop_2_offset;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_read_loop_0_max;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_read_loop_1_max;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_read_loop_2_max;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        stream_rvalid_size;

  wire [ BASE_ADDR_W          -1 : 0 ]        buffer_read_base_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        buffer_read_size;
  wire [ OFFSET_ADDR_W        -1 : 0 ]        buffer_read_offset;
  wire [ RD_LOOP_W            -1 : 0 ]        buffer_read_loop_max;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        buffer_rvalid_size;

  wire [ RD_ROM_ADDR_W        -1 : 0 ]        read_idx_count;
  wire [ RD_ROM_ADDR_W        -1 : 0 ]        read_idx_min;
  wire [ RD_ROM_ADDR_W        -1 : 0 ]        read_idx_max;
  wire [ RD_ROM_ADDR_W        -1 : 0 ]        read_idx_default;
  wire                                        read_idx_inc;
  wire                                        next_read;

  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop0_default;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop0_min;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop0_count;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop0_max;
  wire                                        next_stream_loop_1;
  wire                                        stream_rd_loop0_inc;

  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop1_default;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop1_min;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop1_count;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop1_max;
  wire                                        next_stream_loop_2;
  wire                                        stream_rd_loop1_inc;

  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop2_default;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop2_min;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop2_count;
  wire [ RD_LOOP_W           -1 : 0 ]         stream_rd_loop2_max;
  wire                                        next_stream_loop_3;
  wire                                        stream_rd_loop2_inc;

  wire [ RD_LOOP_W            -1 : 0 ]        buffer_rd_count_default;
  wire [ RD_LOOP_W            -1 : 0 ]        buffer_rd_count_min;
  wire [ RD_LOOP_W            -1 : 0 ]        buffer_rd_count_max;
  wire [ RD_LOOP_W            -1 : 0 ]        buffer_rd_count;
  wire                                        next_stream_read;
  wire                                        buffer_rd_count_inc;

  reg  [ RD_ROM_WIDTH         -1 : 0 ]        rd_cfg;
  reg  [ WR_ROM_WIDTH         -1 : 0 ]        write_cfg;

  wire read_throttle;

  reg [ADDR_W-1:0] buffer_read_address;
  reg [ADDR_W-1:0] stream_read_address;

  reg [ADDR_W-1:0] stream_rd_loop1_addr;
  reg [ADDR_W-1:0] stream_rd_loop2_addr;

// ******************************************************************
// Initialization
// ******************************************************************
  initial begin
    rd_cfg_idx_max = `max_rd_mem_idx;
    wr_cfg_idx_max = `max_wr_mem_idx;
    `ifdef VIVADO_SIM
      $readmemb("/home/centos/src/project_data/free/apps/dnnweaver/design/include/rd_mem_controller.vh", rd_cfg_rom);
      $readmemb("/home/centos/src/project_data/free/apps/dnnweaver/design/include/wr_mem_controller.vh", wr_cfg_rom);
    `else
      $readmemb("rd_mem_controller.dat", rd_cfg_rom);
      $readmemb("wr_mem_controller.dat", wr_cfg_rom);
    `endif
  end

// ******************************************************************
// assigns and sequential logic
// ******************************************************************
  assign GND = 1024'd0;

  assign rd_req = stream_rd_loop0_inc || (buffer_rd_count_inc && rd_l_type != 2);

  // Throttles the read to wait for write to finish
  // assign read_throttle =
  //   rd_l_type == 1 ?
  //   (rd_cfg_idx > (wr_cfg_idx))
  //   && (rd_cfg_idx != 0) :
  //   (rd_cfg_idx == (wr_cfg_idx+1))
  //   &&(stream_rd_loop0_count == stream_wr_count);
  assign read_throttle = rd_cfg_idx > wr_cfg_idx;
  reg read_throttle_d;
  always @(posedge clk)
    read_throttle_d <= (read_throttle || rd_req);

  assign d_type[0] = rd_state == BUSY_BUFFER;
  //assign d_type[1] = rd_state == BUSY_STREAM && rd_l_type == 2;
  assign d_type[1] = 1'b0;
  //assign pu_id = rd_l_type == 2 ? stream_rd_loop0_count : buffer_rd_count;
  assign pu_id = rd_l_type == 2 ? 0 : buffer_rd_count;

  assign rd_cfg_idx = read_idx_count;
  always @(posedge clk)
  begin
    rd_cfg <= rd_cfg_rom[rd_cfg_idx];
  end

  assign {
    rd_l_type,
    stream_rvalid_size,
    stream_read_base_addr,
    stream_read_size,
    stream_read_loop_0_offset,
    stream_read_loop_1_offset,
    stream_read_loop_2_offset,
    stream_read_loop_0_max,
    stream_read_loop_1_max,
    stream_read_loop_2_max,
    buffer_rvalid_size,
    buffer_read_base_addr,
    buffer_read_size,
    buffer_read_offset,
    buffer_read_loop_max
  } = rd_cfg;

  // Counter to loop over multiple buffer reads.
  assign buffer_rd_count_default = GND[RD_LOOP_W-1:0];
  assign buffer_rd_count_inc = (rd_state == BUSY_BUFFER) && rd_ready && !(read_throttle_d);
  assign buffer_rd_count_min = GND[RD_LOOP_W-1:0];
  assign buffer_rd_count_max = buffer_read_loop_max;

  // Counter to loop over multiple input feature streams.
  assign stream_rd_loop0_default = GND[RD_LOOP_W-1:0];
  assign stream_rd_loop0_inc = (rd_state == BUSY_STREAM) && rd_ready && !(read_throttle_d);
  assign stream_rd_loop0_min = GND[RD_LOOP_W-1:0];
  assign stream_rd_loop0_max = stream_read_loop_0_max;

  // Counter to loop over multiple output feature streams.
  assign stream_rd_loop1_default = GND[RD_LOOP_W-1:0];
  assign stream_rd_loop1_inc = stream_rd_loop0_inc && next_stream_loop_1;
  assign stream_rd_loop1_min = GND[RD_LOOP_W-1:0];
  assign stream_rd_loop1_max = stream_read_loop_1_max;

  // Counter to loop over multiple output feature streams.
  assign stream_rd_loop2_default = GND[RD_LOOP_W-1:0];
  assign stream_rd_loop2_inc = stream_rd_loop1_inc && next_stream_loop_2;
  assign stream_rd_loop2_min = GND[RD_LOOP_W-1:0];
  assign stream_rd_loop2_max = stream_read_loop_2_max;

  assign read_idx_inc = next_stream_loop_3 && stream_rd_loop2_inc;

  always @(posedge clk)
  begin
    if (reset)
      rd_req_size <= GND[ADDR_W-1:0];
    else if (rd_state == RD_CFG_BUFFER)
      rd_req_size <= buffer_read_size;
    else if (rd_state == RD_CFG_STREAM)
      rd_req_size <= stream_read_size;
  end

  always @(posedge clk)
  begin
    if (reset)
      rd_rvalid_size <= GND[ADDR_W-1:0];
    else if (rd_state == RD_CFG_BUFFER)
      rd_rvalid_size <= buffer_rvalid_size;
    else if (rd_state == RD_CFG_STREAM)
      rd_rvalid_size <= stream_rvalid_size;
  end

  /* Address generation logic */

  always @(posedge clk)
  begin
    if (reset)
      buffer_read_address <= 'b0;
    else begin
      if (rd_state == RD_CFG_BUFFER && stream_rd_loop0_count == 0 && stream_rd_loop1_count == 0)
        buffer_read_address <= buffer_read_base_addr;
      else if (buffer_rd_count_inc)
        buffer_read_address <= buffer_read_address + buffer_read_offset;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      stream_read_address <= 'b0;
    else begin
      if (rd_state == RD_CFG_STREAM && stream_rd_loop0_count == 0)
        stream_read_address <= stream_rd_loop1_addr;
      else if (stream_rd_loop0_inc)
        stream_read_address <= stream_read_address + stream_read_loop_0_offset;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      stream_rd_loop2_addr <= 'b0;
    else begin
      if (stream_rd_loop2_inc)
        stream_rd_loop2_addr <= stream_rd_loop2_addr + stream_read_loop_2_offset;
      else if (rd_state != RD_CFG_STREAM && stream_rd_loop2_count == 0)
        stream_rd_loop2_addr <= stream_read_base_addr;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      stream_rd_loop1_addr <= 'b0;
    else begin
      if (stream_rd_loop1_inc)
        stream_rd_loop1_addr <= stream_rd_loop1_addr + stream_read_loop_1_offset;
      else if (rd_state != RD_CFG_STREAM && stream_rd_loop1_count == 0)
        stream_rd_loop1_addr <= stream_rd_loop2_addr;
    end
  end


  always @(posedge clk)
  begin
    if (reset)
      rd_addr <= GND[ADDR_W-1:0];
    else if (rd_state_d == RD_CFG_BUFFER)
      rd_addr <= buffer_read_address;
    else if (rd_state_d == RD_CFG_STREAM)
      rd_addr <= stream_read_address;
  end

  always @(posedge clk)
  begin
    if (reset)
      rd_state <= GND[STATE_W-1:0];
    else
      rd_state <= next_rd_state;
  end
  always @(posedge clk)
    rd_state_d <= rd_state;
// ******************************************************************
// INSTANTIATIONS
// ******************************************************************

  counter #(
    .COUNT_WIDTH              ( RD_LOOP_W                )
  )
  buffer_read_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( buffer_rd_count_default  ),  //input
    .INC                      ( buffer_rd_count_inc      ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( buffer_rd_count_min      ),  //input
    .MAX_COUNT                ( buffer_rd_count_max      ),  //input
    .OVERFLOW                 ( next_stream_read         ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( buffer_rd_count          )   //output
  );

  counter #(
    .COUNT_WIDTH              ( RD_LOOP_W                )
  )
  stream_read_loop_0 (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( stream_rd_loop0_default  ),  //input
    .INC                      ( stream_rd_loop0_inc      ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( stream_rd_loop0_min      ),  //input
    .MAX_COUNT                ( stream_rd_loop0_max      ),  //input
    .OVERFLOW                 ( next_stream_loop_1       ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( stream_rd_loop0_count    )   //output
  );

  counter #(
    .COUNT_WIDTH              ( RD_LOOP_W                )
  )
  stream_read_loop_1 (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( stream_rd_loop1_default  ),  //input
    .INC                      ( stream_rd_loop1_inc      ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( stream_rd_loop1_min      ),  //input
    .MAX_COUNT                ( stream_rd_loop1_max      ),  //input
    .OVERFLOW                 ( next_stream_loop_2       ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( stream_rd_loop1_count    )   //output
  );

  counter #(
    .COUNT_WIDTH              ( RD_LOOP_W                )
  )
  stream_read_loop_2 (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( stream_rd_loop2_default  ),  //input
    .INC                      ( stream_rd_loop2_inc      ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( stream_rd_loop2_min      ),  //input
    .MAX_COUNT                ( stream_rd_loop2_max      ),  //input
    .OVERFLOW                 ( next_stream_loop_3       ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( stream_rd_loop2_count    )   //output
  );

always @(*)
begin: FSM
  next_rd_state = rd_state;
  case (rd_state)
    IDLE: begin
      if (start)
        next_rd_state = RD_CFG_BUFFER;
    end
    RD_CFG_BUFFER: begin
      if (rd_state_d == RD_CFG_BUFFER)
        next_rd_state = BUSY_BUFFER;
    end
    BUSY_BUFFER: begin
      if (buffer_rd_count_inc && next_stream_read)
        next_rd_state = RD_CFG_STREAM;
      else if (buffer_rd_count_inc)
        next_rd_state = RD_CFG_BUFFER;
    end
    RD_CFG_STREAM: begin
      if (rd_state_d == RD_CFG_STREAM)
        next_rd_state = BUSY_STREAM;
    end
    BUSY_STREAM: begin
      if (all_reads_done)
        next_rd_state = IDLE;
      else if (stream_rd_loop0_inc)
        next_rd_state = RD_CFG_BUFFER;
    end
  endcase
end

/* Counter to generate index to the mem_cfg ROM. */
  assign read_idx_min = GND[RD_ROM_ADDR_W-1:0];
  assign read_idx_max = rd_cfg_idx_max;
  assign read_idx_default = GND[RD_ROM_ADDR_W-1:0];
  counter #(
    .COUNT_WIDTH              ( RD_ROM_ADDR_W               )
  )
  read_idx_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( read_idx_default         ),  //input
    .INC                      ( read_idx_inc             ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( read_idx_min             ),  //input
    .MAX_COUNT                ( read_idx_max             ),  //input
    .OVERFLOW                 ( next_read                ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( read_idx_count           )   //output
  );

  assign all_reads_done = next_read && read_idx_inc;



//=========================================================================
// Write
//=========================================================================

  assign {
    wr_l_type,
    stream_write_base_addr,
    stream_write_size,
    stream_write_offset,
    stream_write_loop_max
  } = write_cfg;

  assign wr_req = !wr_done && (wr_ready) && wr_state == WR_BUSY; //stream_wr_count_inc;

  localparam WR_IDLE = 0, WR_RD_CFG = 1, WR_BUSY = 2, WR_WAIT_DONE = 3;

  always @(posedge clk)
  begin
    if (reset)
      wr_state <= 0;
    else
      wr_state <= next_wr_state;
  end

  always @(posedge clk)
    wr_state_d <= wr_state;

  wire wait_for_wr_done;
  assign wait_for_wr_done = stream_wr_count_inc && next_stream_write;

  always @(*)
  begin
    next_wr_state = wr_state;
    case (wr_state)
      WR_IDLE: begin
        if (wr_ready && rd_state != 0)
          next_wr_state = WR_RD_CFG;
      end
      WR_RD_CFG: begin
        if (wr_state_d == wr_state)
          next_wr_state = WR_BUSY;
      end
      WR_BUSY: begin
        if (all_writes_done)
          next_wr_state = WR_IDLE;
        else if (wait_for_wr_done)
          next_wr_state = WR_WAIT_DONE;
      end
      WR_WAIT_DONE: begin
        if (wr_done)
          next_wr_state = WR_RD_CFG;
      end
    endcase
  end

// Counter to loop over multiple buffer reads.
  wire [ RD_LOOP_W            -1 : 0 ]        stream_wr_count_default;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_wr_count_min;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_wr_count_max;
  wire [ RD_LOOP_W            -1 : 0 ]        stream_wr_count;
  wire                                        next_stream_write;
  wire                                        stream_wr_count_inc;
  assign stream_wr_count_default = GND[RD_LOOP_W-1:0];
  //assign stream_wr_count_inc = wr_done;
  assign stream_wr_count_inc = wr_req;
  assign stream_wr_count_min = GND[RD_LOOP_W-1:0];
  assign stream_wr_count_max = stream_write_loop_max;
  counter #(
    .COUNT_WIDTH              ( RD_LOOP_W                )
  )
  stream_write_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( stream_wr_count_default  ),  //input
    .INC                      ( stream_wr_count_inc      ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( stream_wr_count_min      ),  //input
    .MAX_COUNT                ( stream_wr_count_max      ),  //input
    .OVERFLOW                 ( next_stream_write        ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( stream_wr_count          )   //output
  );

assign wr_cfg_idx = write_idx_count;
always @(posedge clk)
begin
  write_cfg <= wr_cfg_rom[wr_cfg_idx];
end

  wire [ WR_ROM_ADDR_W           -1 : 0 ]        write_idx_count;
  wire [ WR_ROM_ADDR_W           -1 : 0 ]        write_idx_min;
  wire [ WR_ROM_ADDR_W           -1 : 0 ]        write_idx_max;
  wire [ WR_ROM_ADDR_W           -1 : 0 ]        write_idx_default;
  wire                                        write_idx_inc;
  wire                                        write_idx_overflow;

/* Counter to generate index to the mem_cfg ROM. */
  assign write_idx_min = GND[WR_ROM_ADDR_W-1:0];
  assign write_idx_max = wr_cfg_idx_max;
  assign write_idx_default = GND[WR_ROM_ADDR_W-1:0];
  //assign write_idx_inc = next_stream_write && stream_wr_count_inc;
  assign write_idx_inc = wr_state == WR_WAIT_DONE && wr_done;
  counter #(
    .COUNT_WIDTH              ( WR_ROM_ADDR_W               )
  )
  write_idx_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( write_idx_default        ),  //input
    .INC                      ( write_idx_inc            ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( write_idx_min            ),  //input
    .MAX_COUNT                ( write_idx_max            ),  //input
    .OVERFLOW                 ( write_idx_overflow       ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( write_idx_count          )   //output
  );

  assign all_writes_done = write_idx_overflow && write_idx_inc;
  assign wr_req_size = stream_write_size;

  assign done = all_writes_done;

  reg write_idx_inc_d;
  always @(posedge clk)
    write_idx_inc_d <= write_idx_inc;

always @(posedge clk)
begin
  if (reset)
    wr_addr <= GND[ADDR_W-1:0];
  else if (wr_state == WR_RD_CFG)
    wr_addr <= stream_write_base_addr;
  else if (stream_wr_count_inc)
    wr_addr <= wr_addr + stream_write_offset;
end

  // Round robin writes for PU
  wire [PU_ID_W-1:0] wr_pu_id_default;
  wire [PU_ID_W-1:0] wr_pu_id_min;
  wire [PU_ID_W-1:0] wr_pu_id_max;
  wire [PU_ID_W-1:0] wr_pu_id_count;
  wire               wr_pu_id_inc;
  wire               wr_pu_id_clear;
  assign wr_pu_id_default = GND[PU_ID_W-1:0];
  assign wr_pu_id_min = GND[PU_ID_W-1:0];
  assign wr_pu_id_max = NUM_PU-1;
  assign wr_pu_id_inc = stream_wr_count_inc;
  assign wr_pu_id_clear = write_idx_inc;
  assign wr_pu_id = wr_l_type == 2 ? 0 : wr_pu_id_count;
  counter #(
    .COUNT_WIDTH              ( PU_ID_W                  )
  )
  wr_pu_id_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( wr_pu_id_clear           ),  //input
    .DEFAULT                  ( wr_pu_id_default         ),  //input
    .INC                      ( wr_pu_id_inc             ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( wr_pu_id_min             ),  //input
    .MAX_COUNT                ( wr_pu_id_max             ),  //input
    .OVERFLOW                 ( wr_pu_id_overflow        ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( wr_pu_id_count           )   //output
  );

endmodule
