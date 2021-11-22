module shield_tb;
  // ******************************************************************
  // parameters
  // ******************************************************************
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

  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  wire [AXI_ID_WIDTH-1:0]    m_axi_arid;
  wire [AXI_ADDR_WIDTH-1:0]  m_axi_araddr;
  wire [7:0]                 m_axi_arlen;
  wire [2:0]                 m_axi_arsize;
  wire [1:0]                 m_axi_arburst;
  wire [1:0]                 m_axi_arlock;
  wire [3:0]                 m_axi_arcache;
  wire [2:0]                 m_axi_arprot;
  wire [3:0]                 m_axi_arqos;
  wire                       m_axi_arvalid;
  wire                       m_axi_arready;
  wire [AXI_ID_WIDTH-1:0]    m_axi_rid;
  wire [AXI_DATA_WIDTH-1:0]  m_axi_rdata;
  wire [1:0]                 m_axi_rresp;
  wire                       m_axi_rlast;
  wire                       m_axi_rvalid;
  wire                       m_axi_rready;

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

  reg [CL_ID_WIDTH-1:0]            s_axi_arid      ;
  reg [CL_ADDR_WIDTH-1:0]          s_axi_araddr    ;
  reg [7:0]                        s_axi_arlen     ;
  reg [2:0]                        s_axi_arsize    ;
  reg [1:0]                        s_axi_arburst   ;
  reg [1:0]                        s_axi_arlock    ;
  reg [3:0]                        s_axi_arcache   ;
  reg [2:0]                        s_axi_arprot    ;
  reg [3:0]                        s_axi_arqos     ;
  reg [3:0]                        s_axi_arregion  ;
  reg                              s_axi_arvalid   ;
  wire                             s_axi_arready   ;
  wire [CL_ID_WIDTH-1:0]           s_axi_rid       ;
  wire [CL_DATA_WIDTH-1:0]         s_axi_rdata     ;
  wire [1:0]                       s_axi_rresp     ;
  wire                             s_axi_rlast     ;
  wire                             s_axi_rvalid    ;
  reg                              s_axi_rready    ;

  reg [CL_ID_WIDTH-1:0]            s_axi_awid;
  reg [CL_ADDR_WIDTH-1:0]          s_axi_awaddr;
  reg [7:0]                        s_axi_awlen;
  reg [2:0]                        s_axi_awsize;
  reg [1:0]                        s_axi_awburst;
  reg [1:0]                        s_axi_awlock;
  reg [3:0]                        s_axi_awcache;
  reg [2:0]                        s_axi_awprot;
  reg [3:0]                        s_axi_awqos;
  reg [3:0]                        s_axi_awregion;
  reg                              s_axi_awvalid;
  wire                             s_axi_awready;
  reg [CL_ID_WIDTH-1:0]       s_axi_wid;
  reg [CL_DATA_WIDTH-1:0]     s_axi_wdata;
  reg [CL_DATA_WIDTH/8-1:0]   s_axi_wstrb;
  reg                         s_axi_wlast;
  reg                         s_axi_wvalid;
  wire                             s_axi_wready;
  wire [CL_ID_WIDTH-1:0]           s_axi_bid;
  wire [1:0]                       s_axi_bresp;
  wire                             s_axi_bvalid;
  reg                              s_axi_bready;

  wire [3:0] shield_state;

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

  shield_wrapper #(
    .AXI_ADDR_WIDTH(AXI_ADDR_WIDTH),
    .AXI_ID_WIDTH(AXI_ID_WIDTH),
    .AXI_DATA_WIDTH(AXI_DATA_WIDTH),
    .CL_ADDR_WIDTH(CL_ADDR_WIDTH),
    .CL_ID_WIDTH(CL_ID_WIDTH),
    .CL_DATA_WIDTH(CL_DATA_WIDTH),
    .SHIELD_ADDR_WIDTH(SHIELD_ADDR_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .CACHE_DEPTH(CACHE_DEPTH)
  )
  dut(
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_awid           (s_axi_awid   ),
    .s_axi_awaddr         (s_axi_awaddr ),
    .s_axi_awlen          (s_axi_awlen  ),
    .s_axi_awsize         (s_axi_awsize ),
    .s_axi_awburst        (s_axi_awburst),
    .s_axi_awlock         (s_axi_awlock ),
    .s_axi_awcache        (s_axi_awcache),
    .s_axi_awprot         (s_axi_awprot ),
    .s_axi_awqos          (s_axi_awqos  ),
    .s_axi_awregion       (s_axi_awregion),
    .s_axi_awvalid        (s_axi_awvalid),
    .s_axi_awready        (s_axi_awready),
    .s_axi_wid            (s_axi_wid    ),
    .s_axi_wdata          (s_axi_wdata  ),
    .s_axi_wstrb          (s_axi_wstrb  ),
    .s_axi_wlast          (s_axi_wlast  ),
    .s_axi_wvalid         (s_axi_wvalid ),
    .s_axi_wready         (s_axi_wready ),
    .s_axi_bid            (s_axi_bid    ),
    .s_axi_bresp          (s_axi_bresp  ),
    .s_axi_bvalid         (s_axi_bvalid ),
    .s_axi_bready         (s_axi_bready ),
    .s_axi_arid           (s_axi_arid    ),
    .s_axi_araddr         (s_axi_araddr  ),
    .s_axi_arlen          (s_axi_arlen   ),
    .s_axi_arsize         (s_axi_arsize  ),
    .s_axi_arburst        (s_axi_arburst ),
    .s_axi_arlock         (s_axi_arlock  ),
    .s_axi_arcache        (s_axi_arcache ),
    .s_axi_arprot         (s_axi_arprot  ),
    .s_axi_arqos          (s_axi_arqos   ),
    .s_axi_arregion       (s_axi_arregion),
    .s_axi_arvalid        (s_axi_arvalid ),
    .s_axi_arready        (s_axi_arready ),
    .s_axi_rid            (s_axi_rid     ),
    .s_axi_rdata          (s_axi_rdata   ),
    .s_axi_rresp          (s_axi_rresp   ),
    .s_axi_rlast          (s_axi_rlast   ),
    .s_axi_rvalid         (s_axi_rvalid  ),
    .s_axi_rready         (s_axi_rready  ),
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
    .m_axi_bready         (m_axi_bready  ),
    .m_axi_arid           (m_axi_arid   ),
    .m_axi_araddr         (m_axi_araddr ),
    .m_axi_arlen          (m_axi_arlen  ),
    .m_axi_arsize         (m_axi_arsize ),
    .m_axi_arburst        (m_axi_arburst),
    .m_axi_arlock         (m_axi_arlock ),
    .m_axi_arcache        (m_axi_arcache),
    .m_axi_arprot         (m_axi_arprot ),
    .m_axi_arqos          (m_axi_arqos  ),
    .m_axi_arregion       (),
    .m_axi_arvalid        (m_axi_arvalid),
    .m_axi_arready        (m_axi_arready),
    .m_axi_rid            (m_axi_rid    ),
    .m_axi_rdata          (m_axi_rdata  ),
    .m_axi_rresp          (m_axi_rresp  ),
    .m_axi_rlast          (m_axi_rlast  ),
    .m_axi_rvalid         (m_axi_rvalid ),
    .m_axi_rready         (m_axi_rready ),
    .shield_state         (shield_state)
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

      s_axi_arid     = 0          ;
      s_axi_araddr   = 0          ;
      s_axi_arlen    = 0          ;
      s_axi_arsize   = ARSIZE_INIT  ;
      s_axi_arburst  = 2'b01  ;
      s_axi_arlock   = 2'b00  ;
      s_axi_arcache  = 4'b0011  ;
      s_axi_arprot   = 3'b000  ;
      s_axi_arqos    = 4'b000  ;
      s_axi_arregion = 4'b000  ;
      s_axi_arvalid  = 0  ;
      s_axi_rready   = 0  ;
      s_axi_awid = 0;
      s_axi_awaddr = 0;
      s_axi_awlen = 0;
      s_axi_awsize = AWSIZE_INIT;
      s_axi_awburst = 2'b01;
      s_axi_awlock = 2'b00;
      s_axi_awcache = 4'b0011;
      s_axi_awprot = 3'b000;
      s_axi_awqos = 4'b0000;
      s_axi_awregion = 4'b0000;
      s_axi_awvalid = 0;
      s_axi_wid = 0;
      s_axi_wdata = 0;
      s_axi_wstrb = {WSTRB_INIT{1'b1}};
      s_axi_wlast = 0;
      s_axi_wvalid = 0;
      s_axi_bready = 0;
      
      axi_driver_inst.initialize_ddr;
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

  task read_request;
    input  [CL_ADDR_WIDTH-1:0] addr;
    input  [7:0]               len;
    //input [4:0] expected_state;
    input [CL_DATA_WIDTH-1:0] expected_data;
    reg    [CL_DATA_WIDTH-1:0] read_data;
    reg [4:0] next_state;
    reg [8:0] count;
    reg last;
    begin
      @(posedge clk);
      count = len + 1;
      $display("***Reading %d bursts from address 0x%h***", count, addr);
      s_axi_arvalid = 1'b1;
      s_axi_araddr = addr;
      s_axi_arlen = len;
      wait(s_axi_arready);
      @(negedge clk);
      @(negedge clk);
      s_axi_arvalid = 1'b0;
      
      //Check next state here
      next_state = dut.shield_controller_inst.next_state;
      //$display("     next state: %d, expected state: %d", next_state, expected_state);
//      if(next_state !== expected_state) begin
//        $display("ERROR");
//        $finish;
//      end
//      else begin
//        $display("OK");
//      end

      for(int i = 0; i < count; i++) begin
          @(posedge clk);
          s_axi_rready = 1;
          wait(s_axi_rvalid);
          @(negedge clk);
          read_data = s_axi_rdata;
          last = s_axi_rlast;
          //expected = (addr[CL_ADDR_WIDTH-1:0] + i*8) & ( {CL_ADDR_WIDTH{1'b1}} << OFFSET_WIDTH);
          @(posedge clk);
          s_axi_rready = 0;
    
          $display("      read %h, expected %h", read_data, expected_data);
          
          if((i == (count - 1) ) && last != 1'b1) begin
            $display("ERROR: rlast not asserted");
            $finish;
          end
    
          if(read_data != expected_data) begin
            $display("ERROR");
            $finish;
          end
          else begin
            $display("OK");
          end
      end

    end
  endtask

  task write_request;
    input [CL_ADDR_WIDTH-1:0] addr;
    input [7:0] len;
    input [CL_DATA_WIDTH-1:0] data; //repeat this for len times
    reg [8:0] count;
    begin
      @(posedge clk);
      count = len + 1;
      $display("***Writing %d bursts to address 0x%h***", count, addr);
      s_axi_awvalid = 1'b1;
      s_axi_awaddr = addr;
      s_axi_awlen = len;
      wait(s_axi_awready);

      @(negedge clk);
      @(negedge clk);
      s_axi_awvalid = 1'b0;

      for(int i = 0; i < count; i++) begin
        @(posedge clk);
        s_axi_wvalid = 1;
        s_axi_wdata = data;
        wait(s_axi_wready);
        @(negedge clk);
        @(negedge clk);
        s_axi_wvalid = 0;
      end

      @(posedge clk);
      s_axi_bready = 1;
      wait(s_axi_bvalid);
      @(negedge clk);
      @(negedge clk);
      s_axi_bready = 0;

    end

  endtask
  
  task wait_for_flush;
    begin
    $display("Waiting for stream flush");
    @(posedge clk);
    if(dut.shield_datapath_inst.stream_inst.stream_write_inst.axi_state_r != 4'd0) begin
        wait(dut.shield_datapath_inst.stream_inst.stream_write_inst.axi_state_r == 4'd8);
        wait(dut.shield_datapath_inst.stream_inst.stream_write_inst.axi_state_r == 4'd0);
    end
    end
  endtask


  

  initial begin
    $display("***************************************");
    $display ("Testing Shield");
    $display("***************************************");
    init_sim();
    reset_dut();
    
    #40;

    //Write 1 burst and read 1 burst;
    write_request(64'h0200_0000, 8'd0, 64'h0);
    read_request(64'h0200_0000, 8'd0, 64'h0); //expect hit
    
//    //Write nonzero data and read it
    write_request(64'h0200_0000, 8'd0, 64'hdeadbeef);
    read_request(64'h0200_0000, 8'd0, 64'hdeadbeef);
    
    //Write a stream of data
    write_request(64'h0000_0000, 8'd1, 64'hdeadbeef);
    write_request(64'h0001_0000, 8'd1, 64'h0);
    write_request(64'h0201_0000, 8'd0, 64'hffff0000); //write during eviction - should not interfere evicts 0
    wait_for_flush();
    read_request(64'h0000_0000, 8'd1, 64'hdeadbeef);
    read_request(64'h0200_0000, 8'd0, 64'hdeadbeef); //evicts 2010000
    read_request(64'h0201_0000, 8'd0, 64'hffff0000);
    
    //    //Write to a non-zero index and read it
    write_request(64'h0201_1000, 8'd0, 64'hffff0000);
    write_request(64'h0201_1100, 8'd0, 64'h0000ffff);
    read_request(64'h0201_1100, 8'd0, 64'h0000ffff);
    read_request(64'h0201_1000, 8'd0, 64'hffff0000);
    
    //    //Evict non-zero index with a write
    write_request(64'h1001_1000, 8'd0, 64'h11111111); //should evict 0001_1000
    read_request(64'h0201_1000, 8'd0, 64'hffff0000); //Evicts 1001_1000, refills
    read_request(64'h1001_1000, 8'd0, 64'h11111111);
    
    //write stream beyond
    write_request(64'h00010000, 8'd255, 64'h01010101);
    write_request(64'h000200c0, 8'd0, 64'hdeadbeef);
    wait_for_flush();
    
    write_request(64'h10000000, 8'd3, 64'h00ff00ff);
    read_request(64'h00010000, 8'd255, 64'h01010101);
    
    //    write_request(64'h1000_3000, 8'd1, 64'hbbbbbbbb);
    write_request(64'h1000_3000, 8'd1, 64'hbbbbbbbb);
    write_request(64'h2000_3030, 8'd0, 64'hdeadbeef);
    read_request(64'h1000_3000, 8'd0, 64'hbbbbbbbb);
    read_request(64'h1000_3008, 8'd0, 64'hbbbbbbbb);
    read_request(64'h1000_3000, 8'd1, 64'hbbbbbbbb);
    
    //write beyond 1 cache line
    write_request(64'h1000_3030, 8'd3, 64'h22220000);
    read_request(64'h1000_3030, 8'd3, 64'h22220000);
    write_request(64'h1000_3030, 8'd0, 64'hdeaddead); //dirty 3030
    
    //write beyond 1 page streaming
    write_request(32'h0000_0fc0, 8'd64, 64'h00110011);
    write_request(32'h0000_0000, 8'd0, 64'hbeefbeef);
    wait_for_flush();
    read_request(32'h0000_0fc0, 8'd64, 64'h00110011);
    
    //trigger evict and refill path with opposite read/write requests
    
    read_request(64'h2000_3030, 8'd0, 64'hdeadbeef);
    
    //make the stream read busy, then try to write and refill 3030 -> requires shield read
    read_request(64'h000100c0, 8'd0, 64'h01010101);
    write_request(64'h1000_3030, 8'd0, 64'haaaaaaaa);
    
    write_request(64'h3000_3040, 8'd33, 64'h01010101);
    //lots of small writes to pages
    write_request(64'h00001000, 8'd0, 64'h11111111);
    write_request(64'h000021c0, 8'd0, 64'h22222222);
    write_request(64'h00101200, 8'd0, 64'h33333333);
    read_request(64'h3000_3040, 8'd0, 64'h01010101);
    read_request(64'h3000_3040, 8'd33, 64'h01010101);
    
    write_request(64'h00000000, 8'd0, 64'h0);
    wait_for_flush();
    
     read_request(64'h00001000, 8'd0, 64'h11111111);
    read_request(64'h000021c0, 8'd0, 64'h22222222);
    read_request(64'h00101200, 8'd0, 64'h33333333);
    
    

    
    
////    //Write to nonzero address and read it
//    write_request(64'h0201_0000, 8'd0, 64'hbeefbeef); //Evicts index 0
//    read_request(64'h0201_0000, 8'd0, 5'd2, 64'hbeefbeef);
//    read_request(64'h0200_0000, 8'd0, 5'd7, 64'hdeadbeef); //capacity miss, read from ddr. evicts to dram
//    read_request(64'h0201_0000, 8'd0, 5'd4, 64'hbeefbeef); //capacity miss, read from ddr. no eviction
    
//    //Write to a non-zero index and read it
//    write_request(64'h0201_1000, 8'd0, 64'hffff0000);
//    write_request(64'h0201_1100, 8'd0, 64'h0000ffff);
//    read_request(64'h0201_1100, 8'd0, 5'd2, 64'h0000ffff);
//    read_request(64'h0201_1000, 8'd0, 5'd2, 64'hffff0000);
    
//    //Evict non-zero index with a write
//    write_request(64'h1001_1000, 8'd0, 64'h11111111); //should evict 0001_1000
//    read_request(64'h0201_1000, 8'd0, 5'd7, 64'hffff0000); //Evicts 1001_1000, refills
//    read_request(64'h1001_1000, 8'd0, 5'd4, 64'h11111111);
    
//    //Write multiple bursts
//    write_request(64'h1000_3000, 8'd1, 64'hbbbbbbbb);
//    read_request(64'h1000_3000, 8'd0, 5'd2, 64'hbbbbbbbb);
//    read_request(64'h1000_3008, 8'd0, 5'd2, 64'hbbbbbbbb);
//    read_request(64'h1000_3000, 8'd1, 5'd2, 64'hbbbbbbbb);
    
//    //Write beyond one cache line
//    write_request(64'h1000_3030, 8'd3, 64'h22220000);
//    read_request(64'h1000_3030, 8'd3, 5'd2, 64'h22220000);
    
//    write_request(64'h1000_30c0, 8'd3, 64'h22220000);
//    read_request(64'h1000_30c0, 8'd3, 5'd2, 64'h22220000);
    
//    write_request(64'h2000_3008, 8'd7, 64'h10101010);
//    read_request(64'h2000_3040, 8'd0, 5'd2, 64'h10101010);
//    write_request(64'h3000_3040, 8'd0, 64'h0);
//    read_request(64'h2000_3040, 8'd0, 5'd7, 64'h10101010);
//    read_request(64'h3000_3040, 8'd0, 5'd4, 64'h0);
//    write_request(64'h3000_3040, 8'd15, 64'h01010101);
//    read_request(64'h3000_3040, 8'd0, 5'd2, 64'h01010101);
//    read_request(64'h3000_3040, 8'd15, 5'd2, 64'h01010101);
    
//    read_request(64'h0000_0000, 8'd1, 5'h10, 64'h0);
//    read_request(64'h0000_0000, 8'd15, 5'h10, 64'h0);
//    read_request(64'h0000_1000, 8'd1, 5'h10, 64'h0);
//    read_request(64'h0000_1080, 8'd1, 5'h10, 64'h0);
    
//    read_request(64'h3000_3040, 8'd0, 5'd2, 64'h01010101);
//    read_request(64'h3000_3040, 8'd15, 5'd2, 64'h01010101);
//    write_request(64'h3000_3040, 8'd15, 64'h00001111);
//    read_request(64'h3000_3040, 8'd15, 5'd2, 64'h00001111);
//        //Write beyond one cache line
//        read_request(64'h000f_0000, 8'd1, 5'h10, 64'h0);
//    write_request(64'h1000_3030, 8'd3, 64'h22220000);
//    read_request(64'h1000_3030, 8'd3, 5'd2, 64'h22220000);
    



    
    
    #100;
    $finish;

  end

endmodule
