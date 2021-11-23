`timescale 1ns/1ps
module axi_slave_tb;
// ******************************************************************
// PARAMETERS
// ******************************************************************
    parameter integer PERF_CNTR_WIDTH       = 32;
    parameter integer AXIS_DATA_WIDTH       = 32;
    parameter integer AXIS_ADDR_WIDTH       = 6;
    parameter integer VERBOSITY             = 1;
// ******************************************************************

// ******************************************************************
// Wires and Regs
// ******************************************************************

    reg                                     ACLK;
    reg                                     ARESETN;

    wire                                    tx_req;
    wire                                    tx_done;
    wire                                    rd_done;
    wire                                    wr_done;
    wire                                    processing_done;

    wire [PERF_CNTR_WIDTH-1:0]              total_cycles;
    wire [PERF_CNTR_WIDTH-1:0]              rd_cycles;
    wire [PERF_CNTR_WIDTH-1:0]              pr_cycles;
    wire [PERF_CNTR_WIDTH-1:0]              wr_cycles;

    wire[AXIS_ADDR_WIDTH-1 : 0]             S_AXI_AWADDR;
    wire[2 : 0]                             S_AXI_AWPROT;
    wire                                    S_AXI_AWVALID;
    wire                                    S_AXI_AWREADY;

    wire [AXIS_DATA_WIDTH-1 : 0]            S_AXI_WDATA;
    wire [(AXIS_DATA_WIDTH/8)-1 : 0]        S_AXI_WSTRB;
    wire                                    S_AXI_WVALID;
    wire                                    S_AXI_WREADY;

    wire[1 : 0]                             S_AXI_BRESP;
    wire                                    S_AXI_BVALID;
    wire                                    S_AXI_BREADY;

    wire [AXIS_ADDR_WIDTH-1 : 0]            S_AXI_ARADDR;
    wire [2 : 0]                            S_AXI_ARPROT;
    wire                                    S_AXI_ARVALID;
    wire                                    S_AXI_ARREADY;

    wire[AXIS_DATA_WIDTH-1 : 0]             S_AXI_RDATA;
    wire[1 : 0]                             S_AXI_RRESP;
    wire                                    S_AXI_RVALID;
    wire                                    S_AXI_RREADY;


// ******************************************************************
initial begin
    $display("***************************************");
    $display ("Testing AXI Slave");
    $display("***************************************");
    ACLK = 0;
    ARESETN = 0;
    @(negedge ACLK);
    @(negedge ACLK);
    ARESETN = 1;
#100000

    wait (ARESETN);

    @(negedge ACLK);
    @(negedge ACLK);

    u_axis_driver.test_main;
    u_axis_driver.test_pass;
end

always #1 ACLK = ~ACLK;

always @(posedge ACLK)
begin
end

initial
begin
    $dumpfile("hw-imp/bin/waveform/axi_slave.vcd");
    $dumpvars(0,axi_slave_tb);
end

// ******************************************************************
// DUT - AXI-Slave
// ******************************************************************
    axi4lite_slave #(
        .AXIS_DATA_WIDTH        ( AXIS_DATA_WIDTH       ),
        .AXIS_ADDR_WIDTH        ( AXIS_ADDR_WIDTH       ),
        .PERF_CNTR_WIDTH        ( PERF_CNTR_WIDTH       )
    ) axi_slave_i (
        .S_AXI_ACLK             ( ACLK                  ),  //input
        .S_AXI_ARESETN          ( ARESETN               ),  //input
    
        .S_AXI_AWADDR           ( S_AXI_AWADDR          ),  //input
        .S_AXI_AWPROT           ( S_AXI_AWPROT          ),  //input
        .S_AXI_AWVALID          ( S_AXI_AWVALID         ),  //input
        .S_AXI_AWREADY          ( S_AXI_AWREADY         ),  //output
    
        .S_AXI_WDATA            ( S_AXI_WDATA           ),  //input
        .S_AXI_WSTRB            ( S_AXI_WSTRB           ),  //input
        .S_AXI_WVALID           ( S_AXI_WVALID          ),  //input
        .S_AXI_WREADY           ( S_AXI_WREADY          ),  //output
    
        .S_AXI_BRESP            ( S_AXI_BRESP           ),  //output
        .S_AXI_BVALID           ( S_AXI_BVALID          ),  //output
        .S_AXI_BREADY           ( S_AXI_BREADY          ),  //input
    
        .S_AXI_ARADDR           ( S_AXI_ARADDR          ),  //input
        .S_AXI_ARPROT           ( S_AXI_ARPROT          ),  //input
        .S_AXI_ARVALID          ( S_AXI_ARVALID         ),  //input
        .S_AXI_ARREADY          ( S_AXI_ARREADY         ),  //output
    
        .S_AXI_RDATA            ( S_AXI_RDATA           ),  //output
        .S_AXI_RRESP            ( S_AXI_RRESP           ),  //output
        .S_AXI_RVALID           ( S_AXI_RVALID          ),  //output
        .S_AXI_RREADY           ( S_AXI_RREADY          ),  //input
    
        .tx_req                 ( tx_req                ),  //output
        .tx_done                ( tx_done               ),  //input
        
        .rd_done                ( rd_done               ),  //input
        .processing_done        ( processing_done       ),  //input
        .wr_done                ( wr_done               ),  //input
    
        .total_cycles           ( total_cycles          ),  //input
        .rd_cycles              ( rd_cycles             ),  //input
        .pr_cycles              ( pr_cycles             ),  //input
        .wr_cycles              ( wr_cycles             )   //input
    );
// ******************************************************************

// ******************************************************************
// AXI_slave tb driver
// ******************************************************************
axi_slave_tb_driver
#(
    .PERF_CNTR_WIDTH            ( PERF_CNTR_WIDTH       ),
    .AXIS_DATA_WIDTH            ( AXIS_DATA_WIDTH       ),
    .AXIS_ADDR_WIDTH            ( AXIS_ADDR_WIDTH       ),
    .VERBOSITY                  ( VERBOSITY             )
) u_axis_driver (
    .tx_req                     ( tx_req                ), //input 
    .tx_done                    ( tx_done               ), //output 
    .rd_done                    ( rd_done               ), //output 
    .wr_done                    ( wr_done               ), //output 
    .processing_done            ( processing_done       ), //output 
    .total_cycles               ( total_cycles          ), //output 
    .rd_cycles                  ( rd_cycles             ), //output 
    .pr_cycles                  ( pr_cycles             ), //output 
    .wr_cycles                  ( wr_cycles             ), //output 
    .S_AXI_ACLK                 ( ACLK                  ), //output 
    .S_AXI_ARESETN              ( ARESETN               ), //output 
    .S_AXI_AWADDR               ( S_AXI_AWADDR          ), //output 
    .S_AXI_AWPROT               ( S_AXI_AWPROT          ), //output 
    .S_AXI_AWVALID              ( S_AXI_AWVALID         ), //output 
    .S_AXI_AWREADY              ( S_AXI_AWREADY         ), //input 
    .S_AXI_WDATA                ( S_AXI_WDATA           ), //output 
    .S_AXI_WSTRB                ( S_AXI_WSTRB           ), //output 
    .S_AXI_WVALID               ( S_AXI_WVALID          ), //output 
    .S_AXI_WREADY               ( S_AXI_WREADY          ), //input 
    .S_AXI_BRESP                ( S_AXI_BRESP           ), //input 
    .S_AXI_BVALID               ( S_AXI_BVALID          ), //input 
    .S_AXI_BREADY               ( S_AXI_BREADY          ), //output 
    .S_AXI_ARADDR               ( S_AXI_ARADDR          ), //output 
    .S_AXI_ARPROT               ( S_AXI_ARPROT          ), //output 
    .S_AXI_ARVALID              ( S_AXI_ARVALID         ), //output 
    .S_AXI_ARREADY              ( S_AXI_ARREADY         ), //input 
    .S_AXI_RDATA                ( S_AXI_RDATA           ), //input 
    .S_AXI_RRESP                ( S_AXI_RRESP           ), //input 
    .S_AXI_RVALID               ( S_AXI_RVALID          ), //input 
    .S_AXI_RREADY               ( S_AXI_RREADY          )  //output 
);
// ******************************************************************

endmodule
