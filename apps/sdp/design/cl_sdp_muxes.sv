module sdp_mux2
#(
  parameter integer WIDTH = 1
)(
  input  logic [WIDTH-1:0] in0,
  input  logic [WIDTH-1:0] in1,
  input  logic             sel,
  output logic [WIDTH-1:0] out
);
  always_comb begin
    case(sel)
      1'b0: out = in0;
      1'b1: out = in1;
      default : out = {WIDTH{1'bx}};
    endcase
  end
endmodule : sdp_mux2
