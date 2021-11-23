`timescale 1ns/1ps
module piso_norm 
#( // INPUT PARAMETERS
    parameter integer DATA_IN_WIDTH  = 64,
    parameter integer DATA_OUT_WIDTH = 16
)( // PORTS
    input  wire                         CLK,
    input  wire                         RESET,
    input  wire                         ENABLE,
    input  wire [DATA_IN_WIDTH -1 : 0]  DATA_IN,
    output wire                         READY,
    output wire [DATA_OUT_WIDTH -1 : 0] DATA_OUT,
    output wire                         OUT_VALID
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
    localparam integer NUM_SHIFTS = DATA_IN_WIDTH / DATA_OUT_WIDTH - 1;
// ******************************************************************

// ******************************************************************
// WIRES and REGS
// ******************************************************************
  reg [NUM_SHIFTS -1    : 0]  shift_count;
  reg [DATA_IN_WIDTH -1 : 0]  serial;
// ******************************************************************

  assign OUT_VALID = |shift_count;
  assign READY = !(OUT_VALID);

  assign DATA_OUT = serial [DATA_OUT_WIDTH-1:0];

  always @(posedge CLK)
  begin: SHIFTER_COUNT
    if (RESET)
      shift_count <= 0;
    else
      shift_count <= {shift_count[NUM_SHIFTS-2:0], ENABLE};
  end

always @(posedge CLK)
begin: DATA_SHIFT
    if (RESET)
        serial <= 0;
    else begin
        if (ENABLE)
            serial <= DATA_IN;
        else if (OUT_VALID)
            serial <= {{DATA_OUT_WIDTH{1'b0}}, serial[DATA_IN_WIDTH-1:DATA_OUT_WIDTH]};
    end
end

endmodule
