`timescale 1ns/1ps
module axi_driver
#(
// ******************************************************************
// PARAMETERS
// ******************************************************************
   parameter integer AXI_DATA_WIDTH           = 512,
   parameter integer AXI_ADDR_WIDTH           = 64,
   parameter integer AXI_ID_WIDTH             = 16,
   parameter integer WSTRB_WIDTH = AXI_DATA_WIDTH/8,
   parameter integer TX_SIZE_WIDTH            = 8,
   parameter integer TX_FIFO_DATA_WIDTH       = AXI_ADDR_WIDTH + TX_SIZE_WIDTH

// ******************************************************************
) (

// ******************************************************************
// IO
// ******************************************************************

    // System Signals
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire  [ 32 -1 :0] aw_delay,
  input  wire  [ 32 -1 :0] w_delay,

    // Master Interface Write Address
  input  wire  [AXI_ID_WIDTH-1:0]    M_AXI_AWID,
  input  wire  [AXI_ADDR_WIDTH-1:0]  M_AXI_AWADDR,
  input  wire  [7:0]                 M_AXI_AWLEN,
  input  wire  [2:0]                 M_AXI_AWSIZE,
  input  wire  [1:0]                 M_AXI_AWBURST,
  input  wire  [1:0]                 M_AXI_AWLOCK,
  input  wire  [3:0]                 M_AXI_AWCACHE,
  input  wire  [2:0]                 M_AXI_AWPROT,
  input  wire  [3:0]                 M_AXI_AWQOS,
  input  wire                        M_AXI_AWVALID,
  output reg                         M_AXI_AWREADY,

    // Master Interface Write Data
  input  wire  [AXI_ID_WIDTH-1:0]    M_AXI_WID,
  input  wire  [AXI_DATA_WIDTH-1:0]  M_AXI_WDATA,
  input  wire  [WSTRB_WIDTH-1:0]     M_AXI_WSTRB,
  input  wire                        M_AXI_WLAST,
  input  wire                        M_AXI_WVALID,
  output reg                         M_AXI_WREADY,

  // Master Interface Write Response
  output reg  [AXI_ID_WIDTH-1:0]     M_AXI_BID,
  output reg  [1:0]                  M_AXI_BRESP,
  output reg                         M_AXI_BVALID,
  input  wire                        M_AXI_BREADY,

    // Master Interface Read Address
  input  wire  [AXI_ID_WIDTH-1:0]    M_AXI_ARID,
  input  wire  [AXI_ADDR_WIDTH-1:0]  M_AXI_ARADDR,
  input  wire  [7:0]                 M_AXI_ARLEN,
  input  wire  [2:0]                 M_AXI_ARSIZE,
  input  wire  [1:0]                 M_AXI_ARBURST,
  input  wire  [1:0]                 M_AXI_ARLOCK,
  input  wire  [3:0]                 M_AXI_ARCACHE,
  input  wire  [2:0]                 M_AXI_ARPROT,
  input  wire  [3:0]                 M_AXI_ARQOS,
  input  wire                        M_AXI_ARVALID,
  output reg                         M_AXI_ARREADY,

  // Master Interface Read Data
  output reg  [AXI_ID_WIDTH-1:0]     M_AXI_RID,
  output reg  [AXI_DATA_WIDTH-1:0]   M_AXI_RDATA,
  output reg  [1:0]                  M_AXI_RRESP,
  output reg                         M_AXI_RLAST,
  output reg                         M_AXI_RVALID,
  input  wire                        M_AXI_RREADY

);

// ******************************************************************
// Localparam
// ******************************************************************
    localparam integer DDR_DEPTH = (1 << 25);

// ******************************************************************
// Regs and Wires
// ******************************************************************

  reg  [ AXI_DATA_WIDTH        -1 : 0 ]        ddr_ram [DDR_DEPTH-1:0];

  reg                                         fail_flag;

  integer                                     read_counter;
  integer                                     read_counter_valid;
  integer                                     write_counter;

  reg                                         r_fifo_push;
  reg                                         r_fifo_pop;
  reg  [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        r_fifo_data_in;
  wire [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        r_fifo_data_out;
  wire                                        r_fifo_empty;
  wire                                        r_fifo_full;

  reg                                         w_fifo_push;
  reg                                         w_fifo_pop;
  reg  [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        w_fifo_data_in;
  wire [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        w_fifo_data_out;
  wire                                        w_fifo_empty;
  wire                                        w_fifo_full;
// ******************************************************************

// ******************************************************************
//initial begin
//    #100000
//    fail_flag = 1;
//    check_fail;
//    $finish;
//end

always @(posedge clk)
begin
  if (reset)
    read_counter_valid <= 0;
  else if (M_AXI_RVALID && M_AXI_RREADY)
    read_counter_valid <= read_counter_valid + 1;
end

// Initialize regs
initial
begin
    read_counter = 0;
    write_counter = 0;
    M_AXI_AWREADY = 0;
    M_AXI_WREADY = 0;
    M_AXI_BID = 0;
    M_AXI_BRESP = 0;
    M_AXI_BVALID = 0;
    M_AXI_ARREADY = 0;
    M_AXI_RID = 0;
    M_AXI_RDATA = 0;
    M_AXI_RRESP = 0;
    M_AXI_RLAST = 0;
    M_AXI_RVALID = 0;
    fail_flag = 0;
    r_fifo_data_in = 0;
    r_fifo_push = 0;
    r_fifo_pop = 0;
    w_fifo_data_in = 0;
    w_fifo_push = 0;
    w_fifo_pop = 0;
end

always @(negedge clk)
begin
    ar_channel;
end

always @(negedge clk)
begin
    aw_channel;
end

always @(negedge clk)
begin
    r_channel;
end

always @(posedge clk)
begin
    w_channel;
end

always @(posedge clk)
begin
    b_channel;
end


fifo #(
    .DATA_WIDTH               ( TX_FIFO_DATA_WIDTH       ),
    .ADDR_WIDTH               ( 2                       )
) r_fifo (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .push                     ( r_fifo_push              ),
    .pop                      ( r_fifo_pop               ),
    .data_in                  ( r_fifo_data_in           ),
    .data_out                 ( r_fifo_data_out          ),
    .empty                    ( r_fifo_empty             ),
    .full                     ( r_fifo_full              ),
    .fifo_count               (                          )
);

fifo #(
    .DATA_WIDTH               ( TX_FIFO_DATA_WIDTH       ),
    .ADDR_WIDTH               ( 10                       )
) w_fifo (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .push                     ( w_fifo_push              ),
    .pop                      ( w_fifo_pop               ),
    .data_in                  ( w_fifo_data_in           ),
    .data_out                 ( w_fifo_data_out          ),
    .empty                    ( w_fifo_empty             ),
    .full                     ( w_fifo_full              ),
    .fifo_count               (                          )
);

// ******************************************************************
// Tasks
// ******************************************************************

//-------------------------------------------------------------------
task automatic delay;
  input integer count;
  begin
    repeat (count) begin
      @(negedge clk);
    end
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic random_delay;
  input integer MAX_DELAY;
  reg  [ 3 : 0 ] delay;
  begin
    delay = $random;
    delay[0] = 1'b1;
    repeat (delay) begin
      @(negedge clk);
    end
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic ar_channel;
  reg[AXI_ADDR_WIDTH-1:0] araddr;
  begin
    wait(!reset);
    wait(M_AXI_ARVALID &~r_fifo_full);
    @(negedge clk);
    random_delay(16);
    M_AXI_ARREADY = 1'b1;
    araddr = M_AXI_ARADDR;
    r_fifo_data_in = {araddr, M_AXI_ARLEN};
    r_fifo_push = 1'b1;
    @(negedge clk);
    r_fifo_push = 1'b0;
    //wait(~M_AXI_ARVALID);
    M_AXI_ARREADY = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
wire [AXI_ADDR_WIDTH-1:0] addr_debug;
wire [4-1:0] arlen_debug;
assign {addr_debug, arlen_debug} = r_fifo_data_out;
task automatic r_channel;
  integer i, I;
  reg [AXI_ADDR_WIDTH-1:0] addr;
  reg [7:0] arlen;
  integer offset;
  begin
    wait(!reset);
    //wait(M_AXI_RREADY && ~r_fifo_empty && !clk);
    wait(~r_fifo_empty && !clk);
    wait (M_AXI_RREADY);
    // if (~M_AXI_RREADY)
    // begin
    //   fail_flag = 1'b1;
    //   $display ("Read channel not ready");
    // end
    @(negedge clk);
    M_AXI_RVALID = 1'b0;
    r_fifo_pop = 1'b1;
    @(negedge clk);
    r_fifo_pop = 1'b0;
    {addr, arlen} = r_fifo_data_out;
    addr = addr >> 6;

    wait(M_AXI_RREADY);
    @(negedge clk);
    offset = 0;
    repeat(arlen) begin
      if (!M_AXI_RREADY)
      begin
        wait(M_AXI_RREADY);
        @(negedge clk);
      end
      M_AXI_RDATA = ddr_ram[addr+offset];
      $display("[AR] Address: %x, Data: %x", (addr + offset) << 6, M_AXI_RDATA);
      //M_AXI_RDATA = {8{addr}};
      M_AXI_RVALID = 1'b1;
      offset = offset + 1;
      @(negedge clk);
      M_AXI_RVALID = 1'b0;
    end
    if (!M_AXI_RREADY)
    begin
      wait(M_AXI_RREADY);
      @(negedge clk);
    end
    M_AXI_RVALID = 1'b1;
    M_AXI_RLAST = 1'b1;
    M_AXI_RDATA = ddr_ram[addr+offset];
    //M_AXI_RDATA = {8{addr}};
    $display("[AR] Address: %x, Data: %x", (addr + offset) << 6, M_AXI_RDATA);
    @(negedge clk);
    M_AXI_RLAST = 1'b0;
    M_AXI_RVALID = 1'b0;
  end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
task automatic b_channel;
  begin
    wait(!reset);
    wait(M_AXI_WREADY && M_AXI_WVALID && M_AXI_WLAST);
    // Okay response
    M_AXI_BRESP = 1'b0;
    M_AXI_BVALID = 1'b1;
    wait(M_AXI_BREADY && M_AXI_BVALID);
    @(negedge clk);
    @(negedge clk);
    M_AXI_BVALID = 1'b0;
  end
endtask
////-------------------------------------------------------------------
//
////-------------------------------------------------------------------
task w_channel;
  reg [AXI_ADDR_WIDTH-1:0] awaddr;
  reg [7:0] awlen;
  integer offset;
  integer i, I;
  begin
    wait(!reset);
    wait(M_AXI_WVALID && ~w_fifo_empty && !clk);
    //repeat (10) @(negedge clk);
    M_AXI_WREADY = 1'b0;
    w_fifo_pop = 1'b1;
    @(negedge clk);
    //M_AXI_WREADY = 1'b1;
    w_fifo_pop = 1'b0;
    {awaddr, awlen} = w_fifo_data_out;
    awaddr = awaddr >> 6;
    offset = 0;
    repeat(awlen) begin
      if (!M_AXI_WVALID) begin
        wait(M_AXI_WVALID);
        @(negedge clk);
      end
      delay(0);
      M_AXI_WREADY = 1'b1;
      for(i = 0; i < WSTRB_WIDTH; i++) begin
        if(M_AXI_WSTRB[i] == 1'b1) begin
          ddr_ram[awaddr+offset][8*i +: 8] = M_AXI_WDATA[8*i +: 8];
        end
      end
      $display("[AW] Address: %x, Data: %x", (awaddr + offset) << 6, M_AXI_WDATA);
      //ddr_ram[awaddr+offset] = M_AXI_WDATA;
      //for (i=0; i<I; i=i+1)
      //begin
      //  if (ddr_ram[awaddr+offset] != M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH])
      //  begin
      //    //$error ("Write data does not match expected");
      //    //$display ("Expected: %h", ddr_ram[awaddr+offset]);
      //    //$display ("Got     : %h", M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH]);
      //    //$fatal(1);
      //  end
      //  ddr_ram[awaddr+offset] = M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH];
      //  //$display ("M_AXI_W Addr:%d, Value:%d", (awaddr+offset) << 1, M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH]);
      //  offset = offset + 1;
      //end
      //$display ("%h", M_AXI_WDATA);
      offset = offset + 1;
      @(negedge clk);
      M_AXI_WREADY = 1'b0;
    end

    if (!M_AXI_WVALID) begin
      wait(M_AXI_WVALID);
      @(negedge clk);
    end
    delay(0);
    M_AXI_WREADY = 1'b1;
    if (~M_AXI_WLAST)
    begin
      fail_flag = 1'b1;
      $display ("Failed to asset WLAST\s num of writes = %d", awlen);
      $fatal;// ("Failed to assert WLAST", 0);
    end
    //$display("[AW] Address: %x, Data: %x", awaddr << 6, M_AXI_WDATA);
//    for(i = 0; i < WSTRB_WIDTH; i++) begin
//      if(M_AXI_WSTRB[i] == 1'b1) begin
//        ddr_ram[awaddr+offset][8*i +: 8] = M_AXI_WDATA[8*i +: 8];
//      end
//    end
    ddr_ram[awaddr+offset] = M_AXI_WDATA;
    //for (i=0; i<I; i=i+1)
    //begin
    //  ddr_ram[awaddr+offset] = M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH];
    //  //$display ("LAST: M_AXI_W Addr:%d, Value:%d", (awaddr+offset) << 1, M_AXI_WDATA[i*DATA_WIDTH+:DATA_WIDTH]);
    //  //$display ("%h", M_AXI_WDATA);
    //  offset = offset + 1;
    //end
    $display("[AW] Address: %x, Data: %x", (awaddr + offset) << 6, M_AXI_WDATA);
    @(negedge clk);
    offset = 0;
    M_AXI_WREADY = 1'b0;
  end
endtask
////-------------------------------------------------------------------
//
////-------------------------------------------------------------------
task automatic aw_channel;
  reg [AXI_ADDR_WIDTH-1:0] awaddr;
  begin
    wait(!reset);
    wait(M_AXI_AWVALID && ~w_fifo_full);
    //random_delay(16);
    @(negedge clk);
    delay(0);

    M_AXI_AWREADY = 1'b1;

    awaddr = M_AXI_AWADDR;

    w_fifo_data_in = {awaddr, M_AXI_AWLEN};
    w_fifo_push = 1'b1;
    @(negedge clk);
    w_fifo_push = 1'b0;
    wait(~M_AXI_AWVALID);
    M_AXI_AWREADY = 1'b0;
  end
endtask
////-------------------------------------------------------------------
//
////-------------------------------------------------------------------
//integer writes_remaining;
//task automatic request_random_tx;
//  begin
//    wait(!reset);
//    wait(rd_ready);
//    rd_req = 1'b1;
//    rd_req_size = 40;
//    rd_addr = ($urandom>>10)<<10;
//    if (VERBOSITY > 2)
//      $display ("requesting %d reads", rd_req_size);
//    @(posedge clk);
//    @(posedge clk);
//    rd_req = 1'b0;
//    if (VERBOSITY > 2)
//      $display ("request sent");
//    wr_pu_id = 0;
//    writes_remaining = rd_req_size;
//    repeat(5) begin
//      wait(wr_ready);
//      @(negedge clk);
//      wr_req = 1'b1;
//      if (writes_remaining > 8)
//        wr_req_size = 8;
//      else
//        wr_req_size = writes_remaining;
//      @(negedge clk);
//      wr_req = 1'b0;
//      wait(wr_done);
//      wr_pu_id = (wr_pu_id + 1) % NUM_PU;
//      @(negedge clk);
//      writes_remaining = writes_remaining - wr_req_size;
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//      @(negedge clk);
//    end
//  end
//endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
//task check_fail;
//  if (fail_flag && !reset)
//  begin
//    $display("%c[1;31m",27);
//    $display ("Test Failed");
//    $display("%c[0m",27);
//    $finish;
//  end
//endtask
//
////-------------------------------------------------------------------
//task test_pass;
//  begin
//    $display("%c[1;32m",27);
//    $display ("Test Passed");
//    $display("%c[0m",27);
//    $finish;
//  end
//endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
//task initialize_fm;
//  input integer addr;
//  input integer fm_w;
//  input integer fm_h;
//  input integer fm_c;
//  integer ii, jj, kk;
//  integer idx;
//  integer fm_w_ceil;
//  integer addr_tmp;
//  begin
//    fm_w_ceil = ceil_a_by_b(fm_w, NUM_PE) * NUM_PE;
//    addr_tmp = addr - 32'h08000000;
//    addr_tmp = addr_tmp >> 1;
//    $display ("Initializing Feature map of size %d x %d x %d at location %h",
//      fm_w, fm_h, fm_c, addr_tmp);
//    for(ii=0; ii<fm_c; ii=ii+1)
//    begin
//      for(jj=0; jj<fm_h; jj=jj+1)
//      begin
//        for(kk=0; kk<fm_w_ceil; kk=kk+1)
//        begin
//          idx = kk + fm_w_ceil * (jj + fm_h * (ii));
//          if (kk < fm_w)
//            ddr_ram[addr_tmp+idx] = idx;
//          else
//            ddr_ram[addr_tmp+idx] = 0;
//          $display ("Addr: %d, Value: %d", addr_tmp+idx, ddr_ram[addr_tmp+idx]);
//        end
//      end
//    end
//  end
//endtask
////-------------------------------------------------------------------
//
//  test_status #(
//    .PREFIX                   ( "AXI_MASTER"             ),
//    .TIMEOUT                  ( 1000000                  )
//  ) status (
//    .clk                      ( clk                      ),
//    .reset                    ( reset                    ),
//    .pass                     ( pass                     ),
//    .fail                     ( fail                     )
//  );
task initialize_ddr;
    begin
    for(int i = 0; i < DDR_DEPTH; i++) begin
        ddr_ram[i] = {AXI_DATA_WIDTH{1'b0}};
    end
    end
endtask
endmodule

