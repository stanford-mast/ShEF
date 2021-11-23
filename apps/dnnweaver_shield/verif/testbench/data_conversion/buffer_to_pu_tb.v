`timescale 1ns/1ps
module buffer_to_pu_tb();

//**************************************************************
localparam integer IMAGE_WIDTH  = 10;
localparam integer IMAGE_HEIGHT = 10;
localparam integer PADDING      = 1;
localparam integer INPUT_WIDTH  = NUM_PE*DATA_WIDTH;
localparam integer OUTPUT_WIDTH = (NUM_PE+1)*DATA_WIDTH;
localparam integer DATA_WIDTH   = 8;
localparam integer NUM_PE       = 4;
localparam integer KERNEL_WIDTH = 3;
localparam integer KERNEL_HEIGHT= 3;
localparam integer NUM_STAGES   = (IMAGE_WIDTH-KERNEL_WIDTH+1)/NUM_PE-1;
localparam         VERBOSE      = 1;

//**************************************************************
reg                     clk;
reg                     reset;
reg                     FEED_LAST_PE;
wire [DATA_WIDTH-1:0]   SERIAL_OUTPUT;
reg  [INPUT_WIDTH-1:0]  pu_buf_data_in;
wire [INPUT_WIDTH-1:0]  pu_buf_data_out_fifo;
wire                    inbuf_pop;
reg                     pu_buf_push;
wire                    pu_buf_empty_fifo;
wire                    inbuf_empty;
wire                    pu_buf_full;
reg  [OUTPUT_WIDTH-1:0] tmp;
reg  [10:0]             cycle_count;
wire                    SERIAL_SHIFT_IN;
reg                     pop_buf_mem_d;
reg  [DATA_WIDTH-1:0]   counter;
wire                    MEM_OUTBUF_READY;
reg  [INPUT_WIDTH-1:0]  vectorgen_data_in;
wire [OUTPUT_WIDTH-1:0] vectorgen_data_out;
wire                    vectorgen_shift;
wire                    vectorgen_pop;
wire                    vectorgen_ready;
wire                    vectorgen_nextrow;

reg  [DATA_WIDTH*NUM_PE-1:0]   mem_in[IMAGE_HEIGHT*(IMAGE_WIDTH/NUM_PE+1)-1:0];
reg  [DATA_WIDTH*NUM_PE-1:0]   mem_out[(IMAGE_HEIGHT-KERNEL_HEIGHT+1)*(IMAGE_WIDTH-KERNEL_WIDTH+1)-1:0];

integer test = 1, pe, kw, kh, iw, ih=0;
//**************************************************************
initial begin
    $display ("Initializing Memory");
    counter = 1;
    iw = 0;
    for (ih=0; ih<IMAGE_HEIGHT; ih=ih+1)
    begin
        mem_in[iw] = {counter+2'h3, counter+2'd2, counter+2'd1, counter+2'd0};
        $display ("%3d) %h", iw, mem_in[iw]);
        counter = counter+4;
        iw = iw + 1;
        mem_in[iw] = {counter+2'h3, counter+2'd2, counter+2'd1, counter+2'd0};
        $display ("%3d) %h", iw, mem_in[iw]);
        counter = counter+4;
        iw = iw + 1;
        mem_in[iw] = {8'd0, 8'd0, counter+2'd1, counter+2'd0};
        $display ("%3d) %h", iw, mem_in[iw]);
        counter = counter+2;
        iw = iw + 1;
    end
end
//**************************************************************
integer mem_out_index=0;
reg [OUTPUT_WIDTH-1:0] tmp_data;
initial
begin
    if(VERBOSE==2)$display ("Initializing output memory");
    for (ih=0; ih<IMAGE_HEIGHT; ih=ih+1) begin
        for (iw=0; iw<=NUM_STAGES; iw=iw+1) begin
            for (kh=0; kh<KERNEL_HEIGHT; kh=kh+1) begin
                for (kw=0; kw<KERNEL_WIDTH; kw=kw+1) begin
                    mem_out_index = mem_out_index + 1;
                    tmp_data = 0;
                    for (pe=0; pe<NUM_PE; pe=pe+1) begin
                        tmp_data[pe*DATA_WIDTH+:DATA_WIDTH] = test+pe;
                    end
                    if (kw>0) begin
                        tmp_data[NUM_PE*DATA_WIDTH+:DATA_WIDTH] = test+kw+NUM_PE-1;
                    end
                    if(VERBOSE==2)$display ("%3d)%h", mem_out_index, tmp_data);
                end
            end
            if(VERBOSE==2)$display;
            test = test + NUM_PE;
        end
        test = test + IMAGE_WIDTH%NUM_PE;
    end
end
//**************************************************************

always #1 clk = ~clk;

initial
begin
    $dumpfile("TB.vcd");
    $dumpvars(0,buffer_to_pu_tb);
end


initial
begin
    clk = 0;
    reset = 1;
    pu_buf_push = 0;
    counter = 1;
    @(negedge clk); 
    reset = 0;
    @(negedge clk); 
    pu_buf_push = 1;
    repeat(IMAGE_HEIGHT) begin
        pu_buf_data_in = {counter+2'd3, counter+2'd2, counter+2'd1, counter+2'd0};
        @(negedge clk); 
        counter = counter + 4;
        pu_buf_data_in = {counter+2'd3, counter+2'd2, counter+2'd1, counter+2'd0};
        @(negedge clk); 
        counter = counter + 4;
        pu_buf_data_in = {16'h0, counter+2'd1, counter+2'd0};
        @(negedge clk); 
        counter = counter + 2;
    end
    @(negedge clk); 
    pu_buf_push = 0;

    #1000 $finish;
end

reg pu_buf_pop_d;
reg pu_buf_pop_dd;
always @(posedge clk)
begin
    if (reset) begin
        pu_buf_pop_d <= 0;
        pu_buf_pop_dd <= 0;
    end else begin
        pu_buf_pop_d <= inbuf_pop;
        pu_buf_pop_dd <= pu_buf_pop_d;
    end
end

integer index;

always @(posedge clk)
begin
    if (reset)
        index = 0;
    else if (inbuf_pop && vectorgen_ready) begin
        vectorgen_data_in = mem_in[index];
        //$display ("Data from mem_in index:%d, Value:%h", index, mem_in[index]);
        index = index+1;
    end
end

reg [3:0] random_num;
always @(posedge clk)
begin
    random_num = $random;
end
assign inbuf_empty = pu_buf_empty_fifo;

assign MEM_OUTBUF_READY = !pu_buf_full;

initial
begin
    cycle_count = 0;
    repeat (7) begin
        @(negedge clk);
    end
    cycle_count = 1;
end

always @ (posedge clk)
begin
    if (reset)
        tmp <= 0;
    else
        tmp <= vectorgen_data_out;
end

reg [3:0] count=0;

always @ (posedge clk)
begin
    if (cycle_count % 9 == 0 && VERBOSE)
        $display();

    if (tmp == vectorgen_data_out) begin
        count = count + 1;
    end else begin
        count = 0;
    end

    if (count> 10)
        $finish;

    if (cycle_count > 0) begin
        cycle_count = cycle_count + 1;
    end
end

integer incorrect_count = 0;
initial
begin
    @(posedge cycle_count[0]);
    test = 1;
    for (ih=0; ih<IMAGE_HEIGHT; ih=ih+1) begin
        if (VERBOSE) begin
            $display ("IMAGE_ROW #%2d", ih);
        end
        for (iw=0; iw<=NUM_STAGES; iw=iw+1) begin
            if (VERBOSE) begin
                $display ("IMAGE_WIDTH #%2d", iw);
            end
            for (kh=0; kh<KERNEL_HEIGHT; kh=kh+1) begin
                for (kw=0; kw<KERNEL_WIDTH; kw=kw+1) begin
                    //$display ("test:%d, kw:%d, kh=%d", test, kw, kh);
                    for (pe=0; pe<NUM_PE; pe=pe+1) begin
                        tmp_data[pe*DATA_WIDTH+:DATA_WIDTH] = test+pe;
                    end
                    if (kw>0)
                        tmp_data[NUM_PE*DATA_WIDTH+:DATA_WIDTH] = test+kw+NUM_PE-1;
                    else
                        tmp_data[NUM_PE*DATA_WIDTH+:DATA_WIDTH] = 8'hxx;
                    if (vectorgen_data_out != tmp_data) begin
                        $display ("%4g)Incorrect", cycle_count);
                        $display ("expecting:%2h", tmp_data);
                        $display ("got:%h", vectorgen_data_out);
                        $display ("test:%d, pe:%d, kw=%d", test, pe, kw);
                        //$finish;
                        kw = kw - 1;
                        incorrect_count = incorrect_count + 1;
                        if (incorrect_count > 3)
                            $finish;
                    end
                    else 
                        $display ("%4g)Buffer Data out:%h", cycle_count, vectorgen_data_out);
                    @(negedge clk);
                end
            end
            test = test + NUM_PE;
        end
        test = test + IMAGE_WIDTH%NUM_PE;
    end
    $display ("Test Passed");
    $finish;
end

PU_controller 
#(  // PARAMETERS
    .IMAGE_WIDTH        ( IMAGE_WIDTH       ),
    .IMAGE_HEIGHT       ( IMAGE_HEIGHT      ),
    .NUM_PE             ( NUM_PE            ),
    .WEIGHT_ADDR_WIDTH  ( 10                ),
    .PE_CTRL_WIDTH      ( 9                 )
) u_PU_Controller (   // PORTS
    .CLK                ( clk               ), //input
    .RESET              ( reset             ), //input
    .VECTORGEN_READY    ( vectorgen_ready   ), //input
    .VECTORGEN_POP      ( vectorgen_pop       ), //output
    .VECTORGEN_NEXTROW  ( vectorgen_nextrow          ), //output
    .VECTORGEN_SHIFT    ( vectorgen_shift     ), //output
    .MEM_OUTBUF_READY   ( MEM_OUTBUF_READY  ), //input
    .PE_CTRL            (                   ), //output
    .PU_BUF_CTRL        (                   ), //output
    .WGT_BUF_ADDR       (                   )  //output
);

vectorgen # (
    .DATA_WIDTH         ( DATA_WIDTH        ),
    .NUM_PE             ( NUM_PE            )
) DUT (  
    .CLK                ( clk               ),
    .RESET              ( reset             ),
    .VECTORGEN_POP      ( vectorgen_pop     ),
    .VECTORGEN_SHIFT    ( vectorgen_shift   ),
    .VECTORGEN_DATA_IN  ( vectorgen_data_in ),
    .VECTORGEN_NEXTROW  ( vectorgen_nextrow ),
    .INBUF_EMPTY        ( inbuf_empty       ),
    .INBUF_POP          ( inbuf_pop         ),
    .VECTORGEN_DATA_OUT ( vectorgen_data_out),
    .VECTORGEN_READY    ( vectorgen_ready   )
);
    
fifo #(
    .DATA_WIDTH         ( INPUT_WIDTH       ),
    .ADDR_WIDTH         ( 5                 ),
    .INITIALIZE_FIFO    ( "no"              ),
    .TYPE               ( "BLOCK"           )
) inBuf (
    .clk                ( clk               ), //input
    .reset              ( reset             ), //input
    .push               ( pu_buf_push       ), //input
    .pop                ( inbuf_pop        ), //input
    .data_in            ( pu_buf_data_in    ), //input
    .data_out           ( pu_buf_data_out_fifo   ), //output
    .empty              ( pu_buf_empty_fifo      ), //output
    .full               ( pu_buf_full       )  //output
);   

endmodule
