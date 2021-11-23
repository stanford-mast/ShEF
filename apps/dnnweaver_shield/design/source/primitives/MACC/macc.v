`include "common.vh"
`timescale 1ns/1ps
/*
* supported operations:
  * MULTIPLY      : OP = 000 or 0
  * MULTIPLY-ACC  : OP = 010 or 2
  * MULTIPLY-ADD  : OP = 100 or 4
  * SQUARE        : OP = 001 or 1
  * SQUARE-ACC    : OP = 011 or 3
  * SQUARE-ADD    : OP = 101 or 5
*/
module macc #(
    parameter OP_0_WIDTH  = `PRECISION_OP,
    parameter OP_1_WIDTH  = `PRECISION_OP,
    parameter ACC_WIDTH   = `PRECISION_ACC,
    parameter OUT_WIDTH   = `PRECISION_OP,
    parameter TYPE = "FIXED_POINT",
    parameter FRAC_BITS = `PRECISION_FRAC,
    parameter INT_BITS = `PRECISION_OP - 1 - `PRECISION_FRAC
) (
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         enable,
  input  wire                                         clear,
  input  wire   [ OP_CODE_WIDTH        -1 : 0 ]       op_code,
  input  signed [ OP_0_WIDTH           -1 : 0 ]       op_0,
  input  signed [ OP_1_WIDTH           -1 : 0 ]       op_1,
  input  signed [ ACC_WIDTH            -1 : 0 ]       op_add,
  output signed [ OUT_WIDTH            -1 : 0 ]       out
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
    localparam integer OP_CODE_WIDTH = 3;
// ******************************************************************
// WIRES
// ******************************************************************
    reg  [OP_CODE_WIDTH-1:0] op_code_d;
    reg  [OP_CODE_WIDTH-1:0] op_code_dd;

    reg  signed [OP_0_WIDTH-1:0] op_0_d;
    reg  signed [OP_1_WIDTH-1:0] op_1_d;
    reg  signed [ACC_WIDTH-1:0]  op_add_d;
    reg  signed [ACC_WIDTH-1:0]  op_add_dd;
    reg  signed [ACC_WIDTH-1:0]  product;
    wire signed [ACC_WIDTH-1:0]  data_ADD;
    reg  signed [OUT_WIDTH-1:0]  out_reg;

    wire [255:0] GND = 256'd0;
    reg enable_d;
    reg enable_dd;
    reg clear_d;
    reg clear_dd;
// ******************************************************************
// LOGIC
// ******************************************************************

generate
if (TYPE == "FLOATING_POINT") begin
    float_point
    float_point_i (
        .A_data     ( op_0      ),
        .A_valid    ( 1'b1      ),
        .B_data     ( op_1      ),
        .B_valid    ( 1'b1      ),
        .C          ( op_add    ),
        .C_valid    ( 1'b1      ),
        .Out_data   ( out       ),
        .Out_valid  (           ),
        .aclk       ( clk       ),
        .aclken     ( reset     )
    );

end else begin
// TIER 4 Regs
    always @(posedge clk)
    begin
        if (reset) begin
            op_0_d <= 0;
            op_1_d <= 0;
            op_add_d <= 0;
            op_code_d <= 0;
        end else begin
            op_code_d <= op_code;
            if (enable) begin
                op_0_d <= op_0;
                op_1_d <= (op_code[0])? op_0 : op_1;
                op_add_d <= op_add;
            end else begin
                op_0_d <= 0;
                op_1_d <= 0;
                op_add_d <= 0;
            end
        end
    end

    always@(posedge clk)
      enable_d <= enable;
    always@(posedge clk)
      clear_d <= clear;

    // TIER 5 Regs
    always @(posedge clk)
    begin
        if (reset) begin
            product <= 0;
            op_code_dd <= 0;
        end else begin
            if (enable_d) begin
                product <= op_0_d * op_1_d;
            end else begin
                product <= 0;
            end
            op_code_dd <= op_code_d;
        end
    end

    always@(posedge clk)
      enable_dd <= enable_d;
    always@(posedge clk)
      clear_dd <= clear_d;

    always @(posedge clk)
      op_add_dd <= op_add_d;

    //--// TIER 6 Regs
    assign data_ADD = (op_code_dd[2:1] == 2'd0) ? GND[ACC_WIDTH-1:0] :
      (op_code_dd[1] == 2'd1) ? out_reg : op_add_dd;
    always @(posedge clk)
    begin
        if (reset || clear_dd) begin
            out_reg <= 0;
        end
        else if (enable_dd) begin
            out_reg <= product + (data_ADD <<< FRAC_BITS);
        end
    end

    assign out = out_reg >>> FRAC_BITS;

    //assign data_ADD = !mul ? (accumulate ? out : op_add) : GND[ACC_WIDTH-1:0];
    //always @(posedge clk)
    //begin
    //    if (!reset) begin
    //        if (enable)
    //            out <= op_0 * op_1 + data_ADD;
    //        else
    //            out <= out;
    //    end else begin
    //        out <= 0;
    //    end
    //end
end
endgenerate

`ifdef TOPLEVEL_macc
  initial
  begin
    $dumpfile("macc.vcd");
    $dumpvars(0,macc);
  end
`endif

endmodule
