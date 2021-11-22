module hmac_tb;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [511:0] tb_req_data;
  reg [31:0] tb_req_addr;
  reg [31:0] tb_req_counter;
  reg tb_req_val;
  wire tb_req_rdy;
  wire [255:0] tb_hmac;
  wire tb_hmac_val;
  reg tb_hmac_rdy;

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
  hmac dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_data(tb_req_data),
    .req_addr(tb_req_addr),
    .req_counter(tb_req_counter),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .hmac(tb_hmac),
    .hmac_val(tb_hmac_val),
    .hmac_rdy(tb_hmac_rdy)
  );

  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;

      tb_req_data = 512'd0;
      tb_req_addr = 32'd0;
      tb_req_counter = 32'd0;
      tb_req_val = 0;
      tb_hmac_rdy = 0;
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

  task gen_hmac;
    input [511:0] data;
    input [31:0] addr;
    input [31:0] counter;
    input [255:0] expected;
    begin
      @(posedge clk);
      tb_req_data = data;
      tb_req_addr = addr;
      tb_req_counter = counter;
      tb_req_val = 1'b1;
      wait(tb_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 1'b0;

      @(posedge clk);
      tb_hmac_rdy = 1'b1;
      wait(tb_hmac_val);

      $display("hmac %h", tb_hmac);
      $display("Expected %h", expected);
      if(tb_hmac != expected) begin
        $display("ERROR");
        $finish;
      end
      else begin
        $display("OK");
      end
      
      @(negedge clk);
      @(negedge clk);
      tb_hmac_rdy = 1'b0;

    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing hmac");
    $display("***************************************");
    init_sim();
    reset_dut();

    
    #20;
    gen_hmac(512'd0, 32'd0, 32'd0, 256'he36026f1a38eb7f208f840298089e22d8454d4f8a469a463b06b8b37e2e65aba);
    gen_hmac(512'hdeadbeef, 32'hbeefdead, 32'haaaaaaaa, 256'hf8b71a1aa0fa8c97441e9490f0c2a7d03e702c830ce8c6392d6055935e5c365e);
    gen_hmac(512'h11111111, 32'h22222222, 32'h33333333, 256'h1f0db6b8dd32675386cd17febeda34ea7fd3cb4c0dd026b4b37f4f97b83ebab4);
    gen_hmac(512'h01234567012345670123456701234567012345670123456701234567012345670123456701234567012345670123456701234567012345670123456701234567,
     32'habcdef01 , 32'h23456789, 256'h9a53dd841a39e6a10b5d995b673d723cd23e71178f2e0d5739996982c01860fa);
    //gen_hmac(512'd0, 32'd0, 32'd0, 256'he36026f1a38eb7f208f840298089e22d8454d4f8a469a463b06b8b37e2e65aba);
    
    

    
    
    #20;
    $finish;

  end
endmodule
