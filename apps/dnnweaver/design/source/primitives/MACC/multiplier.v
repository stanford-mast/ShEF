`timescale 1ns/1ps
module multiplier #(
    parameter WIDTH_0 = 16,
    parameter WIDTH_1 = 16,
    parameter WIDTH_OUT = 48
) (
    input  wire                     CLK,
    input  wire                     RESET,
    input  wire                     ENABLE,
    input  wire [WIDTH_0-1     :0]  MUL_0,
    input  wire [WIDTH_1-1     :0]  MUL_1,
    output reg  [WIDTH_OUT-1   :0]  OUT,
    output reg                      OUT_VALID
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
    localparam integer CTRL_WIDTH = 3;
// ******************************************************************
// WIREs & REGs
// ******************************************************************
    wire [WIDTH_OUT-1:0] GND = 'b0;
    reg  [WIDTH_0-1:0] A_d;
    reg  [WIDTH_1-1:0] B_d;
    reg  enable_d;
// ******************************************************************
// LOGIC
// ******************************************************************

    // TIER 4 Regs
    always @(posedge CLK)
    begin
        if (RESET) begin
            A_d <= 0;
            B_d <= 0;
            enable_d <= 0;
        end else begin
            A_d <= MUL_0;
            B_d <= MUL_1;
            enable_d <= ENABLE;
        end
    end
    
    // TIER 5 Regs
    always @(posedge CLK)
    begin
        if (RESET) begin
            OUT <= 0;
            OUT_VALID <= 0;
        end else begin
            OUT <= A_d * B_d;
            OUT_VALID <= enable_d;
        end
    end

endmodule
