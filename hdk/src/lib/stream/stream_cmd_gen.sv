//Mark Zhao
//7/22/20
//Generates a command to the stream module

module stream_cmd_gen
#(
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer PAGE_OFFSET_WIDTH = 12,
  parameter integer BURSTS_PER_PAGE = 512,
  parameter integer BURSTS_PER_PAGE_LOG = 9
)(
  input  wire [SHIELD_ADDR_WIDTH-1:0]   axaddr,
  input  wire [7:0] axlen,

  output wire [8:0] burst_count,   //How many bursts to read from this line

  output wire [7:0] axlen_next,
  output wire [SHIELD_ADDR_WIDTH-1:0]   axaddr_next,
  output wire                           last //Is this the last burst?
);

  localparam integer ADDR_WIDTH_NO_OFFSET = SHIELD_ADDR_WIDTH - PAGE_OFFSET_WIDTH; //20

  //Declarations
  logic [8:0] bursts_to_rw; //How many bursts to read or write for the next page
  logic [9:0] remaining_bursts; //Number of remaining bursts for this page at the max
  logic last_burst;
  logic [ADDR_WIDTH_NO_OFFSET-1:0] axaddr_next_no_offset;
  logic [PAGE_OFFSET_WIDTH-1:0]      start_offset; //12

  assign start_offset = axaddr[PAGE_OFFSET_WIDTH-1:0]; //last offset bits of addr
  assign remaining_bursts = {1'b1, {9{1'b0}}} - start_offset[PAGE_OFFSET_WIDTH-1 -: 9]; 
  //max Number of remaining bursts in this page that are possible in this page

  always_comb begin
    //Is this address aligned?
    if(start_offset == {PAGE_OFFSET_WIDTH{1'b0}}) begin //Address is aligned to page
      if((axlen + 1) > BURSTS_PER_PAGE) begin 
        bursts_to_rw = BURSTS_PER_PAGE;
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
        bursts_to_rw = remaining_bursts[8:0];
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
  assign axaddr_next_no_offset = axaddr[SHIELD_ADDR_WIDTH-1:PAGE_OFFSET_WIDTH] + 1;
  assign axaddr_next = {axaddr_next_no_offset, {PAGE_OFFSET_WIDTH{1'b0}}};

endmodule : stream_cmd_gen
