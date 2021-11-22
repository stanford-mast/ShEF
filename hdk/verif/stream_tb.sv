module stream_tb;
  parameter integer AXI_ADDR_WIDTH = 64;
  parameter integer AXI_ID_WIDTH = 16;
  parameter integer AXI_DATA_WIDTH = 512;
  parameter integer CL_ADDR_WIDTH = 64;
  parameter integer CL_ID_WIDTH = 6;
  parameter integer CL_DATA_WIDTH = 64;
  parameter integer SHIELD_ADDR_WIDTH = 32;
  parameter integer LINE_WIDTH = 512;
  parameter integer CACHE_DEPTH = 256;
  parameter integer OFFSET_WIDTH = 6;
  parameter integer INDEX_WIDTH = 8;
  parameter integer TAG_WIDTH = 18;

  parameter integer CL_DATA_WIDTH_BYTES = CL_DATA_WIDTH/8;
  parameter ARSIZE_INIT = $clog2(CL_DATA_WIDTH/8);
  parameter AWSIZE_INIT = $clog2(CL_DATA_WIDTH/8);
  parameter WSTRB_INIT = {CL_DATA_WIDTH_BYTES{1'b1}};

  reg clk;
  reg rst_n;
  reg  [31:0]  tb_req_addr;
  reg  [8:0]   tb_req_burst_count;
  reg          tb_rd_req_val;
  reg          tb_wr_req_val;
  reg          tb_req_flush;
  wire         tb_rd_req_rdy;
  wire         tb_wr_req_rdy;

  wire [63:0] s_axi_rdata;
  wire s_axi_rvalid;
  reg  s_axi_rready;

  reg [63:0] s_axi_wdata;
  reg s_axi_wvalid;
  wire s_axi_wready;

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

  wire [AXI_ID_WIDTH-1:0]           m_axi_awid;
  wire [AXI_ADDR_WIDTH-1:0]         m_axi_awaddr;
  wire [7:0]                        m_axi_awlen;
  wire [2:0]                        m_axi_awsize;
  wire [1:0]                        m_axi_awburst;
  wire [1:0]                        m_axi_awlock;
  wire [3:0]                        m_axi_awcache;
  wire [2:0]                        m_axi_awprot;
  wire [3:0]                        m_axi_awqos;
  wire                              m_axi_awvalid;
  wire                              m_axi_awready;
  wire [AXI_ID_WIDTH-1:0]           m_axi_wid;
  wire [AXI_DATA_WIDTH-1:0]         m_axi_wdata;
  wire [AXI_DATA_WIDTH/8-1:0]       m_axi_wstrb;
  wire                              m_axi_wlast;
  wire                              m_axi_wvalid;
  wire                              m_axi_wready;
  wire [AXI_ID_WIDTH-1:0]           m_axi_bid;
  wire [1:0]                        m_axi_bresp;
  wire                              m_axi_bvalid;
  wire                              m_axi_bready;

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
  stream_read dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_addr(tb_req_addr),
    .req_burst_count(tb_req_burst_count),
    .req_flush       (tb_req_flush),
    .req_val(tb_rd_req_val),
    .req_rdy(tb_rd_req_rdy),
    .s_axi_rid(), //SET TO 0
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(), //ALWAYS SUCCESS
    .s_axi_rlast(), //IGNORE FOR NOW
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready),
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
  stream_write dut_write(
    .clk(clk),
    .rst_n(rst_n),
    .req_burst_count (tb_req_burst_count),
    .req_addr        (tb_req_addr),
    .req_flush       (tb_req_flush),
    .req_val         (tb_wr_req_val),
    .req_rdy         (tb_wr_req_rdy),

    .s_axi_wid       (),
    .s_axi_wdata     (s_axi_wdata),
    .s_axi_wstrb     (), //IGNORED FOR NOW
    .s_axi_wlast     (),
    .s_axi_wvalid    (s_axi_wvalid),
    .s_axi_wready    (s_axi_wready),

    .m_axi_awid           (m_axi_awid    ),
    .m_axi_awaddr         (m_axi_awaddr  ),
    .m_axi_awlen          (m_axi_awlen   ),
    .m_axi_awsize         (m_axi_awsize  ),
    .m_axi_awburst        (m_axi_awburst ),
    .m_axi_awlock         (m_axi_awlock  ),
    .m_axi_awcache        (m_axi_awcache ),
    .m_axi_awprot         (m_axi_awprot  ),
    .m_axi_awqos          (m_axi_awqos   ),
    .m_axi_awregion       (),
    .m_axi_awvalid        (m_axi_awvalid ),
    .m_axi_awready        (m_axi_awready ),
    .m_axi_wid            (m_axi_wid     ),
    .m_axi_wdata          (m_axi_wdata   ),
    .m_axi_wstrb          (m_axi_wstrb   ),
    .m_axi_wlast          (m_axi_wlast   ),
    .m_axi_wvalid         (m_axi_wvalid  ),
    .m_axi_wready         (m_axi_wready  ),
    .m_axi_bid            (m_axi_bid     ),
    .m_axi_bresp          (m_axi_bresp   ),
    .m_axi_bvalid         (m_axi_bvalid  ),
    .m_axi_bready         (m_axi_bready  )
  );


  axi_driver axi_driver_inst(
    .clk(clk),
    .reset(~rst_n),
    .M_AXI_AWID       (m_axi_awid    ),
    .M_AXI_AWADDR     (m_axi_awaddr  ),
    .M_AXI_AWLEN      (m_axi_awlen   ),
    .M_AXI_AWSIZE     (m_axi_awsize  ),
    .M_AXI_AWBURST    (m_axi_awburst ),
    .M_AXI_AWLOCK     (m_axi_awlock  ),
    .M_AXI_AWCACHE    (m_axi_awcache ),
    .M_AXI_AWPROT     (m_axi_awprot  ),
    .M_AXI_AWQOS      (m_axi_awqos   ),
    .M_AXI_AWVALID    (m_axi_awvalid ),
    .M_AXI_AWREADY    (m_axi_awready ),
    .M_AXI_WID        (m_axi_wid     ),
    .M_AXI_WDATA      (m_axi_wdata   ),
    .M_AXI_WSTRB      (m_axi_wstrb   ),
    .M_AXI_WLAST      (m_axi_wlast   ),
    .M_AXI_WVALID     (m_axi_wvalid  ),
    .M_AXI_WREADY     (m_axi_wready  ),
    .M_AXI_BID        (m_axi_bid     ),
    .M_AXI_BRESP      (m_axi_bresp   ),
    .M_AXI_BVALID     (m_axi_bvalid  ),
    .M_AXI_BREADY     (m_axi_bready  ),
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
      tb_req_burst_count = 0;
      tb_rd_req_val = 0;
      tb_wr_req_val = 0;
      tb_req_flush = 0;
      s_axi_rready = 0;
      s_axi_wvalid = 0;
      s_axi_wdata = 0;
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

  task read_burst;
    input [31:0] addr;
    input [8:0] burst_count;
    input [63:0] expected;
    input flush;
    reg [63:0] data;
    begin
      $display("Reading %d bursts from address %x", burst_count, addr);

      @(posedge clk);
      //Make the request
      tb_rd_req_val = 1'b1;
      tb_req_addr = addr;
      tb_req_burst_count = burst_count;
      tb_req_flush = flush;
      wait(tb_rd_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_rd_req_val = 1'b0;

      @(posedge clk);

      for(int i = 0; i < burst_count; i++) begin
        s_axi_rready = 1'b1;
        #1;
        wait(s_axi_rvalid);
        @(negedge clk);
        data = s_axi_rdata;
        @(posedge clk);
        s_axi_rready = 1'b0;
        $display("      Read data: %x, expected %x", data, expected);
        if(data != expected) begin
          $display("     ERROR");
          $finish;
        end
      end
      $display("    OK");
    end
  endtask

  task write_burst;
    input [31:0] addr;
    input [8:0] burst_count;
    input [63:0] data;
    begin
      $display("Writing %d bursts to address %x", burst_count, addr);
      @(posedge clk);
      tb_wr_req_val = 1'b1;
      tb_req_addr = addr;
      tb_req_burst_count = burst_count;
      tb_req_flush = 1'b0;
      wait(tb_wr_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_wr_req_val = 1'b0;


      for(int i = 0; i < burst_count; i++) begin
        @(posedge clk);
        s_axi_wdata = data;
        s_axi_wvalid = 1'b1;
        wait(s_axi_wready);
        @(negedge clk);
        @(negedge clk);
        s_axi_wvalid = 0;
      end

    end
  endtask

  task write_flush;
    begin
      $display("Flushing write buffer");
      wait(dut_write.axi_state_r == 4'd0);
      @(posedge clk);
      tb_req_flush = 1'b1;
      tb_wr_req_val = 1'b1;
      tb_req_burst_count = 0;
      wait(tb_wr_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_wr_req_val = 1'b0;
      
      wait(dut_write.axi_state_r == 4'd8);
      wait(dut_write.axi_state_r == 4'd0);
      
    end
  endtask
  
  task wait_for_flush;
    begin
    $display("Waiting for write to flush");
    @(posedge clk);
        if(dut_write.axi_state_r != 4'd0) begin
            wait(dut_write.axi_state_r == 4'd8);
            wait(dut_write.axi_state_r == 4'd0);
        end
    end
  endtask



  initial begin
    $display("***************************************");
    $display ("Testing read stream");
    $display("***************************************");
    init_sim();
    reset_dut();
    
    #20;

    write_burst(32'h0, 9'h1, 64'h0); //write one burst
    write_flush(); //flush it
    read_burst(32'h0, 9'h1, 64'h0, 1'b0); //read it
    
    //non-zero data
    write_burst(32'h0, 9'h1, 64'h00000000deadbeef); //write one burst
    write_flush(); //flush it
    read_burst(32'h0, 9'h1, 64'h00000000deadbeef, 1'b1); //read it - should evict first burst, and match tag to all zeros
    
    //Write burst that goes longer than 1
    write_burst(32'h0, 9'h9, 64'h1111000011110000);
    write_flush();
    read_burst(32'h0, 9'h1, 64'h00000000deadbeef, 1'b0); //cached 
    read_burst(32'h0, 9'h9, 64'h1111000011110000, 1'b1); //read from dram - should evict deadbeef, match tag to deadbeef
    
    //write burst that is unaligned
    write_burst(32'h0000_0008, 9'h22, 64'hbeefbeefbeefbeef);
    write_burst(32'h0000_0fc0, 9'h1, 64'hdeaddeaddeaddead);
    write_flush();
    read_burst(32'h0000_0008, 9'h22, 64'hbeefbeefbeefbeef, 1'b1);
    read_burst(32'h0000_0fc0, 9'h1, 64'hdeaddeaddeaddead, 1'b0);
    
    //natural flush
    write_burst(32'h00000000, 9'd64, 64'hffffffffffffffff);
    write_burst(32'h0f000000, 9'h1, 64'hdeadbeefdeadbeef);
    wait_for_flush();
    read_burst(32'h00000000, 9'd64, 64'hffffffffffffffff, 1'b1);
    write_burst(32'h01000000, 9'h1, 64'h0000111100001111);
    wait_for_flush();
    read_burst(32'h0f000000, 9'h1, 64'hdeadbeefdeadbeef, 1'b0);
    
    //max length
    write_burst(32'h00010000, 9'd256, 64'h0000111111110000); //triggers a flush
    write_flush();
    read_burst(32'h00010000, 9'd256, 64'h0000111111110000, 1'b0);
    
    //lots of small writes to different pages
    write_burst(32'h00000000, 9'd1, 64'h0000000011111111);
    write_burst(32'h00001000, 9'd1, 64'h1111111100000000);
    write_burst(32'h000021c0, 9'd1, 64'h2222222222222222);
    write_burst(43'h00101200, 9'd1, 64'hcccccccccccccccc);
    write_flush();
    read_burst(32'h00000000, 9'd1, 64'h0000000011111111, 1'b0); 
    read_burst(32'h00001000, 9'd1, 64'h1111111100000000, 1'b0);
    read_burst(32'h000021c0, 9'd1, 64'h2222222222222222,1'b0 );
    read_burst(43'h00101200, 9'd1, 64'hcccccccccccccccc, 1'b0);
    
    
    //unali
    

    //read_burst(32'h0, 9'h1, 64'h0);
    ////Read burst of longer than 1
    //read_burst(32'h0, 9'h4, 64'h0);
    ////Read burst that goes over one line
    //read_burst(32'h0, 9'h9, 64'h0);
    //
    ////Read burst that is unaligned
    //read_burst(32'h0000_0008, 9'h1, 64'h0); //still in line 0, should be muxed
    //read_burst(32'h0000_0040, 9'h1, 64'h0); //index into ram line 1
    ////Unaligned, multiple lines
    //read_burst(32'h0000_0830, 9'd17, 64'h0); //over 3 lines. 2 bursts from first line, 8 from second, 7 from last
    //
    ////Evict
    //read_burst(32'h0000_1000, 9'd1, 64'h0000_1000);
    //read_burst(32'h0000_1ff8, 9'd1, 64'h0000_1000);
    //
    //read_burst(32'h0f00_3ff8, 9'd1, 64'h0f00_3000); //Evict with unaligned addr
    //read_burst(32'h0f00_3030, 9'd15, 64'h0f00_3000);
    //read_burst(32'h0f00_3000, 9'd1, 64'h0f00_3000);
    //read_burst(32'h0000_0008, 9'h1, 64'h0);
    

    #100;
    $finish;
  end

endmodule
