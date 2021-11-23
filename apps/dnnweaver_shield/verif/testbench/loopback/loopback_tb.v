`include "dw_params.vh"
`include "common.vh"
module loopback_tb;

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

  localparam integer ROM_WIDTH = (BASE_ADDR_W + OFFSET_ADDR_W +
    RD_LOOP_W)*2 + D_TYPE_W;

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

    // Master Interface Write Address
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_AWID;
  wire [ ADDR_W               -1 : 0 ]        M_AXI_AWADDR;
  wire [ 4                    -1 : 0 ]        M_AXI_AWLEN;
  wire [ 3                    -1 : 0 ]        M_AXI_AWSIZE;
  wire [ 2                    -1 : 0 ]        M_AXI_AWBURST;
  wire [ 2                    -1 : 0 ]        M_AXI_AWLOCK;
  wire [ 4                    -1 : 0 ]        M_AXI_AWCACHE;
  wire [ 3                    -1 : 0 ]        M_AXI_AWPROT;
  wire [ 4                    -1 : 0 ]        M_AXI_AWQOS;
  wire                                        M_AXI_AWVALID;
  wire                                        M_AXI_AWREADY;

    // Master Interface Write Data
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_WID;
  wire [ DATA_W               -1 : 0 ]        M_AXI_WDATA;
  wire [ DATA_W/8             -1 : 0 ]        M_AXI_WSTRB;
  wire                                        M_AXI_WLAST;
  wire                                        M_AXI_WVALID;
  wire                                        M_AXI_WREADY;

    // Master Interface Write Response
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_BID;
  wire [ 2                    -1 : 0 ]        M_AXI_BRESP;
  wire                                        M_AXI_BVALID;
  wire                                        M_AXI_BREADY;

    // Master Interface Read Address
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_ARID;
  wire [ ADDR_W               -1 : 0 ]        M_AXI_ARADDR;
  wire [ 4                    -1 : 0 ]        M_AXI_ARLEN;
  wire [ 3                    -1 : 0 ]        M_AXI_ARSIZE;
  wire [ 2                    -1 : 0 ]        M_AXI_ARBURST;
  wire [ 2                    -1 : 0 ]        M_AXI_ARLOCK;
  wire [ 4                    -1 : 0 ]        M_AXI_ARCACHE;
  wire [ 3                    -1 : 0 ]        M_AXI_ARPROT;
  wire [ 4                    -1 : 0 ]        M_AXI_ARQOS;
  wire                                        M_AXI_ARVALID;
  wire                                        M_AXI_ARREADY;

    // Master Interface Read Data
  wire [ TID_WIDTH            -1 : 0 ]        M_AXI_RID;
  wire [ DATA_W               -1 : 0 ]        M_AXI_RDATA;
  wire [ 2                    -1 : 0 ]        M_AXI_RRESP;
  wire                                        M_AXI_RLAST;
  wire                                        M_AXI_RVALID;
  wire                                        M_AXI_RREADY;

  integer read_count;
  integer write_count;

  always @(posedge clk)
    if (reset || start)
      read_count <= 0;
    else if (M_AXI_RVALID && M_AXI_RREADY)
      read_count <= read_count + 1;

  always @(posedge clk)
    if (reset || start)
      write_count <= 0;
    else if (M_AXI_WVALID && M_AXI_WREADY)
      write_count <= write_count + 1;


  initial begin
    $dumpfile("loopback_tb.vcd");
    $dumpvars(0,loopback_tb);
  end

  reg  [ 2                    -1 : 0 ]        _l_type;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        _stream_rvalid_size;
  reg  [ BASE_ADDR_W          -1 : 0 ]        _stream_rd_base_addr;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        _stream_rd_size;
  reg  [ OFFSET_ADDR_W        -1 : 0 ]        _stream_rd_offset;
  reg  [ RD_LOOP_W            -1 : 0 ]        _stream_rd_loop_max;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        _buffer_rvalid_size;
  reg  [ BASE_ADDR_W          -1 : 0 ]        _buffer_rd_base_addr;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        _buffer_rd_size;
  reg  [ OFFSET_ADDR_W        -1 : 0 ]        _buffer_rd_offset;
  reg  [ RD_LOOP_W            -1 : 0 ]        _buffer_rd_loop_max;

  reg  [ BASE_ADDR_W          -1 : 0 ]        _stream_wr_base_addr;
  reg  [ TX_SIZE_WIDTH        -1 : 0 ]        _stream_wr_size;
  reg  [ OFFSET_ADDR_W        -1 : 0 ]        _stream_wr_offset;
  reg  [ RD_LOOP_W            -1 : 0 ]        _stream_wr_loop_max;

  integer max_layers;
  integer rom_idx;
  integer ddr_idx;
  integer tmp;

  integer ii;

  initial begin
    repeat (1000) @(negedge clk);
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
        $display ("Initializing Input FMs at location %d", ddr_idx << 1);
        repeat (_stream_rd_size * 4) begin
          u_axim_driver.ddr_ram[ddr_idx] = tmp;
          $display ("DDR_RAM[%d] = %d", ddr_idx, u_axim_driver.ddr_ram[ddr_idx]);
          ddr_idx = ddr_idx + 1;
          tmp = tmp + 1;
        end
        $display;
      end

      {_l_type,
       _stream_wr_base_addr,
       _stream_wr_size,
       _stream_wr_offset,
       _stream_wr_loop_max
      } = accelerator.mem_ctrl_top.u_mem_ctrl.wr_cfg_rom[rom_idx];

      ddr_idx = (_stream_wr_base_addr-32'h08000000) >> 1;
      tmp = 0;

      if ((_l_type == 0 || _l_type == 1) && rom_idx == 0) begin
        $display;
        $display ("Initializing Output FMs at location %d", ddr_idx << 1);
        repeat (_stream_wr_size * 4) begin
          u_axim_driver.ddr_ram[ddr_idx] = tmp;
          $display ("DDR_RAM[%d] = %d", ddr_idx, u_axim_driver.ddr_ram[ddr_idx]);
          ddr_idx = ddr_idx + 1;
          tmp = tmp + 1;
        end
        $display;
      end


      $display ("TOTAL BUFFER READS = %d", (_buffer_rd_loop_max+1)*(_stream_rd_loop_max+1));

      // if (_l_type == 0) begin
      //   ddr_idx = (_buffer_rd_base_addr-32'h08000000) >> 1;
      //   repeat ((_buffer_rd_loop_max+1) * (_stream_rd_loop_max+1))
      //   begin
      //     for (ii=0; ii<NUM_PE; ii=ii+1)
      //     begin
      //       u_axim_driver.ddr_ram[ddr_idx+ii] = 0;
      //     end
      //     ddr_idx = ddr_idx+NUM_PE;
      //     tmp = 0;
      //     $display ("Initializing Convolution Weights at location %d", ddr_idx);
      //     repeat ((_buffer_rd_size-1) * 4) begin
      //       u_axim_driver.ddr_ram[ddr_idx] = tmp;
      //       $display ("DDR_RAM[%d] = %d", ddr_idx, u_axim_driver.ddr_ram[ddr_idx]);
      //       ddr_idx = ddr_idx + 1;
      //       tmp = tmp + 1;
      //     end
      //     ddr_idx = ddr_idx + (_buffer_rd_offset>>1);
      //   end
      // end




      rom_idx = rom_idx + 1;

    end

    repeat (2) begin
      driver.send_start;
      wait(accelerator.mem_ctrl_top.u_mem_ctrl.done);
      repeat(100) begin
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
// Loopback
// ==================================================================
  loopback_top #(
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

assign rd_req = loopback_tb.accelerator.mem_ctrl_top.rd_req;
assign rd_req_size = loopback_tb.accelerator.mem_ctrl_top.rd_req_size;

assign wr_done = loopback_tb.accelerator.mem_ctrl_top.wr_done;
assign wr_req = loopback_tb.accelerator.mem_ctrl_top.wr_req;
assign wr_req_size = loopback_tb.accelerator.mem_ctrl_top.wr_req_size;

// ==================================================================
  loopback_tb_driver #(
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
axi_master_tb_driver
#(
    .AXI_DATA_WIDTH           ( DATA_W                   ),
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   ),
    .TX_SIZE_WIDTH            ( TX_SIZE_WIDTH            )
) u_axim_driver (
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
    .M_AXI_RREADY             ( M_AXI_RREADY             )
);
// ==================================================================

endmodule
