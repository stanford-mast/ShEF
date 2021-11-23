`timescale 1ns/1ps
module top_tb();
    initial
    begin
        $dumpfile("TB.vcd");
        $dumpvars(0,top_tb);
    end
// ******************************************************************
// local parameters
// ******************************************************************
 
    //localparam integer TYPE                               = "LOOPBACK";    
    //localparam integer TYPE                               = "MULTIPLIER";    
    localparam         TYPE                               = "PU";    
    localparam integer NUM_PE                             = 4;
    localparam integer DATA_WIDTH                         = 16;

    localparam integer READ_ADDR_BASE_0                   = 32'h00000000;
    localparam integer WRITE_ADDR_BASE_0                  = 32'h02000000;
    localparam         C_M_AXI_PROTOCOL                   = "AXI3";
    localparam integer C_M_AXI_THREAD_ID_WIDTH            = 6;
    localparam integer C_M_AXI_ADDR_WIDTH                 = 32;
    localparam integer C_M_AXI_DATA_WIDTH                 = 64;
    localparam integer C_M_AXI_AWUSER_WIDTH               = 1;
    localparam integer C_M_AXI_ARUSER_WIDTH               = 1;
    localparam integer C_M_AXI_WUSER_WIDTH                = 1;
    localparam integer C_M_AXI_RUSER_WIDTH                = 1;
    localparam integer C_M_AXI_BUSER_WIDTH                = 1;
   
   /* Disabling these parameters will remove any throttling.
    The resulting ERROR flag will not be useful */ 
    localparam integer C_M_AXI_SUPPORTS_WRITE             = 1;
    localparam integer C_M_AXI_SUPPORTS_READ              = 1;
   
   /* Max count of written but not yet read bursts.
    If the interconnect/slave is able to accept enough
    addresses and the read channels are stalled; the
    master will issue this many commands ahead of 
    write responses */
    localparam integer C_INTERCONNECT_M_AXI_WRITE_ISSUING = 8;
             
   // Base address of targeted slave
   //Changing read and write addresses
    localparam         C_M_AXI_READ_TARGET        = 32'hFFFF0000;
    localparam         C_M_AXI_WRITE_TARGET       = 32'hFFFF8000;
   
   
   // Number of address bits to test before wrapping   
    localparam integer C_OFFSET_WIDTH             = 8;
   
   /* Burst length for transactions; in C_M_AXI_DATA_WIDTHs.
    Non-2^n lengths will eventually cause bursts across 4K
    address boundaries.*/
   
    localparam         FIFO_ADDR_WIDTH            = 4;


    localparam integer IMAGE_WIDTH  = 10;
    localparam integer IMAGE_HEIGHT = 4;
// ******************************************************************
// IO
// ******************************************************************
    // System Signals
    reg                                  ACLK;
    reg                                  ARESETN;
    
    // Master Interface Write Address
    wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   S_AXI_HP0_awid;
    wire [C_M_AXI_ADDR_WIDTH-1:0]        S_AXI_HP0_awaddr;
    wire [4-1:0]                         S_AXI_HP0_awlen;
    wire [3-1:0]                         S_AXI_HP0_awsize;
    wire [2-1:0]                         S_AXI_HP0_awburst;
    wire [2-1:0]                         S_AXI_HP0_awlock;
    wire [4-1:0]                         S_AXI_HP0_awcache;
    wire [3-1:0]                         S_AXI_HP0_awprot;
    wire [4-1:0]                         S_AXI_HP0_awqos;
    wire [C_M_AXI_AWUSER_WIDTH-1:0]      S_AXI_HP0_awuser;
    wire                                 S_AXI_HP0_awvalid;
    wire                                 S_AXI_HP0_awready;
    
    // Master Interface Write Data
    wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   S_AXI_HP0_wid;
    wire [C_M_AXI_DATA_WIDTH-1:0]        S_AXI_HP0_wdata;
    wire [C_M_AXI_DATA_WIDTH/8-1:0]      S_AXI_HP0_wstrb;
    wire                                 S_AXI_HP0_wlast;
    wire [C_M_AXI_WUSER_WIDTH-1:0]       S_AXI_HP0_wuser;
    wire                                 S_AXI_HP0_wvalid;
    wire                                 S_AXI_HP0_wready;
    
    // Master Interface Write Response
    wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   S_AXI_HP0_bid;
    wire [2-1:0]                         S_AXI_HP0_bresp;
    wire [C_M_AXI_BUSER_WIDTH-1:0]       S_AXI_HP0_buser;
    wire                                 S_AXI_HP0_bvalid;
    wire                                 S_AXI_HP0_bready;
    
    // Master Interface Read Address
    wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   S_AXI_HP0_arid;
    wire [C_M_AXI_ADDR_WIDTH-1:0]        S_AXI_HP0_araddr;
    wire [4-1:0]                         S_AXI_HP0_arlen;
    wire [3-1:0]                         S_AXI_HP0_arsize;
    wire [2-1:0]                         S_AXI_HP0_arburst;
    wire [2-1:0]                         S_AXI_HP0_arlock;
    wire [4-1:0]                         S_AXI_HP0_arcache;
    wire [3-1:0]                         S_AXI_HP0_arprot;
    // AXI3 wire [4-1:0]          M_AXI_ARREGION;
    wire [4-1:0]                         S_AXI_HP0_arqos;
    wire [C_M_AXI_ARUSER_WIDTH-1:0]      S_AXI_HP0_aruser;
    wire                                 S_AXI_HP0_arvalid;
    wire                                 S_AXI_HP0_arready;
    
    // Master Interface Read Data 
    wire [C_M_AXI_THREAD_ID_WIDTH-1:0]   S_AXI_HP0_rid;
    wire [C_M_AXI_DATA_WIDTH-1:0]        S_AXI_HP0_rdata;
    wire [2-1:0]                         S_AXI_HP0_rresp;
    wire                                 S_AXI_HP0_rlast;
    wire [C_M_AXI_RUSER_WIDTH-1:0]       S_AXI_HP0_ruser;
    wire                                 S_AXI_HP0_rvalid;
    wire                                 S_AXI_HP0_rready;

    // OutBuf FIFO
    wire                                 outBuf_push;
    wire                                 outBuf_pop;
    wire                                 outBuf_empty;
    wire                                 outBuf_full;
    wire [C_M_AXI_DATA_WIDTH-1:0]        data_from_outBuf;
    wire [C_M_AXI_DATA_WIDTH-1:0]        data_to_outBuf;
    wire [FIFO_ADDR_WIDTH:0]             outBuf_count;

    // InBuf FIFO
    wire                                 inBuf_push;
    wire                                 inBuf_pop;
    wire                                 inBuf_empty;
    wire                                 inBuf_full;
    wire [C_M_AXI_DATA_WIDTH-1:0]        data_from_inBuf;
    wire [C_M_AXI_DATA_WIDTH-1:0]        data_to_inBuf;
    wire [FIFO_ADDR_WIDTH:0]             inBuf_count;

    // TXN REQ
    reg                                  tx_req;
    wire                                 tx_done;

    // DNN
    wire done;
    reg start;

    reg [9:0] rd_cycles;
    reg [9:0] pr_cycles;
    reg [9:0] wr_cycles;
    reg [9:0] total_cycles;
    reg       status_rd;
    reg       status_pr;
    reg       status_wr;
    reg       status_total;
// ******************************************************************
// CLOCK and RESET
// ******************************************************************

    initial begin
        ACLK = 0;
        ARESETN = 1;
        tx_req = 0;
        @(negedge ACLK);
        ARESETN = 0;
        @(negedge ACLK);
        ARESETN = 1;
        @(negedge ACLK);
        @(negedge ACLK);
        @(negedge ACLK);
        tx_req = 1;
    end

    always #1 ACLK = ~ACLK;

    initial begin
        #100000 $finish;
    end

    always @(negedge ACLK)
    begin: FINISH
        if (done_dd)
            #1000 $finish;
    end


// ******************************************************************
// PERF_COUNTERS
// ******************************************************************

    always @(posedge ACLK)
    begin : STATUS_TOTAL
        if (ARESETN == 1'b0)
            status_total <= 1'b0;
        else if (tx_req)
            status_total <= 1'b1;
    end

    always @(posedge ACLK)
    begin : STATUS_READ
        if (ARESETN == 1'b0 || (S_AXI_HP0_rlast && rd_done))
            status_rd <= 1'b0;
        else if (tx_req && ! tx_req_d)
            status_rd <= 1'b1;
    end

    always @(posedge ACLK)
    begin : STATUS_PROCESS
        if (ARESETN == 1'b0 || state == 3)
            status_pr <= 1'b0;
        else if (tx_req && state != 0)
            status_pr <= 1'b1;
    end

    always @(posedge ACLK)
    begin : STATUS_WRITE
        if (ARESETN == 1'b0 || S_AXI_HP0_wlast)
            status_wr <= 1'b0;
        else if (tx_req && S_AXI_HP0_awvalid && S_AXI_HP0_wvalid)
            status_wr <= 1'b1;
    end

    always @(posedge ACLK)
    begin : PERF_COUNT_TOTAL
        if (ARESETN == 0)
            total_cycles <= 0;
        else if (status_total)
            total_cycles <= total_cycles+1;
    end

    always @(posedge ACLK)
    begin : PERF_COUNT_READ
        if (ARESETN == 0)
            rd_cycles <= 0;
        else if (status_rd)
            rd_cycles <= rd_cycles+1;
    end

    always @(posedge ACLK)
    begin : PERF_COUNT_PROCESS
        if (ARESETN == 0)
            pr_cycles <= 0;
        else if (status_pr)
            pr_cycles <= pr_cycles+1;
    end

    always @(posedge ACLK)
    begin : PERF_COUNT_WRITE
        if (ARESETN == 0)
            wr_cycles <= 0;
        else if (status_wr)
            wr_cycles <= wr_cycles+1;
    end

    
    wire start_test = PU_tb.dnn.PU_GENBLK.u_PU0.START;
    wire start_test_dd;
    register #(2)d0(ACLK, !ARESETN, start_test, start_test_dd);
    reg testing;
    wire testing_dd;
    wire testing_d;

    register #(10)d2(!ACLK, !ARESETN, done, done_dd);

    always @(posedge ACLK)
    begin
        if (ARESETN==0)
            testing = 0;
        else if (start_test)
            testing = 1;
        else if (done_dd)
            testing = 0;
    end
    register #(1)d1(!ACLK, !ARESETN, testing, testing_dd);


reg rd_done;
reg processing_done;
reg wr_done;

always @(posedge ACLK)
begin
    if (!ARESETN)
        rd_done <= 0;
    else if (S_AXI_HP0_rlast)
        rd_done <= 1;
end

always @(posedge ACLK)
begin
    if (!ARESETN)
        processing_done <= 0;
    else if (done)
        processing_done <= 1;
end

always @(posedge ACLK)
begin
    if (!ARESETN)
        wr_done <= 0;
    else if (S_AXI_HP0_wlast)
        wr_done <= 1;
end




    wire [(NUM_PE+1)*DATA_WIDTH-1:0] test_data_in = PU_tb.dnn.PU_GENBLK.u_PU0.vectorgen_data_out;
    wire [(NUM_PE)*DATA_WIDTH-1:0] test_data_out= PU_tb.dnn.PU_GENBLK.u_PU0.MACC_DATA_OUT;
    wire [10:0] wgt          = PU_tb.dnn.PU_GENBLK.u_PU0.wgt_rom_addr_d;
    wire [1:0]  layer_type   = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.layer_type;
    wire [1:0]  state        = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.state;
    wire [1:0]  state_d;//        = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.state;

    register #(5, 2) state_delay (ACLK, !ARESETN, state, state_d);

    wire image_h_inc = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.image_h_inc;
    wire image_h_inc_dd;

    register #(3) d3 (!ACLK, !ARESETN, image_h_inc, image_h_inc_dd);

    wire[5:0] kernel_w_ID = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.kernel_w_ID;
    wire[5:0] kernel_h_ID = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.kernel_h_ID;
    wire[5:0] image_w_ID = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.image_w_ID;
    wire[5:0] image_h_ID = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.image_h_ID;

    wire[5:0] param_kw = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.kernel_width;
    wire[5:0] param_kh = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.kernel_height;
    wire[5:0] param_iw = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.num_stages;
    wire[5:0] param_ih = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.image_height;

    wire [1:0] controller_state = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.state;

    wire vecgen_pop = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.vectorgen_pop;
    wire vecgen_nextrow = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.vectorgen_nextrow;

    wire pe_fifo_push = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.PE_CTRL[4];
    wire pe_fifo_pop  = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.PE_CTRL[5];

    wire [5:0] pe_fifo_count   = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[0].u_PE.fifo_count;

    //-- integer i;
    //-- always @(posedge ACLK)
    //-- begin
    //--     if (testing_dd) begin
    //--        $write("DATA_IN:");
    //--        for (i=NUM_PE; i>=0; i=i-1) begin
    //--            $write("%3d ", test_data_in[i*DATA_WIDTH+:DATA_WIDTH]);
    //--        end
    //--        $write(", DATA_OUT:");
    //--        for (i=NUM_PE-1; i>=0; i=i-1) begin
    //--            $write("%5d ", test_data_out[i*DATA_WIDTH+:DATA_WIDTH]);
    //--        end
    //--         $write (", WEIGHT:%d || KW:%d, KH:%d, IW:%d, IH:%d", 
    //--             wgt, kernel_w_ID, kernel_h_ID, image_w_ID, image_h_ID);
    //--         //$write (" || VECGEN_POP:%b, VECGEN_NEXTROW:%b",
    //--         //    vecgen_pop, vecgen_nextrow);
    //--         $write (" || PE--push:%b, pop:%b, OUT:%d, COUNT:%d",
    //--             pe_fifo_push, pe_fifo_pop, pe_Out, pe_fifo_count);
    //--         $display;
    //--     end
    //--     if (testing_dd&&image_h_inc_dd) begin
    //--         $display;
    //--     end
    //-- end

    localparam integer PE_ID = 0;

    wire [DATA_WIDTH-1:0] lrn_weight = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[PE_ID].u_PE.DATA_OUT;
    wire [DATA_WIDTH-1:0] lrn_center = PU_tb.dnn.PU_GENBLK.u_PU0.norm_data_out[PE_ID*DATA_WIDTH+:DATA_WIDTH];

    wire acc = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.PE_CTRL[1];
    wire mul = PU_tb.dnn.PU_GENBLK.u_PU0.u_PU_Controller.PE_CTRL[2];

    wire op_mult = mul;
    wire op_macc = !mul && acc;
    wire op_madd = !mul && !acc;

    integer i;
    //-- always @(posedge ACLK)
    //-- begin
    //--     if (state_d == 1) begin
    //--         case (layer_type)
    //--             0: begin
    //--                 $display ("Convolution");
    //--                 $display ("Input Image :\t\t\t %6d X %-6d\nConvolution kernel size :\t %6d X %-6d",
    //--                     param_iw+1, param_ih+1, param_kw+1, param_kh+1);
    //--             end
    //--             1: begin
    //--                 $display ("Inner-Product");
    //--                 $display ("Input vector :\t\t\t %6d X 1\nOutput Neurons:\t\t\t %6d X 1",
    //--                     param_iw+1, param_ih+1);
    //--             end
    //--             2: $display ("Normalization");
    //--         endcase
    //--     end
    //--     if (outBuf_push) begin
    //--         $write ("OP1: %5d,   ", pe_X);
    //--         $write ("OP2: %5d,   ", pe_Y);
    //--         $write ("OP3: %5d,   ", pe_A);
    //--         $write ("Out: %5d,   ", pe_Out);
    //--         $write ("WGT: %5d    ", wgt);
    //--         //$write ("LRN_WEIGHT: %5d,   ", lrn_weight);
    //--         //$write ("LRN_CENTER: %5d,   ", lrn_center);
    //--         //$write (" || PE--push:%b, pop:%b, OUT:%d, COUNT:%d",
    //--         //    pe_fifo_push, pe_fifo_pop, pe_Out, pe_fifo_count);
    //--         //$write (", mul:%b, acc:%b", mul, acc);
    //--         //if (op_mult)
    //--         //    $write (", OP=MULT");
    //--         //if (op_macc)
    //--         //    $write (", OP=MACC");
    //--         //if (op_madd)
    //--         //    $write (", OP=MADD");
    //--         //$write (" ||  WEIGHT:%d",
    //--         //    wgt);
    //--         //$write (" || KW:%d, KH:%d, IW:%d, IH:%d", 
    //--         //    kernel_w_ID, kernel_h_ID, image_w_ID, image_h_ID);
    //--         $write (" ||  OBUF_DATA:");
    //--         for (i=NUM_PE-1; i>=0; i=i-1) begin
    //--             $write(" %6d ", data_to_outBuf[i*DATA_WIDTH+:DATA_WIDTH]);
    //--         end
    //--         $write (" ||  VEC_OUT:");
    //--         for (i=NUM_PE; i>=0; i=i-1) begin
    //--             $write(" %6d ", test_data_in[i*DATA_WIDTH+:DATA_WIDTH]);
    //--         end
    //--         $write (" ||  OBUF_PUSH:", outBuf_push);
    //--         $display;
    //--     end
    //--     //if (testing_dd&&image_h_inc_dd) begin
    //--     //    $display;
    //--     //end
    //-- end

    reg                   enable;
    reg  [DATA_WIDTH-1:0] pe_X;
    reg  [DATA_WIDTH-1:0] pe_Y;
    reg  [DATA_WIDTH-1:0] pe_A;
    reg  [DATA_WIDTH-1:0] pe_Out;




    always @(posedge ACLK)
    begin
        enable   = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[PE_ID].u_PE.MACC_pe.enable;
        if (enable) begin
        //if (outBuf_push) begin
            //pe_X   = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[i].u_PE.data_in;
            //pe_Y   = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[PE_ID].u_PE.WEIGHT;
            //pe_A   = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[PE_ID].u_PE.fifo_out;
            //pe_Out = PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[PE_ID].u_PE.DATA_OUT;

            $write ("PE0: %5d,   ", PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[0].u_PE.data_in);
            $write ("PE1: %5d,   ", PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[1].u_PE.data_in);
            $write ("PE2: %5d,   ", PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[2].u_PE.data_in);
            $write ("PE3: %5d,   ", PU_tb.dnn.PU_GENBLK.u_PU0.PE_GENBLK[3].u_PE.data_in);
            //$write ("OP1: %5d,   ", pe_X);
            //$write ("OP2: %5d,   ", pe_Y);
            //$write ("OP3: %5d,   ", pe_A);
            //$write ("Out: %5d,   ", pe_Out);
            $write ("WGT: %5d    ", wgt);
            //$write (" || PE--push:%b, pop:%b, OUT:%d, COUNT:%d",
            //    pe_fifo_push, pe_fifo_pop, pe_Out, pe_fifo_count);
            //$write (", mul:%b, acc:%b", mul, acc);
            //if (op_mult)
            //    $write (", OP=MULT");
            //if (op_macc)
            //    $write (", OP=MACC");
            //if (op_madd)
            //    $write (", OP=MADD");
            //$write (" ||  WEIGHT:%d",
            //    wgt);
            //$write (" || KW:%d, KH:%d, IW:%d, IH:%d", 
            //    kernel_w_ID, kernel_h_ID, image_w_ID, image_h_ID);
            $write (" ||  OBUF_DATA:");
            for (i=0; i< NUM_PE; i=i+1) begin
                $write(" %4d ", data_to_outBuf[i*DATA_WIDTH+:DATA_WIDTH]);
            end
            $write (" ||  VEC_OUT:");
            for (i=NUM_PE; i>=0; i=i-1) begin
                $write(" %4d ", test_data_in[i*DATA_WIDTH+:DATA_WIDTH]);
            end
            $write (" ||  OBUF_PUSH:", outBuf_push);
            $display;
        end
        if (testing_dd&&image_h_inc_dd) begin
            $display;
        end
    end

axi_master #(
    .C_M_AXI_READ_TARGET    ( READ_ADDR_BASE_0    ),
    .C_M_AXI_WRITE_TARGET   ( WRITE_ADDR_BASE_0   )
) axim_hp0 (
    // System Signals
    .ACLK                   ( ACLK                ),  //input
    .ARESETN                ( ARESETN             ),  //input
    
    // Master Interface Write Address
    .M_AXI_AWID             ( S_AXI_HP0_awid      ),  //output
    .M_AXI_AWADDR           ( S_AXI_HP0_awaddr    ),  //output
    .M_AXI_AWLEN            ( S_AXI_HP0_awlen     ),  //output
    .M_AXI_AWSIZE           ( S_AXI_HP0_awsize    ),  //output
    .M_AXI_AWBURST          ( S_AXI_HP0_awburst   ),  //output
    .M_AXI_AWLOCK           ( S_AXI_HP0_awlock    ),  //output
    .M_AXI_AWCACHE          ( S_AXI_HP0_awcache   ),  //output
    .M_AXI_AWPROT           ( S_AXI_HP0_awprot    ),  //output
    .M_AXI_AWQOS            ( S_AXI_HP0_awqos     ),  //output
    .M_AXI_AWVALID          ( S_AXI_HP0_awvalid   ),  //output
    .M_AXI_AWREADY          ( S_AXI_HP0_awready   ),  //input
    
    // Master Interface Write Data
    .M_AXI_WID              ( S_AXI_HP0_wid       ),  //output
    .M_AXI_WDATA            ( S_AXI_HP0_wdata     ),  //output
    .M_AXI_WSTRB            ( S_AXI_HP0_wstrb     ),  //output
    .M_AXI_WLAST            ( S_AXI_HP0_wlast     ),  //output
    .M_AXI_WVALID           ( S_AXI_HP0_wvalid    ),  //output
    .M_AXI_WREADY           ( S_AXI_HP0_wready    ),  //input
    
    // Master Interface Write Response
    .M_AXI_BID              ( S_AXI_HP0_bid       ),  //input
    .M_AXI_BUSER            ( S_AXI_HP0_buser     ),  //input
    .M_AXI_BRESP            ( S_AXI_HP0_bresp     ),  //input
    .M_AXI_BVALID           ( S_AXI_HP0_bvalid    ),  //input
    .M_AXI_BREADY           ( S_AXI_HP0_bready    ),  //output
   
    // Master Interface Read Address
    .M_AXI_ARID             ( S_AXI_HP0_arid      ),  //output
    .M_AXI_ARADDR           ( S_AXI_HP0_araddr    ),  //output
    .M_AXI_ARLEN            ( S_AXI_HP0_arlen     ),  //output
    .M_AXI_ARSIZE           ( S_AXI_HP0_arsize    ),  //output
    .M_AXI_ARBURST          ( S_AXI_HP0_arburst   ),  //output
    .M_AXI_ARLOCK           ( S_AXI_HP0_arlock    ),  //output
    .M_AXI_ARCACHE          ( S_AXI_HP0_arcache   ),  //output
    .M_AXI_ARQOS            ( S_AXI_HP0_arqos     ),  //output
    .M_AXI_ARPROT           ( S_AXI_HP0_arprot    ),  //output
    .M_AXI_ARVALID          ( S_AXI_HP0_arvalid   ),  //output
    .M_AXI_ARREADY          ( S_AXI_HP0_arready   ),  //input
    
    // Master Interface Read Data 
    .M_AXI_RID              ( S_AXI_HP0_rid       ),  //input
    .M_AXI_RDATA            ( S_AXI_HP0_rdata     ),  //input
    .M_AXI_RUSER            ( S_AXI_HP0_ruser     ),  //input
    .M_AXI_RRESP            ( S_AXI_HP0_rresp     ),  //input
    .M_AXI_RLAST            ( S_AXI_HP0_rlast     ),  //input
    .M_AXI_RVALID           ( S_AXI_HP0_rvalid    ),  //input
    .M_AXI_RREADY           ( S_AXI_HP0_rready    ),  //output

    // NPU Design
    // WRITE from BRAM to DDR
    .outBuf_empty           ( outBuf_empty        ),  //input
    .outBuf_pop             ( outBuf_pop          ),  //output
    .data_from_outBuf       ( data_from_outBuf    ),  //input
    .outBuf_count           ( outBuf_count        ),  //input

    // READ from DDR to BRAM
    .data_to_inBuf          ( data_to_inBuf       ),  //output
    .inBuf_push             ( inBuf_push          ),  //output
    .inBuf_full             ( inBuf_full          ),  //input
    .inBuf_count            ( inBuf_count         ),  //input

    .tx_req                 ( tx_req              ),  //input
    .tx_done                ( tx_done             )   //output
);

fifo_fwft #(
    .DATA_WIDTH         ( 64                  ),
    .ADDR_WIDTH         ( FIFO_ADDR_WIDTH     )
) fifo_outBuf (
    .clk                ( ACLK                ),  //input
    .reset              ( !ARESETN            ),  //input
    .push               ( outBuf_push         ),  //input
    .pop                ( outBuf_pop          ),  //input
    .data_in            ( data_to_outBuf      ),  //input
    .data_out           ( data_from_outBuf    ),  //output
    .empty              ( outBuf_empty        ),  //output
    .full               ( outBuf_full         ),  //output
    .fifo_count         ( outBuf_count        )   //output
);
localparam integer C_S_AXI_DATA_WIDTH = 64;
localparam integer C_S_AXI_ADDR_WIDTH = 32;

register #(
    .NUM_STAGES             ( 1                   )
) tx_req_delay (
    .CLK                    ( ACLK           ),
    .RESET                  ( !ARESETN      ),
    .DIN                    ( tx_req              ),
    .DOUT                   ( tx_req_d            )
);

always @(posedge ACLK)
begin
    if (!ARESETN)
    begin
        start <= 0;
    end else if (done)
    begin
        start <= 0;
    end else if (rd_done)
    begin
        start <= 1;
    end
end

dnn_accelerator #(
    .DATA_WIDTH         ( 64                  ),
    .BUFFER_ADDR_WIDTH  ( FIFO_ADDR_WIDTH     ),
    .TYPE               ( TYPE                ),
    .IMAGE_WIDTH        ( IMAGE_WIDTH         ),
    .IMAGE_HEIGHT       ( IMAGE_HEIGHT        ),
    .MODE               ( "SIM"               )
) dnn (
    .ACLK               ( ACLK                ), //input
    .ARESETN            ( ARESETN             ), //input
    .start              ( rd_done && start    ), //input
    .done               ( done                ), //output
    .inBuf_empty        ( inBuf_empty         ), //input
    .inBuf_count        ( inBuf_count         ), //input
    .inBuf_pop          ( inBuf_pop           ), //output
    .data_from_inBuf    ( data_from_inBuf     ), //input
    .outBuf_full        ( outBuf_full         ), //input
    .outBuf_count       ( outBuf_count        ), //input
    .outBuf_push        ( outBuf_push         ), //output
    .data_to_outBuf     ( data_to_outBuf      )  //output
);


fifo #(
    .DATA_WIDTH         ( 64                  ),
    .ADDR_WIDTH         ( FIFO_ADDR_WIDTH     )
) fifo_inBuf (
    .clk                ( ACLK                ), //input
    .reset              ( !ARESETN            ), //input
    .push               ( inBuf_push          ), //input
    .pop                ( inBuf_pop           ), //input
    .data_in            ( data_to_inBuf       ), //input
    .data_out           ( data_from_inBuf     ), //output
    .empty              ( inBuf_empty         ), //output
    .full               ( inBuf_full          ), //output
    .fifo_count         ( inBuf_count         )  //output
);

myip_v1_0_S00_AXI #(
    .C_S_AXI_ID_WIDTH       ( 6                    ),
    .C_S_AXI_DATA_WIDTH     ( 64                   ),
    .C_S_AXI_ADDR_WIDTH     ( 32                   ),
    .C_S_AXI_AWUSER_WIDTH   ( 6                    ),
    .C_S_AXI_ARUSER_WIDTH   ( 6                    ),
    .C_S_AXI_WUSER_WIDTH    ( 6                    ),
    .C_S_AXI_RUSER_WIDTH    ( 6                    ),
    .C_S_AXI_BUSER_WIDTH    ( 6                    )
) axi4_slave_full (
    .S_AXI_ACLK             ( ACLK                 ),  //input
    .S_AXI_ARESETN          ( ARESETN              ),  //input
    .S_AXI_AWID             ( S_AXI_HP0_awid       ),  //input
    .S_AXI_AWADDR           ( S_AXI_HP0_awaddr     ),  //input
    .S_AXI_AWLEN            ( S_AXI_HP0_awlen      ),  //input
    .S_AXI_AWSIZE           ( S_AXI_HP0_awsize     ),  //input
    .S_AXI_AWBURST          ( S_AXI_HP0_awburst    ),  //input
    .S_AXI_AWLOCK           ( S_AXI_HP0_awlock     ),  //input
    .S_AXI_AWCACHE          ( S_AXI_HP0_awcache    ),  //input
    .S_AXI_AWPROT           ( S_AXI_HP0_awprot     ),  //input
    .S_AXI_AWQOS            ( S_AXI_HP0_awqos      ),  //input
    .S_AXI_AWREGION         ( 0                    ),  //input
    .S_AXI_AWUSER           ( S_AXI_HP0_awuser     ),  //input
    .S_AXI_AWVALID          ( S_AXI_HP0_awvalid    ),  //input
    .S_AXI_AWREADY          ( S_AXI_HP0_awready    ),  //output
    .S_AXI_WDATA            ( S_AXI_HP0_wdata      ),  //input
    .S_AXI_WSTRB            ( S_AXI_HP0_wstrb      ),  //input
    .S_AXI_WLAST            ( S_AXI_HP0_wlast      ),  //input
    .S_AXI_WUSER            ( S_AXI_HP0_wuser      ),  //input
    .S_AXI_WVALID           ( S_AXI_HP0_wvalid     ),  //input
    .S_AXI_WREADY           ( S_AXI_HP0_wready     ),  //output
    .S_AXI_BID              ( S_AXI_HP0_bid        ),  //output
    .S_AXI_BRESP            ( S_AXI_HP0_bresp      ),  //output
    .S_AXI_BUSER            ( S_AXI_HP0_buser      ),  //output
    .S_AXI_BVALID           ( S_AXI_HP0_bvalid     ),  //output
    .S_AXI_BREADY           ( S_AXI_HP0_bready     ),  //input
    .S_AXI_ARID             ( S_AXI_HP0_arid       ),  //input
    .S_AXI_ARADDR           ( S_AXI_HP0_araddr     ),  //input
    .S_AXI_ARLEN            ( S_AXI_HP0_arlen      ),  //input
    .S_AXI_ARSIZE           ( S_AXI_HP0_arsize     ),  //input
    .S_AXI_ARBURST          ( S_AXI_HP0_arburst    ),  //input
    .S_AXI_ARLOCK           ( S_AXI_HP0_arlock     ),  //input
    .S_AXI_ARCACHE          ( S_AXI_HP0_arcache    ),  //input
    .S_AXI_ARPROT           ( S_AXI_HP0_arprot     ),  //input
    .S_AXI_ARQOS            ( S_AXI_HP0_arqos      ),  //input
    .S_AXI_ARREGION         ( 0                    ),  //input
    .S_AXI_ARUSER           ( S_AXI_HP0_aruser     ),  //input
    .S_AXI_ARVALID          ( S_AXI_HP0_arvalid    ),  //input
    .S_AXI_ARREADY          ( S_AXI_HP0_arready    ),  //output
    .S_AXI_RID              ( S_AXI_HP0_rid        ),  //output
    .S_AXI_RDATA            ( S_AXI_HP0_rdata      ),  //output
    .S_AXI_RRESP            ( S_AXI_HP0_rresp      ),  //output
    .S_AXI_RLAST            ( S_AXI_HP0_rlast      ),  //output
    .S_AXI_RUSER            ( S_AXI_HP0_ruser      ),  //output
    .S_AXI_RVALID           ( S_AXI_HP0_rvalid     ),  //output
    .S_AXI_RREADY           ( S_AXI_HP0_rready     )   //input
    );

endmodule
