//Mark Zhao
//7/15/20
//
//Wrapper module for shield
//
//NOTE: AXI Requests from CL cannot exceed 32-bit addresses.
//ARSIZE must be full width bursts (clog2(data width in bytes))
//IDs are not used (assumed to be 0)
//WSTRB must be all 1s 
//
`default_nettype none
`timescale 1ns/1ps

module shield_wrapper #(
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer AXI_ID_WIDTH = 16,
  parameter integer AXI_DATA_WIDTH = 512,
  parameter integer CL_ADDR_WIDTH = 64,
  parameter integer CL_ID_WIDTH = 6,
  parameter integer CL_DATA_WIDTH = 64,
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer LINE_WIDTH = 512,
  parameter integer CACHE_DEPTH = 256
)
  (
  //System signals
  input wire clk,
  input wire rst_n,
  //AXI slave interface from user
  input  wire [CL_ID_WIDTH-1:0]            s_axi_awid,
  input  wire [CL_ADDR_WIDTH-1:0]          s_axi_awaddr,
  input  wire [7:0]                        s_axi_awlen,
  input  wire [2:0]                        s_axi_awsize,
  input  wire [1:0]                        s_axi_awburst,
  input  wire [1:0]                        s_axi_awlock,
  input  wire [3:0]                        s_axi_awcache,
  input  wire [2:0]                        s_axi_awprot,
  input  wire [3:0]                        s_axi_awqos,
  input  wire [3:0]                        s_axi_awregion,
  input  wire                              s_axi_awvalid,
  output wire                              s_axi_awready,
  input  wire [CL_ID_WIDTH-1:0]            s_axi_wid,
  input  wire [CL_DATA_WIDTH-1:0]          s_axi_wdata,
  input  wire [CL_DATA_WIDTH/8-1:0]        s_axi_wstrb,
  input  wire                              s_axi_wlast,
  input  wire                              s_axi_wvalid,
  output wire                              s_axi_wready,
  output wire [CL_ID_WIDTH-1:0]            s_axi_bid,
  output wire [1:0]                        s_axi_bresp,
  output wire                              s_axi_bvalid,
  input  wire                              s_axi_bready,
  input  wire [CL_ID_WIDTH-1:0]            s_axi_arid,
  input  wire [CL_ADDR_WIDTH-1:0]          s_axi_araddr,
  input  wire [7:0]                        s_axi_arlen,
  input  wire [2:0]                        s_axi_arsize,
  input  wire [1:0]                        s_axi_arburst,
  input  wire [1:0]                        s_axi_arlock,
  input  wire [3:0]                        s_axi_arcache,
  input  wire [2:0]                        s_axi_arprot,
  input  wire [3:0]                        s_axi_arqos,
  input  wire [3:0]                        s_axi_arregion,
  input  wire                              s_axi_arvalid,
  output wire                              s_axi_arready,
  output wire [CL_ID_WIDTH-1:0]            s_axi_rid,
  output wire [CL_DATA_WIDTH-1:0]          s_axi_rdata,
  output wire [1:0]                        s_axi_rresp,
  output wire                              s_axi_rlast,
  output wire                              s_axi_rvalid,
  input  wire                              s_axi_rready,
  //AXI master interface to dram
  output wire [AXI_ID_WIDTH-1:0]           m_axi_awid,
  output wire [AXI_ADDR_WIDTH-1:0]         m_axi_awaddr,
  output wire [7:0]                        m_axi_awlen,
  output wire [2:0]                        m_axi_awsize,
  output wire [1:0]                        m_axi_awburst,
  output wire [1:0]                        m_axi_awlock,
  output wire [3:0]                        m_axi_awcache,
  output wire [2:0]                        m_axi_awprot,
  output wire [3:0]                        m_axi_awqos,
  output wire [3:0]                        m_axi_awregion,
  output wire                              m_axi_awvalid,
  input  wire                              m_axi_awready,
  output wire [AXI_ID_WIDTH-1:0]           m_axi_wid,
  output wire [AXI_DATA_WIDTH-1:0]         m_axi_wdata,
  output wire [AXI_DATA_WIDTH/8-1:0]       m_axi_wstrb,
  output wire                              m_axi_wlast,
  output wire                              m_axi_wvalid,
  input  wire                              m_axi_wready,
  input  wire [AXI_ID_WIDTH-1:0]           m_axi_bid,
  input  wire [1:0]                        m_axi_bresp,
  input  wire                              m_axi_bvalid,
  output wire                              m_axi_bready,
  output wire [AXI_ID_WIDTH-1:0]           m_axi_arid,
  output wire [AXI_ADDR_WIDTH-1:0]         m_axi_araddr,
  output wire [7:0]                        m_axi_arlen,
  output wire [2:0]                        m_axi_arsize,
  output wire [1:0]                        m_axi_arburst,
  output wire [1:0]                        m_axi_arlock,
  output wire [3:0]                        m_axi_arcache,
  output wire [2:0]                        m_axi_arprot,
  output wire [3:0]                        m_axi_arqos,
  output wire [3:0]                        m_axi_arregion,
  output wire                              m_axi_arvalid,
  input  wire                              m_axi_arready,
  input  wire [AXI_ID_WIDTH-1:0]           m_axi_rid,
  input  wire [AXI_DATA_WIDTH-1:0]         m_axi_rdata,
  input  wire [1:0]                        m_axi_rresp,
  input  wire                              m_axi_rlast,
  input  wire                              m_axi_rvalid,
  output wire                              m_axi_rready,
  //Any register/control interfaces

  output wire [3:0]                        shield_state
);

  //Address slicing offsets
  localparam integer LINE_WIDTH_BYTES = LINE_WIDTH / 8;
  localparam integer OFFSET_WIDTH = $clog2(LINE_WIDTH_BYTES);
  localparam integer INDEX_WIDTH = $clog2(CACHE_DEPTH);
  localparam integer TAG_WIDTH = SHIELD_ADDR_WIDTH - OFFSET_WIDTH - INDEX_WIDTH;


	//////////////////////////////////////////////////////////////////////////////
	// Connect control and datapath
	//////////////////////////////////////////////////////////////////////////////
  //Control Signals
  logic                         req_type;
  logic                         req_en;
  logic                         cl_read_req_rdy;
  logic                         req_rw_mux_sel;
  logic                         req_cycle_mux_sel;
  logic                         array_read_index_mux_sel;
  logic                         tag_array_wr_en;
  logic                         data_array_wr_en;
  logic                         shield_read_slv_input_val;
  logic                         shield_read_mstr_req_val;
  logic                         shield_read_mstr_resp_rdy;
  logic                         cl_write_req_rdy;
  logic                         shield_write_slv_req_val;
  logic                         shield_write_slv_cache_line_rdy;
  logic                         data_array_data_mux_sel;
  logic                         cl_write_resp_val;
  logic                         shield_write_mstr_req_val;
  logic                         stream_axi_read_mux_sel;
  logic                         stream_axi_write_mux_sel;
  logic                         stream_read_req_val;
  logic                         stream_write_req_val;

  //Status Signals
  logic                         cl_read_req_val;
  logic                         tag_match;
  logic [SHIELD_ADDR_WIDTH-1:0] req_addr_r;
  logic                         req_type_r;
  logic                         shield_read_slv_input_rdy;
  logic                         req_last;
  logic                         shield_read_mstr_req_rdy;
  logic                         shield_read_mstr_resp_val;
  logic [INDEX_WIDTH-1:0]       array_refill_index;
  logic                         cl_write_req_val;
  logic                         shield_write_slv_req_rdy;
  logic                         shield_write_slv_cache_line_val;
  logic                         cl_write_resp_rdy;
  logic                         shield_write_mstr_req_rdy;
  logic                         stream_read_req_rdy;
  logic                         stream_write_req_rdy;
  logic                         read_addr_stream_bound;
  logic                         write_addr_stream_bound;
  logic                         stream_read_busy;
  logic                         stream_write_busy;
  logic                         shield_read_busy;
  logic                         shield_write_busy;


  shield_controller #(
    .CL_DATA_WIDTH(CL_DATA_WIDTH),
    .CL_ID_WIDTH(CL_ID_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH), 
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .CACHE_DEPTH(CACHE_DEPTH),
    .OFFSET_WIDTH(OFFSET_WIDTH),
    .INDEX_WIDTH(INDEX_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
  ) shield_controller_inst(
    .clk                             (clk                            ),
    .rst_n                           (rst_n                          ),
    .req_type                        (req_type                       ),
    .req_en                          (req_en                         ),
    .cl_read_req_rdy                 (cl_read_req_rdy                ),
    .req_rw_mux_sel                  (req_rw_mux_sel                 ),
    .req_cycle_mux_sel               (req_cycle_mux_sel              ),
    .array_read_index_mux_sel        (array_read_index_mux_sel       ),
    .tag_array_wr_en                 (tag_array_wr_en                ), 
    .data_array_wr_en                (data_array_wr_en               ),
    .shield_read_slv_input_val       (shield_read_slv_input_val      ),
    .shield_read_mstr_req_val        (shield_read_mstr_req_val       ),
    .shield_read_mstr_resp_rdy       (shield_read_mstr_resp_rdy      ),
    .cl_write_req_rdy                (cl_write_req_rdy               ),
    .shield_write_slv_req_val        (shield_write_slv_req_val       ),
    .shield_write_slv_cache_line_rdy (shield_write_slv_cache_line_rdy),
    .data_array_data_mux_sel         (data_array_data_mux_sel        ),
    .cl_write_resp_val               (cl_write_resp_val              ),
    .shield_write_mstr_req_val       (shield_write_mstr_req_val      ),
    .stream_axi_read_mux_sel         (stream_axi_read_mux_sel        ),
    .stream_axi_write_mux_sel        (stream_axi_write_mux_sel       ),
    .stream_read_req_val             (stream_read_req_val            ),
    .stream_write_req_val            (stream_write_req_val           ),
    .cl_read_req_val                 (cl_read_req_val                ),
    .tag_match                       (tag_match                      ),
    .req_addr_r                      (req_addr_r                     ),
    .req_type_r                      (req_type_r                     ),
    .shield_read_slv_input_rdy       (shield_read_slv_input_rdy      ),
    .req_last                        (req_last                       ),
    .shield_read_mstr_req_rdy        (shield_read_mstr_req_rdy       ),
    .shield_read_mstr_resp_val       (shield_read_mstr_resp_val      ),
    .array_refill_index              (array_refill_index             ),
    .cl_write_req_val                (cl_write_req_val               ),
    .shield_write_slv_req_rdy        (shield_write_slv_req_rdy       ),
    .shield_write_slv_cache_line_val (shield_write_slv_cache_line_val),
    .cl_write_resp_rdy               (cl_write_resp_rdy              ),
    .shield_write_mstr_req_rdy       (shield_write_mstr_req_rdy      ),
    .stream_read_req_rdy             (stream_read_req_rdy            ),
    .stream_write_req_rdy            (stream_write_req_rdy           ),
    .read_addr_stream_bound          (read_addr_stream_bound         ),
    .write_addr_stream_bound         (write_addr_stream_bound        ),
    .stream_read_busy                (stream_read_busy               ),
    .stream_write_busy               (stream_write_busy              ),
    .shield_read_busy                (shield_read_busy               ),
    .shield_write_busy               (shield_write_busy              ),
    .shield_state                    (shield_state)
  );

  shield_datapath #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH(CL_ADDR_WIDTH),
    .CL_ID_WIDTH(CL_ID_WIDTH),
    .CL_DATA_WIDTH(CL_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .CACHE_DEPTH(CACHE_DEPTH),
    .OFFSET_WIDTH(OFFSET_WIDTH),
    .INDEX_WIDTH(INDEX_WIDTH),
    .TAG_WIDTH(TAG_WIDTH)
  ) shield_datapath_inst(
    .clk                             (clk                            ),
    .rst_n                           (rst_n                          ),
    .cl_axi_arid                     (s_axi_arid                     ),
    .cl_axi_araddr                   (s_axi_araddr                   ),
    .cl_axi_arlen                    (s_axi_arlen                    ),
    .cl_axi_arvalid                  (s_axi_arvalid                  ),
    .cl_axi_arready                  (s_axi_arready                  ),
    .cl_axi_rid                      (s_axi_rid                      ),
    .cl_axi_rdata                    (s_axi_rdata                    ),
    .cl_axi_rresp                    (s_axi_rresp                    ),
    .cl_axi_rlast                    (s_axi_rlast                    ),
    .cl_axi_rvalid                   (s_axi_rvalid                   ),
    .cl_axi_rready                   (s_axi_rready                   ),
    .cl_axi_awid                     (s_axi_awid                     ),
    .cl_axi_awaddr                   (s_axi_awaddr                   ),
    .cl_axi_awlen                    (s_axi_awlen                    ),
    .cl_axi_awvalid                  (s_axi_awvalid                  ),
    .cl_axi_awready                  (s_axi_awready                  ),
    .cl_axi_wid                      (s_axi_wid                      ),
    .cl_axi_wdata                    (s_axi_wdata                    ),
    .cl_axi_wstrb                    (s_axi_wstrb                    ),
    .cl_axi_wlast                    (s_axi_wlast                    ),
    .cl_axi_wvalid                   (s_axi_wvalid                   ),
    .cl_axi_wready                   (s_axi_wready                   ),
    .cl_axi_bid                      (s_axi_bid                      ),
    .cl_axi_bresp                    (s_axi_bresp                    ),
    .cl_axi_bvalid                   (s_axi_bvalid                   ),
    .cl_axi_bready                   (s_axi_bready                   ),
    .req_type                        (req_type                       ),
    .req_en                          (req_en                         ),
    .cl_read_req_rdy                 (cl_read_req_rdy                ),
    .req_rw_mux_sel                  (req_rw_mux_sel                 ),
    .req_cycle_mux_sel               (req_cycle_mux_sel              ),
    .array_read_index_mux_sel        (array_read_index_mux_sel       ),
    .tag_array_wr_en                 (tag_array_wr_en                ),
    .data_array_wr_en                (data_array_wr_en               ),
    .shield_read_slv_input_val       (shield_read_slv_input_val      ),
    .shield_read_mstr_req_val        (shield_read_mstr_req_val       ),
    .shield_read_mstr_resp_rdy       (shield_read_mstr_resp_rdy      ),
    .cl_write_req_rdy                (cl_write_req_rdy               ),
    .shield_write_slv_req_val        (shield_write_slv_req_val       ),
    .shield_write_slv_cache_line_rdy (shield_write_slv_cache_line_rdy),
    .data_array_data_mux_sel         (data_array_data_mux_sel        ),
    .cl_write_resp_val               (cl_write_resp_val              ),
    .shield_write_mstr_req_val       (shield_write_mstr_req_val      ),
    .stream_axi_read_mux_sel         (stream_axi_read_mux_sel        ),
    .stream_axi_write_mux_sel        (stream_axi_write_mux_sel       ),
    .stream_read_req_val             (stream_read_req_val            ),
    .stream_write_req_val            (stream_write_req_val           ),
    .cl_read_req_val                 (cl_read_req_val                ),
    .tag_match                       (tag_match                      ),
    .req_addr_r                      (req_addr_r                     ),
    .req_type_r                      (req_type_r                     ),
    .shield_read_slv_input_rdy       (shield_read_slv_input_rdy      ),
    .req_last                        (req_last                       ),
    .shield_read_mstr_req_rdy        (shield_read_mstr_req_rdy       ),
    .shield_read_mstr_resp_val       (shield_read_mstr_resp_val      ),
    .array_refill_index              (array_refill_index             ),
    .cl_write_req_val                (cl_write_req_val               ),
    .shield_write_slv_req_rdy        (shield_write_slv_req_rdy       ),
    .shield_write_slv_cache_line_val (shield_write_slv_cache_line_val),
    .cl_write_resp_rdy               (cl_write_resp_rdy              ),
    .shield_write_mstr_req_rdy       (shield_write_mstr_req_rdy      ),
    .stream_read_req_rdy             (stream_read_req_rdy            ),
    .stream_write_req_rdy            (stream_write_req_rdy           ),
    .read_addr_stream_bound          (read_addr_stream_bound         ),
    .write_addr_stream_bound         (write_addr_stream_bound        ),
    .stream_read_busy                (stream_read_busy               ),
    .stream_write_busy               (stream_write_busy              ),
    .shield_read_busy                (shield_read_busy               ),
    .shield_write_busy               (shield_write_busy              ),
    .m_axi_arid                      (m_axi_arid                     ),
    .m_axi_araddr                    (m_axi_araddr                   ),
    .m_axi_arlen                     (m_axi_arlen                    ),
    .m_axi_arsize                    (m_axi_arsize                   ),
    .m_axi_arburst                   (m_axi_arburst                  ),
    .m_axi_arlock                    (m_axi_arlock                   ),
    .m_axi_arcache                   (m_axi_arcache                  ),
    .m_axi_arprot                    (m_axi_arprot                   ),
    .m_axi_arqos                     (m_axi_arqos                    ),
    .m_axi_arregion                  (m_axi_arregion                 ),
    .m_axi_arvalid                   (m_axi_arvalid                  ),
    .m_axi_arready                   (m_axi_arready                  ),
    .m_axi_rid                       (m_axi_rid                      ),
    .m_axi_rdata                     (m_axi_rdata                    ),
    .m_axi_rresp                     (m_axi_rresp                    ),
    .m_axi_rlast                     (m_axi_rlast                    ),
    .m_axi_rvalid                    (m_axi_rvalid                   ),
    .m_axi_rready                    (m_axi_rready                   ),
    .m_axi_awid                      (m_axi_awid                     ),
    .m_axi_awaddr                    (m_axi_awaddr                   ),
    .m_axi_awlen                     (m_axi_awlen                    ),
    .m_axi_awsize                    (m_axi_awsize                   ),
    .m_axi_awburst                   (m_axi_awburst                  ),
    .m_axi_awlock                    (m_axi_awlock                   ),
    .m_axi_awcache                   (m_axi_awcache                  ),
    .m_axi_awprot                    (m_axi_awprot                   ),
    .m_axi_awqos                     (m_axi_awqos                    ),
    .m_axi_awregion                  (m_axi_awregion                 ),
    .m_axi_awvalid                   (m_axi_awvalid                  ),
    .m_axi_awready                   (m_axi_awready                  ),
    .m_axi_wid                       (m_axi_wid                      ),
    .m_axi_wdata                     (m_axi_wdata                    ),
    .m_axi_wstrb                     (m_axi_wstrb                    ),
    .m_axi_wlast                     (m_axi_wlast                    ),
    .m_axi_wvalid                    (m_axi_wvalid                   ),
    .m_axi_wready                    (m_axi_wready                   ),
    .m_axi_bid                       (m_axi_bid                      ),
    .m_axi_bresp                     (m_axi_bresp                    ),
    .m_axi_bvalid                    (m_axi_bvalid                   ),
    .m_axi_bready                    (m_axi_bready                   )
  );

endmodule : shield_wrapper
`default_nettype wire
