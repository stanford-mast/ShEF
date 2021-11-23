module lfsr
#(
    parameter integer DATA_WIDTH = 4,
    parameter integer INIT_DATA  = 0,
    parameter         POLYNOMIAL = 4'h9
)(
    input  wire                 clk,
    input  wire                 reset,
    output reg [DATA_WIDTH-1:0] lfsr_data_out
);

    wire feedback = ^(lfsr_data_out & POLYNOMIAL);

    always @(posedge clk)
        if (reset)
            lfsr_data_out <= INIT_DATA;
        else
            lfsr_data_out <= {lfsr_data_out[DATA_WIDTH-2:0], feedback};
endmodule
