 /** This module tests the PU for convolution
   * The testbench instantiates the driver
   * and the PU module */
module convolution_tb;
// ******************************************************************
// local parameters
// ******************************************************************
  localparam integer NUM_PE             = 4;
  localparam integer OP_WIDTH           = 16;
  localparam integer DATA_WIDTH         = NUM_PE * OP_WIDTH;
  localparam integer TID_WIDTH          = 16;
  localparam integer PAD_WIDTH          = 3;
  localparam integer LAYER_PARAM_WIDTH  = 10;
// ******************************************************************
// IO
// ******************************************************************
  wire  [DATA_WIDTH-1:0]  pu_data_out;
  wire  [DATA_WIDTH-1:0]  pu_data_in;
  reg                     start;
// ******************************************************************
// Driver
// ******************************************************************
 /** Driver for the convolution tests
   * Generates inputs and tests output */
  convolution_tb_driver #(
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   )
  ) driver (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .pu_rd_req                ( inBuf_pop                ),
    .pu_rd_ready              ( pu_rd_ready              ),
    .pu_wr_req                ( outBuf_push              ),
    .pu_data_out              ( pu_data_out              ),
    .pu_data_in               ( pu_data_in               ),
    .pass                     ( pass                     ),
    .fail                     ( fail                     )
  );
// ******************************************************************

  reg [LAYER_PARAM_WIDTH-1:0] _kw, _kh, _ks;
  reg [LAYER_PARAM_WIDTH-1:0] _iw, _ih, _ic, _batch, _oc;
  reg [LAYER_PARAM_WIDTH-1:0] _endrow_iw;
  reg                         _skip;
  reg [LAYER_PARAM_WIDTH-1:0] _ow;
  reg [PAD_WIDTH-1:0] _pad;
  reg [TID_WIDTH-1:0] _max_threads;
  reg [LAYER_PARAM_WIDTH-1:0] max_layers;

  integer ii;
  initial begin
    driver.status.start;
    start = 0;

    @(negedge clk);

    start = 1;
    wait (u_PU.u_controller.state != 0);
    start = 0;

    max_layers = u_PU.u_controller.max_layers+1;
    $display;
    $display("**************************************************");
    $display ("Number of layers = %d", max_layers);
    $display("**************************************************");
    $display;

    for (ii=0; ii<max_layers; ii++)
    begin
      {_max_threads, _pad, _skip, _endrow_iw, _ic, _ih, _iw, _oc, _kh, _kw} =
        u_PU.u_controller.cfg_rom[ii];
      $display("**************************************************");
      $display("Layer configuration: ");
      $display("**************************************************");
      $display("Input FM: %4d x %4d x %4d", _ih+1, _ih+1, _ic+1);
      $display("Kernel  : %4d x %-4d", _kh+1, _kw+1);
      $display("Padding : %4d", _pad);
      $display("**************************************************");
      wait (u_PU.u_controller.state == 1);
      driver.initialize_weight(_kh+1, _kh+1, _ic+1, 1);
      driver.initialize_input(_ih+1, _ih+1, _ic+1, 1);
      driver.expected_output(_ih+1,_ih+1,_ic+1,1, _kw+1,_kh+1,1, 1, _pad);
      wait (driver.write_count/NUM_PE == driver.expected_writes);
    end
    wait (u_PU.u_controller.state == 0);

    driver.status.test_pass;
  end

  initial
  begin
    $dumpfile("convolution_tb.vcd");
    $dumpvars(0,convolution_tb);
  end

// ******************************************************************
// PU
// ******************************************************************
  PU #(
    // Parameters
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   )
   ) u_PU (
    // IO
    .clk                      ( clk                      ), //input
    .reset                    ( reset                    ), //input
    .read_d_type              ( 0                        ), //input
    .read_id                  ( 0                        ), //input
    .start                    ( start                    ), //input
    .done                     ( done                     ), //input
    .read_ready               ( pu_rd_ready              ), //input
    .read_req                 ( inBuf_pop                ), //output
    .read_data                ( pu_data_in               ), //input,
    .write_data               ( pu_data_out              ), //output
    .write_req                ( outBuf_push              ), //output
    .write_ready              ( 1'b1                     )  //input
// ******************************************************************
  );

  wire [ LAYER_PARAM_WIDTH      -1 : 0 ]      kw, kh, iw, ih;

endmodule
