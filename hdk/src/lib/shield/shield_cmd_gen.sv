//Mark Zhao
//7/13/20
//
//Generates a command to the cache from an AXI slave port

module shield_cmd_gen
#(
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer OFFSET_WIDTH = 6,
  parameter integer BURSTS_PER_LINE = 8,
  parameter integer BURSTS_PER_LINE_LOG = 3
)(
  input  wire [SHIELD_ADDR_WIDTH-1:0] axaddr,
  input  wire [7:0]                   axlen,

  output wire [7:0]                   burst_count,           //How many bursts to read from this line

  output wire [7:0]                   axlen_next,
  output wire [SHIELD_ADDR_WIDTH-1:0] axaddr_next,
  output wire                         last //Is this the last burst?
);

  localparam integer ADDR_WIDTH_NO_OFFSET = SHIELD_ADDR_WIDTH - OFFSET_WIDTH;

  //Declarations
  logic [7:0] bursts_to_rw; //How many bursts to read or write for the next cache line
  logic [BURSTS_PER_LINE_LOG:0] remaining_bursts; //Number of remaining bursts for this cache line at the max
  logic last_burst;
  logic [ADDR_WIDTH_NO_OFFSET-1:0] axaddr_next_no_offset;
  logic [OFFSET_WIDTH-1:0]      start_offset;

  assign start_offset = axaddr[OFFSET_WIDTH-1:0]; //last offset bits of addr
  assign remaining_bursts = {1'b1, {BURSTS_PER_LINE_LOG{1'b0}}} - start_offset[OFFSET_WIDTH-1 -: BURSTS_PER_LINE_LOG]; //Number of remaining bursts in this cache line

  always_comb begin
    //Is this address aligned?
    if(start_offset == {OFFSET_WIDTH{1'b0}}) begin //Address is aligned to cache line
      if((axlen + 1) > BURSTS_PER_LINE) begin //arlen is longer than one cache line
        bursts_to_rw = BURSTS_PER_LINE;
        last_burst = 1'b0;
      end
      else begin
        bursts_to_rw = axlen + 1;
        last_burst = 1'b1;
      end
    end
    else begin //unaligned access
      //If the number of remaining bursts for this cache line is less than arlen + 1
      if((axlen + 1) > remaining_bursts) begin
        bursts_to_rw = remaining_bursts;
        last_burst = 1'b0;
      end
      else begin //Otherwise, just read arlen + 1
        bursts_to_rw = axlen + 1;
        last_burst = 1'b1;
      end
    end
  end

  assign burst_count = bursts_to_rw;

  //Is this the last burst?
  assign last = last_burst;

  //Calculate the next length
  assign axlen_next = (axlen - bursts_to_rw);

  //Calculate the next address - only matters when we overflow - 
  //next access must be aligned to cache line.
  assign axaddr_next_no_offset = axaddr[SHIELD_ADDR_WIDTH-1:OFFSET_WIDTH] + 1;
  assign axaddr_next = {axaddr_next_no_offset, {OFFSET_WIDTH{1'b0}}};

endmodule : shield_cmd_gen
