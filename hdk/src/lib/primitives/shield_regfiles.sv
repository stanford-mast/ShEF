//Mark Zhao
//7/10/20
//
//reg files

module shield_resetregfile
#(
  parameter integer DATA_WIDTH = 1,
  parameter integer ADDR_WIDTH = 8
)(
  input  logic                  clk,   // Clock input
  input  logic                  rst_n, // reset

  //Combinational read port
  input  logic [ADDR_WIDTH-1:0] read_addr,
  output logic [DATA_WIDTH-1:0] read_data,

  //Write port (sampled on posedge clk)
  input  logic                  write_en,
  input  logic [ADDR_WIDTH-1:0] write_addr,
  input  logic [DATA_WIDTH-1:0] write_data
);
  localparam REGFILE_DEPTH = 1 << ADDR_WIDTH;

  logic [DATA_WIDTH-1:0] regfile [REGFILE_DEPTH-1:0];

  //Combinational read
  assign read_data = regfile[read_addr];

  //Write on posedge
  genvar i;
  generate
    for(i = 0; i < REGFILE_DEPTH; i++) begin
      always_ff @(posedge clk) begin
        if(!rst_n) begin
          regfile[i] <= 0;
        end
        else begin
          if(write_en && (i == write_addr)) begin
            regfile[i] <= write_data;
          end
        end
      end
    end
  endgenerate 

endmodule : shield_resetregfile
