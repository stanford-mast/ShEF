`include "common.vh"
module serdes_tb_driver #(
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_COUNT        = 10,
  parameter integer OUT_COUNT       = 10,
  parameter integer OP_WIDTH        = 16,
  parameter integer IN_WIDTH        = IN_COUNT * OP_WIDTH,
  parameter integer OUT_WIDTH       = OUT_COUNT * OP_WIDTH,
  parameter integer COUNT_W         = `C_LOG_2(IN_COUNT)
)
(
// ******************************************************************
// IO
// ******************************************************************
  input  wire                                         clk,
  input  wire                                         reset,
  output reg   [ COUNT_W              -1 : 0 ]        count,
  output reg                                          s_write_flush,
  output reg                                          s_write_req,
  input  wire                                         s_write_ready,
  output reg   [ IN_WIDTH             -1 : 0 ]        s_write_data,
  input  wire                                         m_write_req,
  output reg                                          m_write_ready,
  input  wire  [ OUT_WIDTH            -1 : 0 ]        m_write_data
);


reg [OP_WIDTH-1:0] expected_output [0:1<<10-1];

initial begin
  count = 1;
  s_write_data = 0;
  s_write_req = 0;
  s_write_flush = 0;
  m_write_ready = 1;
end

task send_random_data;
  input integer valid_count;
  integer ii;
  begin
    $display ("Sending data with valid count  = %d", valid_count);
    repeat ($urandom%20) begin
      @(negedge clk);
      s_write_req = 1;
      count = valid_count;
      for (ii=0; ii<IN_WIDTH; ii=ii+1)
      begin
        s_write_data[ii*OP_WIDTH+:OP_WIDTH] = $random;
      end
    end
    s_write_req = 0;
    s_write_flush = 1;
    @(negedge clk);
    s_write_flush = 0;
  end
endtask

always @(posedge clk)
  if (s_write_req)
    get_expected_data;

integer valid_data_count = 0;
task get_expected_data;
  integer ii;
  begin
    for (ii=0; ii<count; ii=ii+1)
    begin
      expected_output[valid_data_count] = s_write_data[ii*OP_WIDTH+:OP_WIDTH];
      $write ("%d ", expected_output[valid_data_count]);
      valid_data_count = (valid_data_count + 1)%1024;
    end
    $display;
  end
endtask

always @(posedge clk)
  if (m_write_req)
    check_expected_data;

integer got_data_count = 0;
task check_expected_data;
  integer ii;
  begin
    $display ("Checking received data");
    for (ii=0; ii<IN_COUNT && (got_data_count < valid_data_count); ii=ii+1)
    begin
      if (m_write_data[ii*OP_WIDTH+:OP_WIDTH] != expected_output[got_data_count])
      begin
        $display ("ERROR");
        $display ("Expected: %d", expected_output[got_data_count]);
        $display ("Got: %d", m_write_data[ii*OP_WIDTH+:OP_WIDTH]);
      end

      if (expected_output[got_data_count] !== 'bx)
        got_data_count = (got_data_count+1)%1024;
    end
  end
endtask

endmodule
