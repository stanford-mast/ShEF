//Mark Zhao
//7/10/20
//
//registers

module sdp_enreg
#(
  parameter integer WIDTH = 1
)(
  input  logic               clk,   // Clock input
  output logic [WIDTH-1:0] q,     // Data output
  input  logic [WIDTH-1:0] d,     // Data input
  input  logic               en     // Enable input
);
  always_ff @(posedge clk) begin
    if(en) begin
      q <= d;
    end
  end
endmodule : sdp_enreg

module sdp_enrstreg
#(
  parameter integer WIDTH = 1
)(
  input  logic             clk, // Clock input
  input  logic             rst_n, //reset
  output logic [WIDTH-1:0] q,     // Data output
  input  logic [WIDTH-1:0] d,     // Data input
  input  logic             en     // Enable input
);
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      q <= {WIDTH{1'b0}};  
    end
    else if(en) begin
      q <= d;
    end
  end
endmodule : sdp_enrstreg
