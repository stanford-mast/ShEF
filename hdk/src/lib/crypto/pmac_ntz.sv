// Combinational logic for ntz calculation - use when timing isn;'t a big deal

module pmac_ntz(
  input [15:0] index,
  output logic [3:0] ntz
);

  logic [7:0] half_8;
  logic [3:0] half_4;
  logic [1:0] half_2;

  assign ntz[3] = (index[7:0] == 8'd0); //all zeros in lower byte?
  assign half_8 = ntz[3] ? index[15:8] : index[7:0];
  assign ntz[2] = (half_8[3:0] == 4'd0); 
  assign half_4 = ntz[2] ? half_8[7:4] : half_8[3:0];
  assign ntz[1] = (half_4[1:0] == 2'd0);
  assign half_2 = ntz[1] ? half_4[3:2] : half_4[1:0];
  assign ntz[0] = (half_2[0] == 1'b0);


endmodule : pmac_ntz
