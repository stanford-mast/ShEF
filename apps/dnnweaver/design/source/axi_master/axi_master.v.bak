`timescale 1ns/1ps
`include "common.vh"
module axi_master
#(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer NUM_PU               = 2,

  parameter integer AXI_ID               = 0,

  parameter integer TID_WIDTH            = 6,
  parameter integer AXI_ADDR_WIDTH       = 32,
  parameter integer AXI_DATA_WIDTH       = 64,
  parameter integer AWUSER_W             = 1,
  parameter integer ARUSER_W             = 1,
  parameter integer WUSER_W              = 1,
  parameter integer RUSER_W              = 1,
  parameter integer BUSER_W              = 1,

  /* Disabling these parameters will remove any throttling.
   The resulting ERROR flag will not be useful */
  parameter integer C_M_AXI_SUPPORTS_WRITE             = 1,
  parameter integer C_M_AXI_SUPPORTS_READ              = 1,

  /* Max count of written but not yet read bursts.
   If the interconnect/slave is able to accept enough
   addresses and the read channels are stalled, the
   master will issue this many commands ahead of
   write responses */

  // Base address of targeted slave
  //Changing read and write addresses
  parameter         C_M_AXI_READ_TARGET                = 32'hFFFF0000,
  parameter         C_M_AXI_WRITE_TARGET               = 32'hFFFF8000,

  // CUSTOM PARAMS
  parameter         TX_SIZE_WIDTH                      = 10,

  // Number of address bits to test before wrapping
  parameter integer C_OFFSET_WIDTH                     = TX_SIZE_WIDTH,

  /* Burst length for transactions, in C_M_AXI_DATA_WIDTHs.
   Non-2^n lengths will eventually cause bursts across 4K
   address boundaries.*/
  parameter integer C_M_AXI_RD_BURST_LEN               = 16,
  parameter integer C_M_AXI_WR_BURST_LEN               = 16
)
(
// ******************************************************************
// IO
// ******************************************************************
    // System Signals
  input  wire                                         clk,
  input  wire                                         reset,

    // Master Interface Write Address
  output wire  [ TID_WIDTH            -1 : 0 ]        M_AXI_AWID,
  output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        M_AXI_AWADDR,
  output wire  [ 4                    -1 : 0 ]        M_AXI_AWLEN,
  output wire  [ 3                    -1 : 0 ]        M_AXI_AWSIZE,
  output wire  [ 2                    -1 : 0 ]        M_AXI_AWBURST,
  output wire  [ 2                    -1 : 0 ]        M_AXI_AWLOCK,
  output wire  [ 4                    -1 : 0 ]        M_AXI_AWCACHE,
  output wire  [ 3                    -1 : 0 ]        M_AXI_AWPROT,
  output wire  [ 4                    -1 : 0 ]        M_AXI_AWQOS,
  output wire  [ AWUSER_W             -1 : 0 ]        M_AXI_AWUSER,
  output wire                                         M_AXI_AWVALID,
  input  wire                                         M_AXI_AWREADY,

    // Master Interface Write Data
  output wire  [ TID_WIDTH            -1 : 0 ]        M_AXI_WID,
  output wire  [ AXI_DATA_WIDTH       -1 : 0 ]        M_AXI_WDATA,
  output wire  [ WSTRB_W              -1 : 0 ]        M_AXI_WSTRB,
  output wire                                         M_AXI_WLAST,
  output wire  [ WUSER_W              -1 : 0 ]        M_AXI_WUSER,
  output wire                                         M_AXI_WVALID,
  input  wire                                         M_AXI_WREADY,

    // Master Interface Write Response
  input  wire  [ TID_WIDTH            -1 : 0 ]        M_AXI_BID,
  input  wire  [ 2                    -1 : 0 ]        M_AXI_BRESP,
  input  wire  [ BUSER_W              -1 : 0 ]        M_AXI_BUSER,
  input  wire                                         M_AXI_BVALID,
  output wire                                         M_AXI_BREADY,

    // Master Interface Read Address
  output wire  [ TID_WIDTH            -1 : 0 ]        M_AXI_ARID,
  output wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        M_AXI_ARADDR,
  output wire  [ 4                    -1 : 0 ]        M_AXI_ARLEN,
  output wire  [ 3                    -1 : 0 ]        M_AXI_ARSIZE,
  output wire  [ 2                    -1 : 0 ]        M_AXI_ARBURST,
  output wire  [ 2                    -1 : 0 ]        M_AXI_ARLOCK,
  output wire  [ 4                    -1 : 0 ]        M_AXI_ARCACHE,
  output wire  [ 3                    -1 : 0 ]        M_AXI_ARPROT,
    // AXI3 output wire [4-1:0]          M_AXI_ARREGION,
  output wire  [ 4                    -1 : 0 ]        M_AXI_ARQOS,
  output wire  [ ARUSER_W             -1 : 0 ]        M_AXI_ARUSER,
  output wire                                         M_AXI_ARVALID,
  input  wire                                         M_AXI_ARREADY,

    // Master Interface Read Data
  input  wire  [ TID_WIDTH            -1 : 0 ]        M_AXI_RID,
  input  wire  [ AXI_DATA_WIDTH       -1 : 0 ]        M_AXI_RDATA,
  input  wire  [ 2                    -1 : 0 ]        M_AXI_RRESP,
  input  wire                                         M_AXI_RLAST,
  input  wire  [ RUSER_W              -1 : 0 ]        M_AXI_RUSER,
  input  wire                                         M_AXI_RVALID,
  output wire                                         M_AXI_RREADY,

    // NPU Design
    // WRITE from BRAM to DDR
  input  wire  [ NUM_PU               -1 : 0 ]        outbuf_empty,
  output reg   [ NUM_PU               -1 : 0 ]        outbuf_pop,
  input  wire  [ OUTBUF_DATA_W        -1 : 0 ]        data_from_outbuf,
  input  wire  [ NUM_PU               -1 : 0 ]        write_valid,

    // READ from DDR to BRAM
  output wire  [ AXI_DATA_WIDTH       -1 : 0 ]        data_to_inbuf,
  output wire                                         inbuf_push,
  input  wire                                         inbuf_full,

    // Memory Controller Interface - Read
  input  wire                                         rd_req,
  output wire                                         rd_ready,
  input  wire  [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size,
  input  wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        rd_addr,

    // Memory Controller Interface - Write
  input  wire                                         wr_req,
  input  wire  [ NUM_PU_W             -1 : 0 ]        wr_pu_id,
  output reg                                          wr_ready,
  input  wire  [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size,
  input  wire  [ AXI_ADDR_WIDTH       -1 : 0 ]        wr_addr,
  output reg                                          wr_done
);

// ******************************************************************
// Internal variables - Regs, Wires and LocalParams
// ******************************************************************
  wire                                        rnext;

  localparam integer WSTRB_W  = AXI_DATA_WIDTH/8;
  localparam integer NUM_PU_W = `C_LOG_2(NUM_PU)+1;
  localparam integer OUTBUF_DATA_W = NUM_PU * AXI_DATA_WIDTH;

  // A fancy terminal counter, using extra bits to reduce decode logic
  localparam integer C_WLEN_COUNT_WIDTH = `C_LOG_2(C_M_AXI_WR_BURST_LEN-2)+2;
  reg  [ C_WLEN_COUNT_WIDTH   -1 : 0 ]        wlen_count;

  // Local address counters
  reg [C_OFFSET_WIDTH-1:0]                    araddr_offset = 'b0;
  reg  [ AXI_ADDR_WIDTH       -1 : 0 ]        awaddr;

  // Example user application signals
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        wdata;
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        wdata_w;

  // Interface response error flags
  wire                                        write_resp_error;
  wire                                        read_resp_error;

  // AXI4 temp signals
  reg                                         awvalid;
  wire                                        wlast;
  reg                                         wvalid;
  reg                                         bready;
  reg                                         arvalid;
  wire                                        rready;

  wire                                        wnext;

  reg  [ AXI_ADDR_WIDTH       -1 : 0 ]        wr_addr_d;
  reg                                         wr_req_d;

  reg  [ NUM_PU_W             -1 : 0 ]        curr_wr_pu_id;
  reg  [ NUM_PU_W             -1 : 0 ]        wr_issued_pu_id;
  reg                                         wburst_ready;
  wire                                        wburst_ready_w;
  wire [ 4                    -1 : 0 ]        wburst_len_w;
  wire                                        wr_flush;

  wire                                        wburst_issued_d;
  reg                                         wburst_issued;
  reg  [ 4                    -1 : 0 ]        wburst_issued_len;

  wire [ NUM_PU               -1 : 0 ]        pu_axi_wr_ready;
  reg  [ NUM_PU               -1 : 0 ]        pu_wr_flush_sticky;
  wire [ NUM_PU               -1 : 0 ]        pu_wr_ready;

  wire [ TX_SIZE_WIDTH        -1 : 0 ]        curr_pu_writes_remaining;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        curr_pu_writes_remaining_d;

  //assign wr_ready = pu_wr_ready[wr_pu_id];
  reg                                         wr_ready_d;
  always@(posedge clk)
    wr_ready <= pu_wr_ready[wr_pu_id] && !(wr_req && wr_ready);

  wire                                        all_writes_done;
  assign all_writes_done = &pu_wr_ready && wchannel_req_buf_empty && wchannel_state == WC_IDLE;

  reg                                         all_writes_done_d;
  always @(posedge clk)
    if (reset)
      all_writes_done_d <= 1'b0;
    else
      all_writes_done_d <= all_writes_done;

    always @(posedge clk)
      if (reset)
        wr_done <= 0;
      else
        wr_done <= all_writes_done && !all_writes_done_d;


//--------------------------------------------------------------
wire rd_req_buf_pop, rd_req_buf_push;
wire rd_req_buf_empty, rd_req_buf_full;
wire [AXI_ADDR_WIDTH+TX_SIZE_WIDTH-1:0] rd_req_buf_data_in, rd_req_buf_data_out;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rx_req_size_buf;
  wire [ AXI_ADDR_WIDTH       -1 : 0 ]        rx_addr_buf;

assign rd_req_buf_pop       = rx_size == 0 && !rd_req_buf_empty && !rd_req_buf_pop_d;
assign rd_req_buf_push      = rd_req;
assign rd_ready = !rd_req_buf_full;
assign rd_req_buf_data_in   = {rd_req_size, rd_addr};
assign {rx_req_size_buf, rx_addr_buf} = rd_req_buf_data_out;

  reg                                         rd_req_buf_pop_d;
always @(posedge clk)
begin
  if (!reset)
    rd_req_buf_pop_d <= rd_req_buf_pop;
  else
    rd_req_buf_pop_d <= 0;
end

  localparam integer RD_RQ_WIDTH = AXI_ADDR_WIDTH + TX_SIZE_WIDTH;
  fifo #(
    .DATA_WIDTH               ( RD_RQ_WIDTH              ),
    .ADDR_WIDTH               ( 2                        )
  ) rd_req_buf (
    .clk                      ( clk                      ), //input
    .reset                    ( reset                    ), //input
    .pop                      ( rd_req_buf_pop           ), //input
    .data_out                 ( rd_req_buf_data_out      ), //output
    .empty                    ( rd_req_buf_empty         ), //output
    .push                     ( rd_req_buf_push          ), //input
    .data_in                  ( rd_req_buf_data_in       ), //input
    .full                     ( rd_req_buf_full          ), //output
    .fifo_count               (                          )  //output
  );
//--------------------------------------------------------------

   // READs
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        rx_size;
   //wire [4-1:0] arlen = (rx_size >= 16) ? 15: (rx_size >= 8) ? 7 : (rx_size >= 4) ? 3 : (rx_size >= 2) ? 1 : 0;
   wire [4-1:0] arlen = (rx_size >= 16) ? 15: (rx_size != 0) ? (rx_size-1) : 0;
  reg  [ 4                    -1 : 0 ]        arlen_d;

   always @(posedge clk)
   begin
     if (reset)
       rx_size <= 0;
     //else if (rd_req)
       //    rx_size <= rx_size + rd_req_size;
       else if (rd_req_buf_pop_d)
         rx_size <= rx_size + rx_req_size_buf;
       else if (arvalid && M_AXI_ARREADY)
         rx_size <= rx_size - arlen - 1;
     end

   always @(posedge clk)
   begin
     if (reset)
       arlen_d <= 0;
     else if (arvalid && M_AXI_ARREADY)
       arlen_d <= arlen;
   end


/////////////////
//I/O Connections
/////////////////
////////////////////
//Write Address (AW)
////////////////////

// Single threaded
assign M_AXI_AWID = 'b0;

// The AXI address is a concatenation of the target base address + active offset range
//assign M_AXI_AWADDR = {C_M_AXI_WRITE_TARGET[AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH],awaddr_offset};
//assign M_AXI_AWADDR = {wr_addr_d[AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH],awaddr_offset};

//Burst LENgth is number of transaction beats, minus 1
  reg  [ 4                    -1 : 0 ]        awlen;
assign M_AXI_AWLEN = awlen;

// Size should be AXI_DATA_WIDTH, in 2^SIZE bytes, otherwise narrow bursts are used
assign M_AXI_AWSIZE = `C_LOG_2(AXI_DATA_WIDTH/8);

// INCR burst type is usually used, except for keyhole bursts
assign M_AXI_AWBURST = 2'b01;
assign M_AXI_AWLOCK = 2'b00;

// Not Allocated, Modifiable and Bufferable
assign M_AXI_AWCACHE = 4'b0011;
assign M_AXI_AWPROT = 3'h0;
assign M_AXI_AWQOS = 4'h0;

//Set User[0] to 1 to allow Zynq coherent ACP transactions
assign M_AXI_AWUSER = 'b1;
assign M_AXI_AWVALID = awvalid;

///////////////
//Write Data(W)
///////////////
assign M_AXI_WDATA = wdata;

assign M_AXI_WID = 'b0;
assign M_AXI_WSTRB = {(AXI_DATA_WIDTH/8){1'b1}};
assign M_AXI_WLAST = wlast;
assign M_AXI_WUSER = 'b0;
assign M_AXI_WVALID = wvalid;

////////////////////
//Write Response (B)
////////////////////
assign M_AXI_BREADY = bready;

///////////////////
//Read Address (AR)
///////////////////
assign M_AXI_ARID = 'b0;
assign M_AXI_ARADDR = {rx_addr_buf[AXI_ADDR_WIDTH-1:C_OFFSET_WIDTH], araddr_offset};

//Burst LENgth is number of transaction beats, minus 1
//assign M_AXI_ARLEN = C_M_AXI_RD_BURST_LEN - 1;
//assign M_AXI_ARLEN = 11;
assign M_AXI_ARLEN = arlen;

// Size should be AXI_DATA_WIDTH, in 2^n bytes, otherwise narrow bursts are used
assign M_AXI_ARSIZE = `C_LOG_2(AXI_DATA_WIDTH/8);

// INCR burst type is usually used, except for keyhole bursts
assign M_AXI_ARBURST = 2'b01;
assign M_AXI_ARLOCK = 2'b00;

// Not Allocated, Modifiable and Bufferable
//assign M_AXI_ARCACHE = 4'b0011;
assign M_AXI_ARCACHE = 4'b1111;
assign M_AXI_ARPROT = 3'h0;
assign M_AXI_ARQOS = 4'h0;

//Set User[0] to 1 to allow Zynq coherent ACP transactions
assign M_AXI_ARUSER = 'b1;
assign M_AXI_ARVALID = arvalid;

////////////////////////////
//Read and Read Response (R)
////////////////////////////
assign M_AXI_RREADY = rready;

///////////////////////
//Write Address Channel
///////////////////////

  reg  [ 1                       : 0 ]        write_state;
  reg  [ 1                       : 0 ]        next_write_state;
  reg  [ 1                       : 0 ]        write_state_d;
always @(posedge clk)
begin
  if (reset)
    write_state_d <= 0;
  else
    write_state_d <= write_state;
end

always @(posedge clk)
begin
  if (reset)
    awlen <= 0;
  else if (axi_wr_req)
  begin
    if (wr_flush)
      awlen <= curr_pu_writes_remaining - 1'b1;
    else if (wburst_ready)
      awlen <= C_M_AXI_WR_BURST_LEN - 1;
  end
end

always @(*)
begin
  next_write_state = write_state;
  case (write_state)
    0: begin
      if (axi_wr_req_d && write_state_d != 3 && !wchannel_req_buf_full)
        next_write_state = 1;
    end
    1: begin
      if (M_AXI_AWVALID && M_AXI_AWREADY)
        next_write_state = 2;
    end
    2: begin
      //if (wnext && wlast)
        next_write_state = 3;
    end
    3: begin
      next_write_state = 0;
    end
  endcase
end

always @(posedge clk)
begin
  if (reset)
    write_state <= 0;
  else
    write_state <= next_write_state;
end

//assign wburst_issued = write_state == 1 && (M_AXI_AWVALID && M_AXI_AWREADY);
always @(posedge clk)
  if (reset)
    wburst_issued <= 0;
  else
    wburst_issued <= write_state == 1 && (M_AXI_AWVALID && M_AXI_AWREADY);

always @(posedge clk)
begin
  if (reset)
    wburst_issued_len <= 0;
  else if (M_AXI_AWVALID && M_AXI_AWREADY)
    wburst_issued_len <= M_AXI_AWLEN;
end

always @(posedge clk)
begin
  if (reset)
    awvalid <= 1'b0;
  else if (C_M_AXI_SUPPORTS_WRITE && !awvalid && write_state == 1)
    awvalid <= 1'b1;
  else if (M_AXI_AWREADY && awvalid)
    awvalid <= 1'b0;
  else
    awvalid <= awvalid;
end

// Next address after AWREADY indicates previous address acceptance
assign M_AXI_AWADDR = awaddr;
  wire [ AXI_ADDR_WIDTH       -1 : 0 ]        curr_pu_awaddr;
always @(posedge clk)
begin
  if (reset)
    awaddr <= 'b0;
  else if (axi_wr_req)
    awaddr <= curr_pu_awaddr;
end

////////////////////////////
//Write Response (B) Channel
////////////////////////////
always @(posedge clk)
begin
  if (reset)
    bready <= 1'b0;
  else
    bready <= C_M_AXI_SUPPORTS_WRITE;
end
//-----------------------------------------------//
//  READ - BEGIN
//-----------------------------------------------//
assign rnext = !reset & M_AXI_RVALID  & M_AXI_RREADY;
//////////////////////
//Read Address Channel
//////////////////////
//Generate ARVALID
always @(posedge clk)
begin
  if (reset)
  begin
      arvalid <= 1'b0;
  end
  else if (arvalid && M_AXI_ARREADY)
  begin
      arvalid <= 1'b0;
  end
  else if (C_M_AXI_SUPPORTS_READ && rx_size != 0)
  begin
      arvalid <= 1'b1;
  end
  else
  begin
      arvalid <= arvalid;
  end
end

always @(posedge clk)
begin
  if (reset)
  begin
      araddr_offset  <= 'b0;
  end
  else if (rd_req_buf_pop_d)
  begin
    araddr_offset <= rx_addr_buf;
  end
  else if (arvalid && M_AXI_ARREADY)
  begin
      araddr_offset <= araddr_offset + 'h80;
  end
  else if (C_M_AXI_SUPPORTS_READ && rx_size != 0)
  begin
      araddr_offset <= araddr_offset;
  end
  else
  begin
      araddr_offset <= araddr_offset;
  end
end

//////////////////////////////////
//Read Data (and Response) Channel
//////////////////////////////////
assign rready = (C_M_AXI_SUPPORTS_READ == 1) && !inbuf_full;

//-----------------------------------------------//
//  Data Fifo Control
//-----------------------------------------------//
assign inbuf_push    = rnext;
assign data_to_inbuf = M_AXI_RDATA;
//-----------------------------------------------//

// ******************************************************************
// WBURST Counter
// ******************************************************************

always@(posedge clk)
begin
  if (reset)
    wburst_ready <= 0;
  else
    wburst_ready <= wburst_ready_w;
end

  wire                                        axi_wr_req;
  reg                                         axi_wr_req_d;
  assign axi_wr_req = pu_axi_wr_ready[curr_wr_pu_id];

  always @(posedge clk)
    axi_wr_req_d <= axi_wr_req;

  assign wr_flush = pu_wr_flush_sticky[curr_wr_pu_id];

  reg                                         wlast_d;
  wire                                        check_next_pu;
  assign check_next_pu = (write_state == 3) || (write_state == 0 && !axi_wr_req && !all_writes_done_d);
  always @(posedge clk)wlast_d <= wlast;
  always @(posedge clk)
  begin
    if (reset)
      curr_wr_pu_id <= 0;
    else if (check_next_pu)
    begin
      if (curr_wr_pu_id == NUM_PU-1)
        curr_wr_pu_id <= 'b0;
      else
        curr_wr_pu_id <= curr_wr_pu_id + 1'b1;
    end
  end

  always @(posedge clk)
  begin
    if (reset)
      wr_issued_pu_id <= 0;
    else if (M_AXI_AWVALID && M_AXI_AWREADY)
      wr_issued_pu_id <= curr_wr_pu_id;
  end

genvar i;
generate
for (i = 0; i < NUM_PU; i = i + 1)
begin: WBURST_COUNTER_GEN

  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        pu_writes_remaining;
  reg  [ AXI_ADDR_WIDTH       -1 : 0 ]        pu_wr_addr;
  reg                                         pu_wr_flush;
  wire                                        _pu_wr_flush;
  wire                                        wr_flush_sticky;
  assign wr_flush_sticky = pu_wr_flush_sticky[i];
  assign curr_pu_awaddr = (curr_wr_pu_id == i) ? pu_wr_addr : 'bz;

  // Current PU is ready
  assign pu_axi_wr_ready[i] = !pu_wr_ready[i] &&
    (wbc_wburst_ready || pu_wr_flush_sticky[i]);

  // Get write address for current PU
  always @(posedge clk)
    if (reset)
      pu_wr_addr <= 'b0;
    else if (wr_req && wr_pu_id == i)
      pu_wr_addr <= wr_addr;
    else if (wburst_issued && wr_issued_pu_id == i)
      pu_wr_addr <= pu_wr_addr + 'h80;

  // Get Write count for current PU
  // Decrement counter when the current PU is read
  always @(posedge clk)
  if (reset)
      pu_writes_remaining <= 0;
    else if (wr_req && wr_pu_id == i)
      pu_writes_remaining <= wr_req_size;
    else if (wburst_issued && wr_issued_pu_id == i)
      pu_writes_remaining <= pu_writes_remaining - wburst_issued_len - 1;

  assign curr_pu_writes_remaining =
    (curr_wr_pu_id == i) ? pu_writes_remaining : 'bz;

  // Flush logic for current PU
  assign _pu_wr_flush =
    (pu_writes_remaining < C_M_AXI_WR_BURST_LEN) &&
    (pu_writes_remaining <= (wbc_wburst_len + 1)) && !pu_wr_ready[i];

  // Flush logic for current PU
  always @(posedge clk)
    pu_wr_flush <= _pu_wr_flush;

  always @(posedge clk)
  begin
    if (reset)
      pu_wr_flush_sticky[i] <= 1'b0;
    else if (pu_wr_flush && !pu_wr_ready[i])
      pu_wr_flush_sticky[i] <= 1'b1;
    else if (pu_wr_ready[i])
      pu_wr_flush_sticky[i] <= 1'b0;
  end

  // Ready for next request from mem controller
  assign pu_wr_ready[i] = pu_writes_remaining == 0;
  // Pop output buffer for the issued PU
  //assign outbuf_pop[i] = wnext && (wr_issued_pu_id == i);
  // Get Write data from current PU
  //assign wdata_w =
    //(wr_issued_pu_id == i) ?
    //data_from_outbuf[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] : 'bz;

  wire                                        wbc_write_valid;
  wire                                        wbc_wr_flush;
  wire [ 4                    -1 : 0 ]        wbc_wburst_len;
  wire                                        wbc_wburst_ready;
  wire                                        pu_wburst_issued;
  wire [ 4                    -1 : 0 ]        pu_wburst_issued_len;

  assign wbc_write_valid = write_valid[i];
  assign wbc_wr_flush = wr_flush && (wr_issued_pu_id == i);
  assign wburst_len_w = (curr_wr_pu_id == i) ? wbc_wburst_len : 'bz;
  assign wburst_ready_w = (curr_wr_pu_id == i) ? wbc_wburst_ready : 'bz;
  assign pu_wburst_issued = (curr_wr_pu_id == i) ? wburst_issued : 1'b0;
  assign pu_wburst_issued_len = (curr_wr_pu_id == i) ? wburst_issued_len : 'b0;
  wburst_counter #(
    .WBURST_COUNTER_LEN       ( 16                       ),
    .WBURST_LEN               ( 4                        ),
    .MAX_BURST_LEN            ( C_M_AXI_WR_BURST_LEN     )
  ) wburst_C (
    .clk                      ( clk                      ),
    .resetn                   ( !reset                   ),
    .write_valid              ( wbc_write_valid          ),
    .write_flush              ( wbc_wr_flush             ),
    .wburst_len               ( wbc_wburst_len           ),
    .wburst_ready             ( wbc_wburst_ready         ),

    .wburst_issued            ( pu_wburst_issued         ),
    .wburst_issued_len        ( pu_wburst_issued_len     )
  );
end
endgenerate
// ******************************************************************


//  `ifdef simulation
//    always @(posedge clk)
//    begin
//      if (wr_req)
//        $display ("AXI %d: requesting %d writes from PU %d", AXI_ID, wr_req_size, AXI_ID+wr_pu_id*4);
//      if (wr_done)
//        $display ("AXI %d: finished %d writes from PU %d", AXI_ID, wr_req_size, AXI_ID+wr_issued_pu_id*4);
//      //if (M_AXI_WVALID && M_AXI_WREADY)
//        //$display ("Writing data %h", wdata);
//    end
//  `endif

  reg                                         wchannel_state;
  reg                                         next_wchannel_state;
  reg                                         write_wchannel_state_d;

always @(posedge clk)
  if (reset)
    wchannel_state <= 'b0;
  else
    wchannel_state <= next_wchannel_state;

localparam WC_IDLE = 0, WC_BUSY = 1;

always @(*)
begin: W_CHANNEL_FSM
  next_wchannel_state = wchannel_state;
  case (wchannel_state)
    WC_IDLE: begin
      if (wchannel_req_buf_pop)
        next_wchannel_state = WC_BUSY;
    end
    WC_BUSY: begin
      if (wlast && wnext)
        next_wchannel_state = WC_IDLE;
    end
  endcase
end

localparam integer WCHANNEL_REQ_W = 4 + NUM_PU_W;
  wire [ WCHANNEL_REQ_W       -1 : 0 ]        wchannel_req_buf_data_in;
  wire [ WCHANNEL_REQ_W       -1 : 0 ]        wchannel_req_buf_data_out;

  wire [ NUM_PU_W             -1 : 0 ]        write_channel_pu_id;
  wire [ 4                    -1 : 0 ]        write_channel_awlen;

wire wchannel_req_buf_push = M_AXI_AWVALID && M_AXI_AWREADY;
assign wchannel_req_buf_data_in = {M_AXI_AWLEN, curr_wr_pu_id};

wire wchannel_req_buf_pop = (wchannel_state == WC_IDLE)
                            && !wchannel_req_buf_empty
                            && !write_buf_empty;
assign {
  write_channel_awlen,
  write_channel_pu_id
  } = wchannel_req_buf_data_out;

fifo_fwft #(
    .DATA_WIDTH               ( WCHANNEL_REQ_W           ),
    .ADDR_WIDTH               ( 4                        )
) wchannel_req_buf (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .push                     ( wchannel_req_buf_push    ),
    .pop                      ( wchannel_req_buf_pop     ),
    .data_in                  ( wchannel_req_buf_data_in ),
    .data_out                 ( wchannel_req_buf_data_out ),
    .empty                    ( wchannel_req_buf_empty   ),
    .full                     ( wchannel_req_buf_full    )
);

// Forward movement occurs when the channel is valid and ready
assign wnext = M_AXI_WREADY & wvalid;

// WVALID logic, similar to the AWVALID always block above
always @(posedge clk)
begin
  if (reset)
    wvalid <= 1'b0;
    //else if (C_M_AXI_SUPPORTS_WRITE && wvalid==0 && (outbuf_count >= C_M_AXI_WR_BURST_LEN))
  else if (C_M_AXI_SUPPORTS_WRITE && wchannel_req_buf_pop)
    wvalid <= 1'b1;
  else if (wnext && wlast)
    wvalid <= 1'b0;
  else
    wvalid <= wvalid;
end

//WLAST generation on the MSB of a counter underflow
assign wlast = wlen_count[C_WLEN_COUNT_WIDTH-1];

/* Burst length counter. Uses extra counter register bit to indicate terminal
 count to reduce decode logic */
always @(posedge clk)
begin
  if (reset)// || (wnext && wlen_count[C_WLEN_COUNT_WIDTH-1]))
    wlen_count <= C_M_AXI_WR_BURST_LEN - 2'd2;
  //else if (wnext && wlen_count[C_WLEN_COUNT_WIDTH-1])
  //else if (M_AXI_AWVALID && M_AXI_AWREADY)
  else if (wchannel_req_buf_pop)
    wlen_count <= write_channel_awlen - 1;
  else if (wnext)
    wlen_count <= wlen_count - 1'b1;
  else
    wlen_count <= wlen_count;
end

//assign wdata = data_from_outbuf;


// ==================================================================
// Logic for reading from outbufs
// Allows the AW-channel to run ahead of the W-channel
//
// Get data from PU's obuf and put them in a write_buf
// for better timing
// ==================================================================
  reg                                         awchannel_state;
  reg                                         next_awchannel_state;
  reg                                         write_awchannel_state_d;

always @(posedge clk)
  if (reset)
    awchannel_state <= 'b0;
  else
    awchannel_state <= next_awchannel_state;

localparam AWC_IDLE = 0, AWC_READ = 1;

always @(*)
begin: AW_CHANNEL_FSM
  next_awchannel_state = awchannel_state;
  case (awchannel_state)
    AWC_IDLE: begin
      if (!awchannel_req_buf_empty)
        next_awchannel_state = AWC_READ;
    end
    AWC_READ: begin
      if (pu_obuf_rd_overflow)
        next_awchannel_state = AWC_IDLE;
    end
  endcase
end

localparam integer AWCHANNEL_REQ_W = 4 + NUM_PU_W;

  wire [ 4                    -1 : 0 ]        pu_obuf_read_len;
  wire [ NUM_PU_W             -1 : 0 ]        pu_obuf_read_id;

  wire                                        awchannel_req_buf_push;
  wire                                        awchannel_req_buf_pop;
  wire [ AWCHANNEL_REQ_W      -1 : 0 ]        awchannel_req_buf_data_in;
  wire [ AWCHANNEL_REQ_W      -1 : 0 ]        awchannel_req_buf_data_out;

assign awchannel_req_buf_push = M_AXI_AWREADY && M_AXI_AWVALID;
assign awchannel_req_buf_data_in = {M_AXI_AWLEN, curr_wr_pu_id};

assign awchannel_req_buf_pop = awchannel_state == AWC_IDLE && !awchannel_req_buf_empty;
assign {pu_obuf_read_len, pu_obuf_read_id} = awchannel_req_buf_data_out;

fifo #(
    .DATA_WIDTH               ( WCHANNEL_REQ_W           ),
    .ADDR_WIDTH               ( 4                        )
) awchannel_req_buf (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .push                     ( awchannel_req_buf_push    ),
    .pop                      ( awchannel_req_buf_pop     ),
    .data_in                  ( awchannel_req_buf_data_in ),
    .data_out                 ( awchannel_req_buf_data_out ),
    .empty                    ( awchannel_req_buf_empty   ),
    .full                     ( awchannel_req_buf_full    )
);
// ==================================================================

// ==================================================================
// Count reads from PU OBuf
// ==================================================================
  wire [ 4                    -1 : 0 ]        pu_obuf_rd_default;
  wire [ 4                    -1 : 0 ]        pu_obuf_rd_min;
  wire [ 4                    -1 : 0 ]        pu_obuf_rd_max;
  wire [ 4                    -1 : 0 ]        pu_obuf_rd_count;
  wire                                        pu_obuf_rd_inc;
  reg                                         pu_obuf_rd_inc_d;

  assign pu_obuf_rd_default = 0;
  assign pu_obuf_rd_min = 0;
  assign pu_obuf_rd_max = pu_obuf_read_len;
  assign pu_obuf_rd_inc = awchannel_state == AWC_READ && !write_buf_almost_full;
  counter #(
    .COUNT_WIDTH              ( 4                        )
  )
  pu_obuf_rd_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( pu_obuf_rd_default       ),  //input
    .INC                      ( pu_obuf_rd_inc           ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( pu_obuf_rd_min           ),  //input
    .MAX_COUNT                ( pu_obuf_rd_max           ),  //input
    .OVERFLOW                 ( pu_obuf_rd_overflow      ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( pu_obuf_rd_count         )   //output
  );

// ==================================================================

// ==================================================================
  reg  [ AXI_DATA_WIDTH       -1 : 0 ]        write_buf_data_in;
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        _write_buf_data_in;
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        write_buf_data_out;
  reg                                         write_buf_push;
  wire                                        write_buf_pop;
  wire                                        write_buf_empty;
  wire                                        write_buf_full;


  localparam WRITE_BUF_ADDR_W = 5;
  wire [ WRITE_BUF_ADDR_W :0] write_buf_count;
  wire [ WRITE_BUF_ADDR_W :0] write_buf_almost_max;
  reg write_buf_almost_full;
  assign write_buf_almost_max = (1<<WRITE_BUF_ADDR_W) - 8;

  always @(posedge clk)
  begin
    if (reset)
      write_buf_almost_full <= 1'b0;
    else
      write_buf_almost_full <= write_buf_count >= write_buf_almost_max;
  end

assign write_buf_pop = wnext;

assign wdata = write_buf_data_out;

`ifdef simulation
integer push_count;
always @(posedge clk)
  if (reset)
    push_count <= 0;
  else if (write_buf_push)
    push_count <= push_count + 1;
integer valid_push_count;
always @(posedge clk)
  if (reset)
    valid_push_count <= 0;
  else if (!write_buf_full && write_buf_push)
    valid_push_count <= valid_push_count + 1;
`endif



fifo_fwft #(
  .DATA_WIDTH               ( AXI_DATA_WIDTH           ),
  .ADDR_WIDTH               ( 5                        )
) write_buf (
  .clk                      ( clk                      ),  //input
  .reset                    ( reset                    ),  //input
  .push                     ( write_buf_push           ),  //input
  .pop                      ( write_buf_pop            ),  //input
  .data_in                  ( write_buf_data_in        ),  //input
  .data_out                 ( write_buf_data_out       ),  //output
  .full                     ( write_buf_full           ),  //output
  .empty                    ( write_buf_empty          ),  //output
  .fifo_count               ( write_buf_count          )   //output
);

// Two cycle delay for the push
always @(posedge clk)
begin
  pu_obuf_rd_inc_d <= pu_obuf_rd_inc;
  write_buf_push <= pu_obuf_rd_inc_d;
end

generate
for (i = 0; i < NUM_PU; i = i + 1)
begin: PU_OBUF_POP

  // pop only the current PU's obuf
  always @(posedge clk)
  begin
    if (reset)
      outbuf_pop[i] <= 1'b0;
    else
      outbuf_pop[i] <= (pu_obuf_read_id == i) && pu_obuf_rd_inc;
  end

  // Get data from the current PU's obuf
  assign _write_buf_data_in = (pu_obuf_read_id == i) ? data_from_outbuf[i*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] : 'bz;

  // Register for better timing
  // One cycle delay for data, two for the push
  always @(posedge clk)
    if (reset)
      write_buf_data_in <= 'b0;
    else if (pu_obuf_rd_inc_d)
      write_buf_data_in <= _write_buf_data_in;

end
endgenerate

// ==================================================================


endmodule
