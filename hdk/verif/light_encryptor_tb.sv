module light_encryptor_tb;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [639:0] tb_req_pt;
  reg tb_req_val;
  wire tb_req_rdy;
  wire [639:0] tb_resp_ct;
  wire [127:0] tb_resp_hmac;
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
  light_encryptor dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_plaintext(tb_req_pt),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .resp_ciphertext(tb_resp_ct),
    .resp_hmac(tb_resp_hmac),
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

      tb_req_pt = 640'h0;
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

  task encrypt;
    input [639:0] pt;
    begin
      @(posedge clk);
      tb_req_pt = pt;
      tb_req_val = 1'b1;
      wait(tb_req_rdy);
      @(negedge clk);
      @(negedge clk);
      //tb_req_val = 1'b0;

      @(posedge clk);
      //tb_resp_rdy = 1'b1;
      wait(tb_resp_val);

      $display("ct: %h", tb_resp_ct);
      $display("hmac: %h", tb_resp_hmac);

      @(negedge clk);
      @(negedge clk);
      //tb_resp_rdy = 1'b0;
    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing hmac");
    $display("***************************************");
    init_sim();
    reset_dut();

    
    #20;
    encrypt(640'd0);
 
    
    
    #20;
    $finish;

  end
endmodule
