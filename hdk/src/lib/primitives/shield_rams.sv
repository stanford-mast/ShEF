//Mark Zhao
//7/10/20
//
//RAMs

`default_nettype none
`timescale 1ns/1ps

module shield_ram #(
  parameter integer DATA_WIDTH = 512,
  parameter integer ADDR_WIDTH = 8
)
(
  input  wire clk,

  input  wire [ADDR_WIDTH-1:0] wr_addr,
  input  wire                  wr_en,
  input  wire [DATA_WIDTH-1:0] wr_data,

  input  wire [ADDR_WIDTH-1:0] rd_addr,
  output reg  [DATA_WIDTH-1:0] rd_data
);
  localparam CACHE_RAM_DEPTH = 1 << ADDR_WIDTH;

  logic [DATA_WIDTH-1:0] mem [CACHE_RAM_DEPTH-1:0];

  always @(posedge clk) begin
    if(wr_en) begin
      mem[wr_addr] <= wr_data;
    end
    rd_data <= mem[rd_addr];
  end

  //Initialize to 0
  integer i;
  initial begin
    for (i = 0; i < CACHE_RAM_DEPTH; i = i + 1) begin
      mem[i] = 0;
    end
  end

endmodule: shield_ram

module shield_ram_byte_en #(
  parameter integer DATA_WIDTH = 512,
  parameter integer ADDR_WIDTH = 8,
  parameter integer ENABLE_WIDTH = 64
)
(
  input  wire clk,

  input  wire [ADDR_WIDTH-1:0]   wr_addr,
  input  wire                    wr_en,
  input  wire [DATA_WIDTH-1:0]   wr_data,
  input  wire [ENABLE_WIDTH-1:0] wr_byte_en,

  input  wire [ADDR_WIDTH-1:0] rd_addr,
  output reg  [DATA_WIDTH-1:0] rd_data
);
  localparam CACHE_RAM_DEPTH = 1 << ADDR_WIDTH;

  logic [DATA_WIDTH-1:0] mem [CACHE_RAM_DEPTH-1:0];

  integer i;
  always @(posedge clk) begin
    if(wr_en) begin
      for(i = 0; i < ENABLE_WIDTH; i++) begin
        if(wr_byte_en[i]) begin
          mem[wr_addr][i*8 +: 8] <= wr_data[i*8 +: 8];
        end
      end
    end
    rd_data <= mem[rd_addr];
  end

  //Initialize to 0
  integer i;
  initial begin
    for (i = 0; i < CACHE_RAM_DEPTH; i = i + 1) begin
      mem[i] = 0;
    end
  end

endmodule: shield_ram_byte_en


`default_nettype wire
