`include "common.vh"
module loopback_pu_controller #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer AXI_DATA_W       = 64
) (
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire                                         stream_read_ready,
  output wire                                         stream_read_req,
  input  wire  [ AXI_DATA_W           -1 : 0 ]        stream_read_data,

  input  wire                                         buffer_read_ready,
  output wire                                         buffer_read_req,
  input  wire  [ AXI_DATA_W           -1 : 0 ]        buffer_read_data,

  input  wire                                         stream_write_ready,
  output wire                                         stream_write_req,
  output wire  [ AXI_DATA_W           -1 : 0 ]        stream_write_data
);
// ******************************************************************
// Regs and Wires
// ******************************************************************
  reg stream_read_req_d;
  reg stream_read_req_dd;
  reg [AXI_DATA_W-1:0] stream_read_data_d;
// ******************************************************************

// ==================================================================
  always @(posedge clk)
  begin
    if (reset) begin
      stream_read_req_d <= 1'b0;
      stream_read_data_d <= 'b0;
    end else begin
      stream_read_req_d <= stream_read_req;
      stream_read_data_d <= stream_read_data;
    end
  end

  // loop back stream reads
  assign stream_read_req = stream_read_ready && stream_write_ready;
  assign stream_write_req = stream_read_req_d;
  assign stream_write_data = stream_read_data;

  // discard buffer reads
  assign buffer_read_req = buffer_read_ready;
// ==================================================================

endmodule
