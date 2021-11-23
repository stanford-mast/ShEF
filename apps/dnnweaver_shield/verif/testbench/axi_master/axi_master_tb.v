`timescale 1ns/1ps
module axi_master_tb;
// ******************************************************************
// PARAMETERS
// ******************************************************************
  parameter integer VERBOSITY = 1;
   parameter integer MAX_AR_DELAY             = 8;
   parameter integer TX_FIFO_DATA_WIDTH       = 16;
   parameter integer TID_WIDTH                = 6;
   parameter integer C_M_AXI_ADDR_WIDTH       = 32;
   parameter integer AXI_DATA_WIDTH           = 64;
   parameter integer C_M_AXI_AWUSER_WIDTH     = 1;
   parameter integer C_M_AXI_ARUSER_WIDTH     = 1;
   parameter integer C_M_AXI_WUSER_WIDTH      = 1;
   parameter integer C_M_AXI_RUSER_WIDTH      = 1;
   parameter integer C_M_AXI_BUSER_WIDTH      = 1;
   parameter integer C_M_AXI_SUPPORTS_WRITE   = 1;
   parameter integer C_M_AXI_SUPPORTS_READ    = 1;
   parameter integer C_M_AXI_READ_TARGET      = 32'hFFFF0000;
   parameter integer C_M_AXI_WRITE_TARGET     = 32'hFFFF8000;
   parameter integer C_OFFSET_WIDTH           = 11;
   parameter integer C_M_AXI_RD_BURST_LEN     = 16;
   parameter integer C_M_AXI_WR_BURST_LEN     = 16;
   parameter integer TX_SIZE_WIDTH            = 20;
   parameter integer OUTBUF_DATA_W            = AXI_DATA_WIDTH*NUM_PU;

   parameter integer NUM_PU                   = 10;
   parameter integer NUM_AXI                  = 1;
   parameter integer PU_PER_AXI               = ceil_a_by_b(NUM_PU, NUM_AXI);
// ******************************************************************

// ******************************************************************
// IO
// ******************************************************************

  // System Signals
  reg                                         clk;
  reg                                         reset;

  wire wr_done;
  wire wr_ready;

  wire [NUM_AXI-1:0] wr_done_axi;
  wire [NUM_AXI-1:0] wr_ready_axi;

    // NPU Design
    // WRITE from BRAM to DDR
  wire [NUM_PU-1:0]outbuf_pop;
  reg  [ NUM_PU*AXI_DATA_WIDTH       -1 : 0 ]        data_from_outbuf;

    // READ from DDR to BRAM
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        data_to_inbuf;
  wire                                        inbuf_push;
  wire [ NUM_PU-1:0]  inbuf_push_axi;
  wire                                        inbuf_full;

    // TXN REQ
  reg  [NUM_AXI-1:0] rd_req_axi;
  wire [NUM_AXI-1:0] rd_ready_axi;
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
  rd_req_axi = 0;
  wr_req = 0;
  wr_addr = 0;
end

task automatic request_random_tx;
  integer writes_remaining;
  integer ii;
  integer id;
  begin
    wait(!reset);
    wait(rd_ready_axi[0]);
    @(negedge clk);
    rd_req_axi = 1'b1;
    rd_req_size = $urandom%1000;
    rd_addr = 0;
    if (VERBOSITY > 0)
      $display ("requesting %d reads", rd_req_size);
    @(negedge clk);
    rd_req_axi = 1'b0;
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
      wait (wr_ready_axi[id]);
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
      wait (wr_ready_axi[id]);
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
    $dumpfile("axi_master_tb.vcd");
    $dumpvars(0,axi_master_tb);
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
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_AWID;
  wire [ C_M_AXI_ADDR_WIDTH   -1 : 0 ]        M_AXI_AWADDR;
  wire [ 4                    -1 : 0 ]        M_AXI_AWLEN;
  wire [ 3                    -1 : 0 ]        M_AXI_AWSIZE;
  wire [ 2                    -1 : 0 ]        M_AXI_AWBURST;
  wire [ 2                    -1 : 0 ]        M_AXI_AWLOCK;
  wire [ 4                    -1 : 0 ]        M_AXI_AWCACHE;
  wire [ 3                    -1 : 0 ]        M_AXI_AWPROT;
  wire [ 4                    -1 : 0 ]        M_AXI_AWQOS;
  wire [ C_M_AXI_AWUSER_WIDTH -1 : 0 ]        M_AXI_AWUSER;
  wire                                        M_AXI_AWVALID;
  wire                                        M_AXI_AWREADY;

    // Master Interface Write Data
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_WID;
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        M_AXI_WDATA;
    wire [AXI_DATA_WIDTH/8-1:0]     M_AXI_WSTRB;
  wire                                        M_AXI_WLAST;
  wire [ C_M_AXI_WUSER_WIDTH  -1 : 0 ]        M_AXI_WUSER;
  wire                                        M_AXI_WVALID;
  wire                                        M_AXI_WREADY;

    // Master Interface Write Response
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_BID;
  wire [ 2                    -1 : 0 ]        M_AXI_BRESP;
  wire [ C_M_AXI_BUSER_WIDTH  -1 : 0 ]        M_AXI_BUSER;
  wire                                        M_AXI_BVALID;
  wire                                        M_AXI_BREADY;

    // Master Interface Read Address
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_ARID;
  wire [ C_M_AXI_ADDR_WIDTH   -1 : 0 ]        M_AXI_ARADDR;
  wire [ 4                    -1 : 0 ]        M_AXI_ARLEN;
  wire [ 3                    -1 : 0 ]        M_AXI_ARSIZE;
  wire [ 2                    -1 : 0 ]        M_AXI_ARBURST;
  wire [ 2                    -1 : 0 ]        M_AXI_ARLOCK;
  wire [ 4                    -1 : 0 ]        M_AXI_ARCACHE;
  wire [ 3                    -1 : 0 ]        M_AXI_ARPROT;
  wire [ 4                    -1 : 0 ]        M_AXI_ARQOS;
  wire [ C_M_AXI_ARUSER_WIDTH -1 : 0 ]        M_AXI_ARUSER;
  wire                                        M_AXI_ARVALID;
  wire                                        M_AXI_ARREADY;

    // Master Interface Read Data
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_RID;
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        M_AXI_RDATA;
  wire [ 2                    -1 : 0 ]        M_AXI_RRESP;
  wire                                        M_AXI_RLAST;
  wire [ C_M_AXI_RUSER_WIDTH  -1 : 0 ]        M_AXI_RUSER;
  wire                                        M_AXI_RVALID;
  wire                                        M_AXI_RREADY;

  wire local_wr_req;
  assign local_wr_req = wr_req && (axi_id == g);
  assign wr_req_axi[g] = wr_req && (axi_id == g);
  wire [PU_PER_AXI-1:0]outbuf_empty;
  assign outbuf_empty = {PU_PER_AXI{1'b0}};
  wire [PU_PER_AXI-1:0] outbuf_pop_axi;
  wire [PU_PER_AXI*AXI_DATA_WIDTH-1:0] data_from_outbuf_axi;

  for (ii=0; ii<PU_PER_AXI && (ii*NUM_AXI+g)<NUM_PU; ii=ii+1)
  begin
    assign outbuf_pop[ii*NUM_AXI+g] = outbuf_pop_axi[ii];
    assign data_from_outbuf_axi[ii*AXI_DATA_WIDTH+:AXI_DATA_WIDTH] =
      data_from_outbuf[(ii*NUM_AXI+g)*AXI_DATA_WIDTH+:AXI_DATA_WIDTH];
  end

axi_master
#(
    .NUM_PU                   ( PU_PER_AXI               ),
    .AXI_ID                   ( g                        ),
    .TID_WIDTH                ( TID_WIDTH                ),
    .AXI_DATA_WIDTH           ( AXI_DATA_WIDTH           ),
    .C_M_AXI_SUPPORTS_WRITE   ( C_M_AXI_SUPPORTS_WRITE   ),
    .C_M_AXI_SUPPORTS_READ    ( C_M_AXI_SUPPORTS_READ    ),
    .C_M_AXI_READ_TARGET      ( C_M_AXI_READ_TARGET      ),
    .C_M_AXI_WRITE_TARGET     ( C_M_AXI_WRITE_TARGET     ),
    .C_OFFSET_WIDTH           ( C_OFFSET_WIDTH           ),
    .C_M_AXI_RD_BURST_LEN     ( C_M_AXI_RD_BURST_LEN     ),
    .C_M_AXI_WR_BURST_LEN     ( C_M_AXI_WR_BURST_LEN     ),
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
    .M_AXI_AWUSER             ( M_AXI_AWUSER             ),
    .M_AXI_AWVALID            ( M_AXI_AWVALID            ),
    .M_AXI_AWREADY            ( M_AXI_AWREADY            ),
    .M_AXI_WID                ( M_AXI_WID                ),
    .M_AXI_WDATA              ( M_AXI_WDATA              ),
    .M_AXI_WSTRB              ( M_AXI_WSTRB              ),
    .M_AXI_WLAST              ( M_AXI_WLAST              ),
    .M_AXI_WUSER              ( M_AXI_WUSER              ),
    .M_AXI_WVALID             ( M_AXI_WVALID             ),
    .M_AXI_WREADY             ( M_AXI_WREADY             ),
    .M_AXI_BID                ( M_AXI_BID                ),
    .M_AXI_BRESP              ( M_AXI_BRESP              ),
    .M_AXI_BUSER              ( M_AXI_BUSER              ),
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
    .M_AXI_ARUSER             ( M_AXI_ARUSER             ),
    .M_AXI_ARVALID            ( M_AXI_ARVALID            ),
    .M_AXI_ARREADY            ( M_AXI_ARREADY            ),
    .M_AXI_RID                ( M_AXI_RID                ),
    .M_AXI_RDATA              ( M_AXI_RDATA              ),
    .M_AXI_RRESP              ( M_AXI_RRESP              ),
    .M_AXI_RLAST              ( M_AXI_RLAST              ),
    .M_AXI_RUSER              ( M_AXI_RUSER              ),
    .M_AXI_RVALID             ( M_AXI_RVALID             ),
    .M_AXI_RREADY             ( M_AXI_RREADY             ),
    .outbuf_empty             ( outbuf_empty             ),
    .outbuf_pop               ( outbuf_pop_axi           ),
    .data_from_outbuf         ( data_from_outbuf_axi     ),
    .data_to_inbuf            ( data_to_inbuf            ),
    .inbuf_push               ( inbuf_push_axi[g]        ),
    .inbuf_full               ( inbuf_full               ),
    .wr_req                   ( local_wr_req             ),
    .wr_addr                  ( wr_addr                  ),
    .wr_pu_id                 ( wr_pu_id_axi             ),
    .wr_ready                 ( wr_ready_axi[g]          ),
    .wr_done                  ( wr_done_axi[g]           ),
    .wr_req_size              ( wr_req_size              ),
    .write_valid              ( write_valid              ),
    .rd_req                   ( rd_req_axi[g]            ),
    .rd_ready                 ( rd_ready_axi[g]          ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  )
);
// ******************************************************************

// ******************************************************************
// AXI_MASTER_TB
// ******************************************************************
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

    .M_AXI_AWID               ( M_AXI_AWID               ),
    .M_AXI_AWADDR             ( M_AXI_AWADDR             ),
    .M_AXI_AWLEN              ( M_AXI_AWLEN              ),
    .M_AXI_AWSIZE             ( M_AXI_AWSIZE             ),
    .M_AXI_AWBURST            ( M_AXI_AWBURST            ),
    .M_AXI_AWLOCK             ( M_AXI_AWLOCK             ),
    .M_AXI_AWCACHE            ( M_AXI_AWCACHE            ),
    .M_AXI_AWPROT             ( M_AXI_AWPROT             ),
    .M_AXI_AWQOS              ( M_AXI_AWQOS              ),
    .M_AXI_AWUSER             ( M_AXI_AWUSER             ),
    .M_AXI_AWVALID            ( M_AXI_AWVALID            ),
    .M_AXI_AWREADY            ( M_AXI_AWREADY            ),
    .M_AXI_WID                ( M_AXI_WID                ),
    .M_AXI_WDATA              ( M_AXI_WDATA              ),
    .M_AXI_WSTRB              ( M_AXI_WSTRB              ),
    .M_AXI_WLAST              ( M_AXI_WLAST              ),
    .M_AXI_WUSER              ( M_AXI_WUSER              ),
    .M_AXI_WVALID             ( M_AXI_WVALID             ),
    .M_AXI_WREADY             ( M_AXI_WREADY             ),
    .M_AXI_BID                ( M_AXI_BID                ),
    .M_AXI_BRESP              ( M_AXI_BRESP              ),
    .M_AXI_BUSER              ( M_AXI_BUSER              ),
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
    .M_AXI_ARUSER             ( M_AXI_ARUSER             ),
    .M_AXI_ARVALID            ( M_AXI_ARVALID            ),
    .M_AXI_ARREADY            ( M_AXI_ARREADY            ),
    .M_AXI_RID                ( M_AXI_RID                ),
    .M_AXI_RDATA              ( M_AXI_RDATA              ),
    .M_AXI_RRESP              ( M_AXI_RRESP              ),
    .M_AXI_RLAST              ( M_AXI_RLAST              ),
    .M_AXI_RUSER              ( M_AXI_RUSER              ),
    .M_AXI_RVALID             ( M_AXI_RVALID             ),
    .M_AXI_RREADY             ( M_AXI_RREADY             ),
    .outbuf_empty             (                          ),
    .outbuf_pop               ( outbuf_pop               ),
    .data_from_outbuf         (                          ),
    .data_to_inbuf            ( data_to_inbuf            ),
    .inbuf_push               ( inbuf_push               ),
    .inbuf_full               ( inbuf_full               ),
    //.rd_req                   ( rd_req                   ),
    //.rd_ready                 ( rd_ready                 ),
    //.rd_req_size              ( rd_req_size              ),
    //.rd_addr                  ( rd_addr                  ),
    .write_valid              ( write_valid              ),
    //.wr_req                   ( wr_req                   ),
    //.wr_pu_id                 ( wr_pu_id                 ),
    //.wr_req_size              ( wr_req_size              ),
    //.wr_addr                  ( wr_addr                  ),
    //.wr_done                  ( wr_done                  ),
    .wr_ready                 ( wr_ready                 )
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

endmodule
