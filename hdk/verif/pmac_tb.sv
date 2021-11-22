module pmac_tb;
  // ******************************************************************
  // Wires and Regs
  // ******************************************************************
  reg clk;
  reg rst_n;

  reg [511:0] tb_req_data;
  reg tb_req_data_val;
  wire tb_req_data_rdy;
  reg [15:0] tb_req_len;
  reg tb_req_val;
  wire tb_req_rdy;
  wire [127:0] tb_mac;
  wire tb_mac_val;
  reg tb_mac_rdy;

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
  pmac #(.DATA_WIDTH(512)) dut(
    .clk(clk),
    .rst_n(rst_n),
    .req_val(tb_req_val),
    .req_rdy(tb_req_rdy),
    .req_len(tb_req_len),
    .stream_data(tb_req_data),
    .stream_data_val(tb_req_data_val),
    .stream_data_rdy(tb_req_data_rdy),
    .pmac(tb_mac),
    .pmac_val(tb_mac_val),
    .pmac_rdy(tb_mac_rdy)
  );

  // ******************************************************************
  // Tasks
  // ******************************************************************
  task init_sim;
    begin
      clk = 1'b0;
      rst_n = 1'b1;

      tb_req_data = 512'd0;
      tb_req_data_val = 0;
      tb_req_len = 16'd0;
      tb_req_val = 0;
      tb_mac_rdy = 0;
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

  task gen_mac;
    input [511:0] data;
    input [15:0] len;
    input [127:0] expected;
    begin
      @(posedge clk);
      tb_req_len = len;
      tb_req_val = 1'b1;
      wait(tb_req_rdy);
      @(negedge clk);
      @(negedge clk);
      tb_req_val = 1'b0;

      for(int i = 0; i < len; i++) begin
        @(posedge clk);
        tb_req_data = data + i;
        tb_req_data_val = 1'b1;
        wait(tb_req_data_rdy);
        @(negedge clk);
        @(negedge clk);
        tb_req_data_val = 1'b0;
      end

      @(posedge clk);
      tb_mac_rdy = 1'b1;
      wait(tb_mac_val);

      $display("mac %h", tb_mac);
      $display("Expected %h", expected);
      if(tb_mac != expected) begin
        $display("ERROR");
        $finish;
      end
      else begin
        $display("OK");
      end
      
      @(negedge clk);
      @(negedge clk);
      tb_mac_rdy = 1'b0;

    end
  endtask

  initial begin
    $display("***************************************");
    $display ("Testing pmac");
    $display("***************************************");
    init_sim();
    reset_dut();

    
    #20;
    gen_mac(512'd0, 16'd1, 128'ha68da5fae5cc2840298cd0d5f24677e9);
    gen_mac(512'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f2021000000000000000000000000000000000000000000000000000000000000,
        16'd1, 128'h9774e82dc0fbaf01af693663d34312cb);
//    gen_mac(512'h0,
//        16'd2, 128'h1efc2d2a86edafc1000c109d0a2458f4);
    gen_mac(512'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f,
        16'd2, 128'h7b40e19daaff678585571c90c0490047);
    gen_mac(512'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f,
        16'd4, 128'he837386444e93062ff1021792b2db592);
    gen_mac(512'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f,
        16'd8, 128'h3506eb018218a08292fc813fef2a1a0b);
    gen_mac(512'h000102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f202122232425262728292a2b2c2d2e2f303132333435363738393a3b3c3d3e3f,
    16'd64, 128'h1cc41049fab379e5091ef94e2e3233c9);
    //gen_mac(512'h, 16'd1, 128'h1cd0bf2be1a4e8630e70100d2d1c2388);
    
    #20;
    $finish;

  end
endmodule
