module buffer_read_counter_tb;

  parameter integer NUM_PU = 1;
  parameter integer D_TYPE_W = 2;
  parameter integer RD_SIZE_W = 20;
  parameter integer PU_ID_W = `C_LOG_2(NUM_PU)+1;

  wire clk;
  wire reset;

  wire buffer_read_req;
  wire buffer_read_last;

  wire buffer_read_pop;
  wire buffer_read_empty;

  wire [PU_ID_W-1:0] pu_id;

  wire rd_req;
  wire [RD_SIZE_W-1:0]rd_req_size;
  wire [PU_ID_W-1:0]rd_req_pu_id;
  wire [D_TYPE_W-1:0]rd_req_d_type;

  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );

  initial
  begin
    $dumpfile("buffer_read_counter_tb.vcd");
    $dumpvars(0,buffer_read_counter_tb);
  end

  initial begin
    driver.status.start;
    wait (reset == 0);
    repeat (10) begin
      driver.send_random_read_req;
    end
  end

  initial begin
    wait (reset == 0);
    repeat (10) begin
      driver.send_buffer_read_req;
    end
    #10000 $finish;
  end

buffer_read_counter_tb_driver #(
    .NUM_PU                   ( NUM_PU                   ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .RD_SIZE_W                ( RD_SIZE_W                )
)
driver
(
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .buffer_read_req          ( buffer_read_req          ),
    .buffer_read_last         ( buffer_read_last         ),
    .buffer_read_pop          ( buffer_read_pop          ),
    .buffer_read_empty        ( buffer_read_empty        ),
    .pu_id                    ( pu_id                    ),
    .rd_req                   ( rd_req                   ),
    .rd_req_size              ( rd_req_size              ),
    .rd_req_pu_id             ( rd_req_pu_id             ),
    .rd_req_d_type            ( rd_req_d_type            )
);

buffer_read_counter #(
    .NUM_PU                   ( NUM_PU                   ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .RD_SIZE_W                ( RD_SIZE_W                )
)
u_buffer_counter
(
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .buffer_read_req          ( buffer_read_req          ),
    .buffer_read_last         ( buffer_read_last         ),
    .buffer_read_pop          ( buffer_read_pop          ),
    .buffer_read_empty        ( buffer_read_empty        ),
    .pu_id                    ( pu_id                    ),
    .rd_req                   ( rd_req                   ),
    .rd_req_size              ( rd_req_size              ),
    .rd_req_pu_id             ( rd_req_pu_id             ),
    .rd_req_d_type            ( rd_req_d_type            )
);

endmodule
