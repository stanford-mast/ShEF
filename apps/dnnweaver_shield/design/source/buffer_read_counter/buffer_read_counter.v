`include "common.vh"
module buffer_read_counter #(
  parameter integer NUM_PU = 1,
  parameter integer PU_LOOP_W = 20,
  parameter integer D_TYPE_W = 2,
  parameter integer RD_SIZE_W = 20
)
(
  input wire clk,
  input wire reset,

  // PU controller
  input wire buffer_read_req,
  output wire buffer_read_last,

  // Buffer Read
  output wire buffer_read_pop,
  input wire buffer_read_empty,

  // PU
  output reg  [PU_ID_W-1:0] pu_id,

  // Memory Controller
  output reg read_info_full,
  input wire rd_req,
  input wire [RD_SIZE_W-1:0]rd_req_size,
  input wire [PU_ID_W-1:0]rd_req_pu_id,
  input wire [D_TYPE_W-1:0]rd_req_d_type
);

  localparam integer PU_ID_W = `C_LOG_2(NUM_PU)+1;
  localparam integer RD_INFO_W = PU_ID_W + RD_SIZE_W;

  wire [PU_ID_W-1:0] _pu_id;

  wire read_info_push;
  wire read_info_pop;
  wire [RD_INFO_W-1:0] read_info_data_in;
  wire [RD_INFO_W-1:0] read_info_data_out;
  wire read_info_empty;

  wire [RD_SIZE_W-1:0] rvalid_default;
  wire rvalid_inc;
  wire [RD_SIZE_W-1:0] rvalid_min;
  wire [RD_SIZE_W-1:0] rvalid_max;
  wire next_read;
  wire [RD_SIZE_W-1:0] rvalid_count;

  wire _read_info_full;

  always @(posedge clk)
    if (reset)
      read_info_full <= 1'b0;
    else
      read_info_full <= _read_info_full;

  assign read_info_push = rd_req && rd_req_d_type == 1;
  assign read_info_data_in = {rd_req_pu_id, rd_req_size};

  assign read_info_pop = state == 0 ? !read_info_empty : rvalid_count == rvalid_max && rvalid_inc;
  assign {_pu_id, rvalid_max} = read_info_data_out;

  fifo #(
    .DATA_WIDTH               ( RD_INFO_W                ),
    .ADDR_WIDTH               ( 7                        )
  ) read_info_fifo (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .push                     ( read_info_push           ),  //input
    .pop                      ( read_info_pop            ),  //input
    .data_in                  ( read_info_data_in        ),  //input
    .data_out                 ( read_info_data_out       ),  //output
    .full                     ( _read_info_full          ),  //output
    .empty                    ( read_info_empty          ),  //output
    .fifo_count               (                          )   //output
    );

  assign rvalid_default = 0;
  assign rvalid_min = 0;
  assign buffer_read_pop = rvalid_inc && !(rvalid_count == rvalid_max);
  assign rvalid_inc = state == 1 && buffer_read_req && (!buffer_read_empty || next_read);
  counter #(
    .COUNT_WIDTH              ( RD_SIZE_W                )
  )
  rvalid_counter (
    .CLK                      ( clk                      ),  //input
    .RESET                    ( reset                    ),  //input
    .CLEAR                    ( 1'b0                     ),  //input
    .DEFAULT                  ( rvalid_default           ),  //input
    .INC                      ( rvalid_inc               ),  //input
    .DEC                      ( 1'b0                     ),  //input
    .MIN_COUNT                ( rvalid_min               ),  //input
    .MAX_COUNT                ( rvalid_max               ),  //input
    .OVERFLOW                 ( next_read                ),  //output
    .UNDERFLOW                (                          ),  //output
    .COUNT                    ( rvalid_count             )   //output
    );
  // ==================================================================

  reg state;
  reg next_state;

  always @(*)
  begin
    next_state = state;
    case (state)
      0: begin
        if (!read_info_empty)
          next_state = 1;
      end
      1:begin
        if (rvalid_count == rvalid_max && rvalid_inc && read_info_empty)
          next_state = 0;
      end
    endcase
  end

  always @(posedge clk)
    if (reset)
      state <= 0;
    else
      state <= next_state;

  assign buffer_read_last = state == 1 && next_read && _pu_id == NUM_PU-1;

  always @(posedge clk)
    pu_id <= _pu_id;



endmodule
