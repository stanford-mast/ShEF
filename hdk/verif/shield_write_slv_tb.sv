module shield_write_slv_tb;
  // ******************************************************************
  // parameters
  // ******************************************************************
  parameter integer CL_ID_WIDTH = 6;
  parameter integer CL_DATA_WIDTH = 64;
  parameter integer LINE_WIDTH = 512;
  parameter integer OFFSET_WIDTH = 6;
  parameter integer BURSTS_PER_LINE = 8;
  parameter integer BURSTS_PER_LINE_LOG = 3;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [CL_ID_WIDTH-1:0]       s_axi_wid;
  reg [CL_DATA_WIDTH-1:0]     s_axi_wdata;
  reg [CL_DATA_WIDTH/8-1:0]   s_axi_wstrb; //IGNORED FOR NOW
  reg                         s_axi_wlast;
  reg                         s_axi_wvalid;
  wire                        s_axi_wready;

  reg tb_req_val;
  reg tb_req_rdy;
  reg [7:0] tb_burst_count;
  reg [OFFSET_WIDTH-1:0] tb_burst_start_offset;

  wire [LINE_WIDTH-1:0] tb_cache_line;
  wire [BURSTS_PER_LINE-1:0] tb_cache_line_burst_en;
  wire tb_cache_line_val;
  reg tb_cache_line_rdy;


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
  shield_write_slv #(
    .CL_ID_WIDTH(CL_ID_WIDTH),
    .CL_DATA_WIDTH(CL_DATA_WIDTH),
    .LINE_WIDTH(LINE_WIDTH),
    .OFFSET_WIDTH(OFFSET_WIDTH),
    .BURSTS_PER_LINE(BURSTS_PER_LINE),
    .BURSTS_PER_LINE_LOG(BURSTS_PER_LINE_LOG)
  ) dut(
    .clk(clk),
    .rst_n(rst_n),
    .s_axi_wid            (s_axi_wid    ),
    .s_axi_wdata          (s_axi_wdata  ),
    .s_axi_wstrb          (s_axi_wstrb  ),
    .s_axi_wlast          (s_axi_wlast  ),
    .s_axi_wvalid         (s_axi_wvalid ),
    .s_axi_wready         (s_axi_wready ),
    .burst_count          (tb_burst_count         ),  //How many bursts to send from this line
    .burst_start_offset   (tb_burst_start_offset  ), //At which byte to start the burst
    .req_val              (tb_req_val             ),
    .req_rdy              (tb_req_rdy             ),
    .cache_line           (tb_cache_line          ),
    .cache_line_burst_en  (tb_cache_line_burst_en ),
    .cache_line_val       (tb_cache_line_val      ),
    .cache_line_rdy       (tb_cache_line_rdy      )
  );
  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;

      s_axi_wid = 0;
      s_axi_wdata = 0;
      s_axi_wstrb = 0;
      s_axi_wlast = 0;
      s_axi_wvalid = 0;
      tb_req_val = 0;
      tb_burst_count = 0;
      tb_burst_start_offset = 0;
      tb_cache_line_rdy = 0;
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

  task write_request;
    input [7:0] len;
    input [OFFSET_WIDTH-1:0] offset;
    reg [BURSTS_PER_LINE_LOG-1:0] burst_index;
    reg [LINE_WIDTH-1:0] expected_line;
    reg [BURSTS_PER_LINE-1:0] expected_burst_en;
    begin
      @(posedge clk);
      wait(tb_req_rdy);
      tb_burst_count = len;
      tb_burst_start_offset = offset;
      tb_req_val = 1; 
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 0;

      for(int i = 0; i < len; i++) begin
        @(posedge clk);
        wait(s_axi_wready);
        s_axi_wdata = i+1;
        s_axi_wvalid = 1;
        @(negedge clk);
        @(negedge clk);
        s_axi_wvalid = 0;
      end

      //generate expected
      expected_line = {LINE_WIDTH{1'b0}};
      expected_burst_en = 0;
      burst_index = offset[OFFSET_WIDTH-1 -: BURSTS_PER_LINE_LOG];
      for(int j = 0; j < len; j++) begin
        expected_line[(j + burst_index)*CL_DATA_WIDTH +: CL_DATA_WIDTH] = j+1;
        expected_burst_en[j+burst_index] = 1;
      end

      @(posedge clk);
      wait(tb_cache_line_val);
      $display("        read %h, expected %h",tb_cache_line, expected_line);
      $display("        en   %h, expected %h", tb_cache_line_burst_en, expected_burst_en);
      if(tb_cache_line != expected_line || tb_cache_line_burst_en != expected_burst_en) begin
        $display("ERROR");
        $finish;
      end
      else begin
        $display("OK");
      end
      tb_cache_line_rdy = 1;
      @(negedge clk);
      @(negedge clk);
      tb_cache_line_rdy = 0;

    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing AXI Slave");
    $display("***************************************");
    init_sim();
    reset_dut();
    
    #20;

    write_request(8'd1, 6'b000000);
    write_request(8'd2, 6'b000000);
    write_request(8'd8, 6'b000000);
    
     write_request(8'd1, 6'b001000);
     
     write_request(8'd3, 6'b001000);
     
     write_request(8'd1, 6'b111000);
     
     write_request(8'd2, 6'b110000);
     
     write_request(8'd2, 6'b010000);
    
    
    #20;
    $finish;

  end



endmodule
