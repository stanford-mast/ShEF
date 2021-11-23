`timescale 1ns/1ps
`include "common.vh"
module mem_controller_top_4AXI
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
  parameter integer ARUSER_W                          = 1,
  parameter integer RUSER_W                           = 1,
  parameter integer BUSER_W                           = 1,
  parameter integer AWUSER_W                          = 1,
  parameter integer WUSER_W                           = 1,
  parameter integer TID_WIDTH                         = 6,
  parameter integer AXI_RD_BUFFER_W                   = 6,
  parameter integer NUM_AXI                           = 4
)( // PORTS
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         start,
  output wire                                         done,

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
  // AXI3 output wire [4-1:0]          M_AXI_ARREGION,
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

  output wire  [ RD_LOOP_W            -1 : 0 ]        pu_id_buf,
  output wire  [ D_TYPE_W             -1 : 0 ]        d_type_buf,
  output wire                                         next_read,

  output wire  [ NUM_PU               -1 : 0 ]        outbuf_full,
  input  wire  [ NUM_PU               -1 : 0 ]        outbuf_push,
  input  wire  [ OUTBUF_DATA_W        -1 : 0 ]        outbuf_data_in,

  output wire                                         stream_fifo_empty,
  input  wire                                         stream_fifo_pop,
  output wire  [ PU_DATA_W           -1 : 0 ]         stream_fifo_data_out,

  output wire                                         buffer_read_empty,
  input  wire                                         buffer_read_pop,
  output wire  [ AXI_DATA_W          -1 : 0 ]         buffer_read_data_out,

  // Debug
  output reg  [ 32                   -1 : 0 ]         buffer_read_count,
  output reg  [ 32                   -1 : 0 ]         stream_read_count,
  output wire [ 11                   -1 : 0 ]         inbuf_count,
  output wire [ NUM_PU               -1 : 0 ]         pu_write_valid,
  output wire [ ROM_ADDR_W           -1 : 0 ]         wr_cfg_idx,
  output wire [ ROM_ADDR_W           -1 : 0 ]         rd_cfg_idx

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
  reg  [ 32                   -1 : 0 ]        inbuf_push_count;
  wire [ AXI_OUT_DATA_W       -1 : 0 ]        outbuf_data_out;
  wire [ AXI_DATA_W           -1 : 0 ]        inbuf_data_in;

  wire                                        read_full;
  // Memory Controller Interface
  wire                                        rd_req;
  wire                                        rd_ready;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_rvalid_size;
  wire [ ADDR_W               -1 : 0 ]        rd_addr;

  wire [ RD_LOOP_W            -1 : 0 ]        pu_id;
  wire [ D_TYPE_W             -1 : 0 ]        d_type;

  wire                                        wr_req;
  wire [PU_ID_W-1:0] wr_pu_id;
  wire                                        wr_ready;
  wire [ ADDR_W               -1 : 0 ]        wr_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size;
  wire                                        wr_done;

  wire [ NUM_PU               -1 : 0 ]        outbuf_empty;
  wire [ NUM_PU               -1 : 0 ]        write_valid;
  wire [ NUM_PU               -1 : 0 ]        outbuf_pop;

  assign M_AXI_AWUSER = 0;
  assign M_AXI_WUSER = 0;
  assign M_AXI_ARUSER = 0;

  wire axi_rd_buffer_push;
  wire axi_rd_buffer_pop;
  wire axi_rd_buffer_empty;
  wire axi_rd_buffer_full;
  wire [AXI_DATA_W-1:0] axi_rd_buffer_data_in;
  wire [AXI_DATA_W-1:0] axi_rd_buffer_data_out;

  wire stream_fifo_push;
  //wire stream_fifo_pop;
  //wire stream_fifo_empty;
  wire stream_fifo_full;
  wire [PU_DATA_W-1:0] stream_fifo_data_in;
  //wire [AXI_DATA_W-1:0] stream_fifo_data_out;

  wire stream_push;
  wire buffer_push;
  wire stream_full;
  wire buffer_full;
  wire [AXI_DATA_W-1:0] stream_data_in;

  wire buffer_read_push;
  //wire buffer_read_pop;
  //wire buffer_read_empty;
  wire buffer_read_full;
  wire [AXI_DATA_W-1:0] buffer_read_data_in;
  //wire [AXI_DATA_W-1:0] buffer_read_data_out;

// ==================================================================
// ==================================================================
  mem_controller #(
  // INPUT PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_PU                   ( NUM_PU                   ),
    .ADDR_W                   ( ADDR_W                   ),
    .BASE_ADDR_W              ( BASE_ADDR_W              ),
    .OFFSET_ADDR_W            ( OFFSET_ADDR_W            ),
    .RD_LOOP_W                ( RD_LOOP_W                ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .ROM_ADDR_W               ( ROM_ADDR_W               )
  ) u_mem_ctrl ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),
    .rd_cfg_idx               ( rd_cfg_idx               ),
    .wr_cfg_idx               ( wr_cfg_idx               ),
    .pu_id                    ( pu_id                    ),
    .d_type                   ( d_type                   ),
    .rd_req                   ( rd_req                   ),
    .rd_ready                 ( rd_ready                 ),
    .rd_req_size              ( rd_req_size              ),
    .rd_rvalid_size           ( rd_rvalid_size           ),
    .rd_addr                  ( rd_addr                  ),
    .wr_req                   ( wr_req                   ),
    .wr_pu_id                 ( wr_pu_id                 ),
    .wr_ready                 ( wr_ready                 ),
    .wr_req_size              ( wr_req_size              ),
    .wr_addr                  ( wr_addr                  ),
    .wr_done                  ( wr_done                  )
  );
// ==================================================================

// ==================================================================
// AXI Master - Generate block
// ==================================================================

localparam PU_PER_AXI = ceil_a_by_b(NUM_PU, NUM_AXI);
localparam AXI_PU_ID_W = `C_LOG_2(PU_PER_AXI)+1;
localparam AXI_ID_W = `C_LOG_2(NUM_AXI);

wire [AXI_PU_ID_W-1:0] wr_pu_id_axi;
wire [AXI_ID_W-1:0] axi_id;

assign {wr_pu_id_axi, axi_id} = wr_pu_id;

genvar ii, g;
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
  wire [ WUSER_W              -1 : 0 ]        wuser;
  wire                                        wvalid;
  wire                                        wready;

    // Master Interface Write Response
  wire [ TID_WIDTH            -1 : 0 ]        bid;
  wire [ 2                    -1 : 0 ]        bresp;
  wire [ BUSER_W              -1 : 0 ]        buser;
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
  wire [ ARUSER_W             -1 : 0 ]        aruser;
  wire                                        arvalid;
  wire                                        arready;

    // Master Interface Read Data
  wire [ TID_WIDTH            -1 : 0 ]        rid;
  wire [ AXI_DATA_W           -1 : 0 ]        rdata;
  wire [ 2                    -1 : 0 ]        rresp;
  wire                                        rlast;
  wire [ RUSER_W              -1 : 0 ]        ruser;
  wire                                        rvalid;
  wire                                        rready;

  wire local_wr_req;
  assign local_wr_req = wr_req && (axi_id == g);

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
  assign bid = M_AXI_BID[g*1+:1];
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

  wire [PU_PER_AXI-1:0] write_valid_axi;
  wire [PU_PER_AXI-1:0] outbuf_empty_axi;
  wire [PU_PER_AXI-1:0] outbuf_pop_axi;
  wire [PU_PER_AXI*AXI_DATA_W-1:0] data_from_outbuf_axi;

  for (ii=0; ii<PU_PER_AXI && (ii*NUM_AXI+g)<NUM_PU; ii=ii+1)
  begin
    assign outbuf_empty_axi[ii] = outbuf_empty[ii*NUM_AXI+g];
    assign outbuf_pop[ii*NUM_AXI+g] = outbuf_pop_axi[ii];
    assign data_from_outbuf_axi[ii*AXI_DATA_W+:AXI_DATA_W] =
      outbuf_data_out[(ii*NUM_AXI+g)*AXI_DATA_W+:AXI_DATA_W];
    assign write_valid_axi[ii] = write_valid[ii*NUM_AXI+g];
  end

  wire [ AXI_DATA_W -1:0] data_to_inbuf_axi;

  wire rd_req_axi;
  assign rd_req_axi = rd_req && (g==0);

  if (g == 0)
  begin
    assign axi_rd_buffer_data_in = data_to_inbuf_axi;
    assign axi_rd_buffer_push = inbuf_push_axi;
    assign rd_ready = rd_ready_axi;
  end

  assign wr_ready = (axi_id == g) ? wr_ready_axi : 'bz;
  assign wr_done  = (axi_id == g) ? wr_done_axi : 'bz;

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
    .M_AXI_AWUSER             ( awuser                   ),
    .M_AXI_AWVALID            ( awvalid                  ),
    .M_AXI_AWREADY            ( awready                  ),
    .M_AXI_WID                ( wid                      ),
    .M_AXI_WDATA              ( wdata                    ),
    .M_AXI_WSTRB              ( wstrb                    ),
    .M_AXI_WLAST              ( wlast                    ),
    .M_AXI_WUSER              ( wuser                    ),
    .M_AXI_WVALID             ( wvalid                   ),
    .M_AXI_WREADY             ( wready                   ),
    .M_AXI_BID                ( bid                      ),
    .M_AXI_BRESP              ( bresp                    ),
    .M_AXI_BUSER              ( buser                    ),
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
    .M_AXI_ARUSER             ( aruser                   ),
    .M_AXI_ARVALID            ( arvalid                  ),
    .M_AXI_ARREADY            ( arready                  ),
    .M_AXI_RID                ( rid                      ),
    .M_AXI_RDATA              ( rdata                    ),
    .M_AXI_RRESP              ( rresp                    ),
    .M_AXI_RLAST              ( rlast                    ),
    .M_AXI_RUSER              ( ruser                    ),
    .M_AXI_RVALID             ( rvalid                   ),
    .M_AXI_RREADY             ( rready                   ),

    .outbuf_empty             ( outbuf_empty_axi         ),
    .outbuf_pop               ( outbuf_pop_axi           ),
    .data_from_outbuf         ( data_from_outbuf_axi     ),

    .data_to_inbuf            ( data_to_inbuf_axi        ),
    .inbuf_push               ( inbuf_push_axi           ),
    .inbuf_full               ( read_full                ),

    .wr_req                   ( local_wr_req             ),
    .wr_pu_id                 ( wr_pu_id_axi             ),
    .wr_ready                 ( wr_ready_axi             ),
    .wr_done                  ( wr_done_axi              ),
    .wr_addr                  ( wr_addr                  ),
    .wr_req_size              ( wr_req_size              ),
    .write_valid              ( write_valid_axi          ),

    .rd_req                   ( rd_req_axi               ),
    .rd_ready                 ( rd_ready_axi             ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  )
  );
end
endgenerate
// ******************************************************************

// ==================================================================
assign read_full = axi_rd_buffer_full || read_info_full;

// ==================================================================
// OutBuf - Output Buffer
// ==================================================================

genvar i;
generate
for (i=0; i<NUM_PU; i=i+1)
begin: OUTPUT_BUFFER_GEN

  wire [ PU_DATA_W               -1 : 0 ]     ob_iw_data_in;
  wire [ PU_DATA_W               -1 : 0 ]     ob_iw_data_out;
  wire                                        ob_iw_push;
  wire                                        ob_iw_pop;
  wire                                        ob_iw_full;
  wire                                        ob_iw_empty;

  assign outbuf_full[i] = ob_iw_full;
  assign ob_iw_push = outbuf_push[i];
  assign ob_iw_data_in = outbuf_data_in[i*PU_DATA_W+:PU_DATA_W];

  fifo #(
    .DATA_WIDTH               ( PU_DATA_W                ),
    .ADDR_WIDTH               ( 7                        )
  ) outbuf_iwidth (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( ob_iw_push               ),  //input
    .pop                      ( ob_iw_pop                ),  //input
    .data_in                  ( ob_iw_data_in            ),  //input
    .data_out                 ( ob_iw_data_out           ),  //output
    .full                     ( ob_iw_full               ),  //output
    .empty                    ( ob_iw_empty              ),  //output
    .fifo_count               (                          )   //output
  );

  wire m_packed_read_req;
  wire m_packed_read_ready;
  wire [PU_DATA_W-1:0] m_packed_read_data;
  wire m_unpacked_write_req;
  wire m_unpacked_write_ready;
  wire [AXI_DATA_W-1:0] m_unpacked_write_data;

  assign m_packed_read_ready = !ob_iw_empty;
  assign ob_iw_pop = m_packed_read_req;
  assign m_packed_read_data = ob_iw_data_out;

  data_unpacker #(
    .IN_WIDTH                 ( PU_DATA_W                ),
    .OUT_WIDTH                ( AXI_DATA_W               )
  ) d_unpacker (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .m_packed_read_req        ( m_packed_read_req        ),  //output
    .m_packed_read_ready      ( m_packed_read_ready      ),  //input
    .m_packed_read_data       ( m_packed_read_data       ),  //output
    .m_unpacked_write_req     ( m_unpacked_write_req     ),  //output
    .m_unpacked_write_ready   ( m_unpacked_write_ready   ),  //input
    .m_unpacked_write_data    ( m_unpacked_write_data    )   //output
  );

  wire [ AXI_DATA_W               -1 : 0 ]    ob_ow_data_in;
  wire [ AXI_DATA_W               -1 : 0 ]    ob_ow_data_out;
  wire                                        ob_ow_push;
  wire                                        ob_ow_pop;
  wire                                        ob_ow_full;
  wire                                        ob_ow_empty;

  assign outbuf_empty[i] = ob_ow_empty;
  assign ob_ow_pop = outbuf_pop[i];
  assign outbuf_data_out[i*AXI_DATA_W+:AXI_DATA_W] = ob_ow_data_out;

  assign ob_ow_push = m_unpacked_write_req;
  assign m_unpacked_write_ready = !ob_ow_full;
  assign ob_ow_data_in = m_unpacked_write_data;

  assign write_valid[i] = ob_ow_push;

  reg  [ 32                   -1 : 0 ]        obuf_ow_push_count;
  always @(posedge clk)
    if (reset)
      obuf_ow_push_count <= 0;
    else if (ob_ow_push)
      obuf_ow_push_count <= obuf_ow_push_count + 1;


  `ifdef simulation
    always @(posedge clk)
    begin
      if (ob_ow_push && ob_ow_full) begin
        $error("Pushing to a full output buffer. Buffer number %d", i);
        $fatal(0);
      end
    end
  `endif


    fifo_fwft #(
      .DATA_WIDTH               ( AXI_DATA_W               ),
      .ADDR_WIDTH               ( 8                        )
    ) outbuf_owidth (
      .clk                      ( clk                      ),  //input
      .reset                    ( reset                    ),  //input
      .push                     ( ob_ow_push               ),  //input
      .pop                      ( ob_ow_pop                ),  //input
      .data_in                  ( ob_ow_data_in            ),  //input
      .data_out                 ( ob_ow_data_out           ),  //output
      .full                     ( ob_ow_full               ),  //output
      .empty                    ( ob_ow_empty              ),  //output
      .fifo_count               (                          )   //output
    );
end
endgenerate

// ==================================================================

// ==================================================================
// InBuf - Input Buffer
// ==================================================================

  fifo#(
    .DATA_WIDTH               ( AXI_DATA_W               ),
    .ADDR_WIDTH               ( AXI_RD_BUFFER_W          )
  ) axi_rd_buffer (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( axi_rd_buffer_push       ),  //input
    .full                     ( axi_rd_buffer_full       ),  //output
    .data_in                  ( axi_rd_buffer_data_in    ),  //input
    .pop                      ( axi_rd_buffer_pop        ),  //input
    .empty                    ( axi_rd_buffer_empty      ),  //output
    .data_out                 ( axi_rd_buffer_data_out   ),  //output
    .fifo_count               (                          )   //output
  );

  assign stream_data_in = axi_rd_buffer_data_out;

  data_packer #(
    .IN_WIDTH                 ( AXI_DATA_W               ),
    .OUT_WIDTH                ( PU_DATA_W                )
  ) packer (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .s_write_req              ( stream_push              ),  //input
    .s_write_data             ( stream_data_in           ),  //input
    .s_write_ready            (                          ),  //output
    .m_write_req              ( stream_fifo_push         ),  //output
    .m_write_data             ( stream_fifo_data_in      ),  //output
    .m_write_ready            ( !stream_fifo_full        )   //input
  );

  assign stream_full = stream_fifo_full;

  fifo#(
    .DATA_WIDTH               ( PU_DATA_W                ),
    .ADDR_WIDTH               ( 8                        )
  ) stream_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( stream_fifo_push         ),  //input
    .full                     ( stream_fifo_full         ),  //output
    .data_in                  ( stream_fifo_data_in      ),  //input
    .pop                      ( stream_fifo_pop          ),  //input
    .empty                    ( stream_fifo_empty        ),  //output
    .data_out                 ( stream_fifo_data_out     ),  //output
    .fifo_count               (                          )   //output
  );

  assign buffer_read_data_in = axi_rd_buffer_data_out;
  assign buffer_read_push = buffer_push;

  assign buffer_full = buffer_read_full;

  fifo#(
    .DATA_WIDTH               ( AXI_DATA_W               ),
    .ADDR_WIDTH               ( 8                        )
  ) buffer_read (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( buffer_read_push         ),  //input
    .full                     ( buffer_read_full         ),  //output
    .data_in                  ( buffer_read_data_in      ),  //input
    .pop                      ( buffer_read_pop          ),  //input
    .empty                    ( buffer_read_empty        ),  //output
    .data_out                 ( buffer_read_data_out     ),  //output
    .fifo_count               (                          )   //output
  );

  always @(posedge clk)
    if (reset)
      inbuf_push_count <= 0;
    else if (stream_push || buffer_push)
      inbuf_push_count <= inbuf_push_count + 1;
// ==================================================================

// ==================================================================
// PU_ID & D_TYPE
// ==================================================================
reg inbuf_valid_read;
  always @(posedge clk)
    if (reset)
      inbuf_valid_read <= 0;
    else
      inbuf_valid_read <= (stream_fifo_pop && !stream_fifo_empty) ||
    (buffer_read_pop && !buffer_read_empty);

reg  [ D_TYPE_W             -1 : 0 ]        d_type_buf_d;
  always @(posedge clk)
    if (reset)
      d_type_buf_d <= 0;
    else
      d_type_buf_d <=  d_type_buf;

  always @(posedge clk)
    if (reset)
      buffer_read_count <= 0;
    else if (buffer_read_push)
      buffer_read_count <=  buffer_read_count + 1'b1;

  reg  [ 32                   -1 : 0 ]         stream_packer_push_count;
  always @(posedge clk)
    if (reset)
      stream_read_count <= 0;
    else if (stream_fifo_push)
      stream_read_count <=  stream_read_count + 1'b1;

  always @(posedge clk)
    if (reset)
      stream_packer_push_count <= 0;
    else if (stream_push)
      stream_packer_push_count <=  stream_packer_push_count + 1'b1;

read_info #(
    .NUM_PU                   ( NUM_PU                   ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .RD_SIZE_W                ( TX_SIZE_WIDTH            )
)
u_read_info
(
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .inbuf_pop                ( axi_rd_buffer_pop        ),
    .inbuf_empty              ( axi_rd_buffer_empty      ),
    .read_info_full           ( read_info_full           ),
    .rd_req                   ( rd_req                   ),
    .rd_req_size              ( rd_req_size              ),
    .rd_req_pu_id             ( pu_id                    ),
    .rd_req_d_type            ( d_type                   ),
    .pu_id                    ( pu_id_buf                ),
    .stream_push              ( stream_push              ),
    .buffer_push              ( buffer_push              ),
    .stream_full              ( stream_full              ),
    .buffer_full              ( buffer_full              ),
    .d_type                   ( d_type_buf               )
);


// ==================================================================

// ==================================================================
// DEBUG
// ==================================================================
  assign pu_write_valid = write_valid;
// ==================================================================
endmodule
