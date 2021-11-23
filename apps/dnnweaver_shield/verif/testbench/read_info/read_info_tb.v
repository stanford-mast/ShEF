module read_info_tb;

  parameter integer NUM_PU = 1;
  parameter integer D_TYPE_W = 2;
  parameter integer RD_SIZE_W = 20;
  parameter integer PU_ID_W = `C_LOG_2(NUM_PU)+1;

  wire clk;
  wire reset;
  wire inbuf_pop;
  wire inbuf_empty;
  wire rd_req;
  wire [RD_SIZE_W-1:0]rd_req_size;
  wire [PU_ID_W-1:0]rd_req_pu_id;
  wire [D_TYPE_W-1:0]rd_req_d_type;
  wire [PU_ID_W-1:0] pu_id;
  wire [D_TYPE_W-1:0] d_type;

  wire stream_push;
  wire buffer_push;

  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );

  initial
  begin
    $dumpfile("read_info_tb.vcd");
    $dumpvars(0,read_info_tb);
  end

  initial begin
    driver.status.start;
    wait (reset == 0);
    driver.send_random_read_req;
    #10000 $finish;
  end

read_info_driver #(
    .NUM_PU                   ( NUM_PU                   ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .RD_SIZE_W                ( RD_SIZE_W                )
)
driver
(
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .read_info_full           ( read_info_full           ),
    .inbuf_pop                ( inbuf_pop                ),
    .inbuf_empty              ( inbuf_empty              ),
    .rd_req                   ( rd_req                   ),
    .rd_req_size              ( rd_req_size              ),
    .rd_req_pu_id             ( rd_req_pu_id             ),
    .rd_req_d_type            ( rd_req_d_type            ),
    .stream_push              ( stream_push              ),
    .buffer_push              ( buffer_push              ),
    .stream_full              ( stream_full              ),
    .buffer_full              ( buffer_full              ),
    .pu_id                    ( pu_id                    ),
    .d_type                   ( d_type                   )
);

read_info #(
    .NUM_PU                   ( NUM_PU                   ),
    .D_TYPE_W                 ( D_TYPE_W                 ),
    .RD_SIZE_W                ( RD_SIZE_W                )
)
u_read_info
(
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .read_info_full           ( read_info_full           ),
    .inbuf_pop                ( inbuf_pop                ),
    .inbuf_empty              ( inbuf_empty              ),
    .rd_req                   ( rd_req                   ),
    .rd_req_size              ( rd_req_size              ),
    .rd_req_pu_id             ( rd_req_pu_id             ),
    .rd_req_d_type            ( rd_req_d_type            ),
    .stream_push              ( stream_push              ),
    .buffer_push              ( buffer_push              ),
    .stream_full              ( stream_full              ),
    .buffer_full              ( buffer_full              ),
    .pu_id                    ( pu_id                    ),
    .d_type                   ( d_type                   )
);

endmodule
