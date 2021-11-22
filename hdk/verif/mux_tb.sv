module mux_tb;

// ******************************************************************
// parameters
// ******************************************************************
// ******************************************************************
// Wires and Regs
// ******************************************************************
  reg [511:0] bus;
  reg [2:0] sel;
  wire [63:0] out;

  clk_rst_driver clkgen(
    .clk(clk),
    .reset_n(rst_n),
    .reset()
  );


  shield_muxp dut(
    .in_bus(bus),
    .sel(sel),
    .out(out)
  );



  initial begin
    bus[63:0] = 64'hdeadbeefdeadbeef;
    bus[127:64] = 64'h10101010ffffffff;
    bus[511:448] = 64'hbbbbbbbbbbbbbbbb;
    sel = 3'd0;
    #20;
    $display("Beginning test...");
    sel = 3'd1;
    #20;
    sel = 3'd7;
    
    #20;
  end

endmodule
