`timescale 1ns/1ps
`include "common.vh"
module mem_controller_top
#( // INPUT PARAMETERS
  parameter integer NUM_PE                            = 4,
  parameter integer NUM_PU                            = 2,
  parameter integer NUM_AXI                           = 1,
  parameter integer OP_WIDTH                          = 16,
  parameter integer AXI_DATA_W                        = 64,
  parameter integer ADDR_W                            = 32,
  parameter integer BASE_ADDR_W                       = ADDR_W,
  parameter integer OFFSET_ADDR_W                     = ADDR_W,
  parameter integer RD_LOOP_W                         = 32,
  parameter integer TX_SIZE_WIDTH                     = 20,
  parameter integer D_TYPE_W                          = 2,
  parameter integer RD_ROM_ADDR_W                     = `C_LOG_2(`max_rd_mem_idx+2),
  parameter integer WR_ROM_ADDR_W                     = `C_LOG_2(`max_wr_mem_idx+2),
  parameter integer ARUSER_W                          = 2,
  parameter integer RUSER_W                           = 2,
  parameter integer BUSER_W                           = 2,
  parameter integer AWUSER_W                          = 2,
  parameter integer WUSER_W                           = 2,
  parameter integer TID_WIDTH                         = 6,
  parameter integer AXI_RD_BUFFER_W                   = 6
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

  output wire  [ PU_ID_W              -1 : 0 ]        pu_id_buf,
  output wire  [ D_TYPE_W             -1 : 0 ]        d_type_buf,
  output wire                                         next_read,

  output wire  [ NUM_PU               -1 : 0 ]        outbuf_full,
  input  wire  [ NUM_PU               -1 : 0 ]        outbuf_push,
  input  wire  [ OUTBUF_DATA_W        -1 : 0 ]        outbuf_data_in,

  output wire                                         stream_fifo_empty,
  input  wire                                         stream_fifo_pop,
  output wire  [ PU_DATA_W            -1 : 0 ]        stream_fifo_data_out,

  output wire  [ NUM_PU               -1 : 0 ]        stream_pu_empty,
  input  wire  [ NUM_PU               -1 : 0 ]        stream_pu_pop,
  output wire  [ STREAM_PU_DATA_W     -1 : 0 ]        stream_pu_data_out,

  output wire                                         buffer_read_last,
  output wire                                         buffer_read_empty,
  input  wire                                         buffer_read_req,
  output wire  [ PU_ID_W              -1 : 0 ]        buffer_pu_id,
  output wire  [ AXI_DATA_W           -1 : 0 ]        buffer_read_data_out,

  // Debug
  output reg   [ 32                   -1 : 0 ]        buffer_read_count,
  output reg   [ 32                   -1 : 0 ]        stream_read_count,
  output wire  [ 11                   -1 : 0 ]        inbuf_count,
  output wire  [ NUM_PU               -1 : 0 ]        pu_write_valid,
  output wire  [ WR_ROM_ADDR_W        -1 : 0 ]        wr_cfg_idx,
  output wire  [ RD_ROM_ADDR_W        -1 : 0 ]        rd_cfg_idx

);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer WSTRB_W = AXI_DATA_W/8;
  localparam integer PU_DATA_W = OP_WIDTH * NUM_PE;
  localparam integer STREAM_PU_DATA_W = OP_WIDTH * NUM_PE * NUM_PU;
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
  wire                                        axi_rd_ready;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_rvalid_size;
  wire [ ADDR_W               -1 : 0 ]        rd_addr;

  //wire [ RD_LOOP_W            -1 : 0 ]        buffer_pu_id;
  wire [ D_TYPE_W             -1 : 0 ]        d_type;

  wire                                        wr_req;
  wire [PU_ID_W-1:0] wr_pu_id;
  wire [PU_ID_W-1:0] pu_id;
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
  reg  [AXI_DATA_W-1:0] axi_rd_buffer_data_out_d;

  localparam STREAM_FIFO_ADDR_W = 8;

  wire stream_fifo_push;
  //wire stream_fifo_pop;
  //wire stream_fifo_empty;
  wire stream_fifo_full;
  wire [STREAM_FIFO_ADDR_W:0] stream_fifo_count;
  wire [STREAM_FIFO_ADDR_W:0] stream_fifo_count_almost_max;
  wire [PU_DATA_W-1:0] stream_fifo_data_in;
  //wire [AXI_DATA_W-1:0] stream_fifo_data_out;

  wire stream_push;
  wire buffer_push;
  wire stream_full;
  wire buffer_full;
  wire [AXI_DATA_W-1:0] stream_data_in;

  localparam BUFFER_READ_ADDR_W = 10;

  wire buffer_read_push;
  wire buffer_read_pop;
  //wire buffer_read_empty;
  wire buffer_read_full;
  wire [AXI_DATA_W-1:0] buffer_read_data_in;
  wire [BUFFER_READ_ADDR_W:0] buf_rd_fifo_count;
  wire [BUFFER_READ_ADDR_W:0] buffer_read_count_almost_max;
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
    .D_TYPE_W                 ( D_TYPE_W                 )
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
  axi_master_wrapper
  #(
    .AXI_DATA_W               ( AXI_DATA_W               ),
    .ADDR_W                   ( ADDR_W                   ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    .NUM_AXI                  ( NUM_AXI                  ),
    .NUM_PU                   ( NUM_PU                   )
  )
  u_axim
  (
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
    .data_from_outbuf         ( outbuf_data_out          ),

    .data_to_inbuf            ( axi_rd_buffer_data_in    ),
    .inbuf_push               ( axi_rd_buffer_push       ),
    .inbuf_full               ( read_full                ),

    .rd_req                   ( rd_req                   ),
    .rd_ready                 ( axi_rd_ready             ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  ),

    .wr_req                   ( wr_req                   ),
    .wr_pu_id                 ( wr_pu_id                 ),
    .wr_done                  ( wr_done                  ),
    .wr_ready                 ( wr_ready                 ),
    .wr_req_size              ( wr_req_size              ),
    .wr_addr                  ( wr_addr                  ),
    .write_valid              ( write_valid              )
  );
// ==================================================================

assign read_full = axi_rd_buffer_full || read_info_full || buffer_counter_full;
// assign read_full = axi_rd_buffer_full || buffer_counter_full;

assign rd_ready = !buffer_counter_full && axi_rd_ready;


// ==================================================================
// Stream PU Buffer
// ==================================================================

  localparam STREAM_PU_FIFO_ADDR_W = 6;
  reg stream_pu_full;
  wire [STREAM_PU_FIFO_ADDR_W-1:0] stream_pu_count;
  wire stream_pu_push;
  wire [PU_ID_W-1:0] stream_pu_id;

assign stream_pu_count = STREAM_PU_GEN[NUM_PU-1].stream_pu_fifo_count;

always @(posedge clk)
  if (reset)
    stream_pu_full <= 1'b0;
  else
    stream_pu_full <= stream_pu_count > (1<<STREAM_PU_FIFO_ADDR_W) - 4;

genvar i;
generate
  for (i=0; i<NUM_PU; i=i+1)
  begin: STREAM_PU_GEN

    `ifdef simulation
      integer push_count = 0;
      integer packer_push_count = 0;
      always @(posedge clk)
      begin
        if (reset) begin
          push_count <= 0;
          packer_push_count <= 0;
        end else begin
          push_count <= push_count + stream_pu_push_local;
          packer_push_count <= packer_push_count + stream_pu_fifo_push;
        end
      end
    `endif

    wire stream_pu_push_local;
    assign stream_pu_push_local = stream_pu_push && stream_pu_id == i;

    wire [AXI_DATA_W-1:0] stream_pu_data_in;

    wire [ PU_DATA_W               -1 : 0 ]     stream_pu_fifo_data_in;
    wire [ PU_DATA_W               -1 : 0 ]     stream_pu_fifo_data_out;
    wire                                        stream_pu_fifo_push;
    wire                                        stream_pu_fifo_pop;
    wire                                        stream_pu_fifo_full;
    wire                                        stream_pu_fifo_empty;
    wire [STREAM_PU_FIFO_ADDR_W:0] stream_pu_fifo_count;

    assign stream_pu_data_in = axi_rd_buffer_data_out_d;

    assign stream_pu_fifo_pop = stream_pu_pop[i];
    assign stream_pu_empty[i] = stream_pu_fifo_empty;
    assign stream_pu_data_out[i*PU_DATA_W+:PU_DATA_W] = stream_pu_fifo_data_out;

    data_packer #(
      .IN_WIDTH                 ( AXI_DATA_W               ),
      .OUT_WIDTH                ( PU_DATA_W                )
    ) packer (
      .clk                      ( clk                      ),  //input
      .reset                    ( reset                    ),  //input
      .s_write_req              ( stream_pu_push_local     ),  //input
      .s_write_data             ( stream_pu_data_in        ),  //input
      .s_write_ready            (                          ),  //output
      .m_write_req              ( stream_pu_fifo_push      ),  //output
      .m_write_data             ( stream_pu_fifo_data_in   ),  //output
      .m_write_ready            ( !stream_pu_full          )   //input
      );

    fifo #(
      .DATA_WIDTH               ( PU_DATA_W                ),
      .ADDR_WIDTH               ( STREAM_PU_FIFO_ADDR_W    )
    ) stream_pu (
      .clk                      ( clk                      ),  //input
      .reset                    ( reset                    ),  //input
      .push                     ( stream_pu_fifo_push      ),  //input
      .pop                      ( stream_pu_fifo_pop       ),  //input
      .data_in                  ( stream_pu_fifo_data_in   ),  //input
      .data_out                 ( stream_pu_fifo_data_out  ),  //output
      .full                     ( stream_pu_fifo_full      ),  //output
      .empty                    ( stream_pu_fifo_empty     ),  //output
      .fifo_count               ( stream_pu_fifo_count     )   //output
    );

  end
endgenerate

// ==================================================================


// ==================================================================
// OutBuf - Output Buffer
// ==================================================================

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


    fifo_fwft #(
      .DATA_WIDTH               ( AXI_DATA_W               ),
      .ADDR_WIDTH               ( 5                        )
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

  reg [31:0] axi_rd_count;
  always @(posedge clk)
    if (reset)
      axi_rd_count <= 0;
    else
      axi_rd_count <= axi_rd_count + axi_rd_buffer_push;

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

  assign stream_data_in = axi_rd_buffer_data_out_d;

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

  assign stream_full = stream_fifo_almost_full;

  assign stream_fifo_count_almost_max = (1<<STREAM_FIFO_ADDR_W) - 16;
  reg stream_fifo_almost_full;
  always @(posedge clk)
  begin: STREAM_FIFO_ALMOST_FULL
    if (reset)
      stream_fifo_almost_full <= 1'b0;
    else
      stream_fifo_almost_full <= stream_fifo_count >= stream_fifo_count_almost_max;
  end

  fifo#(
    .DATA_WIDTH               ( PU_DATA_W                ),
    .ADDR_WIDTH               ( STREAM_FIFO_ADDR_W       )
  ) stream_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( stream_fifo_push         ),  //input
    .full                     ( stream_fifo_full         ),  //output
    .data_in                  ( stream_fifo_data_in      ),  //input
    .pop                      ( stream_fifo_pop          ),  //input
    .empty                    ( stream_fifo_empty        ),  //output
    .data_out                 ( stream_fifo_data_out     ),  //output
    .fifo_count               ( stream_fifo_count        )   //output
  );

  assign buffer_read_data_in = axi_rd_buffer_data_out_d;
  assign buffer_read_push = buffer_push;

  reg buffer_read_almost_full;
  assign buffer_full = buffer_read_almost_full;

  assign buffer_read_count_almost_max = (1<<BUFFER_READ_ADDR_W) - 16;
  always @(posedge clk)
  begin: BUFFER_READ_ALMOST_FULL
    if (reset)
      buffer_read_almost_full <= 1'b0;
    else
      buffer_read_almost_full <= buf_rd_fifo_count >= buffer_read_count_almost_max;
  end

  fifo#(
    .DATA_WIDTH               ( AXI_DATA_W               ),
    .ADDR_WIDTH               ( BUFFER_READ_ADDR_W       )
  ) buffer_read (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( buffer_read_push         ),  //input
    .full                     ( buffer_read_full         ),  //output
    .data_in                  ( buffer_read_data_in      ),  //input
    .pop                      ( buffer_read_pop          ),  //input
    .empty                    ( buffer_read_empty        ),  //output
    .data_out                 ( buffer_read_data_out     ),  //output
    .fifo_count               ( buf_rd_fifo_count        )   //output
  );

  buffer_read_counter #(
    .NUM_PU                   ( NUM_PU                   ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .RD_SIZE_W                ( TX_SIZE_WIDTH            )
  )
  u_buffer_counter
  (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .read_info_full           ( buffer_counter_full      ),
    .buffer_read_req          ( buffer_read_req          ),
    .buffer_read_last         ( buffer_read_last         ),
    .buffer_read_pop          ( buffer_read_pop          ),
    .buffer_read_empty        ( buffer_read_empty        ),
    .pu_id                    ( pu_id_buf                ),
    .rd_req                   ( rd_req                   ),
    .rd_req_size              ( rd_req_size              ),
    .rd_req_pu_id             ( pu_id                    ),
    .rd_req_d_type            ( d_type                   )
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
    else if (buffer_read_pop && !buffer_read_empty)
      buffer_read_count <=  buffer_read_count + 1'b1;

  reg [32-1:0] buffer_write_count;
  reg [32-1:0] buffer_push_count;
  always @(posedge clk)
    if (reset)
      buffer_write_count <= 0;
    else if (buffer_read_push && !buffer_read_full)
      buffer_write_count <= buffer_write_count + 1'b1;
  always @(posedge clk)
    if (reset)
      buffer_push_count <= 0;
    else if (buffer_read_push && !buffer_read_full)
      buffer_push_count <= buffer_push_count + 1'b1;

  reg  [ 32                   -1 : 0 ]         stream_packer_push_count;
  always @(posedge clk)
    if (reset)
      stream_read_count <= 0;
    else if (stream_fifo_pop && !stream_fifo_empty)
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
  .pu_id                    (                          ),
  .stream_pu_push           ( stream_pu_push           ),
  .stream_pu_id             ( stream_pu_id             ),
  .stream_push              ( stream_push              ),
  .buffer_push              ( buffer_push              ),
  .stream_full              ( stream_full              ),
  .stream_pu_full           ( stream_pu_full           ),
  .buffer_full              ( buffer_full              ),
  .d_type                   ( d_type_buf               )
  );

always @(posedge clk)
begin
  if (reset)
    axi_rd_buffer_data_out_d <= 0;
  else
    axi_rd_buffer_data_out_d <= axi_rd_buffer_data_out;
end


// ==================================================================

// ==================================================================
// DEBUG
// ==================================================================
  assign pu_write_valid = write_valid;
// ==================================================================
endmodule
