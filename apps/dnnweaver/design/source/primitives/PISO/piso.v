`timescale 1ns/1ps
module piso
#( // INPUT PARAMETERS
    parameter integer DATA_IN_WIDTH  = 64,
    parameter integer DATA_OUT_WIDTH = 16
)( // PORTS
    input  wire                         CLK,
    input  wire                         RESET,
    input  wire                         LOAD,
    input  wire                         SHIFT,
    input  wire [DATA_IN_WIDTH -1 : 0]  DATA_IN,
    output wire [DATA_OUT_WIDTH -1 : 0] DATA_OUT
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
    localparam integer NUM_SHIFTS = DATA_IN_WIDTH / DATA_OUT_WIDTH;
// ******************************************************************

// ******************************************************************
// WIRES and REGS
// ******************************************************************
    reg [DATA_IN_WIDTH -1 : 0]  serial;
// ******************************************************************

assign DATA_OUT = serial [DATA_OUT_WIDTH-1:0];

always @(posedge CLK)
begin: DATA_SHIFT
    if (RESET)
        serial <= 0;
    else begin
        if (LOAD)
            serial <= DATA_IN;
        else if (SHIFT)
            //serial <= {{DATA_OUT_WIDTH{1'b0}}, serial[DATA_IN_WIDTH-1:DATA_OUT_WIDTH]};
            serial <= serial >> DATA_OUT_WIDTH;
    end
end

endmodule
