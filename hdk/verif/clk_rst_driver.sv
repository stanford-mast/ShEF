module clk_rst_driver (
    output reg      clk,
    output reg      reset_n,
    output wire     reset
);

always #5 clk = !clk;
assign reset = !reset_n;

initial begin
    clk = 0;
    reset_n = 0;
    @(negedge clk);
    @(negedge clk);
    reset_n = 1;
end

endmodule
