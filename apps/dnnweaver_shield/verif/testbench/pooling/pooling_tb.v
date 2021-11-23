`timescale 1ns/1ps
module pooling_tb;

// ******************************************************************
// local parameters
// ******************************************************************
    localparam DATA_WIDTH       = 16;
    localparam NUM_PE           = 4;
    localparam DATA_IN_WIDTH    = DATA_WIDTH * NUM_PE;
    localparam DATA_OUT_WIDTH   = DATA_WIDTH * NUM_PE;
    localparam CFG_WIDTH        = 3;
    localparam CTRL_WIDTH       = 6;
// ******************************************************************
// IO
// ******************************************************************
  wire                                    clk;
  wire                                    reset;
  wire                                    enable;
  wire                                    ready;
  wire [ CFG_WIDTH        -1 : 0 ]        cfg;
  wire [ CTRL_WIDTH       -1 : 0 ]        ctrl;
  wire [ DATA_OUT_WIDTH   -1 : 0 ]        read_data;
  wire                                    read_req;
  wire                                    read_ready;
  wire [ DATA_IN_WIDTH    -1 : 0 ]        write_data;
  wire                                    write_req;
  wire                                    write_ready;

// ******************************************************************
// Common modules
//*******************************************************************

  clk_rst_driver
  clkgen (
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );

// ******************************************************************
// TB
//*******************************************************************

 initial
 begin
   $dumpfile("pooling_tb.vcd");
   $dumpvars(0,pooling_tb);
 end

 initial begin
   driver.status.start;
   wait(!reset);
   @(negedge clk);
   driver.initialize_input(24, 24);
   driver.print_input;
   driver.initialize_expected_output(3, 3, 2);
   driver.print_output;
   driver.send_inputs;
   wait (driver.read_count == driver.max_reads);
   driver.status.test_pass;
 end

 initial begin
   #10000 driver.status.test_fail;
 end

/////////////////////////////////////////////////
// Instantiating Pooling Module
/////////////////////////////////////////////////

  pooling #(
    // INPUT PARAMETERS
    .DATA_WIDTH               ( DATA_WIDTH               ),
    .NUM_PE                   ( NUM_PE                   ),
    .NUM_COMPARATOR           ( 1                        )
  ) pool_DUT (
    // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .ready                    ( ready                    ),
    .enable                   ( enable                   ),
    .cfg                      ( cfg                      ),
    .ctrl                     ( ctrl                     ),
    .read_data                ( read_data                ),
    .read_req                 ( read_req                 ),
    .read_ready               ( read_ready               ),
    .write_data               ( write_data               ),
    .write_req                ( write_req                ),
    .write_ready              ( write_ready              )
  );

  pooling_tb_driver #(
    .NUM_PE                   ( NUM_PE                   ),
    .DATA_WIDTH               ( DATA_WIDTH               ),
    .CFG_WIDTH                ( CFG_WIDTH                )
  ) driver (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .ready                    ( ready                    ),
    .enable                   ( enable                   ),
    .cfg                      ( cfg                      ),
    .ctrl                     ( ctrl                     ),
    .read_data                ( read_data                ),
    .read_req                 ( read_req                 ),
    .read_ready               ( read_ready               ),
    .write_data               ( write_data               ),
    .write_req                ( write_req                ),
    .write_ready              ( write_ready              )
  );

endmodule
