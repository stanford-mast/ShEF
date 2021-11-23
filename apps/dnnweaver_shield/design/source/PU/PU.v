`timescale 1ns/1ps
`include "common.vh"
module PU
#( // INPUT PARAMETERS
  parameter integer PU_ID             = 0,
  parameter integer OP_WIDTH          = 16,
  parameter integer ACC_WIDTH         = 48,
  parameter integer NUM_PE            = 4,
  parameter integer VECGEN_CTRL_W     = 9,
  parameter integer TID_WIDTH         = 16,
  parameter integer PAD_WIDTH         = 3,
  parameter integer STRIDE_SIZE_W     = 3,
  parameter integer VECGEN_CFG_W      = STRIDE_SIZE_W + PAD_WIDTH,
  parameter integer WR_ADDR_WIDTH     = 5,
  parameter integer RD_ADDR_WIDTH     = WR_ADDR_WIDTH+`C_LOG_2(NUM_PE),
  parameter integer PE_BUF_ADDR_WIDTH = 10,
  parameter integer LAYER_PARAM_WIDTH = 10,
  parameter integer POOL_CTRL_WIDTH   = 7,
  parameter integer POOL_CFG_WIDTH    = 3,
  parameter integer AXI_DATA_WIDTH    = 64,

  parameter integer D_TYPE_W          = 2,
  parameter integer RD_LOOP_W         = 10,
  parameter integer SERDES_COUNT_W    = `C_LOG_2(NUM_PE+1),

  parameter integer PE_SEL_W          = `C_LOG_2(NUM_PE)

)( // PORTS
  input  wire                                         clk,
  input  wire                                         reset,

  input  wire                                         lrn_enable,

  // PU_controller
  input  wire  [ SERDES_COUNT_W       -1 : 0 ]        pu_serdes_count,
  input  wire  [ PE_CTRL_WIDTH        -1 : 0 ]        pe_ctrl,
  input  wire                                         bias_read_req,
  input  wire                                         wb_read_req,
  input  wire  [ RD_ADDR_WIDTH        -1 : 0 ]        wb_read_addr,
  // PU Source and Destination Select
  input  wire  [ `SRC_0_SEL_WIDTH     -1 : 0 ]        src_0_sel,
  input  wire  [ `SRC_1_SEL_WIDTH     -1 : 0 ]        src_1_sel,
  input  wire  [ `SRC_2_SEL_WIDTH     -1 : 0 ]        src_2_sel,
  input  wire  [ `OUT_SEL_WIDTH       -1 : 0 ]        out_sel,
  input  wire  [ `DST_SEL_WIDTH       -1 : 0 ]        dst_sel,

  input  wire  [ PE_SEL_W             -1 : 0 ]        pe_neuron_sel,
  input  wire                                         pe_neuron_bias,
  input  wire                                         pe_neuron_read_req,

  input  wire  [ NUM_PE               -1 : 0 ]        vecgen_mask,

  input  wire  [ DATA_IN_WIDTH        -1 : 0 ]        vecgen_wr_data,

  input  wire  [ POOL_CTRL_WIDTH      -1 : 0 ]        pool_ctrl,
  input  wire  [ POOL_CFG_WIDTH       -1 : 0 ]        pool_cfg,

  input  wire  [ AXI_DATA_WIDTH       -1 : 0 ]        read_data,
  input  wire  [ RD_LOOP_W            -1 : 0 ]        read_id,
  input  wire  [ D_TYPE_W             -1 : 0 ]        read_d_type,
  input  wire                                         buffer_read_data_valid,
  output wire                                         read_req,

  input  wire                                         write_ready,
  output wire  [ DATA_OUT_WIDTH       -1 : 0 ]        write_data,
  output wire                                         write_req
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
  localparam integer DATA_IN_WIDTH            = OP_WIDTH * NUM_PE;
  localparam integer DATA_OUT_WIDTH           = OP_WIDTH * NUM_PE;
  localparam integer PE_OP_CODE_WIDTH         = 3;
  localparam integer DATA_POOLING_OUT_WIDTH   = DATA_IN_WIDTH;
  localparam integer COUNTER_WIDTH            = `C_LOG_2(NUM_PE)+1;
  localparam integer PE_CTRL_WIDTH            = 10 + 2*PE_BUF_ADDR_WIDTH;

// ******************************************************************
// WIRES
// ******************************************************************
  genvar i;

  wire [ DATA_IN_WIDTH        -1 : 0 ]        pe_write_data;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        lrn_center;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        norm_out;
  wire norm_in_valid;
  wire norm_out_valid;

  wire [ 1024                 -1 : 0 ]        GND;


  // -- weight buffer -- //
  reg                                         wb_bias_valid;
  reg  [ OP_WIDTH             -1 : 0 ]        wb_bias_data;
  wire [ OP_WIDTH             -1 : 0 ]        wb_read_data;
  wire                                        wb_write_req;
  wire                                        wb_weight_read_req;
  wire [ AXI_DATA_WIDTH       -1 : 0 ]        wb_write_data;
  reg  [ WR_ADDR_WIDTH        -1 : 0 ]        wb_write_addr;

  // -- pooling -- //
  wire [ DATA_IN_WIDTH        -1 : 0 ]        pool_write_data;
  wire                                        pool_write_req;
  wire                                        pool_write_ready;
  wire [ DATA_IN_WIDTH        -1 : 0 ]        pool_read_data;
  wire                                        pool_read_req;
  wire                                        pool_read_ready;
  wire [ POOL_CTRL_WIDTH      -1 : 0 ]        pool_ctrl_d;
  wire [ POOL_CFG_WIDTH       -1 : 0 ]        pool_cfg_d;

  wire pu_bias_read_req;

  wire lrn_enable_local;
  wire pu_write_valid_local;

// ******************************************************************
// Connections
// ******************************************************************
  assign GND = 1024'd0;

  assign read_req = wb_weight_read_req || pu_bias_read_req;

  assign lrn_enable_local = PU_ID == 0 && lrn_enable;

// ******************************************************************
// INSTANTIATIONS
// ******************************************************************

// ==================================================================
// Delays
// ==================================================================
wire  [ DATA_IN_WIDTH        -1 : 0 ]        vecgen_wr_data_d;
wire  [ PE_CTRL_WIDTH        -1 : 0 ]        pe_ctrl_d;
wire  [ RD_ADDR_WIDTH        -1 : 0 ]        wb_read_addr_d;
wire                                         bias_read_req_d;
wire                                         wb_read_req_d;
wire  [ `SRC_0_SEL_WIDTH     -1 : 0 ]        src_0_sel_d;
wire  [ `SRC_1_SEL_WIDTH     -1 : 0 ]        src_1_sel_d;
wire  [ `SRC_2_SEL_WIDTH     -1 : 0 ]        src_2_sel_d;
wire  [ `OUT_SEL_WIDTH       -1 : 0 ]        out_sel_d;
wire  [ `DST_SEL_WIDTH       -1 : 0 ]        dst_sel_d;
wire  [ NUM_PE               -1 : 0 ]        vecgen_mask_d;


wire  [ PE_SEL_W             -1 : 0 ]        pe_neuron_sel_d;
wire                                         pe_neuron_bias_d;

register #(1, DATA_IN_WIDTH)
pu_vg_data_delay (clk, reset, vecgen_wr_data, vecgen_wr_data_d);
register #(3, PE_CTRL_WIDTH)
pu_ctrl_delay (clk, reset, pe_ctrl, pe_ctrl_d);
register #(3, RD_ADDR_WIDTH)
wb_read_addr_delay (clk, reset, wb_read_addr, wb_read_addr_d);
register #(3, 1)
wb_read_req_delay (clk, reset, wb_read_req, wb_read_req_d);
register #(3, `SRC_0_SEL_WIDTH)
src_0_sel_delay (clk, reset, src_0_sel, src_0_sel_d);
register #(3, `SRC_1_SEL_WIDTH)
src_1_sel_delay (clk, reset, src_1_sel, src_1_sel_d);
register #(3, `SRC_2_SEL_WIDTH)
src_2_sel_delay (clk, reset, src_2_sel, src_2_sel_d);
register #(1, `OUT_SEL_WIDTH)
out_sel_delay (clk, reset, out_sel, out_sel_d);
register #(3, `DST_SEL_WIDTH)
dst_sel_delay (clk, reset, dst_sel, dst_sel_d);
register #(3, NUM_PE)
vg_mask_delay (clk, reset, vecgen_mask, vecgen_mask_d);



  register #(3, POOL_CTRL_WIDTH)
  pool_ctrl_delay (clk, reset, pool_ctrl, pool_ctrl_d);
  register #(3, POOL_CFG_WIDTH)
  pool_cfg_delay (clk, reset, pool_cfg, pool_cfg_d);


register #(1, PE_SEL_W)
pe_neuron_sel_delay (clk, reset, pe_neuron_sel, pe_neuron_sel_d);
register #(1, 1)
pe_neuron_bias_delay (clk, reset, pe_neuron_bias, pe_neuron_bias_d);

// ==================================================================

// ==================================================================
// Weight Buffer
// ==================================================================

  reg  [ OP_WIDTH             -1 : 0 ]        bias;
  reg                                         bias_v;
  reg  [ D_TYPE_W             -1 : 0 ]        read_d_type_d;

  wire weight_reset;
  assign weight_reset = bias_read_req;

  always @(posedge clk)
    if (reset)
      bias <= 0;
    else if (pu_bias_read_req)
      bias <= read_data[OP_WIDTH-1:0];

  always @(posedge clk)
  begin
    if (reset)
      bias_v <= 1'b0;
    else if (weight_reset)
      bias_v <= 1'b0;
    else if (pu_bias_read_req)
      bias_v <= 1'b1;
  end

  assign pu_bias_read_req = buffer_read_data_valid && !bias_v && read_id == PU_ID;
  reg pu_bias_read_req_d;
  always @(posedge clk)
    pu_bias_read_req_d <= pu_bias_read_req;

  assign wb_weight_read_req = buffer_read_data_valid && bias_v && read_id == PU_ID;

  assign wb_write_req = wb_weight_read_req;

  always @(posedge clk)
    read_d_type_d <= read_d_type;

  assign wb_write_data = read_data;
  always @(posedge clk)
  begin: WB_WRITE
    if (reset)
      wb_write_addr <= GND[WR_ADDR_WIDTH-1:0];
    else if (weight_reset)
      wb_write_addr <= GND[WR_ADDR_WIDTH-1:0];
    else if (wb_write_req)
      wb_write_addr <= wb_write_addr + 1;
  end
  weight_buffer #(
    .RD_WIDTH                 ( OP_WIDTH                 ),
    .WR_WIDTH                 ( AXI_DATA_WIDTH           ),
    .RD_ADDR_WIDTH            ( RD_ADDR_WIDTH            ),
    .WR_ADDR_WIDTH            ( WR_ADDR_WIDTH            )
  )
  u_wb
  (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),

    .read_req                 ( wb_read_req_d            ),
    .read_data                ( wb_read_data             ),
    .read_addr                ( wb_read_addr_d           ),

    // TODO: Verify the wb weights
    .write_req                ( wb_write_req             ),
    //.write_req                ( 1'b0             ),
    .write_data               ( wb_write_data            ),
    .write_addr               ( wb_write_addr            )
  );

//  wire wb_bias_read_req;
  always @(posedge clk)
    if (reset)
      wb_bias_data <= 0;
    else if (bias_v)
      wb_bias_data <= bias;
// ==================================================================

// ==================================================================
// Neuron Read/Write
// ==================================================================

assign pe_enable = 1'b1;
assign pe_write_req = PE_GENBLK[0].pe_write_valid;

wire [ DATA_IN_WIDTH        -1 : 0 ]        pe_buffer_read_data;
wire [ DATA_IN_WIDTH        -1 : 0 ]        pe_neuron_write_data;
wire [ OP_WIDTH             -1 : 0 ]        pe_read_neuron;
wire [ OP_WIDTH             -1 : 0 ]        pe_read_neuron_d;

// Read Neurons for the Fully-Connected Layer
generate
for (i=0; i<NUM_PE; i=i+1)
begin: NEURON_SEL_GEN
  assign pe_read_neuron = pe_neuron_bias_d ? 1'b1 :
    (pe_neuron_sel_d == i) ? pe_buffer_read_data[i*OP_WIDTH+:OP_WIDTH]
    : 'bz;
end
endgenerate

register #(1, OP_WIDTH)
neuron_delay (clk, reset, pe_read_neuron, pe_read_neuron_d);

wire pe_neuron_write_req;

wire buffer_neuron_read;
wire [AXI_DATA_WIDTH-1:0] buffer_read_data;
assign buffer_neuron_read = buffer_read_data_valid && src_1_sel_d == `SRC_1_PE_BUFFER && read_id == PU_ID;
assign buffer_read_data = read_data;

data_packer #(
    .IN_WIDTH                 ( AXI_DATA_WIDTH           ),
    .OUT_WIDTH                ( DATA_IN_WIDTH            )
) packer (
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .s_write_req              ( buffer_neuron_read       ),  //input
    .s_write_data             ( buffer_read_data         ),  //input
    .s_write_ready            (                          ),  //output
    .m_write_req              ( pe_neuron_write_req      ),  //output
    .m_write_data             ( pe_neuron_write_data     ),  //output
    .m_write_ready            (                          )   //input
);

reg [PE_BUF_ADDR_WIDTH-1:0] pe_neuron_write_addr;
always @(posedge clk)
begin
  if (reset)
    pe_neuron_write_addr <= 'b0;
  else begin
    if (pe_neuron_write_req)
      pe_neuron_write_addr <= pe_neuron_write_addr + 1'b1;
    else if (pe_neuron_read_req)
      pe_neuron_write_addr <= 'b0;
  end
end

// ==================================================================

// ==================================================================
// COMPUTE
// ==================================================================

generate
for (i=0; i<NUM_PE; i=i+1)
begin : PE_GENBLK

  wire                                        pe_write_valid;
  wire                                        pe_mask;

  wire [ OP_WIDTH             -1 : 0 ]        pe_read_data_0;
  wire [ OP_WIDTH             -1 : 0 ]        pe_read_data_1;
  wire [ OP_WIDTH             -1 : 0 ]        pe_read_data_2;
  wire [ OP_WIDTH             -1 : 0 ]        pe_write_data_local;
  wire [ OP_WIDTH             -1 : 0 ]        lrn_center_local;


  assign pe_read_data_0  = vecgen_wr_data_d [i*OP_WIDTH+:OP_WIDTH];
  //assign pe_read_data_1  = {{(OP_WIDTH-1){1'b0}}, 1'b1};
  assign pe_read_data_1  = src_1_sel_d ? pe_read_neuron_d : wb_read_data;
  //assign pe_read_data_1  = wb_read_data;
  assign pe_read_data_2  = wb_bias_data;

  assign pe_write_data[i*OP_WIDTH+:OP_WIDTH] = pe_write_data_local;
  assign lrn_center[i*OP_WIDTH+:OP_WIDTH] = lrn_center_local;

  assign pe_mask = vecgen_mask_d[i];

  wire [ OP_WIDTH             -1 : 0 ]        buf_rd_data;
  wire [ OP_WIDTH             -1 : 0 ]        buf_wr_data;
  assign pe_buffer_read_data[i*OP_WIDTH+:OP_WIDTH] = buf_rd_data;
  assign buf_wr_data = pe_neuron_write_data[i*OP_WIDTH+:OP_WIDTH];

  PE #(   // INPUT PARAMETERS
    .OP_WIDTH                 ( OP_WIDTH                 ),  //parameter
    .ACC_WIDTH                ( ACC_WIDTH                )   //parameter
  ) u_PE (// PORTS
    .clk                      ( clk                      ),  //input
    .reset                    ( reset                    ),  //input
    .ctrl                     ( pe_ctrl_d                ),  //input
    .src_2_sel                ( src_2_sel_d              ),  //input
    .pe_buffer_read_data      ( buf_rd_data              ),  //output
    .pe_neuron_read_req       ( pe_neuron_read_req       ),  //output
    .pe_neuron_write_addr     ( pe_neuron_write_addr     ),  //output
    .pe_neuron_write_data     ( buf_wr_data              ),  //output
    .pe_neuron_write_req      ( pe_neuron_write_req      ),  //output
    .read_data_0              ( pe_read_data_0           ),  //input
    .read_data_1              ( pe_read_data_1           ),  //input
    .read_data_2              ( pe_read_data_2           ),  //input
    .lrn_center               ( lrn_center_local         ),  //output
    .write_data               ( pe_write_data_local      ),  //output
    .write_valid              ( pe_write_valid           ),  //output
    .mask                     ( pe_mask                  )   //output
  );

end
endgenerate
// ==================================================================

// ==================================================================
// Normalization
// ==================================================================

  assign norm_in_valid = pe_write_req && lrn_enable_local;
  normalization #(
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   )
  ) u_norm (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .enable                   ( norm_in_valid            ),
    .square_sum               ( pe_write_data            ),
    .lrn_center               ( lrn_center               ),
    .norm_out                 ( norm_out                 ),
    .out_valid                ( norm_out_valid           )
  );

// ==================================================================

// ==================================================================
// Pooling Module
// ==================================================================

  assign pool_write_req = lrn_enable_local ? (norm_out_valid && out_sel_d == `OUT_POOL) : pe_write_req && (out_sel_d == `OUT_POOL);
  assign pool_write_data = lrn_enable_local ? norm_out : pe_write_data;
  assign pool_read_ready = 1'b1;
  pooling #(
    // INPUT PARAMETERS
    .OP_WIDTH                 ( OP_WIDTH                 ),
    .NUM_PE                   ( NUM_PE                   )
  ) pool_DUT (
    // PORTS
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .ready                    (                          ),
    .cfg                      ( pool_cfg_d               ),
    .ctrl                     ( pool_ctrl_d              ),
    .read_data                ( pool_read_data           ),
    .read_req                 ( pool_read_req            ),
    .read_ready               ( pool_read_ready          ),
    .write_data               ( pool_write_data          ),
    .write_req                ( pool_write_req           ),
    .write_ready              ( pool_write_ready         )
  );
// ==================================================================

  wire  [ DATA_OUT_WIDTH       -1 : 0 ]        serdes_write_data;
  wire                                         serdes_write_req;

  assign serdes_write_req =
    out_sel_d == `OUT_POOL ?
    pool_read_req : lrn_enable_local ? norm_out_valid : pe_write_req;
  assign serdes_write_data =
    out_sel_d == `OUT_POOL ?
    pool_read_data : lrn_enable_local ? norm_out : pe_write_data;

  reg [SERDES_COUNT_W-1:0] pool_serdes_count;
  always @(posedge clk)
    if (reset)
      pool_serdes_count <= NUM_PE;
    else if (pe_write_req)
      pool_serdes_count <= pu_serdes_count;

  wire [SERDES_COUNT_W-1:0] serdes_count;
  assign serdes_count =
    out_sel_d == `OUT_POOL ?
    pool_serdes_count : pu_serdes_count;

  serdes #(
    .IN_COUNT                 ( NUM_PE                   ),
    .OUT_COUNT                ( NUM_PE                   ),
    .OP_WIDTH                 ( OP_WIDTH                 )
  ) u_serdes (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .count                    ( serdes_count             ),
    .s_write_ready            (                          ),
    .s_write_flush            ( s_write_flush            ),
    .s_write_req              ( serdes_write_req         ),
    .s_write_data             ( serdes_write_data        ),
    .m_write_ready            ( m_write_ready            ),
    .m_write_req              ( pu_write_valid_local     ),
    .m_write_data             ( write_data               )
  );

assign write_req = pu_write_valid_local && !(lrn_enable && PU_ID != 0);

  `ifdef simulation
    integer pu_write_count;
    always @(posedge clk)
      if (reset)
        pu_write_count <= 0;
      else if (write_req)
        pu_write_count <= pu_write_count + 1;
  `endif
`ifdef TOPLEVEL_PU
  initial
  begin
    $dumpfile("PU.vcd");
    $dumpvars(0,PU);
  end
`endif

endmodule
