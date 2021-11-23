module xilix_bram_sdp
#(  // Parameters
    parameter         BRAM_SIZE             = "36Kb",        // Target BRAM: "18Kb" or "36Kb"
    parameter integer OUT_REG               = 1,             // Optional port A output register (0 or 1)
    parameter integer INIT                  = 36'd0,         // Initial values on port A output port
    parameter         INIT_FILE             = "NONE",                    
    parameter integer READ_WIDTH            = 16,            // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    parameter         SIM_COLLISION_CHK     = "ALL",         // Collision check enable "ALL", "WARNING_ONLY", // "GENERATE_X_ONLY" or "NONE"
    parameter integer SRVAL                 = 36'd0,         // Set/Reset value for port A output
    parameter         WRITE_MODE            = "WRITE_FIRST", // "WRITE_FIRST", "READ_FIRST", or "NO_CHANGE"
    parameter         WRITE_WIDTH           = 16             // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
)(  //Ports                                                    
    input  wire                             RST,             // 1-bit input reset
    input  wire                             RDCLK,           // 1-bit input read clock
    input  wire [ ADDR_WIDTH      -1 : 0 ]  RDADDR,          // Input read address, width defined by read port depth
    input  wire                             RDEN,            // 1-bit input read port enable
    input  wire                             REGCE,           // 1-bit input read output register enable
    output wire [ READ_WIDTH      -1 : 0 ]  DO,              // Output read data port, width defined by READ_WIDTH parameter
    input  wire                             WRCLK,           // 1-bit input write clock
    input  wire [ ADDR_WIDTH      -1 : 0 ]  WRADDR,          // Input write address, width defined by write port depth
    input  wire                             WREN,            // 1-bit input write port enable
    input  wire [ WE_WIDTH        -1 : 0 ]  WE,              // Input write enable, width defined by write port depth
    input  wire [ WRITE_WIDTH     -1 : 0 ]  DI               // Input write data port, width defined by WRITE_WIDTH parameter
);

localparam ADDR_WIDTH   = 4;

localparam WE_WIDTH = 4;

// ******************************************************************
// MACRO: SIMPLE DUAL PORT BRAM
// ******************************************************************
BRAM_SDP_MACRO #(
    .BRAM_SIZE              ( BRAM_SIZE                 ),   // Target BRAM, "18Kb" or "36Kb"
    .DEVICE                 ( "7SERIES"                 ),   // Target device: "VIRTEX5", "VIRTEX6", "SPARTAN6", "7SERIES"
    .WRITE_WIDTH            ( WRITE_WIDTH               ),   // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    .READ_WIDTH             ( READ_WIDTH                ),   // Valid values are 1-72 (37-72 only valid when BRAM_SIZE="36Kb")
    .DO_REG                 ( OUT_REG                   ),   // Optional output register (0 or 1)
    .INIT_FILE              ( INIT_FILE                 ),
    .SIM_COLLISION_CHECK    ( SIM_COLLISION_CHK         ),   // Collision check enable "ALL", "WARNING_ONLY", "GENERATE_X_ONLY" or "NONE"
    .SRVAL                  ( SRVAL                     ),   // Set/Reset value for port output
    .INIT                   ( INIT                      ),   // Initial values on output port
    .WRITE_MODE             ( WRITE_MODE                )    // Specify "READ_FIRST" for same clock or synchronous clocks. Specify "WRITE_FIRST for asynchronous clocks on ports
) BRAM_SDP_MACRO_inst (
    .RST                    ( RST                       ),   // 1-bit input reset
    .RDCLK                  ( RDCLK                     ),   // 1-bit input read clock
    .RDADDR                 ( RDADDR                    ),   // Input read address, width defined by read port depth
    .RDEN                   ( RDEN                      ),   // 1-bit input read port enable
    .REGCE                  ( REGCE                     ),   // 1-bit input read output register enable
    .DO                     ( DO                        ),   // Output read data port, width defined by READ_WIDTH parameter
    .WRCLK                  ( WRCLK                     ),   // 1-bit input write clock
    .WRADDR                 ( WRADDR                    ),   // Input write address, width defined by write port depth
    .WREN                   ( WREN                      ),   // 1-bit input write port enable
    .WE                     ( WE                        ),   // Input write enable, width defined by write port depth
    .DI                     ( DI                        )    // Input write data port, width defined by WRITE_WIDTH parameter
);

endmodule
