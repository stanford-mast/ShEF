`timescale 1ns/1ps
module delay_tb();
localparam integer DATA_WIDTH = 8;
localparam integer DELAY = 1;
reg CLK, RESET;
reg [DATA_WIDTH-1:0] TEST_DATA_IN;
wire [DATA_WIDTH-1:0] TEST_DATA_OUT;

initial
begin
    CLK = 0;
    RESET = 0;
    TEST_DATA_IN = 0;
    @(negedge CLK);
    RESET = 1;
    @(negedge CLK);
    RESET = 0;
    #100 $finish;
end

always #1 CLK = !CLK;

always @(posedge CLK)
begin
    TEST_DATA_IN <= $time;
end

always @(posedge CLK)
begin
    $display ("IN: %h, OUT: %h", TEST_DATA_IN, TEST_DATA_OUT);
end

delay #(
    .DATA_WIDTH     (DATA_WIDTH),
    .DELAY          (DELAY)
) DUT (
    .CLK            (CLK),
    .RESET          (RESET),
    .DIN            (TEST_DATA_IN),
    .DOUT           (TEST_DATA_OUT)
);

endmodule
