`include "dw_params.vh"
`include "common.vh"
module mem_controller_4AXI_tb;

  localparam integer TID_WIDTH         = 6;
  localparam integer ADDR_W            = 32;
  localparam integer OP_WIDTH          = 16;
  localparam integer DATA_W            = 64;
  localparam integer NUM_PU            = `num_pu;
  localparam integer NUM_PE            = `num_pe;
  localparam integer BASE_ADDR_W       = ADDR_W;
  localparam integer OFFSET_ADDR_W     = ADDR_W;
  localparam integer TX_SIZE_WIDTH     = 20;
  localparam integer RD_LOOP_W         = 32;
  localparam integer D_TYPE_W          = 2;
  localparam integer ROM_ADDR_W        = 3;
  localparam integer NUM_AXI           = 4;

  localparam integer ROM_WIDTH = (BASE_ADDR_W + OFFSET_ADDR_W +
    RD_LOOP_W)*2 + D_TYPE_W;

  localparam integer WSTRB_W = DATA_W/8;
  localparam integer ARUSER_W = 1;
  localparam integer RUSER_W = 1;
  localparam integer BUSER_W = 1;
  localparam integer WUSER_W = 1;
  localparam integer AWUSER_W = 1;


  wire [ RD_LOOP_W            -1 : 0 ]        pu_id;
  wire [ D_TYPE_W             -1 : 0 ]        d_type;

  wire                                        clk;
  wire                                        reset;
  reg                                         start;
  wire                                        done;
  wire                                        rd_req;
  wire                                        rd_ready;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_req_size;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        rd_rvalid_size;
  wire [ ADDR_W               -1 : 0 ]        rd_addr;
  wire                                        wr_req;
  wire                                        wr_done;
  wire [ ADDR_W               -1 : 0 ]        wr_addr;
  wire [ TX_SIZE_WIDTH        -1 : 0 ]        wr_req_size;

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
  wire  [ NUM_AXI*DATA_W   -1 : 0 ]        M_AXI_WDATA;
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
  // AXI3 output wire [4-1:0]          M_AXI_ARREGION,
  wire  [ NUM_AXI*4            -1 : 0 ]        M_AXI_ARQOS;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_ARREADY;

  // Master Interface Read Data
  wire  [ NUM_AXI*TID_WIDTH    -1 : 0 ]        M_AXI_RID;
  wire  [ NUM_AXI*DATA_W   -1 : 0 ]        M_AXI_RDATA;
  wire  [ NUM_AXI*2            -1 : 0 ]        M_AXI_RRESP;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RLAST;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RVALID;
  wire  [ NUM_AXI              -1 : 0 ]        M_AXI_RREADY;

  integer read_count;
  integer write_count;
  integer write_count0;
  integer write_count1;
  integer write_count2;
  integer write_count3;

  always @(posedge clk)
    if (reset || start)
      read_count <= 0;
    else if (M_AXI_RVALID && M_AXI_RREADY)
      read_count <= read_count + 1;

  always @(posedge clk)
    if (reset || start)
      write_count0 <= 0;
    else if (M_AXI_WVALID[0] && M_AXI_WREADY[0])
      write_count0 <= write_count0 + 1;

  always @(posedge clk)
    if (reset || start)
      write_count1 <= 0;
    else if (M_AXI_WVALID[1] && M_AXI_WREADY[1])
      write_count1 <= write_count1 + 1;

  always @(posedge clk)
    if (reset || start)
      write_count2 <= 0;
    else if (M_AXI_WVALID[2] && M_AXI_WREADY[2])
      write_count2 <= write_count2 + 1;

  always @(posedge clk)
    if (reset || start)
      write_count3 <= 0;
    else if (M_AXI_WVALID[3] && M_AXI_WREADY[3])
      write_count3 <= write_count3 + 1;

  always @(posedge clk)
    if (reset || start)
      write_count <= 0;
    else
      write_count <= write_count0 + write_count1 + write_count2 + write_count3;


  initial begin
    $dumpfile("mem_controller_4AXI_tb.vcd");
    $dumpvars(0,mem_controller_4AXI_tb);
  end

  reg [2-1:0] _l_type;
  reg [TX_SIZE_WIDTH-1:0] _stream_rvalid_size;
  reg [BASE_ADDR_W-1:0] _stream_rd_base_addr;
  reg [TX_SIZE_WIDTH-1:0] _stream_rd_size;
  reg [OFFSET_ADDR_W-1:0] _stream_rd_offset;
  reg [RD_LOOP_W-1:0] _stream_rd_loop_max;
  reg [TX_SIZE_WIDTH-1:0] _buffer_rvalid_size;
  reg [BASE_ADDR_W-1:0] _buffer_rd_base_addr;
  reg [TX_SIZE_WIDTH-1:0] _buffer_rd_size;
  reg [OFFSET_ADDR_W-1:0] _buffer_rd_offset;
  reg [RD_LOOP_W-1:0] _buffer_rd_loop_max;

  integer max_layers;
  integer rom_idx;
  integer ddr_idx;
  integer tmp;

  integer ii;

  initial begin
    driver.status.start;
    max_layers = `max_layers;

    rom_idx = 0;
    repeat (max_layers+1) begin
      {_l_type,
       _stream_rvalid_size,
       _stream_rd_base_addr,
       _stream_rd_size,
       _stream_rd_offset,
       _stream_rd_loop_max,
       _buffer_rvalid_size,
       _buffer_rd_base_addr,
       _buffer_rd_size,
       _buffer_rd_offset,
       _buffer_rd_loop_max
      } = accelerator.mem_ctrl_top.u_mem_ctrl.rd_cfg_rom[rom_idx];
      $display ("Layer Type              : %8d", _l_type);
      $display ("Stream Read base addr   : %8h", _stream_rd_base_addr);
      $display ("Stream Read size        : %8d", _stream_rd_size);
      $display ("Stream Read offset addr : %8d", _stream_rd_offset);
      $display ("Stream Read loop        : %8d", _stream_rd_loop_max);
      $display ("Buffer Read base addr   : %8h", _buffer_rd_base_addr);
      $display ("Buffer Read size        : %8d", _buffer_rd_size);
      $display ("Buffer Read offset addr : %8d", _buffer_rd_offset);
      $display ("Buffer Read loop        : %8d", _buffer_rd_loop_max);

      ddr_idx = (_stream_rd_base_addr-32'h08000000) >> 1;
      tmp = 0;

      if ((_l_type == 0 || _l_type == 1) && rom_idx == 0) begin
        $display;
        if (_l_type == 0) $display ("Initializing Input FMs at location %d", ddr_idx << 1);
        if (_l_type == 1) $display ("Initializing Inner Product weights at location %d", ddr_idx<<1);
        repeat (_stream_rd_size * 4) begin
          AXI_GEN[0].u_axim_driver.ddr_ram[ddr_idx] = tmp;
          //$display ("DDR_RAM[%d] = %d", ddr_idx, AXI_GEN[0].u_axim_driver.ddr_ram[ddr_idx]);
          ddr_idx = ddr_idx + 1;
          tmp = tmp + 1;
        end
        $display;
      end


      $display ("TOTAL BUFFER READS = %d", (_buffer_rd_loop_max+1)*(_stream_rd_loop_max+1));

      if (_l_type == 0) begin
        ddr_idx = (_buffer_rd_base_addr-32'h08000000) >> 1;
        repeat ((_buffer_rd_loop_max+1) * (_stream_rd_loop_max+1))
        begin
          for (ii=0; ii<NUM_PE; ii=ii+1)
          begin
            AXI_GEN[0].u_axim_driver.ddr_ram[ddr_idx+ii] = 0;
          end
          ddr_idx = ddr_idx+NUM_PE;
          tmp = 0;
          $display ("Initializing Convolution Weights at location %d", ddr_idx);
          repeat (_buffer_rd_size * 4) begin
            AXI_GEN[0].u_axim_driver.ddr_ram[ddr_idx] = tmp;
            //$display ("DDR_RAM[%d] = %d", ddr_idx, AXI_GEN[0].u_axim_driver.ddr_ram[ddr_idx]);
            ddr_idx = ddr_idx + 1;
            tmp = tmp + 1;
          end
          ddr_idx = ddr_idx + (_buffer_rd_offset>>1);
        end
      end




      rom_idx = rom_idx + 1;

    end

    repeat (2) begin
      wait(accelerator.PU_GEN[0].u_PU.u_controller.state == 0);
      driver.send_start;
      wait(accelerator.PU_GEN[0].u_PU.u_controller.state == 4)
      wait(accelerator.PU_GEN[0].u_PU.u_controller.state == 0);
      wait(accelerator.mem_ctrl_top.u_mem_ctrl.wr_ready);
      repeat(1000) begin
        @(negedge clk);
      end
      $display("Read count = %d\nWrite_count = %d", read_count, write_count);
    end
    driver.status.test_pass;
  end

// ==================================================================
  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );
// ==================================================================

// ==================================================================
// DnnWeaver
// ==================================================================
  dnn_accelerator_dummy_4AXI #(
  // INPUT PARAMETERS
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_PU                   ( NUM_PU                   ),
    .ADDR_W                   ( ADDR_W                   ),
    .AXI_DATA_W               ( DATA_W                   ),
    .BASE_ADDR_W              ( BASE_ADDR_W              ),
    .OFFSET_ADDR_W            ( OFFSET_ADDR_W            ),
    .RD_LOOP_W                ( RD_LOOP_W                ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .ROM_ADDR_W               ( ROM_ADDR_W               )
  ) accelerator ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),

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
    .M_AXI_RREADY             ( M_AXI_RREADY             )
  );
// ==================================================================

assign rd_req = mem_controller_4AXI_tb.accelerator.mem_ctrl_top.rd_req;
assign rd_req_size = mem_controller_4AXI_tb.accelerator.mem_ctrl_top.rd_req_size;

assign wr_done = mem_controller_4AXI_tb.accelerator.mem_ctrl_top.wr_done;
assign wr_req = mem_controller_4AXI_tb.accelerator.mem_ctrl_top.wr_req;
assign wr_req_size = mem_controller_4AXI_tb.accelerator.mem_ctrl_top.wr_req_size;

// ==================================================================
  mem_controller_4AXI_tb_driver #(
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
  ) driver ( // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .start                    ( start                    ),
    .done                     ( done                     ),
    .rd_req                   ( rd_req                   ),
    .rd_ready                 (                          ),
    .rd_req_size              ( rd_req_size              ),
    .rd_addr                  ( rd_addr                  ),
    .wr_req                   ( wr_req                   ),
    .wr_done                  ( wr_done                  ),
    .wr_req_size              ( wr_req_size              ),
    .wr_addr                  ( wr_addr                  )
  );
// ==================================================================

// ==================================================================
genvar g;
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
  wire [ DATA_W           -1 : 0 ]        wdata;
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
  wire [ DATA_W           -1 : 0 ]        rdata;
  wire [ 2                    -1 : 0 ]        rresp;
  wire                                        rlast;
  wire [ RUSER_W              -1 : 0 ]        ruser;
  wire                                        rvalid;
  wire                                        rready;



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
  assign wdata = M_AXI_WDATA[g*DATA_W+:DATA_W];
  assign wstrb = M_AXI_WSTRB[g*WSTRB_W+:WSTRB_W];
  assign wlast = M_AXI_WLAST[g*1+:1];
  assign wvalid = M_AXI_WVALID[g*1+:1];
  assign M_AXI_WREADY[g*1+:1] = wready;

  // Master Interface Write Response
  assign M_AXI_BID[g*1+:1] = bid;
  assign M_AXI_BRESP[g*2+:2] = bresp;
  assign M_AXI_BVALID[g*1+:1] = bvalid;
  assign bready = M_AXI_BREADY[g*1+:1];

  // Master Interface Read Address
  assign arid = M_AXI_ARID[g*TID_WIDTH+:TID_WIDTH];
  assign araddr = M_AXI_ARADDR[g*ADDR_W+:ADDR_W];
  assign arlen = M_AXI_ARLEN[g*4+:4];
  assign arsize = M_AXI_ARSIZE[g*3+:3];
  assign arburst = M_AXI_ARBURST[g*2+:2];
  assign arlock = M_AXI_ARLOCK[g*2+:2];
  assign arcache = M_AXI_ARCACHE[g*4+:4];
  assign arprot = M_AXI_ARPROT[g*3+:3];
  assign arqos = M_AXI_ARQOS[g*4+:4];
  assign arvalid = M_AXI_ARVALID[g*1+:1];
  assign M_AXI_ARREADY[g*1+:1] = arready;

  // Master Interface Read Data
  assign M_AXI_RID[g*TID_WIDTH+:TID_WIDTH] = rid;
  assign M_AXI_RDATA[g*DATA_W+:DATA_W] = rdata;
  assign M_AXI_RRESP[g*2+:2] = rresp;
  assign M_AXI_RLAST[g*1+:1] = rlast;
  assign M_AXI_RVALID[g*1+:1] = rvalid;
  assign rready = M_AXI_RREADY[g*1+:1];



axi_master_tb_driver
#(
    .AXI_DATA_WIDTH           ( DATA_W                   ),
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            )
) u_axim_driver (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .M_AXI_AWID               ( awid               ),
    .M_AXI_AWADDR             ( awaddr             ),
    .M_AXI_AWLEN              ( awlen              ),
    .M_AXI_AWSIZE             ( awsize             ),
    .M_AXI_AWBURST            ( awburst            ),
    .M_AXI_AWLOCK             ( awlock             ),
    .M_AXI_AWCACHE            ( awcache            ),
    .M_AXI_AWPROT             ( awprot             ),
    .M_AXI_AWQOS              ( awqos              ),
    .M_AXI_AWVALID            ( awvalid            ),
    .M_AXI_AWREADY            ( awready            ),
    .M_AXI_WID                ( wid                ),
    .M_AXI_WDATA              ( wdata              ),
    .M_AXI_WSTRB              ( wstrb              ),
    .M_AXI_WLAST              ( wlast              ),
    .M_AXI_WVALID             ( wvalid             ),
    .M_AXI_WREADY             ( wready             ),
    .M_AXI_BID                ( bid                ),
    .M_AXI_BRESP              ( bresp              ),
    .M_AXI_BVALID             ( bvalid             ),
    .M_AXI_BREADY             ( bready             ),
    .M_AXI_ARID               ( arid               ),
    .M_AXI_ARADDR             ( araddr             ),
    .M_AXI_ARLEN              ( arlen              ),
    .M_AXI_ARSIZE             ( arsize             ),
    .M_AXI_ARBURST            ( arburst            ),
    .M_AXI_ARLOCK             ( arlock             ),
    .M_AXI_ARCACHE            ( arcache            ),
    .M_AXI_ARPROT             ( arprot             ),
    .M_AXI_ARQOS              ( arqos              ),
    .M_AXI_ARVALID            ( arvalid            ),
    .M_AXI_ARREADY            ( arready            ),
    .M_AXI_RID                ( rid                ),
    .M_AXI_RDATA              ( rdata              ),
    .M_AXI_RRESP              ( rresp              ),
    .M_AXI_RLAST              ( rlast              ),
    .M_AXI_RVALID             ( rvalid             ),
    .M_AXI_RREADY             ( rready             )
);
end
endgenerate
// ==================================================================

endmodule
