`timescale 1ns/1ps
module axi_master_wrapper_tb;
// ******************************************************************
// PARAMETERS
// ******************************************************************
  parameter integer VERBOSITY = 1;
  parameter integer MAX_AR_DELAY             = 8;
  parameter integer TX_FIFO_DATA_WIDTH       = 16;
  parameter integer TID_WIDTH                = 6;
  parameter integer C_M_AXI_ADDR_WIDTH       = 32;
  parameter integer AXI_DATA_WIDTH           = 64;
  parameter integer C_M_AXI_SUPPORTS_WRITE   = 1;
  parameter integer C_M_AXI_SUPPORTS_READ    = 1;
  parameter integer C_M_AXI_READ_TARGET      = 32'hFFFF0000;
  parameter integer C_M_AXI_WRITE_TARGET     = 32'hFFFF8000;
  parameter integer C_OFFSET_WIDTH           = 11;
  parameter integer C_M_AXI_RD_BURST_LEN     = 16;
  parameter integer C_M_AXI_WR_BURST_LEN     = 16;
  parameter integer TX_SIZE_WIDTH            = 20;
  parameter integer OUTBUF_DATA_W            = AXI_DATA_WIDTH*NUM_PU;
  parameter integer ADDR_W                   = C_M_AXI_ADDR_WIDTH;
  parameter integer AXI_DATA_W               = AXI_DATA_WIDTH;
  parameter integer WSTRB_W                  = AXI_DATA_WIDTH/8;

  parameter integer NUM_PU                   = 10;
  parameter integer NUM_AXI                  = 4;
  parameter integer PU_PER_AXI               = ceil_a_by_b(NUM_PU, NUM_AXI);
// ******************************************************************

// ******************************************************************
// IO
// ******************************************************************

  // System Signals
  reg                                         clk;
  reg                                         reset;

  // Master Interface Write Address
  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_AWID;
  wire  [ NUM_AXI*ADDR_W       -1 : 0 ]        M_AXI_AWADDR;
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_AWLEN;
  wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_AWSIZE;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_AWBURST;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_AWLOCK;
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_AWCACHE;
  wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_AWPROT;
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_AWQOS;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_AWVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_AWREADY;

  // Master Interface Write Data
  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_WID;
  wire  [ NUM_AXI*AXI_DATA_W   -1 : 0 ]        M_AXI_WDATA;
  wire  [ NUM_AXI*WSTRB_W      -1 : 0 ]        M_AXI_WSTRB;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WLAST;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WREADY;

  // Master Interface Write Response
  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_BID;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_BRESP;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_BVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_BREADY;

  // Master Interface Read Address
  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_ARID;
  wire  [ NUM_AXI*ADDR_W       -1 : 0 ]        M_AXI_ARADDR;
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARLEN;
  wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_ARSIZE;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_ARBURST;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_ARLOCK;
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARCACHE;
  wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_ARPROT;
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARQOS;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARREADY;

  // Master Interface Read Data
  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_RID;
  wire  [ NUM_AXI*AXI_DATA_W   -1 : 0 ]        M_AXI_RDATA;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_RRESP;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RLAST;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RREADY;

  wire wr_done;
  wire wr_ready;

  wire [NUM_AXI-1:0] wr_done_axi;

    // NPU Design
    // WRITE from BRAM to DDR
  wire [NUM_PU-1:0]outbuf_pop;
  reg  [ NUM_PU*AXI_DATA_WIDTH       -1 : 0 ]        data_from_outbuf;

    // READ from DDR to BRAM
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        data_to_inbuf;
  wire                                        inbuf_push;
  wire [ NUM_AXI-1:0]  inbuf_push_axi;
  wire                                        inbuf_full;

    // TXN REQ
  reg  rd_req;
  wire rd_ready;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size;
  reg  [ C_M_AXI_ADDR_WIDTH   -1 : 0 ]        rd_addr;
  reg  [ C_M_AXI_ADDR_WIDTH   -1 : 0 ]        wr_addr;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size;
  wire                                        wr_flush;
  wire [NUM_PU-1:0] write_valid;
  wire [NUM_AXI-1:0] wr_req_axi;
  reg  wr_req;

  assign write_valid = {NUM_PU{inbuf_push_axi[0]}};

  reg                                         fail_flag;

  reg                                         tx_fifo_push;
  reg                                         tx_fifo_pop;
  reg  [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        tx_fifo_data_in;
  wire [ TX_FIFO_DATA_WIDTH   -1 : 0 ]        tx_fifo_data_out;
  wire                                        tx_fifo_empty;
  wire                                        tx_fifo_full;

  integer aw_delay = 0;
  integer w_delay = 0;

  integer                             read_counter;
  integer                             write_counter;

reg  [ NUM_PU_W             -1 : 0 ]        wr_pu_id;
wire [ AXI_NUM_PU_W-1:0] wr_pu_id_axi;
wire [ AXI_ID_W-1:0] axi_id;

//assign {wr_pu_id_axi, axi_id} = wr_pu_id;
assign wr_pu_id_axi = wr_pu_id;
assign axi_id = 0;

// ******************************************************************

// ******************************************************************
initial begin
    $display("***************************************");
    $display ("Testing AXI Master");
    $display("***************************************");
    clk = 0;
    reset = 1;
    @(negedge clk);
    @(negedge clk);
    reset = 0;
    repeat(5) begin
      request_random_tx;
      aw_delay = aw_delay + 16;
      w_delay = w_delay + 4;
    end
    AXI_GEN[0].u_axim_driver.check_fail;
    AXI_GEN[0].u_axim_driver.test_pass;
end

initial begin
  rd_req = 0;
  wr_req = 0;
  wr_addr = 0;
end

task automatic request_random_tx;
  integer writes_remaining;
  integer ii;
  integer id;
  begin
    wait(!reset);
    wait(rd_ready);
    @(negedge clk);
    rd_req = 1'b1;
    rd_req_size = $urandom%1000;
    rd_addr = 0;
    if (VERBOSITY > 0)
      $display ("requesting %d reads", rd_req_size);
    @(negedge clk);
    rd_req = 1'b0;
    if (VERBOSITY > 0)
      $display ("request sent");
    @(negedge clk);
    wr_pu_id = 0;
    wr_addr = rd_addr;
    writes_remaining = rd_req_size;

    for (ii=0; ii<NUM_PU; ii=ii+1)
    begin
      id = ii%NUM_AXI;
      wr_addr = rd_req_size * ii * 8;
      wait (wr_ready);
      @(negedge clk);
      wr_req = 1;
      wr_req_size = rd_req_size;
      @(negedge clk);
      wr_req = 0;
      wr_pu_id = (wr_pu_id + 1) % NUM_PU;
    end

    for (ii=0; ii<NUM_PU; ii=ii+1)
    begin
      id = ii%NUM_AXI;
      wait (wr_ready);
    end

    repeat(100) @(negedge clk);

  end
endtask


  initial begin
    AXI_GEN[0].u_axim_driver.status.watchdog(1000000);
  end

always #1 clk = ~clk;

always @(posedge clk)
begin
end

initial
begin
    $dumpfile("axi_master_wrapper_tb.vcd");
    $dumpvars(0,axi_master_wrapper_tb);
end

genvar g, ii;

// ******************************************************************
// DUT - AXI-Master
// ******************************************************************
localparam AXI_ID_W = `C_LOG_2(NUM_AXI);
localparam NUM_PU_W = `C_LOG_2(NUM_PU)+1;
localparam AXI_NUM_PU_W = `C_LOG_2(PU_PER_AXI)+1;

generate
for (g=0; g<NUM_AXI; g=g+1)
begin: AXI_GEN

  // Master Interface Write Address
  wire [ TID_WIDTH            -1 : 0 ]        awid;
  wire [ ADDR_W               -1 : 0 ]        awaddr;
  wire [ 4                    -1 : 0 ]        awlen;
  wire [ 3                    -1 : 0 ]        awsize;
  wire [ 2                    -1 : 0 ]        awburst;
  wire [ 2                    -1 : 0 ]        awlock;
  wire [ 4                    -1 : 0 ]        awcache;
  wire [ 3                    -1 : 0 ]        awprot;
  wire [ 4                    -1 : 0 ]        awqos;
  wire                                        awvalid;
  wire                                        awready;

    // Master Interface Write Data
  wire [ TID_WIDTH            -1 : 0 ]        wid;
  wire [ AXI_DATA_W           -1 : 0 ]        wdata;
  wire [ WSTRB_W              -1 : 0 ]        wstrb;
  wire                                        wlast;
  wire                                        wvalid;
  wire                                        wready;

    // Master Interface Write Response
  wire [ TID_WIDTH            -1 : 0 ]        bid;
  wire [ 2                    -1 : 0 ]        bresp;
  wire                                        bvalid;
  wire                                        bready;

    // Master Interface Read Address
  wire [ TID_WIDTH            -1 : 0 ]        arid;
  wire [ ADDR_W               -1 : 0 ]        araddr;
  wire [ 4                    -1 : 0 ]        arlen;
  wire [ 3                    -1 : 0 ]        arsize;
  wire [ 2                    -1 : 0 ]        arburst;
  wire [ 2                    -1 : 0 ]        arlock;
  wire [ 4                    -1 : 0 ]        arcache;
  wire [ 3                    -1 : 0 ]        arprot;
  wire [ 4                    -1 : 0 ]        arqos;
  wire                                        arvalid;
  wire                                        arready;

    // Master Interface Read Data
  wire [ TID_WIDTH            -1 : 0 ]        rid;
  wire [ AXI_DATA_W           -1 : 0 ]        rdata;
  wire [ 2                    -1 : 0 ]        rresp;
  wire                                        rlast;
  wire                                        rvalid;
  wire                                        rready;

  // Master Interface Write Address
  assign awid = M_AXI_AWID[g*TID_WIDTH+:TID_WIDTH];
  assign awaddr = M_AXI_AWADDR[g*ADDR_W+:ADDR_W];
  assign awlen = M_AXI_AWLEN[g*4+:4];
  assign awsize = M_AXI_AWSIZE[g*3+:3];
  assign awburst = M_AXI_AWBURST[g*2+:2];
  assign awlock = M_AXI_AWLOCK[g*2+:2];
  assign awcache = M_AXI_AWCACHE[g*4+:4];
  assign awprot = M_AXI_AWPROT[g*3+:3];
  assign awqos = M_AXI_AWQOS[g*4+:4];
  assign awvalid = M_AXI_AWVALID[g*1+:1];
  assign M_AXI_AWREADY[g*1+:1] = awready;

  // Master Interface Write Data
  assign wid = M_AXI_WID[g*TID_WIDTH+:TID_WIDTH];
  assign wdata = M_AXI_WDATA[g*AXI_DATA_WIDTH+:AXI_DATA_WIDTH];
  assign wstrb = M_AXI_WSTRB[g*WSTRB_W+:WSTRB_W];
  assign wlast = M_AXI_WLAST[g*1+:1];
  assign wvalid = M_AXI_WVALID[g*1+:1];
  assign M_AXI_WREADY[g*1+:1] = wready;

  // Master Interface Write Response
  assign M_AXI_BID[g*TID_WIDTH+:TID_WIDTH] = bid;
  assign M_AXI_BRESP[g*2+:2] = bresp;
  assign M_AXI_BVALID[g*1+:1] = bvalid;
  assign bready = M_AXI_BREADY[g*1+:1];

  // Master Interface Read Address
  assign arid = M_AXI_ARID[g*TID_WIDTH+:TID_WIDTH];
  assign araddr = M_AXI_ARADDR[g*ADDR_W+:ADDR_W];
  assign arlen = M_AXI_ARLEN[g*4+:4];
  assign arsize = M_AXI_ARSIZE[g*3+:3];
  assign arburst = M_AXI_ARBURST[g*3+:3];
  assign arlock = M_AXI_ARLOCK[g*2+:2];
  assign arcache = M_AXI_ARCACHE[g*4+:4];
  assign arprot = M_AXI_ARPROT[g*3+:3];
  assign arqos = M_AXI_ARQOS[g*4+:4];
  assign arvalid = M_AXI_ARVALID[g*1+:1];
  assign M_AXI_ARREADY[g*1+:1] = arready;

  // Master Interface Read Data
  assign M_AXI_RID[g*TID_WIDTH+:TID_WIDTH] = rid;
  assign M_AXI_RDATA[g*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] = rdata;
  assign M_AXI_RRESP[g*2+:2] = rresp;
  assign M_AXI_RLAST[g*1+:1] = rlast;
  assign M_AXI_RVALID[g*1+:1] = rvalid;
  assign rready = M_AXI_RREADY[g*1+:1];

axi_master_tb_driver
#(
    .NUM_PU                   ( NUM_PU                   ),
    .TX_FIFO_DATA_WIDTH       ( TX_FIFO_DATA_WIDTH       ),
    .AXI_DATA_WIDTH           ( AXI_DATA_WIDTH           ),
    .C_M_AXI_SUPPORTS_WRITE   ( C_M_AXI_SUPPORTS_WRITE   ),
    .C_M_AXI_SUPPORTS_READ    ( C_M_AXI_SUPPORTS_READ    ),
    .C_M_AXI_READ_TARGET      ( C_M_AXI_READ_TARGET      ),
    .C_M_AXI_WRITE_TARGET     ( C_M_AXI_WRITE_TARGET     ),
    .C_OFFSET_WIDTH           ( C_OFFSET_WIDTH           ),
    .C_M_AXI_RD_BURST_LEN     ( C_M_AXI_RD_BURST_LEN     ),
    .C_M_AXI_WR_BURST_LEN     ( C_M_AXI_WR_BURST_LEN     ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            )
) u_axim_driver (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),

    .aw_delay                 ( aw_delay                 ),
    .w_delay                  ( w_delay                  ),

    .M_AXI_AWID               ( awid                     ),
    .M_AXI_AWADDR             ( awaddr                   ),
    .M_AXI_AWLEN              ( awlen                    ),
    .M_AXI_AWSIZE             ( awsize                   ),
    .M_AXI_AWBURST            ( awburst                  ),
    .M_AXI_AWLOCK             ( awlock                   ),
    .M_AXI_AWCACHE            ( awcache                  ),
    .M_AXI_AWPROT             ( awprot                   ),
    .M_AXI_AWQOS              ( awqos                    ),
    .M_AXI_AWVALID            ( awvalid                  ),
    .M_AXI_AWREADY            ( awready                  ),
    .M_AXI_WID                ( wid                      ),
    .M_AXI_WDATA              ( wdata                    ),
    .M_AXI_WSTRB              ( wstrb                    ),
    .M_AXI_WLAST              ( wlast                    ),
    .M_AXI_WVALID             ( wvalid                   ),
    .M_AXI_WREADY             ( wready                   ),
    .M_AXI_BID                ( bid                      ),
    .M_AXI_BRESP              ( bresp                    ),
    .M_AXI_BVALID             ( bvalid                   ),
    .M_AXI_BREADY             ( bready                   ),
    .M_AXI_ARID               ( arid                     ),
    .M_AXI_ARADDR             ( araddr                   ),
    .M_AXI_ARLEN              ( arlen                    ),
    .M_AXI_ARSIZE             ( arsize                   ),
    .M_AXI_ARBURST            ( arburst                  ),
    .M_AXI_ARLOCK             ( arlock                   ),
    .M_AXI_ARCACHE            ( arcache                  ),
    .M_AXI_ARPROT             ( arprot                   ),
    .M_AXI_ARQOS              ( arqos                    ),
    .M_AXI_ARVALID            ( arvalid                  ),
    .M_AXI_ARREADY            ( arready                  ),
    .M_AXI_RID                ( rid                      ),
    .M_AXI_RDATA              ( rdata                    ),
    .M_AXI_RRESP              ( rresp                    ),
    .M_AXI_RLAST              ( rlast                    ),
    .M_AXI_RVALID             ( rvalid                   ),
    .M_AXI_RREADY             ( rready                   ),
    .data_from_outbuf         (                          ),
    .data_to_inbuf            ( data_to_inbuf            ),
    .inbuf_push               ( inbuf_push               ),
    .inbuf_full               ( inbuf_full               )
  );
// ******************************************************************
end
endgenerate

generate
for (g=0; g<NUM_PU; g=g+1)
begin: DATAGEN
  always @(posedge clk)
    if (reset)
      data_from_outbuf[g*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] <= 0;
    else if (outbuf_pop[g])
      data_from_outbuf[g*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] <= data_from_outbuf[g*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] + g;
end
endgenerate

  axi_master_wrapper
  #(
    .NUM_AXI                  ( NUM_AXI                  ),
    .NUM_PU                   ( NUM_PU                   ),
    .TID_WIDTH                ( TID_WIDTH                ),
    .AXI_DATA_W               ( AXI_DATA_WIDTH           ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            )
  ) u_axim (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .M_AXI_AWID               ( M_AXI_AWID               ),
    .M_AXI_AWADDR             ( M_AXI_AWADDR             ),
    .M_AXI_AWLEN              ( M_AXI_AWLEN              ),
    .M_AXI_AWSIZE             ( M_AXI_AWSIZE             ),
    .M_AXI_AWBURST            ( M_AXI_AWBURST            ),
    .M_AXI_AWLOCK             ( M_AXI_AWLOCK             ),
    .M_AXI_AWCACHE            ( M_AXI_AWCACHE            ),
    .M_AXI_AWPROT             ( M_AXI_AWPROT             ),
    .M_AXI_AWQOS              ( M_AXI_AWQOS              ),
    .M_AXI_AWVALID            ( M_AXI_AWVALID            ),
    .M_AXI_AWREADY            ( M_AXI_AWREADY            ),
    .M_AXI_WID                ( M_AXI_WID                ),
    .M_AXI_WDATA              ( M_AXI_WDATA              ),
    .M_AXI_WSTRB              ( M_AXI_WSTRB              ),
    .M_AXI_WLAST              ( M_AXI_WLAST              ),
    .M_AXI_WVALID             ( M_AXI_WVALID             ),
    .M_AXI_WREADY             ( M_AXI_WREADY             ),
    .M_AXI_BID                ( M_AXI_BID                ),
    .M_AXI_BRESP              ( M_AXI_BRESP              ),
    .M_AXI_BVALID             ( M_AXI_BVALID             ),
    .M_AXI_BREADY             ( M_AXI_BREADY             ),
    .M_AXI_ARID               ( M_AXI_ARID               ),
    .M_AXI_ARADDR             ( M_AXI_ARADDR             ),
    .M_AXI_ARLEN              ( M_AXI_ARLEN              ),
    .M_AXI_ARSIZE             ( M_AXI_ARSIZE             ),
    .M_AXI_ARBURST            ( M_AXI_ARBURST            ),
    .M_AXI_ARLOCK             ( M_AXI_ARLOCK             ),
    .M_AXI_ARCACHE            ( M_AXI_ARCACHE            ),
    .M_AXI_ARPROT             ( M_AXI_ARPROT             ),
    .M_AXI_ARQOS              ( M_AXI_ARQOS              ),
    .M_AXI_ARVALID            ( M_AXI_ARVALID            ),
    .M_AXI_ARREADY            ( M_AXI_ARREADY            ),
    .M_AXI_RID                ( M_AXI_RID                ),
    .M_AXI_RDATA              ( M_AXI_RDATA              ),
    .M_AXI_RRESP              ( M_AXI_RRESP              ),
    .M_AXI_RLAST              ( M_AXI_RLAST              ),
    .M_AXI_RVALID             ( M_AXI_RVALID             ),
    .M_AXI_RREADY             ( M_AXI_RREADY             ),
    .outbuf_empty             ( outbuf_empty             ),
    .outbuf_pop               ( outbuf_pop               ),
    .data_from_outbuf         ( data_from_outbuf         ),
    .data_to_inbuf            ( data_to_inbuf            ),
    .inbuf_push               ( inbuf_push_axi           ),
    .inbuf_full               ( inbuf_full               ),
    .wr_req                   ( wr_req                   ),
    .wr_addr                  ( wr_addr                  ),
    .wr_pu_id                 ( wr_pu_id                 ),
    .wr_ready                 ( wr_ready                 ),
    .wr_done                  ( wr_done                  ),
    .wr_req_size              ( wr_req_size              ),
    .write_valid              ( write_valid              ),
    .rd_req                   ( rd_req                   ),
    .rd_ready                 ( rd_ready                 ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  )
  );
// ******************************************************************

endmodule
