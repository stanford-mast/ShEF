module shield_read_mstr_tb;
  // ******************************************************************
  // parameters
  // ******************************************************************
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg  [31:0]  tb_req_addr;
  reg          tb_req_val;
  wire         tb_req_rdy;
  wire [31:0]  tb_resp_addr;
  wire [511:0] tb_resp_data;
  wire         tb_resp_val;
  reg          tb_resp_rdy;

  wire [15:0]  m_axi_arid;
  wire [63:0]  m_axi_araddr;
  wire [7:0]   m_axi_arlen;
  wire [2:0]   m_axi_arsize;
  wire [1:0]   m_axi_arburst;
  wire [1:0]   m_axi_arlock;
  wire [3:0]   m_axi_arcache;
  wire [2:0]   m_axi_arprot;
  wire [3:0]   m_axi_arqos;
  wire [3:0]   m_axi_arregion;
  wire         m_axi_arvalid;
  wire         m_axi_arready;
  wire [15:0]  m_axi_rid;
  wire [511:0] m_axi_rdata;
  wire [1:0]   m_axi_rresp;
  wire         m_axi_rlast;
  wire         m_axi_rvalid;
  wire         m_axi_rready;

  // ******************************************************************
  // Clock generation
  // ******************************************************************
  always begin : clk_gen
    #5;
    clk = !clk;
  end

  // ******************************************************************
  // DUT
  // ******************************************************************
  //
  shield_read_mstr dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_addr(tb_req_addr),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .resp_addr(tb_resp_addr),
    .resp_data(tb_resp_data),
    .resp_val(tb_resp_val),
    .resp_rdy(tb_resp_rdy),
    .m_axi_arid    (m_axi_arid    ),
    .m_axi_araddr  (m_axi_araddr  ),
    .m_axi_arlen   (m_axi_arlen   ),
    .m_axi_arsize  (m_axi_arsize  ),
    .m_axi_arburst (m_axi_arburst ),
    .m_axi_arlock  (m_axi_arlock  ),
    .m_axi_arcache (m_axi_arcache ),
    .m_axi_arprot  (m_axi_arprot  ),
    .m_axi_arqos   (m_axi_arqos   ),
    .m_axi_arregion(m_axi_arregion),
    .m_axi_arvalid (m_axi_arvalid ),
    .m_axi_arready (m_axi_arready ),
    .m_axi_rid     (m_axi_rid     ),
    .m_axi_rdata   (m_axi_rdata   ),
    .m_axi_rresp   (m_axi_rresp   ),
    .m_axi_rlast   (m_axi_rlast   ),
    .m_axi_rvalid  (m_axi_rvalid  ),
    .m_axi_rready  (m_axi_rready  )
  );


  axi_driver axi_driver_inst(
    .clk(clk),
    .reset(~rst_n),
    .M_AXI_AWID       (),
    .M_AXI_AWADDR     (),
    .M_AXI_AWLEN      (),
    .M_AXI_AWSIZE     (),
    .M_AXI_AWBURST    (),
    .M_AXI_AWLOCK     (),
    .M_AXI_AWCACHE    (),
    .M_AXI_AWPROT     (),
    .M_AXI_AWQOS      (),
    .M_AXI_AWVALID    (),
    .M_AXI_AWREADY    (),
    .M_AXI_WID        (),
    .M_AXI_WDATA      (),
    .M_AXI_WSTRB      (),
    .M_AXI_WLAST      (),
    .M_AXI_WVALID     (),
    .M_AXI_WREADY     (),
    .M_AXI_BID        (),
    .M_AXI_BRESP      (),
    .M_AXI_BVALID     (),
    .M_AXI_BREADY     (),
    .M_AXI_ARID       (m_axi_arid    ),
    .M_AXI_ARADDR     (m_axi_araddr  ),
    .M_AXI_ARLEN      (m_axi_arlen   ),
    .M_AXI_ARSIZE     (m_axi_arsize  ),
    .M_AXI_ARBURST    (m_axi_arburst ),
    .M_AXI_ARLOCK     (m_axi_arlock  ),
    .M_AXI_ARCACHE    (m_axi_arcache ),
    .M_AXI_ARPROT     (m_axi_arprot  ),
    .M_AXI_ARQOS      (m_axi_arqos   ),
    .M_AXI_ARVALID    (m_axi_arvalid ),
    .M_AXI_ARREADY    (m_axi_arready ),
    .M_AXI_RID        (m_axi_rid     ),
    .M_AXI_RDATA      (m_axi_rdata   ),
    .M_AXI_RRESP      (m_axi_rresp   ),
    .M_AXI_RLAST      (m_axi_rlast   ),
    .M_AXI_RVALID     (m_axi_rvalid  ),
    .M_AXI_RREADY     (m_axi_rready  )
  );


  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;

      tb_req_addr = 0;
      tb_req_val = 0;
      tb_resp_rdy = 0;
    end
  endtask


  task reset_dut;
    begin
      $display("**** Toggling reset **** ");
      rst_n = 1'b0;

      #20;
      rst_n = 1'b1;
      @(posedge clk);
      $display("Reset done at %0t",$time);
    end
  endtask

  task read_value;
    input [31:0] addr;
    reg [511:0] resp_data;
    reg [31:0] resp_addr;
    reg [511:0] resp_expected;
    begin
      @(posedge clk);
      $display("***Reading cache line from address %h***", addr);
      wait(tb_req_rdy);
      tb_req_val = 1'b1;
      tb_req_addr = addr;
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 1'b0;
      
      @(posedge clk);
      tb_resp_rdy = 1;
      wait(tb_resp_val);
      @(negedge clk);
      resp_data = tb_resp_data;
      resp_addr = tb_resp_addr;
      @(posedge clk);
      tb_resp_rdy = 1'b0;

      //Generate expected response
      for(int i = 0; i < 8; i++) begin
        resp_expected[i*64 +: 64] = {{32{1'd0}}, tb_resp_addr[31:6], 6'd0}; //aligned to 64B cache line - 6 bits
      end
      $display("     Read %h from address %h, expected %h", resp_data, resp_addr, resp_expected);

      if(resp_expected != resp_data) begin
        $display("ERROR");
        $finish;
      end
      else begin
        $display("OK");
      end

    end
  endtask

  

  initial begin
    $display("***************************************");
    $display ("Testing AXI Master");
    $display("***************************************");
    init_sim();
    reset_dut();
    
    #40;

    read_value(64'h0);
    read_value(64'h0001_0000);
    read_value(64'hfff1_0000);
    
    //Try to read unaligned address
    read_value(64'h0000_0010);
    read_value(64'hf000_0048);
    read_value(64'hffff_fff8);
    
    
    #20;
    $finish;

  end

endmodule
