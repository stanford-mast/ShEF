module controller_tb;
  initial
  begin
    $dumpfile("controller_tb.vcd");
    $dumpvars(0,controller_tb);
  end

// ******************************************************************
// local parameters
// ******************************************************************
  parameter integer NUM_PE            = 4;
  parameter integer WEIGHT_ADDR_WIDTH = 4;
  parameter integer PE_CTRL_WIDTH     = 9;
  parameter integer VECGEN_CTRL_W     = 9;
  parameter integer TID_WIDTH         = 8;
  parameter integer PAD_WIDTH         = 3;
  parameter integer VECGEN_CFG_W      = TID_WIDTH + PAD_WIDTH;
// ******************************************************************
// IO
// ******************************************************************
  wire [VECGEN_CTRL_W-1:0] ctrl;
  reg  [VECGEN_CTRL_W-1:0] ctrl_d;
  wire [VECGEN_CTRL_W-1:0] ctrl_driver;
  reg  [VECGEN_CTRL_W-1:0] ctrl_driver_p;
  reg  [VECGEN_CTRL_W-1:0] ctrl_driver_d;
  reg                      ready;
  reg                      start;
  wire                     done;
// ******************************************************************

// ==================================================================
// clkgen
// ==================================================================
  clk_rst_driver
  clkgen(
    .clk      ( clk       ),
    .reset_n  (           ),
    .reset    ( reset     )
  );
// ==================================================================

// ==================================================================
// Driver
// ==================================================================
    controller_tb_driver
    #(  // PARAMETERS
        .NUM_PE             ( NUM_PE            ),
        .WEIGHT_ADDR_WIDTH  ( WEIGHT_ADDR_WIDTH ),
        .PE_CTRL_WIDTH      ( 9                 )
    ) driver (   // PORTS
        .clk                ( clk               ), //input
        .reset              ( reset             ), //input
        .ready              ( ready             ), //input
        .ctrl               ( ctrl_driver       )  //output
    );
// ==================================================================

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
    .PAD_WIDTH          ( PAD_WIDTH         )
  ) controller_dut (   // PORTS
    .clk                ( clk               ), //input
    .reset              ( reset             ), //input
    .start              ( start             ), //input
    .done               ( done              ), //output
    .vectorgen_ready    ( ready             ), //input
    .ctrl               ( ctrl              )  //output
  );
// ==================================================================

initial begin
  driver.initialize_layer_params
  (
    28,
    28,
    1,
    1,
    5,
    5,
    1,
    1,
    0
  );
  wait (reset == 1'b0);
  ready = 1'b1;
  @(negedge clk);
  @(negedge clk);
  driver.generate_vectors;
  driver.status.test_pass;
end

initial begin
  wait (reset == 1'b0);
  start = 1'b1;
  @(negedge clk);
  start = 1'b0;
end

reg exp_vectorgen_nextData_p;
reg exp_vectorgen_nextRead_p;
reg exp_vectorgen_nextrow_p;
reg exp_vectorgen_endrow_p;
reg exp_vectorgen_start_p;
reg exp_vectorgen_nextfm_p;

always @(posedge clk)
begin
  exp_vectorgen_nextData_p <= exp_vectorgen_nextData;
  exp_vectorgen_nextRead_p <= exp_vectorgen_nextRead;
  exp_vectorgen_endrow_p <= exp_vectorgen_endrow;
  exp_vectorgen_nextrow_p <= exp_vectorgen_nextrow;
  exp_vectorgen_start_p <= exp_vectorgen_start;
  exp_vectorgen_nextfm_p <= exp_vectorgen_nextfm;
end

wire [VECGEN_CTRL_W-1:0] exp_ctrl_p;

assign exp_ctrl_p = {
  exp_vectorgen_nextData_p,
  exp_vectorgen_nextRead_p,
  exp_vectorgen_pop,
  exp_vectorgen_shift,
  exp_vectorgen_nextrow_p,
  exp_vectorgen_skip,
  exp_vectorgen_endrow_p,
  exp_vectorgen_start_p,
  exp_vectorgen_nextfm_p};

always @(posedge clk)
begin
  if (vectorgen_pop != exp_vectorgen_pop)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_shift != exp_vectorgen_shift)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_nextData != exp_vectorgen_nextData)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_nextData != exp_vectorgen_nextData)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_nextRead != exp_vectorgen_nextRead)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_skip != exp_vectorgen_skip)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_nextrow != exp_vectorgen_nextrow)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_endrow != exp_vectorgen_endrow)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_start != exp_vectorgen_start)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (vectorgen_nextfm != exp_vectorgen_nextfm)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
  if (ctrl != ctrl_driver)
  begin
    $display ("CTRL\nExpected = %h, Got = %h", exp_ctrl_p, ctrl);
    driver.status.test_fail;
  end
end

  assign {
    vectorgen_nextData,
    vectorgen_nextRead,
    vectorgen_pop,
    vectorgen_shift,
    vectorgen_nextrow,
    vectorgen_skip,
    vectorgen_endrow,
    vectorgen_start,
    vectorgen_nextfm
    } = ctrl;

  assign {
    exp_vectorgen_nextData,
    exp_vectorgen_nextRead,
    exp_vectorgen_pop,
    exp_vectorgen_shift,
    exp_vectorgen_nextrow,
    exp_vectorgen_skip,
    exp_vectorgen_endrow,
    exp_vectorgen_start,
    exp_vectorgen_nextfm
    } = ctrl_driver;

endmodule
