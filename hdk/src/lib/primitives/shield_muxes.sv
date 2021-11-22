//Mark Zhao
//7/10/20
//
//muxes

module shield_mux2
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
endmodule : shield_mux2

module shield_mux4
#(
  parameter integer WIDTH = 1
)(
  input  logic [WIDTH-1:0] in0,
  input  logic [WIDTH-1:0] in1,
  input  logic [WIDTH-1:0] in2,
  input  logic [WIDTH-1:0] in3,
  input  logic [1:0]       sel,
  output logic [WIDTH-1:0] out
);
  always_comb begin
    case(sel)
      2'd0: out = in0;
      2'd1: out = in1;
      2'd2: out = in2;
      2'd3: out = in3;
      default : out = {WIDTH{1'bx}};
    endcase
  end
endmodule : shield_mux4

module shield_muxp
#(
  parameter integer BUS_WIDTH = 512,
  parameter integer OUTPUT_WIDTH = 64,
  parameter integer SELECT_WIDTH = 3, //==log2(bus_width/output_width)
  parameter integer SELECT_COUNT = 8 //==bus_width/output_width
)(
  input  logic [BUS_WIDTH-1:0] in_bus,
  input  logic [SELECT_WIDTH-1:0] sel,
  output logic [OUTPUT_WIDTH-1:0] out
);

  logic [OUTPUT_WIDTH-1:0] map [SELECT_COUNT-1:0];
  genvar i;
  generate
    for(i = 0; i < SELECT_COUNT; i++) begin
      assign map[i] = in_bus[i*OUTPUT_WIDTH +: OUTPUT_WIDTH];
    end
  endgenerate

  //select to one hot
  logic [SELECT_COUNT-1:0] sel_onehot;
  assign sel_onehot= 1 << sel;

  //Mux
  integer j;
  always_comb begin
    out = 'x;
    for(j = 0; j < SELECT_COUNT; j++) begin
      if(sel_onehot[j] == 1'b1) out = map[j];
    end
  end

endmodule : shield_muxp
