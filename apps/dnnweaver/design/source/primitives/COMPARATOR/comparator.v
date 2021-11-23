`timescale 1ns/1ps
module comparator #(
    // INPUT PARAMETERS
    parameter DATA_WIDTH = 16
)
(
    // PORTS
    input  wire                             CLK,
    input  wire                             RESET,
    input  wire [ DATA_WIDTH   -1 : 0]      DATA_IN_0,
    input  wire [ DATA_WIDTH   -1 : 0]      DATA_IN_1,
    output reg  [ DATA_WIDTH   -1 : 0]      COMP_OUT
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
// ******************************************************************
// WIRES & REGS
// ******************************************************************

always @ (posedge CLK)
begin: COMPARISON
    if (RESET)
        COMP_OUT <= 0;
    else
        COMP_OUT <= DATA_IN_0 < DATA_IN_1 ? DATA_IN_0 : DATA_IN_1;
end

endmodule
