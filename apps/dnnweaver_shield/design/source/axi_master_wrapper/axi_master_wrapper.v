`timescale 1ns/1ps
`include "common.vh"
module axi_master_wrapper
#( // INPUT PARAMETERS
  parameter integer NUM_PE                            = 4,
  parameter integer NUM_PU                            = 2,
  parameter integer OP_WIDTH                          = 16,
  parameter integer AXI_DATA_W                        = 64,
  parameter integer ADDR_W                            = 32,
  parameter integer BASE_ADDR_W                       = ADDR_W,
  parameter integer OFFSET_ADDR_W                     = ADDR_W,
  parameter integer RD_LOOP_W                         = 32,
  parameter integer TX_SIZE_WIDTH                     = 10,
  parameter integer D_TYPE_W                          = 2,
  parameter integer ROM_ADDR_W                        = 2,
  parameter integer TID_WIDTH                         = 6,
  parameter integer AXI_RD_BUFFER_W                   = 6,
  parameter integer NUM_AXI                           = 1
)( // PORTS
  input  wire                                         clk,
  input  wire                                         reset,

  // Master Interface Write Address
  output wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_AWID,
  output wire  [ NUM_AXI*ADDR_W       -1 : 0 ]        M_AXI_AWADDR,
  output wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_AWLEN,
  output wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_AWSIZE,
  output wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_AWBURST,
  output wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_AWLOCK,
  output wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_AWCACHE,
  output wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_AWPROT,
  output wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_AWQOS,
  output wire  [ NUM_AXI              -1 : 0 ]        M_AXI_AWVALID,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_AWREADY,

  // Master Interface Write Data
  output wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_WID,
  output wire  [ NUM_AXI*AXI_DATA_W   -1 : 0 ]        M_AXI_WDATA,
  output wire  [ NUM_AXI*WSTRB_W      -1 : 0 ]        M_AXI_WSTRB,
  output wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WLAST,
  output wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WVALID,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_WREADY,

  // Master Interface Write Response
  input  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_BID,
  input  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_BRESP,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_BVALID,
  output wire  [ NUM_AXI              -1 : 0 ]        M_AXI_BREADY,

  // Master Interface Read Address
  output wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_ARID,
  output wire  [ NUM_AXI*ADDR_W       -1 : 0 ]        M_AXI_ARADDR,
  output wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARLEN,
  output wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_ARSIZE,
  output wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_ARBURST,
  output wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_ARLOCK,
  output wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARCACHE,
  output wire  [ NUM_AXI*3            -1 : 0 ]        M_AXI_ARPROT,
  output wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARQOS,
  output wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARVALID,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARREADY,

  // Master Interface Read Data
  input  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_RID,
  input  wire  [ NUM_AXI*AXI_DATA_W   -1 : 0 ]        M_AXI_RDATA,
  input  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_RRESP,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RLAST,
  input  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RVALID,
  output wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RREADY,

  input  wire  [ NUM_PU               -1 : 0 ]        outbuf_empty,
  output wire  [ NUM_PU               -1 : 0 ]        outbuf_pop,
  input  wire  [ OUTBUF_DATA_W        -1 : 0 ]        data_from_outbuf,
  input  wire  [ NUM_PU               -1 : 0 ]        write_valid,

  input  wire                                         inbuf_full,
  output wire                                         inbuf_push,
  output wire  [ AXI_DATA_W           -1 : 0 ]        data_to_inbuf,

    // Memory Controller Interface - Read
  input  wire                                         rd_req,
  output wire                                         rd_ready,
  input  wire  [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size,
  input  wire  [ ADDR_W               -1 : 0 ]        rd_addr,

    // Memory Controller Interface - Write
  input  wire                                         wr_req,
  input  wire  [ PU_ID_W              -1 : 0 ]        wr_pu_id,
  output wire                                         wr_ready,
  input  wire  [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size,
  input  wire  [ ADDR_W               -1 : 0 ]        wr_addr,
  output wire                                         wr_done
);
// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer WSTRB_W = AXI_DATA_W/8;
  localparam integer PU_DATA_W = OP_WIDTH * NUM_PE;
  localparam integer OUTBUF_DATA_W = PU_DATA_W * NUM_PU;
  localparam integer AXI_OUT_DATA_W = AXI_DATA_W * NUM_PU;
  localparam integer PU_ID_W = `C_LOG_2(NUM_PU)+1;
// ******************************************************************
// WIRES
// ******************************************************************

localparam integer PU_PER_AXI = ceil_a_by_b(NUM_PU, NUM_AXI);
localparam integer AXI_ID_W = `C_LOG_2(NUM_AXI+0);
localparam integer AXI_PU_ID_W = `C_LOG_2(NUM_PU) + 1;

wire [NUM_AXI-1:0] rd_ready_axi;
wire [NUM_AXI-1:0] wr_ready_axi;
assign rd_ready = rd_ready_axi[0];
assign wr_ready = wr_ready_axi[write_axi_id];

assign wr_done = &wr_done_sticky;
reg  [NUM_AXI-1:0] wr_done_sticky;

wire [AXI_ID_W-1:0] write_axi_id;
wire [AXI_PU_ID_W-1:0] wr_pu_id_axi;

wire [NUM_AXI-1:0] inbuf_push_axi;
assign inbuf_push = inbuf_push_axi[0];

generate
if (NUM_AXI > 1) begin
  assign {wr_pu_id_axi, write_axi_id} = wr_pu_id;
end else begin
  assign wr_pu_id_axi = wr_pu_id;
  assign write_axi_id = 0;
end
endgenerate

genvar g, ii;
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
  assign M_AXI_AWID[g*TID_WIDTH+:TID_WIDTH] = awid;
  assign M_AXI_AWADDR[g*ADDR_W+:ADDR_W] = awaddr;
  assign M_AXI_AWLEN[g*4+:4] = awlen;
  assign M_AXI_AWSIZE[g*3+:3] = awsize;
  assign M_AXI_AWBURST[g*2+:2] = awburst;
  assign M_AXI_AWLOCK[g*2+:2] = awlock;
  assign M_AXI_AWCACHE[g*4+:4] = awcache;
  assign M_AXI_AWPROT[g*3+:3] = awprot;
  assign M_AXI_AWQOS[g*4+:4] = awqos;
  assign M_AXI_AWVALID[g*1+:1] = awvalid;
  assign awready = M_AXI_AWREADY[g*1+:1];

  // Master Interface Write Data
  assign M_AXI_WID[g*TID_WIDTH+:TID_WIDTH] = wid;
  assign M_AXI_WDATA[g*AXI_DATA_W+:AXI_DATA_W] = wdata;
  assign M_AXI_WSTRB[g*WSTRB_W+:WSTRB_W] = wstrb;
  assign M_AXI_WLAST[g*1+:1] = wlast;
  assign M_AXI_WVALID[g*1+:1] = wvalid;
  assign wready = M_AXI_WREADY[g*1+:1];

  // Master Interface Write Response
  assign bid = M_AXI_BID[g*TID_WIDTH+:TID_WIDTH];
  assign bresp = M_AXI_BRESP[g*2+:2];
  assign bvalid = M_AXI_BVALID[g*1+:1];
  assign M_AXI_BREADY[g*1+:1] = bready;

  // Master Interface Read Address
  assign M_AXI_ARID[g*TID_WIDTH+:TID_WIDTH] = arid;
  assign M_AXI_ARADDR[g*ADDR_W+:ADDR_W] = araddr;
  assign M_AXI_ARLEN[g*4+:4] = arlen;
  assign M_AXI_ARSIZE[g*3+:3] = arsize;
  assign M_AXI_ARBURST[g*2+:2] = arburst;
  assign M_AXI_ARLOCK[g*2+:2] = arlock;
  assign M_AXI_ARCACHE[g*4+:4] = arcache;
  assign M_AXI_ARPROT[g*3+:3] = arprot;
  assign M_AXI_ARQOS[g*4+:4] = arqos;
  assign M_AXI_ARVALID[g*1+:1] = arvalid;
  assign arready = M_AXI_ARREADY[g*1+:1];

  // Master Interface Read Data
  assign rid = M_AXI_RID[g*TID_WIDTH+:TID_WIDTH];
  assign rdata = M_AXI_RDATA[g*AXI_DATA_W+:AXI_DATA_W];
  assign rresp = M_AXI_RRESP[g*2+:2];
  assign rlast = M_AXI_RLAST[g*1+:1];
  assign rvalid = M_AXI_RVALID[g*1+:1];
  assign M_AXI_RREADY[g*1+:1] = rready;

  wire [ PU_PER_AXI           -1 : 0 ]        outbuf_pop_axi;
  wire [PU_PER_AXI*AXI_DATA_W    -1:0] data_from_outbuf_axi;

  for (ii=0; ii<PU_PER_AXI && (ii*NUM_AXI+g)<NUM_PU; ii=ii+1)
  begin
    assign outbuf_pop[ii*NUM_AXI+g] = outbuf_pop_axi[ii];
    assign data_from_outbuf_axi[ii*AXI_DATA_W+:AXI_DATA_W] =
      data_from_outbuf[(ii*NUM_AXI+g)*AXI_DATA_W+:AXI_DATA_W];
  end

  wire wr_ready_local;
  wire wr_done_local;
  wire wr_req_local;

  wire rd_req_local;
  wire rd_ready_local;

  wire inbuf_push_local;

  assign inbuf_push_axi[g] = inbuf_push_local;

  // TOTO: Use 4 AXI for Reads
  assign rd_req_local = rd_req && (g == 0);
  assign rd_ready_axi[g] = rd_ready_local;

  assign wr_ready_axi[g] = wr_ready_local;
  assign wr_req_local = wr_req && (write_axi_id == g);

  wire [AXI_DATA_W-1:0] data_to_inbuf_local;
  if (g == 0)
    assign data_to_inbuf = data_to_inbuf_local;

  always @(posedge clk)
  begin
    if (reset)
      wr_done_sticky[g] <= 1'b0;
    else begin
      if (wr_done_local)
        wr_done_sticky[g] <= 1'b1;
      else if (wr_done)
        wr_done_sticky[g] <= 1'b0;
    end
  end

axi_master
#(
    .NUM_PU                   ( PU_PER_AXI               ),
    .AXI_ID                   ( g                        ),
    .TID_WIDTH                ( TID_WIDTH                ),
    .AXI_DATA_WIDTH           ( AXI_DATA_W               ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            )
) u_axim (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
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
    .outbuf_empty             (                          ),
    .outbuf_pop               ( outbuf_pop_axi           ),
    .data_from_outbuf         ( data_from_outbuf_axi     ),
    .data_to_inbuf            ( data_to_inbuf_local      ),
    .inbuf_push               ( inbuf_push_local         ),
    .inbuf_full               ( inbuf_full               ),
    .wr_req                   ( wr_req_local             ),
    .wr_addr                  ( wr_addr                  ),
    .wr_pu_id                 ( wr_pu_id_axi             ),
    .wr_ready                 ( wr_ready_local           ),
    .wr_done                  ( wr_done_local            ),
    .wr_req_size              ( wr_req_size              ),
    .write_valid              ( write_valid              ),
    .rd_req                   ( rd_req_local             ),
    .rd_ready                 ( rd_ready_local           ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  )
);
// ******************************************************************
end
endgenerate

endmodule
