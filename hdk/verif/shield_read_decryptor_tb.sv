module shield_read_decryptor_tb;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [511:0] tb_req_data;
  reg [31:0] tb_req_addr;
  reg [31:0] tb_req_counter;
  reg [63:0] tb_iv;
  reg tb_req_val;
  wire tb_req_rdy;
  wire [511:0] tb_resp_pad;
  wire [127:0] tb_resp_hmac_tag;
  wire tb_resp_val;
  reg tb_resp_rdy;

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
  shield_read_decryptor dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_data(tb_req_data),
    .req_addr(tb_req_addr),
    .req_counter(tb_req_counter),
    .req_iv(tb_iv),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .resp_pad(tb_resp_pad),
    .resp_hmac_tag(tb_resp_hmac_tag),
    .resp_val(tb_resp_val),
    .resp_rdy(tb_resp_rdy)
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
      tb_iv = 64'd0;
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

  task decrypt;
    input [511:0] data;
    input [31:0] addr;
    input [31:0] counter;
    input [63:0] iv;
    input [511:0] expected_pad;
    input [127:0] expected_tag;
    begin
      @(posedge clk);
      tb_req_data = data;
      tb_req_addr = addr;
      tb_req_counter = counter;
      tb_iv = iv;
      tb_req_val = 1'b1;
      wait(tb_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 1'b0;

      @(posedge clk);
      tb_resp_rdy = 1'b1;
      wait(tb_resp_val);

      $display("pad %h", tb_resp_pad);
      $display("Expected %h", expected_pad);
      $display("tag %h", tb_resp_hmac_tag);
      $display("Expected %h", expected_tag);
      if((tb_resp_pad != expected_pad) || (tb_resp_hmac_tag != expected_tag)) begin
        $display("ERROR");
        $finish;
      end
      else begin
        $display("OK");
      end
      
      @(negedge clk);
      @(negedge clk);
      tb_resp_rdy = 1'b0;

    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing decryptor");
    $display("***************************************");
    init_sim();
    reset_dut();

    
    #20;
    decrypt(512'h0, 32'h0, 32'h0, 64'h0,
      512'h9d2c4daace64ad10ae833e596c022ca7b83049b3ceae6b3e777af984af4b5fb7aa3f9d432ddee7fcbb5b59555262e20d827d6516271e5f93704df15f75f01ae7,
      128'he36026f1a38eb7f208f840298089e22d);
      
    decrypt(
        512'h01234567012345670123456701234567012345670123456701234567012345670123456701234567012345670123456701234567012345670123456701234567,
        32'habcdef01, 32'h23456789, 64'hdeadbeefdeadbeef,
        512'h81f6af64a8d1a8a100727f9bdcf7be3ed1c81cacb453109116d8d8687a72f6affbb11b4a5d161f1eb0916cfab2d3fb29829defee7ebc270fe6f2ebca5b2ac278,
        128'h9a53dd841a39e6a10b5d995b673d723c);
        
     decrypt(
        512'h36363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636363636,
        32'hcccccccc, 32'h01010101, 64'h00001111aaaabbbb,
        512'h27a239ea0548d93bccffd4ab86f0a00cc7fc637e567182fc5608e317ff647c62e74460fb8c1ff33d84cb24298c1bcff22f5daf48e7e473bf18db2219226b4cd1,
        128'h1ddb0eeac69a0434e74581bff9c9a4dc);
        
      

    //gen_hmac(512'd0, 32'd0, 32'd0, 256'he36026f1a38eb7f208f840298089e22d8454d4f8a469a463b06b8b37e2e65aba);
    //gen_hmac(512'hdeadbeef, 32'hbeefdead, 32'haaaaaaaa, 256'hf8b71a1aa0fa8c97441e9490f0c2a7d03e702c830ce8c6392d6055935e5c365e);
    //gen_hmac(512'h11111111, 32'h22222222, 32'h33333333, 256'h1f0db6b8dd32675386cd17febeda34ea7fd3cb4c0dd026b4b37f4f97b83ebab4);
    //gen_hmac(512'h01234567012345670123456701234567012345670123456701234567012345670123456701234567012345670123456701234567012345670123456701234567,
    // 32'habcdef01 , 32'h23456789, 256'h9a53dd841a39e6a10b5d995b673d723cd23e71178f2e0d5739996982c01860fa);
    //gen_hmac(512'd0, 32'd0, 32'd0, 256'he36026f1a38eb7f208f840298089e22d8454d4f8a469a463b06b8b37e2e65aba);
    
    

    
    
    #20;
    $finish;

  end
endmodule
