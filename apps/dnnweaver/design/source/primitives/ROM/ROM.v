`timescale 1ns/1ps
module ROM #(
// Parameters
  parameter   DATA_WIDTH          = 16,
  parameter   INIT                = "weight.mif",
  parameter   ADDR_WIDTH          = 6,
  parameter   TYPE                = "DISTRIBUTED",
  parameter   INITIALIZE_FIFO     = "yes"
) (
// Port Declarations
  input  wire                         clk,
  input  wire                         reset,
  input  wire  [ADDR_WIDTH-1:0]       address,
  input  wire                         enable,
  output reg   [DATA_WIDTH-1:0]       data_out
);

// ******************************************************************
// Internal variables
// ******************************************************************
  localparam   ROM_DEPTH          = 1 << ADDR_WIDTH;
  (* ram_style = TYPE *)
  reg     [DATA_WIDTH-1:0]        mem[0:ROM_DEPTH-1];     //Memory
// ******************************************************************
// Read Logic
// ******************************************************************

  always @ (posedge clk)
  begin : READ_BLK
    if(!reset) begin
      if (enable)
        data_out <= mem[address];
      else
        data_out <= data_out;
    end else begin
      data_out <= 0;
    end
  end

// ******************************************************************
// Initialization
// ******************************************************************

  initial begin
    `ifdef VIVADO_SIM
      $readmemb("/home/centos/src/project_data/free/apps/dnnweaver/design/include/norm_lut.vh", mem);
    `else
      $readmemb("norm_lut.dat", mem);
    `endif
  end


endmodule
