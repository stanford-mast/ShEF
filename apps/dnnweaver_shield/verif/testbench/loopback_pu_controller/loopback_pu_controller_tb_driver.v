`timescale 1ns/1ps
`include "common.vh"
module loopback_pu_controller_tb_driver
#( // INPUT PARAMETERS
  parameter integer NUM_PE            = 4,
  parameter integer NUM_PU            = 1,
  parameter integer ADDR_W            = 1,
  parameter integer BASE_ADDR_W       = ADDR_W,
  parameter integer OFFSET_ADDR_W     = ADDR_W,
  parameter integer RD_LOOP_W         = 10,
  parameter integer TX_SIZE_WIDTH     = 20,
  parameter integer D_TYPE_W          = 1,
  parameter integer ROM_ADDR_W        = 1
)( // PORTS
  input  wire                           clk,
  input  wire                           reset,
  output reg                            start,
  input  wire                           done,
  input  wire                           rd_req,
  input  wire                           rd_ready,
  output wire [ TX_SIZE_WIDTH  -1 : 0 ] rd_req_size,
  output wire [ ADDR_W         -1 : 0 ] rd_addr,
  input  wire                           wr_req,
  input  wire                           wr_done,
  input  wire [TX_SIZE_WIDTH-1:0] wr_req_size,
  output wire [ ADDR_W         -1 : 0 ] wr_addr,
  output wire                           wr_flush
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
localparam integer STATE_W  = 2;
localparam integer ROM_WIDTH = BASE_ADDR_W + OFFSET_ADDR_W + TX_SIZE_WIDTH +
  RD_LOOP_W + D_TYPE_W;
localparam integer ROM_DEPTH = 1<<ROM_ADDR_W;
// ******************************************************************
// WIRES
// ******************************************************************
genvar i;
wire [ 1024                 -1 : 0 ]        GND;
reg [TX_SIZE_WIDTH-1:0] wr_req_size_d;
// ******************************************************************
// Connections
// ******************************************************************
assign GND = 1024'd0;
// ******************************************************************
// INSTANTIATIONS
// ******************************************************************
test_status #(
  .PREFIX                   ( "LOOPBACK"                ),
  .TIMEOUT                  ( 100000                    )
) status (
  .clk                      ( clk                      ),
  .reset                    ( reset                    ),
  .pass                     ( pass                     ),
  .fail                     ( fail                     )
);
initial begin
  start = 0;
end

task send_start;
  begin
    curr_idx = 0;
    wait (!reset);
    @(negedge clk);
    start = 1;
    @(negedge clk);
    start = 0;
  end
endtask

integer mem_cfg_idx_max = 0;
integer curr_idx = 0;
integer curr_rd_count = 0;
integer curr_offset = 0;
reg [ROM_WIDTH-1:0] mem_cfg_rom [0:1023];

task check_rd_req;
  reg [D_TYPE_W-1:0] _read_type;
  reg [BASE_ADDR_W-1:0] _read_base_addr;
  reg [OFFSET_ADDR_W-1:0] _read_offset_addr;
  reg [TX_SIZE_WIDTH  -1 : 0 ] _rd_req_size;
  reg [RD_LOOP_W-1:0] _read_loop_max;
  integer expected_address;
  begin
      {_read_type,
      _read_base_addr,
      _read_offset_addr,
      _rd_req_size,
      _read_loop_max} = mem_cfg_rom[curr_idx];
    expected_address = _read_base_addr + curr_offset;
    //$display ("CFG read IDX = %d", curr_idx);
    //$display ("Read request for address %h", rd_addr);
    if (expected_address !== rd_addr)
    begin
      //$error ("Address does not match expected");
      //$display("Expected %h, Got %h", expected_address, rd_addr);
      //status.test_fail;
    end
    if (curr_rd_count == _read_loop_max)
    begin
      curr_offset = 0;
      curr_rd_count = 0;
      curr_idx = curr_idx + 1;
    end
    else
    begin
      curr_offset = curr_offset + _read_offset_addr;
      curr_rd_count = curr_rd_count + 1;
    end
  end
endtask

always @(posedge clk)
begin
  if (rd_req)
  begin
    //$display ("Got Read request of size %d", rd_req_size);
  end
end

always @(posedge clk)
  if (wr_req)
    wr_req_size_d <= wr_req_size;

//always @(posedge clk)
  //if (wr_done)
    //$display ("Finished %d writes", wr_req_size_d);

always @(posedge clk)
  if (rd_req)
    check_rd_req;

endmodule
