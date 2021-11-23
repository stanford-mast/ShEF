//Copyright 1986-2015 Xilinx, Inc. All Rights Reserved.
//--------------------------------------------------------------------------------
//Tool Version: Vivado v.2015.2 (lin64) Build 1266856 Fri Jun 26 16:35:25 MDT 2015
//Date        : Thu Aug 27 11:43:04 2015
//Host        : hardik-H97M-HD3 running 64-bit Ubuntu 15.04
//Command     : generate_target zynq_wrapper.bd
//Design      : zynq_wrapper
//Purpose     : IP block netlist
//--------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

// TODO:
// 1) get a ref clock from outside.
// 2) Connect it to a pll.
// 3) Remove ps7.
// 4) Connect all AXI ports to IOs. (input/output)
//  i'm logging off

module stratix_wrapper_mar23_2016 #(
//    parameter PU_CLK_FREQ        = "300 MHz",
//    parameter REF_CLK_FREQ       = "100 MHz",
    parameter READ_ADDR_BASE_0   = 32'h00000000,
    parameter WRITE_ADDR_BASE_0  = 32'h02000000,
    parameter READ_ADDR_BASE_1   = 32'h04000000,
    parameter WRITE_ADDR_BASE_1  = 32'h06000000,
    parameter READ_ADDR_BASE_2   = 32'h08000000,
    parameter WRITE_ADDR_BASE_2  = 32'h0A000000,
    parameter READ_ADDR_BASE_3   = 32'h0C000000,
    parameter WRITE_ADDR_BASE_3  = 32'h0E000000,

    parameter DATA_WIDTH         = 16,
    parameter WEIGHT_WIDTH       = 16,
    parameter MACC_OUT_WIDTH     = 16,
    parameter NUM_PE             = 8,
    parameter NUM_PU             = 150
)
(
    input  wire                pll_ref_clk,
    input  wire                global_reset,

    output wire [31:0]         S_AXI_HP0_araddr,
    output wire [1:0]          S_AXI_HP0_arburst,
    output wire [3:0]          S_AXI_HP0_arcache,
    output wire [5:0]          S_AXI_HP0_arid,
    output wire [3:0]          S_AXI_HP0_arlen,
    output wire [1:0]          S_AXI_HP0_arlock,
    output wire [2:0]          S_AXI_HP0_arprot,
    output wire [3:0]          S_AXI_HP0_arqos,
    input wire                S_AXI_HP0_arready,
    output wire [2:0]          S_AXI_HP0_arsize,
    output wire                S_AXI_HP0_arvalid,
    output wire [31:0]         S_AXI_HP0_awaddr,
    output wire [1:0]          S_AXI_HP0_awburst,
    output wire [3:0]          S_AXI_HP0_awcache,
    output wire [5:0]          S_AXI_HP0_awid,
    output wire [3:0]          S_AXI_HP0_awlen,
    output wire [1:0]          S_AXI_HP0_awlock,
    output wire [2:0]          S_AXI_HP0_awprot,
    output wire [3:0]          S_AXI_HP0_awqos,
    input wire                S_AXI_HP0_awready,
    output wire [2:0]          S_AXI_HP0_awsize,
    output wire                S_AXI_HP0_awvalid,
    input wire [5:0]          S_AXI_HP0_bid,
    output wire                S_AXI_HP0_bready,
    input wire [1:0]          S_AXI_HP0_bresp,
    input wire                S_AXI_HP0_bvalid,
    input wire [63:0]         S_AXI_HP0_rdata,
    input wire [5:0]          S_AXI_HP0_rid,
    input wire                S_AXI_HP0_rlast,
    output wire                S_AXI_HP0_rready,
    input wire [1:0]          S_AXI_HP0_rresp,
    input wire                S_AXI_HP0_rvalid,
    output wire [63:0]         S_AXI_HP0_wdata,
    output wire [5:0]          S_AXI_HP0_wid,
    output wire                S_AXI_HP0_wlast,
    input wire                S_AXI_HP0_wready,
    output wire [7:0]          S_AXI_HP0_wstrb,
    output wire                S_AXI_HP0_wvalid


//    output wire [31:0]         S_AXI_HP1_araddr,
//    output wire [1:0]          S_AXI_HP1_arburst,
//    output wire [3:0]          S_AXI_HP1_arcache,
//    output wire [5:0]          S_AXI_HP1_arid,
//    output wire [3:0]          S_AXI_HP1_arlen,
//    output wire [1:0]          S_AXI_HP1_arlock,
//    output wire [2:0]          S_AXI_HP1_arprot,
//    output wire [3:0]          S_AXI_HP1_arqos,
//    input wire                S_AXI_HP1_arready,
//    output wire [2:0]          S_AXI_HP1_arsize,
//    output wire                S_AXI_HP1_arvalid,
//    output wire [31:0]         S_AXI_HP1_awaddr,
//    output wire [1:0]          S_AXI_HP1_awburst,
//    output wire [3:0]          S_AXI_HP1_awcache,
//    output wire [5:0]          S_AXI_HP1_awid,
//    output wire [3:0]          S_AXI_HP1_awlen,
//    output wire [1:0]          S_AXI_HP1_awlock,
//    output wire [2:0]          S_AXI_HP1_awprot,
//    output wire [3:0]          S_AXI_HP1_awqos,
//    input wire                S_AXI_HP1_awready,
//    output wire [2:0]          S_AXI_HP1_awsize,
//    output wire                S_AXI_HP1_awvalid,
//    input wire [5:0]          S_AXI_HP1_bid,
//    output wire                S_AXI_HP1_bready,
//    input wire [1:0]          S_AXI_HP1_bresp,
//    input wire                S_AXI_HP1_bvalid,
//    input wire [63:0]         S_AXI_HP1_rdata,
//    input wire [5:0]          S_AXI_HP1_rid,
//    input wire                S_AXI_HP1_rlast,
//    output wire                S_AXI_HP1_rready,
//    input wire [1:0]          S_AXI_HP1_rresp,
//    input wire                S_AXI_HP1_rvalid,
//    output wire [63:0]         S_AXI_HP1_wdata,
//    output wire [5:0]          S_AXI_HP1_wid,
//    output wire                S_AXI_HP1_wlast,
//    input wire                S_AXI_HP1_wready,
//    output wire [7:0]          S_AXI_HP1_wstrb,
//    output wire                S_AXI_HP1_wvalid


//    output wire [31:0]         S_AXI_HP2_araddr,
//    output wire [1:0]          S_AXI_HP2_arburst,
//    output wire [3:0]          S_AXI_HP2_arcache,
//    output wire [5:0]          S_AXI_HP2_arid,
//    output wire [3:0]          S_AXI_HP2_arlen,
//    output wire [1:0]          S_AXI_HP2_arlock,
//    output wire [2:0]          S_AXI_HP2_arprot,
//    output wire [3:0]          S_AXI_HP2_arqos,
//    input wire                S_AXI_HP2_arready,
//    output wire [2:0]          S_AXI_HP2_arsize,
//    output wire                S_AXI_HP2_arvalid,
//    output wire [31:0]         S_AXI_HP2_awaddr,
//    output wire [1:0]          S_AXI_HP2_awburst,
//    output wire [3:0]          S_AXI_HP2_awcache,
//    output wire [5:0]          S_AXI_HP2_awid,
//    output wire [3:0]          S_AXI_HP2_awlen,
//    output wire [1:0]          S_AXI_HP2_awlock,
//    output wire [2:0]          S_AXI_HP2_awprot,
//    output wire [3:0]          S_AXI_HP2_awqos,
//    input wire                S_AXI_HP2_awready,
//    output wire [2:0]          S_AXI_HP2_awsize,
//    output wire                S_AXI_HP2_awvalid,
//    input wire [5:0]          S_AXI_HP2_bid,
//    output wire                S_AXI_HP2_bready,
//    input wire [1:0]          S_AXI_HP2_bresp,
//    input wire                S_AXI_HP2_bvalid,
//    input wire [63:0]         S_AXI_HP2_rdata,
//    input wire [5:0]          S_AXI_HP2_rid,
//    input wire                S_AXI_HP2_rlast,
//    output wire                S_AXI_HP2_rready,
//    input wire [1:0]          S_AXI_HP2_rresp,
//    input wire                S_AXI_HP2_rvalid,
//    output wire [63:0]         S_AXI_HP2_wdata,
//    output wire [5:0]          S_AXI_HP2_wid,
//    output wire                S_AXI_HP2_wlast,
//    input wire                S_AXI_HP2_wready,
//    output wire [7:0]          S_AXI_HP2_wstrb,
//    output wire                S_AXI_HP2_wvalid


    //,
    //output wire [31:0]         S_AXI_HP3_araddr,
    //output wire [1:0]          S_AXI_HP3_arburst,
    //output wire [3:0]          S_AXI_HP3_arcache,
    //output wire [5:0]          S_AXI_HP3_arid,
    //output wire [3:0]          S_AXI_HP3_arlen,
    //output wire [1:0]          S_AXI_HP3_arlock,
    //output wire [2:0]          S_AXI_HP3_arprot,
    //output wire [3:0]          S_AXI_HP3_arqos,
    //input wire                S_AXI_HP3_arready,
    //output wire [2:0]          S_AXI_HP3_arsize,
    //output wire                S_AXI_HP3_arvalid,
    //output wire [31:0]         S_AXI_HP3_awaddr,
    //output wire [1:0]          S_AXI_HP3_awburst,
    //output wire [3:0]          S_AXI_HP3_awcache,
    //output wire [5:0]          S_AXI_HP3_awid,
    //output wire [3:0]          S_AXI_HP3_awlen,
    //output wire [1:0]          S_AXI_HP3_awlock,
    //output wire [2:0]          S_AXI_HP3_awprot,
    //output wire [3:0]          S_AXI_HP3_awqos,
    //input wire                S_AXI_HP3_awready,
    //output wire [2:0]          S_AXI_HP3_awsize,
    //output wire                S_AXI_HP3_awvalid,
    //input wire [5:0]          S_AXI_HP3_bid,
    //output wire                S_AXI_HP3_bready,
    //input wire [1:0]          S_AXI_HP3_bresp,
    //input wire                S_AXI_HP3_bvalid,
    //input wire [63:0]         S_AXI_HP3_rdata,
    //input wire [5:0]          S_AXI_HP3_rid,
    //input wire                S_AXI_HP3_rlast,
    //output wire                S_AXI_HP3_rready,
    //input wire [1:0]          S_AXI_HP3_rresp,
    //input wire                S_AXI_HP3_rvalid,
    //output wire [63:0]         S_AXI_HP3_wdata,
    //output wire [5:0]          S_AXI_HP3_wid,
    //output wire                S_AXI_HP3_wlast,
    //input wire                S_AXI_HP3_wready,
    //output wire [7:0]          S_AXI_HP3_wstrb,
    //output wire                S_AXI_HP3_wvalid
);

    wire                FCLK_CLK0;
    wire                FCLK_RESET0;
    //wire [31:0]         M_AXI_GP0_araddr;
    //wire [1:0]          M_AXI_GP0_arburst;
    //wire [3:0]          M_AXI_GP0_arcache;
    //wire [11:0]         M_AXI_GP0_arid;
    //wire [3:0]          M_AXI_GP0_arlen;
    //wire [1:0]          M_AXI_GP0_arlock;
    //wire [2:0]          M_AXI_GP0_arprot;
    //wire [3:0]          M_AXI_GP0_arqos;
    //wire                M_AXI_GP0_arready;
    //wire [2:0]          M_AXI_GP0_arsize;
    //wire                M_AXI_GP0_arvalid;
    //wire [31:0]         M_AXI_GP0_awaddr;
    //wire [1:0]          M_AXI_GP0_awburst;
    //wire [3:0]          M_AXI_GP0_awcache;
    //wire [11:0]         M_AXI_GP0_awid;
    //wire [3:0]          M_AXI_GP0_awlen;
    //wire [1:0]          M_AXI_GP0_awlock;
    //wire [2:0]          M_AXI_GP0_awprot;
    //wire [3:0]          M_AXI_GP0_awqos;
    //wire                M_AXI_GP0_awready;
    //wire [2:0]          M_AXI_GP0_awsize;
    //wire                M_AXI_GP0_awvalid;
    //wire [11:0]         M_AXI_GP0_bid;
    //wire                M_AXI_GP0_bready;
    //wire [1:0]          M_AXI_GP0_bresp;
    //wire                M_AXI_GP0_bvalid;
    //wire [31:0]         M_AXI_GP0_rdata;
    //wire [11:0]         M_AXI_GP0_rid;
    //wire                M_AXI_GP0_rlast;
    //wire                M_AXI_GP0_rready;
    //wire [1:0]          M_AXI_GP0_rresp;
    //wire                M_AXI_GP0_rvalid;
    //wire [31:0]         M_AXI_GP0_wdata;
    //wire [11:0]         M_AXI_GP0_wid;
    //wire                M_AXI_GP0_wlast;
    //wire                M_AXI_GP0_wready;
    //wire [3:0]          M_AXI_GP0_wstrb;
    //wire                M_AXI_GP0_wvalid;



    wire                HP0_inBuf_Read_empty;
    wire [63:0]         HP0_inBuf_Read_rd_data;
    wire                HP0_inBuf_Read_rd_en;
    wire                HP0_inBuf_Write_full;
    wire [63:0]         HP0_inBuf_Write_wr_data;
    wire                HP0_inBuf_Write_wr_en;
    wire                HP1_inBuf_Read_empty;
    wire [63:0]         HP1_inBuf_Read_rd_data;
    wire                HP1_inBuf_Read_rd_en;
    wire                HP1_inBuf_Write_full;
    wire [63:0]         HP1_inBuf_Write_wr_data;
    wire                HP1_inBuf_Write_wr_en;
    wire                HP2_inBuf_Read_empty;
    wire [63:0]         HP2_inBuf_Read_rd_data;
    wire                HP2_inBuf_Read_rd_en;
    wire                HP2_inBuf_Write_full;
    wire [63:0]         HP2_inBuf_Write_wr_data;
    wire                HP2_inBuf_Write_wr_en;
    wire                HP3_inBuf_Read_empty;
    wire [63:0]         HP3_inBuf_Read_rd_data;
    wire                HP3_inBuf_Read_rd_en;
    wire                HP3_inBuf_Write_full;
    wire [63:0]         HP3_inBuf_Write_wr_data;
    wire                HP3_inBuf_Write_wr_en;

    wire                HP0_outBuf_Read_empty;
    wire [63:0]         HP0_outBuf_Read_rd_data;
    wire                HP0_outBuf_Read_rd_en;
    wire                HP0_outBuf_Write_full;
    wire [63:0]         HP0_outBuf_Write_wr_data;
    wire                HP0_outBuf_Write_wr_en;
    wire                HP1_outBuf_Read_empty;
    wire [63:0]         HP1_outBuf_Read_rd_data;
    wire                HP1_outBuf_Read_rd_en;
    wire                HP1_outBuf_Write_full;
    wire [63:0]         HP1_outBuf_Write_wr_data;
    wire                HP1_outBuf_Write_wr_en;
    wire                HP2_outBuf_Read_empty;
    wire [63:0]         HP2_outBuf_Read_rd_data;
    wire                HP2_outBuf_Read_rd_en;
    wire                HP2_outBuf_Write_full;
    wire [63:0]         HP2_outBuf_Write_wr_data;
    wire                HP2_outBuf_Write_wr_en;
    wire                HP3_outBuf_Read_empty;
    wire [63:0]         HP3_outBuf_Read_rd_data;
    wire                HP3_outBuf_Read_rd_en;
    wire                HP3_outBuf_Write_full;
    wire [63:0]         HP3_outBuf_Write_wr_data;
    wire                HP3_outBuf_Write_wr_en;

//   	generic_pll pll_PU (
//		.refclk     (pll_ref_clk),
//		.rst        (global_reset),
//		.outclk     (FCLK_CLK0)
//	);	

wire locked;
assign FCLK_RESET0 = !locked;
pll_arria10 pll999(
		.refclk     ( pll_ref_clk   ),   // refclk.clk
		.rst        ( global_reset  ),   // reset.reset
		.outclk_0   ( FCLK_CLK0     ),   // outclk0.clk
		.locked     ( locked        )    // locked.export
	);
//	defparam pll_PU.reference_clock_frequency = REF_CLK_FREQ,
//		     pll_PU.output_clock_frequency = PU_CLK_FREQ,
//		     pll_PU.duty_cycle = 50;

/////////////////////////////////////////////////////////////////////////////
// Buffers for HP0 interface
/////////////////////////////////////////////////////////////////////////////
// PU

    reg  [NUM_PE*NUM_PU*DATA_WIDTH-1:0]        PU0_in_data;
    wire                                PU0_mem_inbuf_ready;
    wire                                PU0_pop_mem_buf;
    wire                                PU0_data_valid;
    wire [NUM_PE*NUM_PU*DATA_WIDTH-1:0]        PU0_out_data;

    reg  [NUM_PE*NUM_PU*DATA_WIDTH-1:0]        PU0_out_data_outBuf;

    wire [NUM_PU-1:0] PU0_pop_mem_buf_inst;

    register #(.NUM_STAGES(1), .DATA_WIDTH(1)) pu_pop (.CLK(FCLK_CLK0), .RESET(FCLK_RESET0), .DIN(&PU0_pop_mem_buf_inst), .DOUT(PU0_pop_mem_buf));

    //assign  PU0_in_data               = HP0_inBuf_Read_rd_data;
    assign  PU0_mem_inbuf_ready         = !HP0_inBuf_Read_empty;
    assign  HP0_inBuf_Read_rd_en        = PU0_pop_mem_buf;

    assign  PU0_mem_outbuf_ready        = !HP0_outBuf_Write_full && PU0_count == 0;
    assign  HP0_outBuf_Write_wr_data    = PU0_out_data_outBuf[63:0];
    //assign  HP0_outBuf_Write_wr_en      = PU0_data_valid;
    //assign  HP0_outBuf_Write_wr_en      = 1'b1;
    assign  HP0_outBuf_Write_wr_en      = PU0_count != NUM_PU*NUM_PE*DATA_WIDTH/64;


    always @ (posedge FCLK_CLK0)
    begin
        if (FCLK_RESET0) begin
            PU0_in_data <= 0;
        end else if (PU0_pop_mem_buf) begin
            PU0_in_data <= HP0_inBuf_Read_rd_data;
        end else begin
            PU0_in_data <= {PU0_in_data[NUM_PE*DATA_WIDTH-1-64:0], HP0_inBuf_Read_rd_data};
        end
    end

    reg [15:0] PU0_count;
    always @ (posedge FCLK_CLK0)
    begin
        if (FCLK_RESET0) begin
            PU0_out_data_outBuf <= 0;
            PU0_count <= 0;
        end 
        //else if (PU0_data_valid) begin
        else if (PU0_count != NUM_PU*NUM_PE*DATA_WIDTH/64) begin
            PU0_out_data_outBuf <= PU0_out_data_outBuf >> 64;
            PU0_count <= PU0_count + 1;
        end
        else begin
            PU0_out_data_outBuf <= PU0_out_data;
            PU0_count <= 0;
        end
        //end 
        //else if (PU0_count != 0) begin
            //PU0_out_data_outBuf <= {PU0_out_data_outBuf} >> 64;
            //PU0_count <= PU0_count + 1;
        //end
    end

    genvar i;
    generate
    for (i=0; i< NUM_PU; i=i+1)
    begin: PU0_inst

        wire [NUM_PE*DATA_WIDTH-1:0] PU0_inst_in_data = PU0_in_data[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH];
        wire [NUM_PE*DATA_WIDTH-1:0] PU0_inst_out_data;
        wire                         PU0_inst_data_valid;
        assign PU0_out_data[(i+1)*DATA_WIDTH-1:i*DATA_WIDTH] = PU0_inst_data_valid ? PU0_inst_out_data : {NUM_PE*DATA_WIDTH{1'b0}};

        PU #(
        // INPUT PARAMETERS
            .DATA_WIDTH         ( DATA_WIDTH            ),
            .WEIGHT_WIDTH       ( DATA_WIDTH            ),
            .MACC_OUT_WIDTH     ( DATA_WIDTH            ),
            .NUM_PE             ( NUM_PE                )
        ) u_PU0 (
        // PORTS
            .CLK                ( FCLK_CLK0             ), //input
            .RESET              ( FCLK_RESET0           ), //input
            .START              ( 1'b1                  ), //input
            .DONE               (                       ), //output
            .INBUF_DATA_OUT     ( PU0_inst_in_data      ), //input
            .OUTBUF_READY       ( 1'b1                  ), //input
            .INBUF_READY        ( 1'b1                  ), //input
            .INBUF_POP          ( PU0_pop_mem_buf_inst[i]), //output
            .MACC_DATA_OUT      ( PU0_inst_out_data     ), //output
            .OUTBUF_PUSH        ( PU0_inst_data_valid   ), //output
            .STATE              (                       )  //output
        );
    end
    endgenerate

//--- old --- PU #(
//--- old ---     // INPUT PARAMETERS
//--- old ---     .DATA_WIDTH                  ( DATA_WIDTH                  ),
//--- old ---     .WEIGHT_WIDTH                ( WEIGHT_WIDTH                ),
//--- old ---     .MACC_OUT_WIDTH              ( MACC_OUT_WIDTH              ),
//--- old ---     .NUM_PE                      ( NUM_PE                      )
//--- old --- ) u_PU0 (
//--- old ---     // PORTS
//--- old ---     .CLK                         ( FCLK_CLK0                   ),  //input
//--- old ---     .RESET                       ( FCLK_RESET0               ),  //input
//--- old ---     .GLOBAL_DATA                 ( PU0_in_data                 ),  //input
//--- old ---     //.GLOBAL_WEIGHTS              ( PU0_in_data                 ),  //input
//--- old ---     .MEM_OUTBUF_READY            ( PU0_mem_outbuf_ready        ),  //input
//--- old ---     .MEM_INBUF_READY             ( PU0_mem_inbuf_ready         ),  //input
//--- old ---     .POP_MEM_BUF                 ( PU0_pop_mem_buf             ),  //output
//--- old ---     //.FEED_LAST_PE                ( PU0_in_data[DATA_WIDTH-1:0] ),  //input
//--- old ---     .MACC_DATA_OUT               ( PU0_out_data                ),  //output
//--- old ---     .DATA_VALID                  ( PU0_data_valid              )   //output
//--- old --- );

scfifo_arria10 HP0_inbuf (
    .clock                       ( FCLK_CLK0                   ),  //input
    .aclr                        ( FCLK_RESET0                 ),  //input
    .empty                       ( HP0_inBuf_Read_empty        ),  //output
    .q                           ( HP0_inBuf_Read_rd_data      ),  //input
    .rdreq                       ( HP0_inBuf_Read_rd_en        ),  //input
    .full                        ( HP0_inBuf_Write_full        ),  //output
    .data                        ( HP0_inBuf_Write_wr_data     ),  //output
    .wrreq                       ( HP0_inBuf_Write_wr_en       )   //input
    );
//    defparam HP0_inbuf.lpm_width = 64;
//    defparam HP0_inbuf.lpm_numwords = 256;

scfifo_arria10 HP0_outbuf (
    .clock                       ( FCLK_CLK0                   ),  //input
    .aclr                        ( FCLK_RESET0               ),  //input
    .empty                       ( HP0_outBuf_Read_empty       ),  //output
    .q                           ( HP0_outBuf_Read_rd_data     ),  //input
    .rdreq                       ( HP0_outBuf_Read_rd_en       ),  //input
    .full                        ( HP0_outBuf_Write_full       ),  //output
    .data                        ( HP0_outBuf_Write_wr_data    ),  //output
    .wrreq                       ( HP0_outBuf_Write_wr_en      )   //input
    );
//    defparam HP0_outbuf.lpm_width = 64;
//    defparam HP0_outbuf.lpm_numwords = 256;

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Buffers for HP1 interface
/////////////////////////////////////////////////////////////////////////////
// PU

//    reg  [NUM_PE*DATA_WIDTH-1:0]        PU1_in_data;
//    wire                                PU1_mem_inbuf_ready;
//    wire                                PU1_pop_mem_buf;
//    wire                                PU1_data_valid;
//    wire [NUM_PE*DATA_WIDTH-1:0]        PU1_out_data;
//
//    reg  [NUM_PE*DATA_WIDTH-1:0]        PU1_out_data_outBuf;
//
//
//    //assign  PU1_in_data               = HP1_inBuf_Read_rd_data;
//    assign  PU1_mem_inbuf_ready         = !HP1_inBuf_Read_empty;
//    assign  HP1_inBuf_Read_rd_en        = PU1_pop_mem_buf;
//
//    assign  PU1_mem_outbuf_ready        = !HP1_outBuf_Write_full && PU1_count == 0;
//    assign  HP1_outBuf_Write_wr_data    = PU1_out_data_outBuf[63:0];
//    assign  HP1_outBuf_Write_wr_en      = PU1_data_valid;
//
//
//    always @ (posedge FCLK_CLK0)
//    begin
//        if (FCLK_RESET0) begin
//            PU1_in_data <= 0;
//        end else if (PU1_pop_mem_buf) begin
//            PU1_in_data <= HP1_inBuf_Read_rd_data;
//        end else begin
//            PU1_in_data <= {PU1_in_data[NUM_PE*DATA_WIDTH-1-64:0], HP1_inBuf_Read_rd_data};
//        end
//    end
//
//    reg [10:0] PU1_count;
//    always @ (posedge FCLK_CLK0)
//    begin
//        if (FCLK_RESET0) begin
//            PU1_out_data_outBuf <= 0;
//            PU1_count <= 0;
//        end 
//        else if (PU1_data_valid) begin
//            PU1_out_data_outBuf <= PU1_out_data;
//            PU1_count <= 1;
//        end 
//        else if (PU1_count != 0) begin
//            PU1_out_data_outBuf <= {PU1_out_data_outBuf} >> 64;
//            PU1_count <= PU1_count + 1;
//        end
//    end
//
//PU #(
//// INPUT PARAMETERS
//    .DATA_WIDTH         ( DATA_WIDTH            ),
//    .WEIGHT_WIDTH       ( DATA_WIDTH            ),
//    .MACC_OUT_WIDTH     ( DATA_WIDTH            ),
//    .NUM_PE             ( NUM_PE                )
//) u_PU1 (
//// PORTS
//    .CLK                ( FCLK_CLK0             ), //input
//    .RESET              ( FCLK_RESET0           ), //input
//    .START              ( 1'b1                  ), //input
//    .DONE               (                       ), //output
//    .INBUF_DATA_OUT     ( PU1_in_data           ), //input
//    .OUTBUF_READY       ( 1'b1                  ), //input
//    .INBUF_READY        ( 1'b1                  ), //input
//    .INBUF_POP          ( PU1_pop_mem_buf       ), //output
//    .MACC_DATA_OUT      ( PU1_out_data          ), //output
//    .OUTBUF_PUSH        ( PU1_data_valid        ), //output
//    .STATE              (                       )  //output
//);

//--- old --- PU #(
//--- old ---     // INPUT PARAMETERS
//--- old ---     .DATA_WIDTH                  ( DATA_WIDTH                  ),
//--- old ---     .WEIGHT_WIDTH                ( WEIGHT_WIDTH                ),
//--- old ---     .MACC_OUT_WIDTH              ( MACC_OUT_WIDTH              ),
//--- old ---     .NUM_PE                      ( NUM_PE                      )
//--- old --- ) u_PU1 (
//--- old ---     // PORTS
//--- old ---     .CLK                         ( FCLK_CLK0                   ),  //input
//--- old ---     .RESET                       ( FCLK_RESET0               ),  //input
//--- old ---     .GLOBAL_DATA                 ( PU1_in_data                 ),  //input
//--- old ---     .MEM_OUTBUF_READY            ( PU1_mem_outbuf_ready        ),  //input
//--- old ---     .MEM_INBUF_READY             ( PU1_mem_inbuf_ready         ),  //input
//--- old ---     .POP_MEM_BUF                 ( PU1_pop_mem_buf             ),  //output
//--- old ---     //.FEED_LAST_PE                ( PU1_in_data[DATA_WIDTH-1:0] ),  //input
//--- old ---     .MACC_DATA_OUT               ( PU1_out_data                ),  //output
//--- old ---     .DATA_VALID                  ( PU1_data_valid              )   //output
//--- old --- );

//scfifo_arria10 HP1_inbuf (
//    .clock                       ( FCLK_CLK0                   ),  //input
//    .aclr                        ( FCLK_RESET0               ),  //input
//    .empty                       ( HP1_inBuf_Read_empty        ),  //output
//    .q                           ( HP1_inBuf_Read_rd_data      ),  //input
//    .rdreq                       ( HP1_inBuf_Read_rd_en        ),  //input
//    .full                        ( HP1_inBuf_Write_full        ),  //output
//    .data                        ( HP1_inBuf_Write_wr_data     ),  //output
//    .wrreq                       ( HP1_inBuf_Write_wr_en       )   //input
//    );
////    defparam HP1_inbuf.lpm_numwords = 256;
////    defparam HP1_inbuf.lpm_width = 64;
//
//scfifo_arria10 HP1_outbuf (
//    .clock                       ( FCLK_CLK0                   ),  //input
//    .aclr                        ( FCLK_RESET0               ),  //input
//    .empty                       ( HP1_outBuf_Read_empty       ),  //output
//    .q                           ( HP1_outBuf_Read_rd_data     ),  //input
//    .rdreq                       ( HP1_outBuf_Read_rd_en       ),  //input
//    .full                        ( HP1_outBuf_Write_full       ),  //output
//    .data                        ( HP1_outBuf_Write_wr_data    ),  //output
//    .wrreq                       ( HP1_outBuf_Write_wr_en      )   //input
//    );
//    defparam HP1_outbuf.lpm_numwords = 256;
//    defparam HP1_outbuf.lpm_width = 64;

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Buffers for HP2 interface
/////////////////////////////////////////////////////////////////////////////
//--// PU
//--
//--    reg  [NUM_PE*DATA_WIDTH-1:0]        PU2_in_data;
//--    wire                                PU2_mem_inbuf_ready;
//--    wire                                PU2_pop_mem_buf;
//--    wire                                PU2_data_valid;
//--    wire [NUM_PE*DATA_WIDTH-1:0]        PU2_out_data;
//--
//--    reg  [NUM_PE*DATA_WIDTH-1:0]        PU2_out_data_outBuf;
//--
//--
//--    //assign  PU2_in_data               = HP2_inBuf_Read_rd_data;
//--    assign  PU2_mem_inbuf_ready         = !HP2_inBuf_Read_empty;
//--    assign  HP2_inBuf_Read_rd_en        = PU2_pop_mem_buf;
//--
//--    assign  PU2_mem_outbuf_ready        = !HP2_outBuf_Write_full && PU2_count == 0;
//--    assign  HP2_outBuf_Write_wr_data    = PU2_out_data_outBuf[63:0];
//--    assign  HP2_outBuf_Write_wr_en      = PU2_data_valid;
//--
//--
//--    always @ (posedge FCLK_CLK0)
//--    begin
//--        if (FCLK_RESET0) begin
//--            PU2_in_data <= 0;
//--        end else if (PU2_pop_mem_buf) begin
//--            PU2_in_data <= HP2_inBuf_Read_rd_data;
//--        end else begin
//--            PU2_in_data <= {PU2_in_data[NUM_PE*DATA_WIDTH-1-64:0], HP2_inBuf_Read_rd_data};
//--        end
//--    end
//--
//--    reg [10:0] PU2_count;
//--    always @ (posedge FCLK_CLK0)
//--    begin
//--        if (FCLK_RESET0) begin
//--            PU2_out_data_outBuf <= 0;
//--            PU2_count <= 0;
//--        end 
//--        else if (PU2_data_valid) begin
//--            PU2_out_data_outBuf <= PU2_out_data;
//--            PU2_count <= 1;
//--        end 
//--        else if (PU2_count != 0) begin
//--            PU2_out_data_outBuf <= {PU2_out_data_outBuf} >> 64;
//--            PU2_count <= PU2_count + 1;
//--        end
//--    end
//--
//--
//--PU #(
//--    // INPUT PARAMETERS
//--    .DATA_WIDTH                  ( DATA_WIDTH                  ),
//--    .WEIGHT_WIDTH                ( WEIGHT_WIDTH                ),
//--    .MACC_OUT_WIDTH              ( MACC_OUT_WIDTH              ),
//--    .NUM_PE                      ( NUM_PE                      )
//--) u_PU2 (
//--    // PORTS
//--    .CLK                         ( FCLK_CLK0                   ),  //input
//--    .RESET                       ( FCLK_RESET0               ),  //input
//--    .GLOBAL_DATA                 ( PU2_in_data                 ),  //input
//--    .MEM_OUTBUF_READY            ( PU2_mem_outbuf_ready        ),  //input
//--    .MEM_INBUF_READY             ( PU2_mem_inbuf_ready         ),  //input
//--    .POP_MEM_BUF                 ( PU2_pop_mem_buf             ),  //output
//--    //.FEED_LAST_PE                ( PU2_in_data[DATA_WIDTH-1:0] ),  //input
//--    .MACC_DATA_OUT               ( PU2_out_data                ),  //output
//--    .DATA_VALID                  ( PU2_data_valid              )   //output
//--);
//--
//--scfifo HP2_inbuf (
//--    .clock                       ( FCLK_CLK0                   ),  //input
//--    .aclr                        ( FCLK_RESET0               ),  //input
//--    .empty                       ( HP2_inBuf_Read_empty        ),  //output
//--    .q                           ( HP2_inBuf_Read_rd_data      ),  //input
//--    .rdreq                       ( HP2_inBuf_Read_rd_en        ),  //input
//--    .full                        ( HP2_inBuf_Write_full        ),  //output
//--    .data                        ( HP2_inBuf_Write_wr_data     ),  //output
//--    .wrreq                       ( HP2_inBuf_Write_wr_en       )   //input
//--    );
//--
//--scfifo HP2_outbuf (
//--    .clock                       ( FCLK_CLK0                   ),  //input
//--    .aclr                        ( FCLK_RESET0               ),  //input
//--    .empty                       ( HP2_outBuf_Read_empty       ),  //output
//--    .q                           ( HP2_outBuf_Read_rd_data     ),  //input
//--    .rdreq                       ( HP2_outBuf_Read_rd_en       ),  //input
//--    .full                        ( HP2_outBuf_Write_full       ),  //output
//--    .data                        ( HP2_outBuf_Write_wr_data    ),  //output
//--    .wrreq                       ( HP2_outBuf_Write_wr_en      )   //input
//--    );

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// Buffers for HP3 interface
/////////////////////////////////////////////////////////////////////////////
//--// PU
//--
//--    reg  [NUM_PE*DATA_WIDTH-1:0]        PU3_in_data;
//--    wire                                PU3_mem_inbuf_ready;
//--    wire                                PU3_pop_mem_buf;
//--    wire                                PU3_data_valid;
//--    wire [NUM_PE*DATA_WIDTH-1:0]        PU3_out_data;
//--
//--    reg  [NUM_PE*DATA_WIDTH-1:0]        PU3_out_data_outBuf;
//--
//--
//--    //assign  PU3_in_data               = HP3_inBuf_Read_rd_data;
//--    assign  PU3_mem_inbuf_ready         = !HP3_inBuf_Read_empty;
//--    assign  HP3_inBuf_Read_rd_en        = PU3_pop_mem_buf;
//--
//--    assign  PU3_mem_outbuf_ready        = !HP3_outBuf_Write_full && PU3_count == 0;
//--    assign  HP3_outBuf_Write_wr_data    = PU3_out_data_outBuf[63:0];
//--    assign  HP3_outBuf_Write_wr_en      = PU3_data_valid;
//--
//--
//--    always @ (posedge FCLK_CLK0)
//--    begin
//--        if (FCLK_RESET0) begin
//--            PU3_in_data <= 0;
//--        end else if (PU3_pop_mem_buf) begin
//--            PU3_in_data <= HP3_inBuf_Read_rd_data;
//--        end else begin
//--            PU3_in_data <= {PU3_in_data[NUM_PE*DATA_WIDTH-1-64:0], HP3_inBuf_Read_rd_data};
//--        end
//--    end
//--
//--    reg [10:0] PU3_count;
//--    always @ (posedge FCLK_CLK0)
//--    begin
//--        if (FCLK_RESET0) begin
//--            PU3_out_data_outBuf <= 0;
//--            PU3_count <= 0;
//--        end 
//--        else if (PU3_data_valid) begin
//--            PU3_out_data_outBuf <= PU3_out_data;
//--            PU3_count <= 1;
//--        end 
//--        else if (PU3_count != 0) begin
//--            PU3_out_data_outBuf <= {PU3_out_data_outBuf} >> 64;
//--            PU3_count <= PU3_count + 1;
//--        end
//--    end
//--
//--
//--PU #(
//--    // INPUT PARAMETERS
//--    .DATA_WIDTH                  ( DATA_WIDTH                  ),
//--    .WEIGHT_WIDTH                ( WEIGHT_WIDTH                ),
//--    .MACC_OUT_WIDTH              ( MACC_OUT_WIDTH              ),
//--    .NUM_PE                      ( NUM_PE                      )
//--) u_PU3 (
//--    // PORTS
//--    .CLK                         ( FCLK_CLK0                   ),  //input
//--    .RESET                       ( FCLK_RESET0               ),  //input
//--    .GLOBAL_DATA                 ( PU3_in_data                 ),  //input
//--    .MEM_OUTBUF_READY            ( PU3_mem_outbuf_ready        ),  //input
//--    .MEM_INBUF_READY             ( PU3_mem_inbuf_ready         ),  //input
//--    .POP_MEM_BUF                 ( PU3_pop_mem_buf             ),  //output
//--    //.FEED_LAST_PE                ( PU3_in_data[DATA_WIDTH-1:0] ),  //input
//--    .MACC_DATA_OUT               ( PU3_out_data                ),  //output
//--    .DATA_VALID                  ( PU3_data_valid              )   //output
//--);
//--
//--scfifo HP3_inbuf (
//--    .clock                       ( FCLK_CLK0                   ),  //input
//--    .aclr                        ( FCLK_RESET0               ),  //input
//--    .empty                       ( HP3_inBuf_Read_empty        ),  //output
//--    .q                           ( HP3_inBuf_Read_rd_data      ),  //input
//--    .rdreq                       ( HP3_inBuf_Read_rd_en        ),  //input
//--    .full                        ( HP3_inBuf_Write_full        ),  //output
//--    .data                        ( HP3_inBuf_Write_wr_data     ),  //output
//--    .wrreq                       ( HP3_inBuf_Write_wr_en       )   //input
//--    );
//--
//--scfifo HP3_outbuf (
//--    .clock                       ( FCLK_CLK0                   ),  //input
//--    .aclr                        ( FCLK_RESET0               ),  //input
//--    .empty                       ( HP3_outBuf_Read_empty       ),  //output
//--    .q                           ( HP3_outBuf_Read_rd_data     ),  //input
//--    .rdreq                       ( HP3_outBuf_Read_rd_en       ),  //input
//--    .full                        ( HP3_outBuf_Write_full       ),  //output
//--    .data                        ( HP3_outBuf_Write_wr_data    ),  //output
//--    .wrreq                       ( HP3_outBuf_Write_wr_en      )   //input
//--    );

/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
//
/////////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////////
// AXI Interface
axi_master
#(
    .C_M_AXI_READ_TARGET         ( READ_ADDR_BASE_0            ),
    .C_M_AXI_WRITE_TARGET        ( WRITE_ADDR_BASE_0           )
)
axim_hp0
   (
    // System Signals
    .ACLK                        ( FCLK_CLK0                   ),  //input
    .ARESETN                     ( FCLK_RESET0               ),  //input

    // Master Interface Write Address
    .M_AXI_AWID                  ( S_AXI_HP0_awid              ),  //output
    .M_AXI_AWADDR                ( S_AXI_HP0_awaddr            ),  //output
    .M_AXI_AWLEN                 ( S_AXI_HP0_awlen             ),  //output
    .M_AXI_AWSIZE                ( S_AXI_HP0_awsize            ),  //output
    .M_AXI_AWBURST               ( S_AXI_HP0_awburst           ),  //output
    .M_AXI_AWLOCK                ( S_AXI_HP0_awlock            ),  //output
    .M_AXI_AWCACHE               ( S_AXI_HP0_awcache           ),  //output
    .M_AXI_AWPROT                ( S_AXI_HP0_awprot            ),  //output
    .M_AXI_AWQOS                 ( S_AXI_HP0_awqos             ),  //output
    .M_AXI_AWVALID               ( S_AXI_HP0_awvalid           ),  //output
    .M_AXI_AWREADY               ( S_AXI_HP0_awready           ),  //input

    // Master Interface Write Data
    .M_AXI_WID                   ( S_AXI_HP0_wid               ),  //output
    .M_AXI_WDATA                 ( S_AXI_HP0_wdata             ),  //output
    .M_AXI_WSTRB                 ( S_AXI_HP0_wstrb             ),  //output
    .M_AXI_WLAST                 ( S_AXI_HP0_wlast             ),  //output
    .M_AXI_WVALID                ( S_AXI_HP0_wvalid            ),  //output
    .M_AXI_WREADY                ( S_AXI_HP0_wready            ),  //input

    // Master Interface Write Response
    .M_AXI_BID                   ( S_AXI_HP0_bid               ),  //input
    .M_AXI_BRESP                 ( S_AXI_HP0_bresp             ),  //input
    .M_AXI_BVALID                ( S_AXI_HP0_bvalid            ),  //input
    .M_AXI_BREADY                ( S_AXI_HP0_bready            ),  //output

    // Master Interface Read Address
    .M_AXI_ARID                  ( S_AXI_HP0_arid              ),  //output
    .M_AXI_ARADDR                ( S_AXI_HP0_araddr            ),  //output
    .M_AXI_ARLEN                 ( S_AXI_HP0_arlen             ),  //output
    .M_AXI_ARSIZE                ( S_AXI_HP0_arsize            ),  //output
    .M_AXI_ARBURST               ( S_AXI_HP0_arburst           ),  //output
    .M_AXI_ARLOCK                ( S_AXI_HP0_arlock            ),  //output
    .M_AXI_ARCACHE               ( S_AXI_HP0_arcache           ),  //output
    .M_AXI_ARQOS                 ( S_AXI_HP0_arqos             ),  //output
    .M_AXI_ARPROT                ( S_AXI_HP0_arprot            ),  //output
    .M_AXI_ARVALID               ( S_AXI_HP0_arvalid           ),  //output
    .M_AXI_ARREADY               ( S_AXI_HP0_arready           ),  //input

    // Master Interface Read Data
    .M_AXI_RID                   ( S_AXI_HP0_rid               ),  //input
    .M_AXI_RDATA                 ( S_AXI_HP0_rdata             ),  //input
    .M_AXI_RRESP                 ( S_AXI_HP0_rresp             ),  //input
    .M_AXI_RLAST                 ( S_AXI_HP0_rlast             ),  //input
    .M_AXI_RVALID                ( S_AXI_HP0_rvalid            ),  //input
    .M_AXI_RREADY                ( S_AXI_HP0_rready            ),  //output

    .outBuf_empty                ( HP0_outBuf_Read_empty       ),
    .outBuf_pop                  ( HP0_outBuf_Read_rd_en       ),
    .data_from_outBuf            ( HP0_outBuf_Read_rd_data     ),

    .data_to_inBuf               ( HP0_inBuf_Write_wr_data     ),
    .inBuf_push                  ( HP0_inBuf_Write_wr_en       ),
    .inBuf_full                  ( HP0_inBuf_Write_full        )
    );

//axi_master_v4
//#(
//    .C_M_AXI_READ_TARGET         ( READ_ADDR_BASE_1            ),
//    .C_M_AXI_WRITE_TARGET        ( WRITE_ADDR_BASE_1           )
//)
//axim_hp1
//   (
//    // System Signals
//    .ACLK                        ( FCLK_CLK0                   ),  //input
//    .ARESETN                     ( FCLK_RESET0               ),  //input
//
//    // Master Interface Write Address
//    .M_AXI_AWID                  ( S_AXI_HP1_awid              ),  //output
//    .M_AXI_AWADDR                ( S_AXI_HP1_awaddr            ),  //output
//    .M_AXI_AWLEN                 ( S_AXI_HP1_awlen             ),  //output
//    .M_AXI_AWSIZE                ( S_AXI_HP1_awsize            ),  //output
//    .M_AXI_AWBURST               ( S_AXI_HP1_awburst           ),  //output
//    .M_AXI_AWLOCK                ( S_AXI_HP1_awlock            ),  //output
//    .M_AXI_AWCACHE               ( S_AXI_HP1_awcache           ),  //output
//    .M_AXI_AWPROT                ( S_AXI_HP1_awprot            ),  //output
//    .M_AXI_AWQOS                 ( S_AXI_HP1_awqos             ),  //output
//    .M_AXI_AWVALID               ( S_AXI_HP1_awvalid           ),  //output
//    .M_AXI_AWREADY               ( S_AXI_HP1_awready           ),  //input
//
//    // Master Interface Write Data
//    .M_AXI_WID                   ( S_AXI_HP1_wid               ),  //output
//    .M_AXI_WDATA                 ( S_AXI_HP1_wdata             ),  //output
//    .M_AXI_WSTRB                 ( S_AXI_HP1_wstrb             ),  //output
//    .M_AXI_WLAST                 ( S_AXI_HP1_wlast             ),  //output
//    .M_AXI_WVALID                ( S_AXI_HP1_wvalid            ),  //output
//    .M_AXI_WREADY                ( S_AXI_HP1_wready            ),  //input
//
//    // Master Interface Write Response
//    .M_AXI_BID                   ( S_AXI_HP1_bid               ),  //input
//    .M_AXI_BRESP                 ( S_AXI_HP1_bresp             ),  //input
//    .M_AXI_BVALID                ( S_AXI_HP1_bvalid            ),  //input
//    .M_AXI_BREADY                ( S_AXI_HP1_bready            ),  //output
//
//    // Master Interface Read Address
//    .M_AXI_ARID                  ( S_AXI_HP1_arid              ),  //output
//    .M_AXI_ARADDR                ( S_AXI_HP1_araddr            ),  //output
//    .M_AXI_ARLEN                 ( S_AXI_HP1_arlen             ),  //output
//    .M_AXI_ARSIZE                ( S_AXI_HP1_arsize            ),  //output
//    .M_AXI_ARBURST               ( S_AXI_HP1_arburst           ),  //output
//    .M_AXI_ARLOCK                ( S_AXI_HP1_arlock            ),  //output
//    .M_AXI_ARCACHE               ( S_AXI_HP1_arcache           ),  //output
//    .M_AXI_ARQOS                 ( S_AXI_HP1_arqos             ),  //output
//    .M_AXI_ARPROT                ( S_AXI_HP1_arprot            ),  //output
//    .M_AXI_ARVALID               ( S_AXI_HP1_arvalid           ),  //output
//    .M_AXI_ARREADY               ( S_AXI_HP1_arready           ),  //input
//
//    // Master Interface Read Data
//    .M_AXI_RID                   ( S_AXI_HP1_rid               ),  //input
//    .M_AXI_RDATA                 ( S_AXI_HP1_rdata             ),  //input
//    .M_AXI_RRESP                 ( S_AXI_HP1_rresp             ),  //input
//    .M_AXI_RLAST                 ( S_AXI_HP1_rlast             ),  //input
//    .M_AXI_RVALID                ( S_AXI_HP1_rvalid            ),  //input
//    .M_AXI_RREADY                ( S_AXI_HP1_rready            ),  //output
//
//    .outBuf_empty                ( HP1_outBuf_Read_empty       ),
//    .outBuf_pop                  ( HP1_outBuf_Read_rd_en       ),
//    .data_from_outBuf            ( HP1_outBuf_Read_rd_data     ),
//
//    .data_to_inBuf               ( HP1_inBuf_Write_wr_data     ),
//    .inBuf_push                  ( HP1_inBuf_Write_wr_en       ),
//    .inBuf_full                  ( HP1_inBuf_Write_full        )
//    );

endmodule
