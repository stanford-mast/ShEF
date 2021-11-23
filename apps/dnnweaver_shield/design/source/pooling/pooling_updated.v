`timescale 1ns/1ps
module pooling 
#(  // INPUT PARAMETERS
    parameter DATA_WIDTH   = 16,
    parameter NUM_COMPARATOR = 1,
    parameter NUM_PE       = 4,
    parameter POOL_X       = 2,
    parameter POOL_Y       = 2,
    parameter COUNTER_WIDTH = 4
)
(   // PORTS
    input  wire                             CLK,
    input  wire                             RESET,
    input  wire                             ENABLE,
    input  wire [ DATA_IN_WIDTH   -1 : 0]   DATA_IN,
    output wire [ DATA_OUT_WIDTH  -1 : 0]   DATA_OUT,
    output wire                             OUT_VALID
);

// ******************************************************************
// LOCALPARAMS
// ******************************************************************
    localparam integer DATA_IN_WIDTH  = DATA_WIDTH * NUM_PE;
    localparam integer DATA_OUT_WIDTH = DATA_WIDTH * NUM_PE;

// ******************************************************************
// Wires and Regs
// ******************************************************************
    wire [ DATA_WIDTH     -1 : 0]   row_fifo_in;
    wire [ DATA_WIDTH     -1 : 0]   row_fifo_out;
    wire                            row_fifo_push;
    wire                            row_fifo_pop;
    wire                            row_fifo_pop_d;
    wire                            row_fifo_empty;

    wire [ DATA_IN_WIDTH  -1 : 0]   pool_fifo_in;
    wire [ DATA_OUT_WIDTH -1 : 0]   SIPO_OUT;
    wire [ DATA_OUT_WIDTH -1 : 0]   pool_fifo_out;
    wire                            pool_fifo_push;
    wire                            pool_fifo_pop;
    wire                            pool_fifo_pop_d;
    wire                            pool_fifo_empty;

    wire                            piso_output;

    wire                            pool_piso_load;
    reg                             pool_piso_shift;
    wire [ DATA_IN_WIDTH  -1 : 0]   pool_piso_in;
    wire [ DATA_WIDTH*2   -1 : 0]   pool_piso_out;


    wire [ DATA_WIDTH     -1 : 0]   comp_in_0;
    wire [ DATA_WIDTH     -1 : 0]   comp_in_1;
    wire [ DATA_WIDTH     -1 : 0]   comp_out;
    wire [ DATA_WIDTH     -1 : 0]   comp_out_d;
    wire [ DATA_WIDTH     -1 : 0]   comp2_out;
    wire [ DATA_WIDTH     -1 : 0]   mux_out;

    wire                            sel;
    wire                            sel_d;

    reg  [ 1              -1 : 0]   shift;

    wire                            pool_w_inc;
    wire [ COUNTER_WIDTH  -1 : 0]   pool_w_count;
    wire [ COUNTER_WIDTH  -1 : 0]   pool_w_max_count;
    wire                            pool_w_overflow;

    wire                            pool_h_inc;
    wire [ COUNTER_WIDTH  -1 : 0]   pool_h_count;
    wire [ COUNTER_WIDTH  -1 : 0]   pool_h_max_count;
    wire                            pool_h_overflow;

    wire                            comp_done;

// ******************************************************************
// Pool-FIFO-Input
// ******************************************************************
    assign pool_fifo_in = DATA_IN;
    assign pool_fifo_push = ENABLE;
    fifo#(
        .DATA_WIDTH         ( DATA_IN_WIDTH     ),
        .ADDR_WIDTH         ( 4                 )
    ) pool_fifo (
        .clk                ( CLK               ),  //input
        .reset              ( RESET             ),  //input
        .push               ( pool_fifo_push    ),  //input
        .pop                ( pool_fifo_pop     ),  //input
        .data_in            ( pool_fifo_in      ),  //input
        .data_out           ( pool_fifo_out     ),  //output
        .full               (                   ),  //output
        .empty              ( pool_fifo_empty   ),  //output
        .fifo_count         (                   )   //output
    );

    assign pool_fifo_pop = !pool_fifo_empty && shift== 0;
    register #(1) pool_piso_dly (CLK, RESET, pool_fifo_pop, pool_fifo_pop_d);

    assign pool_piso_in = pool_fifo_out;

    counter #(
        .COUNT_WIDTH            ( 1                           )
    )
    weight_addr_counter (
        .CLK                    ( CLK                         ),  //input
        .RESET                  ( RESET                       ),  //input
        .CLEAR                  ( 0                           ),  //input
        .DEFAULT                ( 0                           ),  //input
        .INC                    ( pool_piso_load || pool_piso_shift               ),  //input
        .DEC                    ( 0                           ),  //input
        .MIN_COUNT              ( 0                           ),  //input
        .MAX_COUNT              ( 1                           ),  //input
        .OVERFLOW               (                             ),  //output
        .COUNT                  ( shift_load                  )   //output
    );

    assign pool_piso_load  = pool_fifo_pop_d;
    //assign pool_piso_shift = (|shift);

    always @(posedge CLK)
    begin
        if (RESET)
            pool_piso_shift <= 0;
        else
            pool_piso_shift <= |shift;
    end

    always @(posedge CLK)
    begin: DATA_SHIFT
        if (RESET)
            shift <= 0;
        else 
            shift <= {pool_fifo_pop};
    end

    piso 
    #( // INPUT PARAMETERS
        .DATA_IN_WIDTH      ( DATA_IN_WIDTH ),
        .DATA_OUT_WIDTH     ( DATA_WIDTH*2  )
    ) pool_piso
    (  // PORTS
        .CLK                ( CLK               ),
        .RESET              ( RESET             ),
        .LOAD               ( pool_piso_load    ),
        .SHIFT              ( pool_piso_shift   ),
        .DATA_IN            ( pool_piso_in      ),
        .DATA_OUT           ( pool_piso_out     )
    );

    assign {comp_in_0, comp_in_1} = pool_piso_out;

    comparator#(
        .DATA_WIDTH         ( DATA_WIDTH        )
    ) pool_comp1 (
        .CLK                ( CLK               ),
        .RESET              ( RESET             ),
        .DATA_IN_0          ( comp_in_0         ),
        .DATA_IN_1          ( comp_in_1         ),
        .COMP_OUT           ( comp_out          )
    );
    comparator#(
        .DATA_WIDTH         ( DATA_WIDTH        )
    ) pool_comp2 (
        .CLK                ( CLK               ),
        .RESET              ( RESET             ),
        .DATA_IN_0          ( comp_out          ),
        .DATA_IN_1          ( row_fifo_out      ),
        .COMP_OUT           ( comp2_out         )
    );

    assign sel = !ENABLE;//row_fifo_pop;

    register #(0, DATA_WIDTH) comp_reg (CLK, RESET, comp_out, comp_out_d);
    register #(4) sel_delay (CLK, RESET, sel, sel_d);
    mux_2x1 #(
        .DATA_WIDTH         ( DATA_WIDTH        ),
        .REGISTERED         ( "NO"              )
    ) fifo_input_mux (
        .clk                ( CLK               ),
        .reset              ( RESET             ),
        .in_0               ( comp_out_d        ), 
        .in_1               ( comp2_out         ), 
        .sel                ( sel_d             ), 
        .out                ( mux_out           )
    );


    register #(0) row_fifo_push_reg (CLK, RESET, (pool_piso_load||pool_piso_shift), comp_done);
    //register #(1) mux_sel_d (CLK, RESET,  (pool_h_count != 0), sel);
    register #(0) row_fifo_pop_reg (CLK, RESET,  (pool_h_count == 0 && (pool_w_count > 4) || pool_h_count != 0), row_fifo_pop);

    assign row_fifo_in = comp_out;
    //assign row_fifo_pop = pool_h_count != 0;
    assign row_fifo_push = comp_done && pool_h_count != 1;
    //assign row_fifo_pop  = !row_fifo_empty;

    fifo#(
        .DATA_WIDTH         ( DATA_WIDTH        ),
        .ADDR_WIDTH         ( 4                 )
    ) row_fifo (
        .clk                ( CLK               ),  //input
        .reset              ( RESET             ),  //input
        .push               ( row_fifo_push     ),  //input
        .pop                ( row_fifo_pop      ),  //input
        .data_in            ( mux_out           ),  //input
        .data_out           ( row_fifo_out      ),  //output
        .full               (                   ),  //output
        .empty              ( row_fifo_empty    ),  //output
        .fifo_count         (                   )   //output
    );


    assign pool_w_max_count = NUM_PE-1;
    //assign pool_w_inc = row_fifo_push;
    assign pool_w_inc = (pool_piso_load||pool_piso_shift);
    counter #(
        .COUNT_WIDTH        ( COUNTER_WIDTH         )
    )
    pool_width_counter (
        .CLK                ( CLK                   ),  //input
        .RESET              ( RESET                 ),  //input
        .CLEAR              ( 0                     ),  //input
        .DEFAULT            ( 0                     ),  //input
        .INC                ( pool_w_inc            ),  //input
        .DEC                ( 0                     ),  //input
        .MIN_COUNT          ( 0                     ),  //input
        .MAX_COUNT          ( pool_w_max_count      ),  //input
        .OVERFLOW           ( pool_w_overflow       ),  //output
        .COUNT              ( pool_w_count          )   //output
    );

    assign pool_h_inc = pool_w_overflow;
    assign pool_h_max_count = POOL_X;
     
    counter #(
        .COUNT_WIDTH        ( COUNTER_WIDTH         )
    )
    pool_height_counter (
        .CLK                ( CLK                   ),  //input
        .RESET              ( RESET                 ),  //input
        .CLEAR              ( 0                     ),  //input
        .DEFAULT            ( 0                     ),  //input
        .INC                ( pool_h_inc            ),  //input
        .DEC                ( 0                     ),  //input
        .MIN_COUNT          ( 0                     ),  //input
        .MAX_COUNT          ( pool_h_max_count      ),  //input
        .OVERFLOW           ( pool_h_overflow       ),  //output
        .COUNT              ( pool_h_count          )   //output
    );

    //assign DATA_OUT = mux_out;
    //assign OUT_VALID = !row_fifo_push;
    //assign OUT_VALID = comp_done && pool_h_count == 1;
    assign sipo_enable = ENABLE;//comp_done && pool_h_count == 1;
    
    sipo #( 
        // INPUT PARAMETERS
        .DATA_IN_WIDTH      ( DATA_WIDTH            ),
        .DATA_OUT_WIDTH     ( DATA_OUT_WIDTH        )
    ) sipo_output ( 
        // PORTS
        .CLK                ( CLK                   ),
        .RESET              ( RESET                 ),
        .ENABLE             ( sipo_enable           ),
        .DATA_IN            ( mux_out               ),
        .READY              (                       ),
        .DATA_OUT           ( DATA_OUT              ),
        .OUT_VALID          ( OUT_VALID             )
    );

endmodule
