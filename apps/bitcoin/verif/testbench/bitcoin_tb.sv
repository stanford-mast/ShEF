module bitcoin_tb;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [607:0] tb_block_header;
  reg [7:0] tb_hash_target;
  reg tb_req_val;
  wire tb_req_rdy;
  wire [31:0] tb_golden_nonce;
  wire [255:0] tb_golden_digest;
  wire tb_golden_nonce_val;
  reg tb_golden_nonce_rdy;

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
  bitcoin dut(
    .clk(clk),
    .rst_n(rst_n),
    .block_header(tb_block_header),
    .hash_target(tb_hash_target),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .golden_nonce(tb_golden_nonce),
    .golden_digest(tb_golden_digest),
    .golden_nonce_val(tb_golden_nonce_val),
    .golden_nonce_rdy(tb_golden_nonce_rdy)
  );

  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;

      tb_block_header = 608'd0;
      tb_hash_target = 0;
      tb_req_val = 0;
      tb_golden_nonce_rdy = 0;
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

  task gen_nonce;
    input [607:0] block_header;
    input [7:0] hash_target;
    begin
      @(posedge clk);
      tb_block_header = block_header;
      tb_hash_target = hash_target;
      tb_req_val = 1'b1;
      wait(tb_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 1'b0;

      @(posedge clk);
      tb_golden_nonce_rdy = 1'b1;
      wait(tb_golden_nonce_val);

      $display("nonce %h", tb_golden_nonce);
      $display("hash %h", tb_golden_digest);
      $display("OK");
      
      @(negedge clk);
      @(negedge clk);
      tb_golden_nonce_rdy = 1'b0;

    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing btc");
    $display("***************************************");
    init_sim();
    reset_dut();

    
    #20;
    gen_nonce(608'd0, 8'd4);
    gen_nonce(608'd0, 8'd8);
    gen_nonce(608'd0, 8'd12);
    
    
    

    
    
    #20;
    $finish;

  end
endmodule
