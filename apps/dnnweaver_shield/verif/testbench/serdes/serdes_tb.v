module serdes_tb;
// ******************************************************************
// Parameters
// ******************************************************************
  parameter integer IN_COUNT        = 10;
  parameter integer OUT_COUNT       = 10;
  parameter integer OP_WIDTH        = 16;
  parameter integer IN_WIDTH        = IN_COUNT * OP_WIDTH;
  parameter integer OUT_WIDTH       = OUT_COUNT * OP_WIDTH;
  parameter integer COUNT_W         = `C_LOG_2(IN_COUNT);
// ******************************************************************
// IO
// ******************************************************************
  wire                                         clk;
  wire                                         reset;
  wire  [ COUNT_W              -1 : 0 ]        count;
  wire                                         s_write_req;
  wire                                         s_write_flush;
  wire                                         s_write_ready;
  wire  [ IN_WIDTH             -1 : 0 ]        s_write_data;
  wire                                         m_write_req;
  wire                                         m_write_ready;
  wire  [ OUT_WIDTH            -1 : 0 ]        m_write_data;

// ==================================================================
  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );
// ==================================================================

initial begin
  @(negedge clk);
  $display("serdes test");
  driver.send_random_data(9);
  wait (driver.got_data_count == driver.valid_data_count);
  driver.send_random_data(7);
  wait (driver.got_data_count == driver.valid_data_count);
  driver.send_random_data(10);
  wait (driver.got_data_count == driver.valid_data_count);
  driver.send_random_data(9);
  wait (driver.got_data_count == driver.valid_data_count);
  driver.send_random_data(7);
  wait (driver.got_data_count == driver.valid_data_count);
  #1000 $finish;
end

initial begin
  $dumpfile("serdes_tb.vcd");
  $dumpvars(0,serdes_tb);
end

  serdes #(
    .IN_COUNT                 ( IN_COUNT                 ),
    .OUT_COUNT                ( OUT_COUNT                ),
    .OP_WIDTH                 ( OP_WIDTH                 )
  ) u_serdes (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .count                    ( count                    ),
    .s_write_ready            ( s_write_ready            ),
    .s_write_flush            ( s_write_flush            ),
    .s_write_req              ( s_write_req              ),
    .s_write_data             ( s_write_data             ),
    .m_write_ready            ( m_write_ready            ),
    .m_write_req              ( m_write_req              ),
    .m_write_data             ( m_write_data             )
  );

  serdes_tb_driver #(
    .IN_COUNT                 ( IN_COUNT                 ),
    .OUT_COUNT                ( OUT_COUNT                ),
    .OP_WIDTH                 ( OP_WIDTH                 )
  ) driver (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .count                    ( count                    ),
    .s_write_ready            ( s_write_ready            ),
    .s_write_flush            ( s_write_flush            ),
    .s_write_req              ( s_write_req              ),
    .s_write_data             ( s_write_data             ),
    .m_write_ready            ( m_write_ready            ),
    .m_write_req              ( m_write_req              ),
    .m_write_data             ( m_write_data             )
  );

endmodule
