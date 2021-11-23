`timescale 1ns/1ps
`include "common.vh"
module weight_buffer
#(  // PARAMETERS
  parameter integer RD_WIDTH      = 16,
  parameter integer WR_WIDTH      = 64,
  parameter integer RD_ADDR_WIDTH = 7,
  parameter integer WR_ADDR_WIDTH = 5
)
(   // PORTS
  input  wire                           clk,
  input  wire                           reset,

  input  wire                           read_req,
  output reg  [ RD_WIDTH      -1 : 0 ]  read_data,
  input  wire [ RD_ADDR_WIDTH -1 : 0 ]  read_addr,

  input  wire                           write_req,
  input  wire [ WR_WIDTH      -1 : 0 ]  write_data,
  input  wire [ WR_ADDR_WIDTH -1 : 0 ]  write_addr
);

// ******************************************************************
// Local params
// ******************************************************************
  localparam integer MEM_WIDTH      = WR_WIDTH;
  localparam integer MEM_ADDR_WIDTH = WR_ADDR_WIDTH;
  localparam integer MUX_SEL_WIDTH  = `C_LOG_2(WR_WIDTH/RD_WIDTH);
// ******************************************************************

// ******************************************************************
// Wire and Regs
// ******************************************************************
  reg  [ MEM_WIDTH      -1 : 0 ] mem [ 0 : (1<<WR_ADDR_WIDTH) - 1 ];
  reg  [ MEM_WIDTH      -1 : 0 ] mem_out;
  reg  [ MUX_SEL_WIDTH  -1 : 0 ] mux_sel, mux_sel_d;

  reg  [ WR_ADDR_WIDTH  -1 : 0 ] mem_addr;

  reg                            read_req_d, read_req_dd;

  wire [ 1024           -1 : 0 ] GND = 1024'd0;

// ******************************************************************

  integer ii, jj;
  reg [WR_WIDTH-1:0] tmp;
  initial begin
    for (ii=0; ii<1<<WR_ADDR_WIDTH; ii=ii+1)
    begin
      tmp = 0;
      for (jj=1<<(RD_ADDR_WIDTH-WR_ADDR_WIDTH); jj > -1; jj=jj-1)
      begin
        tmp = (tmp << RD_WIDTH) + (ii*(1<<(RD_ADDR_WIDTH - WR_ADDR_WIDTH)) + jj);
        mem [ii] = tmp;
      end
    end
  end

  always @(posedge clk)
  begin: MEM_ADDR_GEN
    if (reset)
      {mem_addr, mux_sel} <= 'b0;
    else if (read_req)
      {mem_addr, mux_sel} <= read_addr;
  end

  always @(posedge clk)
    read_req_d <= read_req;
  always @(posedge clk)
    read_req_dd <= read_req_d;

  always @(posedge clk)
  begin: MEM_READ
    if (reset)
      mem_out <= GND[MEM_WIDTH-1:0];
    else if (read_req_d)
      mem_out <= mem[mem_addr];
  end

  always @(posedge clk)
    mux_sel_d <= mux_sel;

  always @(posedge clk)
  begin: MUX_READ
    read_data <= mem_out[mux_sel_d*RD_WIDTH+:RD_WIDTH];
  end

  always @(posedge clk)
  begin: WRITE
    if (write_req)
    begin
      mem[write_addr] <= write_data;
    end
  end

endmodule
