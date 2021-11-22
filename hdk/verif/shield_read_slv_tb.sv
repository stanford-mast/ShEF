module shield_read_slv_tb;
  // ******************************************************************
  // parameters
  // ******************************************************************
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [511:0] cache_line;
  reg [7:0] burst_len;
  reg [5:0] burst_start_offset;
  reg burst_last;
  reg input_val;
  wire input_rdy;
  wire busy;

  wire [63:0] s_axi_rdata;
  wire s_axi_rvalid;
  wire s_axi_rlast;
  reg  s_axi_rready;
  

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

  shield_read_slv dut(
    .clk(clk),
    .rst_n(rst_n),
    .cache_line(cache_line), //Data 
    .burst_count(burst_len),  //How many bursts to send from this line
    .burst_start_offset(burst_start_offset), //At which byte to start the burst
    .burst_last(burst_last),
    .input_val(input_val),
    .input_rdy(input_rdy),
    .busy(busy),
    .s_axi_rid(), //SET TO 0
    .s_axi_rdata(s_axi_rdata),
    .s_axi_rresp(), //ALWAYS SUCCESS
    .s_axi_rlast(s_axi_rlast), 
    .s_axi_rvalid(s_axi_rvalid),
    .s_axi_rready(s_axi_rready)
  );

  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;
      
      for(int i = 0; i < 16; i++) begin
        cache_line[i*32 +: 32] = $random;
      end

      burst_len = 0;
      burst_start_offset = 0;
      input_val = 0;
      burst_last = 0;
      
      s_axi_rready = 0;
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

  //Wait until ready
  task wait_for_ready;
    begin
     $display ("*** Wait for input ready ***");
      while(!input_rdy) begin
        #10;
      end
       $display ("Ready at %0t", $time);
    end
  endtask
  
  task load_input;
    input [7:0] len;
    input [5:0] offset;
    input last;
    begin
      @(posedge clk);
      $display("***Loading input: len %d, offset %h***", len, offset);
      wait(input_rdy);
      input_val = 1'b1;
      burst_len = len;
      burst_start_offset = offset;
      burst_last = last;
      @(negedge clk);
      @(negedge clk);
      input_val = 1'b0;
  
    end
  endtask
  
  //Wait until output is ready
  task wait_for_valid;
    begin
      while(!s_axi_rvalid) begin
        #10;
      end
    end
  endtask
  
  task read_output;
    input [7:0] len;
    input [5:0] offset;
    input last;
    reg [63:0] data;
    reg rlast;
    begin
    @(posedge clk);

      for(int i = 0; i < len; i++) begin
        s_axi_rready = 1'b1;  
        wait(s_axi_rvalid);
        @(negedge clk);
        data = s_axi_rdata;
        rlast = s_axi_rlast;
        @(posedge clk);
        s_axi_rready = 1'b0;
        $display("    reading offset %d, expected %h, read %h", offset*8 + i*64, cache_line[offset*8+(i*64)+:64], data);
        if (cache_line[offset*8 + (i*64) +: 64] != data) begin
            $display("ERROR");
            $finish;
        end
        if (i == (len-1)) begin
          if(rlast != last) begin
            $display("ERROR");
            $finish;
          end
        end
        else begin
          if(rlast != 0) begin
            $display("ERROR");
            $finish;
          end
        end
      end
      $display("    OK");
    end
  endtask
  

  initial begin
    $display("***************************************");
    $display ("Testing AXI Slave");
    $display("***************************************");
    init_sim();
    reset_dut();
    
    #20;
    
    //Load one burst
    load_input(8'd1, 6'd0, 1'b0);
    read_output(8'd1, 6'd0, 1'b0);
    
    load_input(8'd1, 6'd0, 1'b1);
    read_output(8'd1, 6'd0, 1'b1);
    
    //Load two bursts
    load_input(8'd2, 6'b001000, 1'b0);
    read_output(8'd2, 6'b001000, 1'b0);
    //
    ////Load multiple before read
    load_input(8'd4, 6'b001000, 1'b0);
    load_input(8'd1, 6'b111000, 1'b1);
    read_output(8'd4, 6'b001000, 1'b0);
    read_output(8'd1, 6'b111000, 1'b1);
    //
    ////Load and read full cache line
    load_input(8'd8, 6'd0, 1'b1);
    read_output(8'd8, 6'd0, 1'b1);
    //
    load_input(8'd7, 6'd0, 1'b0);
    read_output(8'd7, 6'd0, 1'b0);
    load_input(8'd7, 6'd0, 1'b1);
    read_output(8'd7, 6'd0, 1'b1);

    
    
    #20;
    $finish;

  end

endmodule
