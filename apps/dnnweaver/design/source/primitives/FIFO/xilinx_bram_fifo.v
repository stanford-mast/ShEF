`timescale 1ns/1ps
module xilinx_bram_fifo 
#(  // Parameters
    parameter integer DATA_WIDTH                = 64,
    parameter integer ALMOST_FULL_OFFSET        = 9'h080,
    parameter integer ALMOST_EMPTY_OFFSET       = 9'h080,
    parameter         FIFO_SIZE                 = "36Kb",
    parameter         FIRST_WORD_FALL_THROUGH   = "FALSE",
    parameter         MODE                      = "SIM"
)(  // Ports
    input  wire                         RESET,

    input  wire                         RD_CLK,
    input  wire                         RD_EN,
    output wire                         RD_EMPTY,
    output wire                         RD_ALMOSTEMPTY,
    output wire [ DATA_WIDTH -1 : 0 ]   RD_DATA,
    output wire [ COUNT_WIDTH   : 0 ]   RD_COUNT,
    output wire                         RD_ERR,

    input  wire                         WR_CLK,
    input  wire                         WR_EN,
    output wire                         WR_FULL,
    output wire                         WR_ALMOSTFULL,
    input  wire [ DATA_WIDTH -1 : 0 ]   WR_DATA,
    output wire [ COUNT_WIDTH   : 0 ]   WR_COUNT,
    output wire                         WR_ERR
);    

localparam COUNT_WIDTH = ( (FIFO_SIZE == "18Kb") ? 
                         ( (DATA_WIDTH <= 4) ? 12 : (DATA_WIDTH > 4 && DATA_WIDTH <= 9) ? 11 : 
                         (DATA_WIDTH > 9 && DATA_WIDTH <= 18) ? 10 : (DATA_WIDTH > 18 && DATA_WIDTH <= 36) ? 9 : 12 ) : 
                         (FIFO_SIZE == "36Kb") ? 
                         ( (DATA_WIDTH <= 4) ? 13 : (DATA_WIDTH > 4 && DATA_WIDTH <=9) ? 12 : 
                         (DATA_WIDTH > 9 && DATA_WIDTH <= 18) ? 11 : (DATA_WIDTH > 18 && DATA_WIDTH <= 36) ? 10 : 
                         (DATA_WIDTH > 36 && DATA_WIDTH <= 72) ? 9 : 13 ) : 13 );

generate

if (MODE == "FPGA" || MODE == "fpga")
begin : BRAM_MACRO
    // **********************
    // MACRO: DUAL CLOCK FIFO
    // **********************
    FIFO_DUALCLOCK_MACRO  #(
        .ALMOST_EMPTY_OFFSET        ( ALMOST_EMPTY_OFFSET       ), // Sets the almost empty threshold
        .ALMOST_FULL_OFFSET         ( ALMOST_FULL_OFFSET        ), // Sets almost full threshold
        .DATA_WIDTH                 ( DATA_WIDTH                ), // Valid values are 1-72 (37-72 only valid when FIFO_SIZE="36Kb")
        .DEVICE                     ( "7SERIES"                 ), // Target device: "VIRTEX5", "VIRTEX6", "7SERIES"
        .FIFO_SIZE                  ( FIFO_SIZE                 ), // Target BRAM: "18Kb" or "36Kb"
        .FIRST_WORD_FALL_THROUGH    ( FIRST_WORD_FALL_THROUGH   )  // Sets the FIfor FWFT to "TRUE" or "FALSE"
    ) FIFO_DUALCLOCK_MACRO_inst (
        .RST                        ( RESET                     ), // 1-bit input reset
        .RDCLK                      ( RD_CLK                    ), // 1-bit input read clock
        .RDEN                       ( RD_EN                     ), // 1-bit input read enable
        .EMPTY                      ( RD_EMPTY                  ), // 1-bit output empty
        .ALMOSTEMPTY                ( RD_ALMOSTEMPTY            ), // 1-bit output almost empty
        .DI                         ( RD_DATA                   ), // Input data, width defined by DATA_WIDTH parameter
        .RDCOUNT                    ( RD_COUNT                  ), // Output read count, width determined by FIfor depth
        .RDERR                      ( RD_ERR                    ), // 1-bit output read error
        .WRCLK                      ( WR_CLK                    ), // 1-bit input write clock
        .WREN                       ( WR_EN                     ), // 1-bit input write enable
        .FULL                       ( WR_FULL                   ), // 1-bit output full
        .ALMOSTFULL                 ( WR_ALMOSTFULL             ), // 1-bit output almost full
        .DO                         ( WR_DATA                   ), // Output data, width defined by DATA_WIDTH parameter
        .WRCOUNT                    ( WR_COUNT                  ), // Output write count, width determined by FIfor depth
        .WRERR                      ( WR_ERR                    )  // 1-bit output write error
    );
end else begin

    wire [COUNT_WIDTH-1:0]  FIFO_count;

    assign RD_COUNT       = FIFO_count;
    assign WR_COUNT       = FIFO_count;
    assign RD_ALMOSTEMPTY = RD_EMPTY;
    assign WR_ALMOSTFULL  = WR_FULL;

    fifo #(
        .DATA_WIDTH                 ( DATA_WIDTH                ),
        .ADDR_WIDTH                 ( COUNT_WIDTH-1             )
    ) fifo_sim (
        .clk                        ( RD_CLK                    ), //input
        .reset                      ( RESET                     ), //input
        .pop                        ( RD_EN                     ), //input
        .data_out                   ( RD_DATA                   ), //output
        .empty                      ( RD_EMPTY                  ), //output
        .push                       ( WR_EN                     ), //input
        .data_in                    ( WR_DATA                   ), //input
        .full                       ( WR_FULL                   ), //output
        .fifo_count                 ( FIFO_count                )  //output
    );
end
endgenerate

endmodule
