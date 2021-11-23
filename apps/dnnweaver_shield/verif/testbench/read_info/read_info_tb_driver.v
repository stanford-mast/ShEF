module read_info_driver #(
  parameter integer NUM_PU = 1,
  parameter integer D_TYPE_W = 2,
  parameter integer RD_SIZE_W = 20
)
(
  input  wire clk,
  input  wire reset,
  input  wire inbuf_pop,
  input  wire read_info_full,
  output reg  inbuf_empty,
  output reg  rd_req,
  output reg  [RD_SIZE_W-1:0]rd_req_size,
  output reg  [PU_ID_W-1:0]rd_req_pu_id,
  output reg  [D_TYPE_W-1:0]rd_req_d_type,
  input  wire [PU_ID_W-1:0] pu_id,
  input  wire               stream_push,
  input  wire               buffer_push,
  output reg                stream_full,
  output reg                buffer_full,
  input  wire [D_TYPE_W-1:0] d_type
);

localparam integer PU_ID_W = `C_LOG_2(NUM_PU) + 1;

  integer d_0_count;
  integer d_1_count;


  test_status #(
    .PREFIX                   ( "RD_INFO"                     ),
    .TIMEOUT                  ( 1000000                  )
  ) status (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .pass                     ( pass                     ),
    .fail                     ( fail                     )
  );

  integer read_count;
  integer read_info_pop_count;
  integer d0_pop_count;
  integer d1_pop_count;
  integer rd_pointer;
  integer wr_pointer;

  initial begin
    rd_req = 0;
    rd_req_size = 0;
    rd_req_pu_id = 0;
    rd_req_d_type = 0;
    d_0_count = 0;
    d_1_count = 0;
    rd_pointer = 0;
    read_info_pop_count = 0;
    d0_pop_count = 0;
    d1_pop_count = 0;
    read_count = 0;
  end

  task send_random_read_req;
    begin
      @(negedge clk);
      repeat (1000)
      begin
        if (read_info_full)begin
          wait (!read_info_full);
          @(negedge clk);
        end

        rd_req = 1;
        rd_req_size = $urandom%10 +1;
        rd_req_pu_id = $urandom % NUM_PU;
        rd_req_d_type = $urandom % 2;
        //rd_req_d_type = 0;
        read_count = read_count + rd_req_size;
        //$display ("Requesting %d reads of type %d", rd_req_size, rd_req_d_type);
        if (rd_req_d_type == 0)
          d_0_count = d_0_count + rd_req_size;
        else
          d_1_count = d_1_count + rd_req_size;
        @(negedge clk);
        rd_req = 0;
      end
      wait (read_info_pop_count == read_count);
      repeat (100) @(negedge clk);
      if (d0_pop_count == d_0_count && d1_pop_count == d_1_count)
        status.test_pass;
      else
        status.test_fail;
    end
  endtask

  always @(posedge clk)
    if (reset)
      inbuf_empty <= 0;
    else
      inbuf_empty <= (read_count == read_info_pop_count) || ($random%2 == 0);

  always @(posedge clk)
    if (reset)
      read_info_pop_count <= 0;
    else
      read_info_pop_count <= read_info_pop_count + inbuf_pop;

  always @(posedge clk)
    if (reset)
      d0_pop_count <= 0;
    else
      d0_pop_count <= d0_pop_count + (stream_push && !stream_full);

  always @(posedge clk)
    if (reset)
      d1_pop_count <= 0;
    else
      d1_pop_count <= d1_pop_count + (buffer_push && !buffer_full);

  always @(posedge clk)
    buffer_full <= $random;
  always @(posedge clk)
    stream_full <= $random;

endmodule
