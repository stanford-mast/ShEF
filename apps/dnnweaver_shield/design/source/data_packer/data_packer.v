`include "common.vh"
module data_packer #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_WIDTH        = 64,
  parameter integer OUT_WIDTH       = 128,
  parameter integer OP_WIDTH        = 16
)
(
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         s_write_req,
  output wire                                         s_write_ready,
  input  wire  [ IN_WIDTH             -1 : 0 ]        s_write_data,
  output wire                                         m_write_req,
  input  wire                                         m_write_ready,
  output wire  [ OUT_WIDTH            -1 : 0 ]        m_write_data
);

localparam integer OUT_NUM_DATA = ceil_a_by_b(OUT_WIDTH, IN_WIDTH);
localparam integer DATA_COUNT_W = `C_LOG_2(OUT_NUM_DATA);

assign s_write_ready = m_write_ready;

genvar g;
generate
  if (OUT_NUM_DATA == 1)
  begin
    assign m_write_data = s_write_data;
    assign m_write_req = s_write_req;
  end
  else begin
    reg [DATA_COUNT_W-1:0] dcount;
    reg [DATA_COUNT_W-1:0] dcount_d;

    always @(posedge clk)
      if (reset)
        dcount_d <= 0;
      else
        dcount_d <= dcount;

    always @(posedge clk)
    begin
      if (reset)
        dcount <= 0;
      else if (s_write_req)
      begin
        if (dcount == OUT_NUM_DATA-1)
          dcount <= 0;
        else
          dcount <= dcount + 1'b1;
      end
    end

    reg [OUT_WIDTH-1:0] data;
    always @(posedge clk)
      if (reset)
        data <= 'b0;
      else if (s_write_req)
        data <= {s_write_data, data} >> IN_WIDTH;

    wire ready;
    reg ready_d;
    assign ready = ((dcount_d == OUT_NUM_DATA-1) && (dcount == 0));
    always @(posedge clk)
      if (reset) ready_d <= 0;
      else ready_d <= ready;

    assign m_write_req = ready;
    assign m_write_data = data;

  end
endgenerate

endmodule
