`timescale 1ns/1ps
module PE_buffer 
#(  // Parameters
    parameter   DATA_WIDTH          = 64,
    parameter   ADDR_WIDTH          = 8,
    parameter   RAM_DEPTH           = (1 << ADDR_WIDTH),
    parameter   TYPE                = "LUT"
)(  // Ports
    input  wire                         CLK,
    input  wire                         RESET,
    input  wire                         PUSH,
    input  wire                         POP,
    input  wire                         SAVE_RD_ADDR,
    input  wire                         RESTORE_RD_ADDR,
    input  wire [ DATA_WIDTH -1 : 0 ]   DATA_IN,
    output reg  [ DATA_WIDTH -1 : 0 ]   DATA_OUT,
    output reg                          EMPTY,
    output reg                          FULL,
    output reg  [ ADDR_WIDTH    : 0 ]   FIFO_COUNT
);    
 
// Port Declarations
// ******************************************************************
// Internal variables
// ******************************************************************
    reg     [ADDR_WIDTH-1:0]        wr_pointer;             //Write Pointer
    reg     [ADDR_WIDTH-1:0]        rd_pointer;             //Read Pointer
    reg     [ADDR_WIDTH-1:0]        rd_pointer_checkpoint;  //Read Pointer
    reg     [ADDR_WIDTH  :0]        fifo_count_checkpoint;  //Read Pointer
	(* ram_style = TYPE *)
    reg     [DATA_WIDTH-1:0]        mem[0:RAM_DEPTH-1];     //Memory
// ******************************************************************
// INSTANTIATIONS
// ******************************************************************

    always @ (FIFO_COUNT)
    begin : FIFO_STATUS
    	EMPTY   = (FIFO_COUNT == 0);
    	FULL    = (FIFO_COUNT == RAM_DEPTH);
    end
    
    always @ (posedge CLK)
    begin : FIFO_COUNTER
    	if (RESET)
    		FIFO_COUNT <= 0;

        else if (RESTORE_RD_ADDR)
            FIFO_COUNT <= fifo_count_checkpoint;
    	
    	else if (PUSH && !POP && !FULL)
    		FIFO_COUNT <= FIFO_COUNT + 1;
    		
    	else if (POP && !PUSH && !EMPTY)
    		FIFO_COUNT <= FIFO_COUNT - 1;
    end

    always @ (posedge CLK)
    begin : WRITE_PTR
    	if (RESET) begin
       		wr_pointer <= 0;
    	end 
        else if (PUSH) begin
    		wr_pointer <= wr_pointer + 1;
    	end
    end

    always @ (posedge CLK)
    begin : FIFO_COUNT_CHECKPOINT
        if (RESET) begin
            fifo_count_checkpoint <= 0;
        end else if (SAVE_RD_ADDR && !PUSH) begin
            fifo_count_checkpoint <= FIFO_COUNT;
        end else if (SAVE_RD_ADDR && PUSH) begin
            fifo_count_checkpoint <= FIFO_COUNT+1;
        end else if (PUSH) begin
            fifo_count_checkpoint <= fifo_count_checkpoint+1;
        end
    end

    always @ (posedge CLK)
    begin : SAVE_CHECKPOINT
        if (RESET) begin
            rd_pointer_checkpoint <= 0;
        end else if (SAVE_RD_ADDR) begin
            rd_pointer_checkpoint <= rd_pointer;
        end
    end
    
    always @ (posedge CLK)
    begin : READ_PTR
    	if (RESET) begin
    		rd_pointer <= 0;
    	end
        else if (POP && !RESTORE_RD_ADDR && !EMPTY) begin
    		rd_pointer <= rd_pointer + 1;
    	end
        else if (RESTORE_RD_ADDR) begin
            rd_pointer <= rd_pointer_checkpoint;
        end
    end
    
    always @ (posedge CLK)
    begin : WRITE
        if (PUSH && !FULL) begin
    		mem[wr_pointer] <= DATA_IN;
        end
    end
    
    always @ (posedge CLK)
    begin : READ
        if (RESET) begin
	    	DATA_OUT <= 0;
        end
        if (POP && !EMPTY) begin
    		DATA_OUT <= mem[rd_pointer];
        end
        else begin
    		DATA_OUT <= DATA_OUT;
        end
    end

endmodule
