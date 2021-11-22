module aes_tb;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [95:0] tb_nonce;
  reg [31:0] tb_counter;
  reg tb_req_val;
  wire tb_req_rdy;
  wire [127:0] tb_pad;
  wire tb_pad_val;
  reg tb_pad_rdy;

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
  aes dut(
    .clk(clk),
    .rst_n(rst_n),
    .nonce(tb_nonce),
    .counter(tb_counter),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .pad(tb_pad),
    .pad_val(tb_pad_val),
    .pad_rdy(tb_pad_rdy)
  );

  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;

      tb_nonce = 96'd0;
      tb_counter = 32'd0;
      tb_req_val = 0;
      tb_pad_rdy = 0;
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

  task gen_pad;
    input [95:0] nonce;
    input [31:0] counter;
    input [127:0] expected;
    begin
      @(posedge clk);
      tb_nonce = nonce;
      tb_counter = counter;
      tb_req_val = 1'b1;
      wait(tb_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 1'b0;

      @(posedge clk);
      tb_pad_rdy = 1'b1;
      wait(tb_pad_val);

      $display("Pad %h", tb_pad);
      $display("Expected %h", expected);
      if(tb_pad != expected) begin
        $display("ERROR");
        $finish;
      end
      else begin
        $display("OK");
      end
      
      @(negedge clk);
      @(negedge clk);
      tb_pad_rdy = 1'b0;

    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing AES");
    $display("***************************************");
    init_sim();
    reset_dut();

    
    #20;
    
    
    gen_pad(96'd0, 32'd0, 128'h827d6516271e5f93704df15f75f01ae7);
    gen_pad(96'd0, 32'd1, 128'haa3f9d432ddee7fcbb5b59555262e20d);
    gen_pad(96'hff, 32'hdeadbeef, 128'hf3b1416dee9638c4c51dcaf14d1bb8a7);

    
    
    #20;
    $finish;

  end
endmodule
