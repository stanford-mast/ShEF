`include "common.vh"
module vectorgen_tb;

// ******************************************************************
// local parameters
// ******************************************************************
  localparam integer LAYER_PARAM_WIDTH         = 6;
  localparam integer NUM_PE     = 4;
  localparam integer OP_WIDTH   = 16;
  localparam integer DATA_WIDTH = NUM_PE * OP_WIDTH;
  localparam integer VECGEN_CTRL_W = 9;
  localparam integer TID_WIDTH         = 8;
  localparam integer PAD_WIDTH         = 3;
  localparam integer VECGEN_CFG_W      = TID_WIDTH + PAD_WIDTH;
  localparam integer WEIGHT_ADDR_WIDTH = 4;

// ******************************************************************
// IO
// ******************************************************************
  wire  [DATA_WIDTH-1:0]      read_data;
  wire  [DATA_WIDTH-1:0]      write_data;
  wire  [NUM_PE-1:0]          write_mask;
  wire  [VECGEN_CTRL_W-1:0]   vectorgen_ctrl;
  wire  [VECGEN_CFG_W -1:0]   cfg;
  reg                         start;

  vectorgen_tb_driver #(
    .OP_WIDTH     ( OP_WIDTH    ),
    .NUM_PE       ( NUM_PE      )
  ) driver (
    .clk          ( clk         ),
    .reset        ( reset       ),
    .ready        ( ready       ),
    //.vectorgen_ctrl         ( vectorgen_ctrl        ), //output
    //.cfg          ( cfg         ), //output
    .read_ready   ( read_ready  ), //output
    .read_data    ( read_data   ), //output
    .read_req     ( read_req    ), //input
    .write_valid  ( write_valid ), //input
    .write_data   ( write_data  ), //input
    .write_mask   ( write_mask  )  //input
  );

  reg [LAYER_PARAM_WIDTH-1:0] _kw, _kh, _ks;
  reg [LAYER_PARAM_WIDTH-1:0] _iw, _ih, _ic, _batch, _oc;
  reg [LAYER_PARAM_WIDTH-1:0] _endrow_iw;
  reg                         _skip;
  reg [LAYER_PARAM_WIDTH-1:0] _ow;
  reg [PAD_WIDTH-1:0] _pad;
  reg [TID_WIDTH-1:0] _max_threads;

  integer layer_id, max_layers;

  initial begin
    driver.status.start;
    @(negedge clk);
    max_layers = controller_dut.max_layers+1;
    for (layer_id = 0; layer_id < max_layers; layer_id = layer_id+1)
    begin
      wait (controller_dut.state == 1);
      _ks = 1;
      {_max_threads, _pad, _skip, _endrow_iw, _ic, _ih, _iw, _oc, _kh, _kw} = controller_dut.cfg_rom[layer_id];
      driver.initialize_input(_ih+1, _ih+1, _ic+1, 1);
      driver.print_input;
      driver.initialize_expected_output(_ih+1, _ih+1, _ic, _batch, _kw+1, _kh+1, _ks, _oc, _pad);
      driver.generate_vectors;
      wait (driver.data_in_counter == driver.max_data_in_count);
    end


    // {_max_threads, _pad, _skip, _endrow_iw, _ih, _iw, _kh, _kw} = controller_dut.cfg_rom[1];
    // driver.initialize_expected_output(_max_threads+1, _ih+1, _ic, _batch, _kw+1, _kh+1, _ks, _oc, _pad);
    // driver.generate_vectors;

    // {_max_threads, _pad, _skip, _endrow_iw, _ih, _iw, _kh, _kw} = controller_dut.cfg_rom[2];
    // driver.initialize_expected_output(_max_threads+1, _ih+1, _ic, _batch, _kw+1, _kh+1, _ks, _oc, _pad);
    // driver.generate_vectors;

    // {_max_threads, _pad, _skip, _endrow_iw, _ih, _iw, _kh, _kw} = controller_dut.cfg_rom[3];
    // driver.initialize_expected_output(_max_threads+1, _ih+1, _ic, _batch, _kw+1, _kh+1, _ks, _oc, _pad);
    // driver.generate_vectors;

    // {_max_threads, _pad, _skip, _endrow_iw, _ih, _iw, _kh, _kw} = controller_dut.cfg_rom[4];
    // driver.initialize_expected_output(_max_threads+1, _ih+1, _ic, _batch, _kw+1, _kh+1, _ks, _oc, _pad);
    // driver.generate_vectors;

    driver.pass = 1;
  end

  initial
  begin
    $dumpfile("vectorgen_tb.vcd");
    $dumpvars(0,vectorgen_tb);
  end

  vectorgen #( //Parameters
     .OP_WIDTH      ( OP_WIDTH    ),
     .NUM_PE        ( NUM_PE      )
   ) u_vecgen (
     .clk           ( clk         ), //input
     .reset         ( reset       ), //input
     .ready         ( ready       ), //output
     .ctrl          ( vectorgen_ctrl        ), //input
     .cfg           ( cfg         ), //input
     .read_ready    ( read_ready  ), //input
     .read_data     ( read_data   ), //input
     .read_req      ( read_req    ), //output
     .write_valid   ( write_valid ), //output
     .write_data    ( write_data  ), //output
     .write_mask    ( write_mask  )  //output
  );

// ==================================================================
// PU controller
// ==================================================================
  PU_controller
  #(  // PARAMETERS
    .NUM_PE             ( NUM_PE            ),
    .WEIGHT_ADDR_WIDTH  ( WEIGHT_ADDR_WIDTH ),
    .PE_CTRL_WIDTH      ( 9                 ),
    .VECGEN_CTRL_W      ( VECGEN_CTRL_W     ),
    .TID_WIDTH          ( TID_WIDTH         ),
    .MAX_LAYERS         ( 5                 ),
    .PAD_WIDTH          ( PAD_WIDTH         )
  ) controller_dut (   // PORTS
    .clk                ( clk               ), //input
    .reset              ( reset             ), //input
    .start              ( start             ), //input
    .done               ( done              ), //output
    .vectorgen_ready    ( ready             ), //input
    .vectorgen_ctrl               ( vectorgen_ctrl              ), //output
    .cfg                ( cfg               )  //output
  );
// ==================================================================

initial begin
  start = 0;
  wait (read_ready);
  start = 1;
  wait (ready);
  @(negedge clk);
  @(negedge clk);
  start = 0;

end

endmodule
