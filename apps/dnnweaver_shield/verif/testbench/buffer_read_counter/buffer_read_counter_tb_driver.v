module buffer_read_counter_tb_driver #(
  parameter integer NUM_PU = 1,
  parameter integer D_TYPE_W = 2,
  parameter integer RD_SIZE_W = 20
)
(
  input wire clk,
  input wire reset,

  // PU controller
  output reg buffer_read_req,
  input wire buffer_read_last,

  // Buffer Read
  input wire buffer_read_pop,
  output reg buffer_read_empty,

  // PU
  input wire [PU_ID_W-1:0] pu_id,

  // Memory Controller
  output reg  rd_req,
  output reg  [RD_SIZE_W-1:0]rd_req_size,
  output reg  [PU_ID_W-1:0]rd_req_pu_id,
  output reg  [D_TYPE_W-1:0]rd_req_d_type
);

  localparam integer PU_ID_W = `C_LOG_2(NUM_PU) + 1;

  integer buffer_read_count = 0;
  integer buffer_read_count_expected = 0;

  test_status #(
    .PREFIX                   ( "BUFFER_RD_COUNT"        ),
    .TIMEOUT                  ( 1000000                  )
  ) status (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .pass                     ( pass                     ),
    .fail                     ( fail                     )
  );

  initial begin
    rd_req = 0;
    rd_req_size = 0;
    rd_req_pu_id = 0;
    rd_req_d_type = 0;
  end

  task send_random_read_req;
    begin
      @(negedge clk);
      rd_req = 1;
      rd_req_size = $urandom%1000;
      rd_req_pu_id = $urandom % NUM_PU;
      rd_req_d_type = 1;
      @(negedge clk);
      rd_req = 0;
      if (rd_req_d_type)
      begin
        buffer_read_count_expected = buffer_read_count_expected + rd_req_size;
        wait (buffer_read_count_expected == buffer_read_count);
      end
    end
  endtask

  task send_buffer_read_req;
    begin
      @(negedge clk);
      buffer_read_req = 1;
      wait (buffer_read_last);
      @(posedge clk);
      buffer_read_req = 0;
    end
  endtask

  always @(posedge clk)
    buffer_read_empty <= $random;

  always @(posedge clk)
    if (!buffer_read_empty && buffer_read_pop)
      buffer_read_count <= buffer_read_count + 1;

endmodule
