module weight_buffer_tb_driver
#(  // PARAMETERS
  parameter integer RD_WIDTH      = 16,
  parameter integer WR_WIDTH      = 64,
  parameter integer RD_ADDR_WIDTH = 7,
  parameter integer WR_ADDR_WIDTH = 5
)
(   // PORTS
  input  wire                           clk,
  input  wire                           reset,

  output reg                            read_req,
  input  wire [ RD_WIDTH      -1 : 0 ]  read_data,
  output reg  [ RD_ADDR_WIDTH -1 : 0 ]  read_addr,

  output reg                            write_req,
  output reg  [ WR_WIDTH      -1 : 0 ]  write_data,
  output reg  [ WR_ADDR_WIDTH -1 : 0 ]  write_addr
);


// ******************************************************************
// Test Status module
// ******************************************************************
  test_status #(
    .PREFIX   ( "weight_buffer" ),
    .TIMEOUT  ( 100000          )
  ) status (
    .clk      ( clk             ),
    .reset    ( reset           ),
    .pass     ( pass            ),
    .fail     ( fail            )
  );
// ******************************************************************

initial begin
  status.start;
  read_req = 0;
  write_req = 0;
  write_addr = 0;
  read_addr = 0;
  @(negedge clk);
  @(negedge clk);
  @(negedge clk);
  @(negedge clk);
  repeat (100) begin
    @(negedge clk);
    random_read;
  end
  repeat (100) begin
    @(negedge clk);
    random_write_read;
  end
  status.test_pass;
end

task random_read;
  begin
    read_addr = $random;
    read_req = 1'b1;
    $display ("Reading from address: %d", read_addr);
    @(negedge clk);
    read_req = 1'b0;
    @(negedge clk);
    @(negedge clk);
    $display ("Got data: %d", read_data);
    if (read_data != read_addr)
      status.test_fail;
  end
endtask

task random_write_read;
  integer addr;
  begin
    addr = $random;
    write_addr = addr;
    write_req = 1'b1;
    write_data = 3;
    $display ("Writing to address: %d", write_addr);
    @(negedge clk);
    write_req = 1'b0;
    read_addr = addr<<2;
    read_req = 1'b1;
    $display ("Reading from address: %d", read_addr);
    @(negedge clk);
    read_req = 1'b0;
    @(negedge clk);
    @(negedge clk);
    $display ("Got data: %d", read_data);
  end
endtask

endmodule
