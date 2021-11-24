// Top level module for sdp controller.
// This module drives AXI bus signals to read/write 
// files from DRAM

module cl_sdp_driver #(
  parameter integer AXI_ADDR_WIDTH    = 64,
  parameter integer AXI_DATA_WIDTH    = 64,
  parameter integer AXI_ID_WIDTH      = 6,
  parameter integer C_LENGTH_WIDTH    = 32
)(
  // System signals
  input wire   clk,
  input wire   rst_n,
  // Control signals
  input wire   start,
  output wire  done,

  input  wire [31:0]     command,
  input  wire [AXI_ADDR_WIDTH-1:0] storage_addr,
  input  wire [AXI_ADDR_WIDTH-1:0] memory_addr,
  input  wire [C_LENGTH_WIDTH-1:0] file_len,
  

  //AXI interface to DRAM
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
  output wire                              m_axi_rready
);

  ////////////////////////////////////
  //Local params
  ////////////////////////////////////
  localparam STATE_IDLE          = 4'd0,
             STATE_GET_INIT      = 4'd1,
             STATE_GET           = 4'd2,
             STATE_PUT_INIT      = 4'd3,
             STATE_PUT           = 4'd4,
             STATE_DONE          = 4'd5;

  ////////////////////////////////////
  // Variables
  ////////////////////////////////////
  logic [3:0] state_r;
  logic [3:0] next_state;

  logic cs_rd_start;
  logic cs_wr_start;
  logic cs_done;
  logic cs_rd_addr_mux_sel;
  logic cs_addr_reg_en;
  logic cs_wr_addr_mux_sel;
  logic cs_done_reg_rst_n;


  // status signals
  logic rd_done;
  logic wr_done;

  // logic variables
  logic [AXI_DATA_WIDTH-1:0] loopback_data;
  logic loopback_valid;
  logic loopback_ready;

  logic [AXI_ADDR_WIDTH-1:0] rd_axi_addr;
  logic [AXI_ADDR_WIDTH-1:0] rd_axi_addr_q;
  logic [AXI_ADDR_WIDTH-1:0] wr_axi_addr;
  logic [AXI_ADDR_WIDTH-1:0] wr_axi_addr_q;

  logic [C_LENGTH_WIDTH-1:0] file_len_q;

  logic rd_done_q;
  logic wr_done_q;

  logic cmd_get_put; // 0 for get, 1 for put

  // State assignment
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r <= STATE_IDLE;
    end
    else begin
      state_r <= next_state;
    end
  end

  //next state transition
  always_comb begin
    next_state = state_r;
    case (state_r)
      STATE_IDLE: begin // Wait for start signal to come
        if (start) begin
          if ( cmd_get_put == 1'b0 ) begin
            next_state = STATE_GET_INIT;
          end
          else begin
            next_state = STATE_PUT_INIT;
          end
        end
      end
      STATE_GET_INIT: begin // Initialize control signals
        next_state = STATE_GET;
      end
      STATE_GET: begin // Wait for get to complete
        if (rd_done_q && wr_done_q) begin
          next_state = STATE_DONE;
        end
      end
      STATE_PUT_INIT: begin // initialize signals
        next_state = STATE_PUT;
      end
      STATE_PUT: begin // Wait for put to complete
        if (rd_done_q && wr_done_q) begin
          next_state = STATE_DONE;
        end
      end
      STATE_DONE: begin // Set done for one cycle
        next_state = STATE_IDLE;
      end
    endcase
  end

  always_comb begin
    cs_rd_start = 0;
    cs_wr_start = 0;
    cs_done = 0;
    cs_rd_addr_mux_sel = 0;
    cs_addr_reg_en = 0;
    cs_wr_addr_mux_sel = 0;
    cs_done_reg_rst_n = 0;

    case (state_r)
      STATE_IDLE: begin
        cs_addr_reg_en = 1'b1;
        if ( cmd_get_put == 1'b0 ) begin //get
          cs_rd_addr_mux_sel = 1'b1; // read from storage
          cs_wr_addr_mux_sel = 1'b0; // write to memory
        end
        else begin // put
          cs_rd_addr_mux_sel = 1'b0; // read from memory
          cs_wr_addr_mux_sel = 1'b1; // write to storage
        end
      end
      STATE_GET_INIT: begin
        cs_rd_start = 1'b1;
        cs_wr_start = 1'b1;

        cs_rd_addr_mux_sel = 1'b1;
        cs_wr_addr_mux_sel = 1'b0;

      end
      STATE_GET: begin
        cs_rd_addr_mux_sel = 1'b1;
        cs_wr_addr_mux_sel = 1'b0;

        cs_done_reg_rst_n = 1'b1;
      end
      STATE_PUT_INIT: begin
        cs_rd_start = 1'b1;
        cs_wr_start = 1'b1;

        cs_rd_addr_mux_sel = 1'b0;
        cs_wr_addr_mux_sel = 1'b1;
      end
      STATE_PUT: begin
        cs_rd_addr_mux_sel = 1'b0;
        cs_wr_addr_mux_sel = 1'b1;

        cs_done_reg_rst_n = 1'b1;
      end
      STATE_DONE: begin
        cs_done = 1'b1;
      end
    endcase
  end


  // Datapath
  assign cmd_get_put = (command == 32'h00000000) ? 1'b0 : 1'b1;

  sdp_mux2 #(.WIDTH(AXI_ADDR_WIDTH)) rd_addr_mux (
    .in0( memory_addr ),
    .in1( storage_addr ),
    .sel( cs_rd_addr_mux_sel ),
    .out( rd_axi_addr )
  );
  sdp_enreg #(.WIDTH(AXI_ADDR_WIDTH)) rd_addr_reg (
    .clk( clk ),
    .q( rd_axi_addr_q ),
    .d( rd_axi_addr ),
    .en( cs_addr_reg_en )
  );

  sdp_mux2 #(.WIDTH(AXI_ADDR_WIDTH)) wr_addr_mux (
    .in0( memory_addr ),
    .in1( storage_addr ),
    .sel( cs_wr_addr_mux_sel ),
    .out( wr_axi_addr )
  );
  sdp_enreg #(.WIDTH(AXI_ADDR_WIDTH)) wr_addr_reg (
    .clk( clk ),
    .q( wr_axi_addr_q ),
    .d( wr_axi_addr ),
    .en( cs_addr_reg_en )
  );

  sdp_enreg #(.WIDTH(C_LENGTH_WIDTH)) file_len_reg (
    .clk( clk ),
    .q( file_len_q ),
    .d( file_len ),
    .en( cs_addr_reg_en )
  );

  // Registers to hold done signals
  sdp_enrstreg #(.WIDTH(1)) rd_done_reg (
    .clk( clk ),
    .rst_n( cs_done_reg_rst_n ),
    .q( rd_done_q ),
    .d( 1'b1 ),
    .en( rd_done )
  );

  sdp_enrstreg #(.WIDTH(1)) wr_done_reg (
    .clk( clk ),
    .rst_n( cs_done_reg_rst_n ),
    .q( wr_done_q ),
    .d( 1'b1 ),
    .en( wr_done )
  );


  cl_sdp_axi_mstr #(
    .AXI_ID_WIDTH (AXI_ID_WIDTH),
    .AXI_DATA_WIDTH (AXI_DATA_WIDTH),
    .AXI_ADDR_WIDTH (AXI_ADDR_WIDTH),
    .C_LENGTH_WIDTH (C_LENGTH_WIDTH)
  ) inst_cl_sdp_axi_mstr (
    .clk    (clk),
    .rst_n  (rst_n),

    .rd_ctrl_start(cs_rd_start),
    .rd_ctrl_done(rd_done),
    .rd_ctrl_offset( rd_axi_addr_q ),
    .rd_ctrl_length( file_len_q ),

    .wr_ctrl_start(cs_wr_start),
    .wr_ctrl_done(wr_done),
    .wr_ctrl_offset( wr_axi_addr_q ),
    .wr_ctrl_length( file_len_q ),

    .rd_data( loopback_data ),
    .rd_valid( loopback_valid ),
    .rd_ready( loopback_ready ),
    
    .wr_data( loopback_data ),
    .wr_valid( loopback_valid ),
    .wr_ready( loopback_ready ),

    .m_axi_awid       ( m_axi_awid     ),
    .m_axi_awaddr     ( m_axi_awaddr   ),
    .m_axi_awlen      ( m_axi_awlen    ),
    .m_axi_awsize     ( m_axi_awsize   ),
    .m_axi_awburst    ( m_axi_awburst  ),
    .m_axi_awlock     ( m_axi_awlock   ),
    .m_axi_awcache    ( m_axi_awcache  ),
    .m_axi_awprot     ( m_axi_awprot   ),
    .m_axi_awqos      ( m_axi_awqos    ),
    .m_axi_awregion   ( m_axi_awregion ),
    .m_axi_awvalid    ( m_axi_awvalid  ),
    .m_axi_awready    ( m_axi_awready  ),
    .m_axi_wid        ( m_axi_wid      ),
    .m_axi_wdata      ( m_axi_wdata    ),
    .m_axi_wstrb      ( m_axi_wstrb    ),
    .m_axi_wlast      ( m_axi_wlast    ),
    .m_axi_wvalid     ( m_axi_wvalid   ),
    .m_axi_wready     ( m_axi_wready   ),
    .m_axi_bid        ( m_axi_bid      ),
    .m_axi_bresp      ( m_axi_bresp    ),
    .m_axi_bvalid     ( m_axi_bvalid   ),
    .m_axi_bready     ( m_axi_bready   ),
    .m_axi_arid       ( m_axi_arid     ),
    .m_axi_araddr     ( m_axi_araddr   ),
    .m_axi_arlen      ( m_axi_arlen    ),  
    .m_axi_arsize     ( m_axi_arsize   ),
    .m_axi_arburst    ( m_axi_arburst  ),
    .m_axi_arlock     ( m_axi_arlock   ),
    .m_axi_arcache    ( m_axi_arcache  ),
    .m_axi_arprot     ( m_axi_arprot   ),
    .m_axi_arqos      ( m_axi_arqos    ),
    .m_axi_arregion   ( m_axi_arregion ),
    .m_axi_arvalid    ( m_axi_arvalid  ),
    .m_axi_arready    ( m_axi_arready  ),
    .m_axi_rid        ( m_axi_rid      ),
    .m_axi_rdata      ( m_axi_rdata    ),
    .m_axi_rresp      ( m_axi_rresp    ),
    .m_axi_rlast      ( m_axi_rlast    ),
    .m_axi_rvalid     ( m_axi_rvalid   ),
    .m_axi_rready     ( m_axi_rready   )
  );

  assign done = cs_done;


endmodule
