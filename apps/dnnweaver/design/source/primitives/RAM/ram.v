module ram
#(
  parameter integer DATA_WIDTH    = 10,
  parameter integer ADDR_WIDTH    = 12,
  parameter         RAM_TYPE      = "block"
)
(
  input  wire                         clk,
  input  wire                         reset,

  input  wire                         s_read_req,
  input  wire [ ADDR_WIDTH  -1 : 0 ]  s_read_addr,
  output reg  [ DATA_WIDTH  -1 : 0 ]  s_read_data,

  input  wire                         s_write_req,
  input  wire [ ADDR_WIDTH  -1 : 0 ]  s_write_addr,
  input  wire [ DATA_WIDTH  -1 : 0 ]  s_write_data
);

  (* RAM_STYLE = RAM_TYPE *)
  reg  [ DATA_WIDTH -1 : 0 ] mem [ 0 : 1<<ADDR_WIDTH ];
  reg[ADDR_WIDTH-1:0] rd_addr;
  reg[ADDR_WIDTH-1:0] wr_addr;
  reg[DATA_WIDTH-1:0] wr_data;

  reg rd_addr_v;
  reg wr_addr_v;

  always @(posedge clk)
    if (reset)
      rd_addr_v <= 1'b0;
    else
      rd_addr_v <= s_read_req;

  always @(posedge clk)
  begin
    if (reset)
      rd_addr <= 0;
    else if (s_read_req)
      rd_addr <= s_read_addr;
  end

  always @(posedge clk)
  begin
    if (reset)
    begin
      wr_addr <= 0;
    end
    else if (s_write_req)
    begin
      wr_addr <= s_write_addr;
    end
  end

  always @(posedge clk)
    if (reset)
      wr_addr_v <= 1'b0;
    else
      wr_addr_v <= s_write_req;

  always @(posedge clk)
    if (reset)
      wr_data <= 0;
    else if (s_write_req)
      wr_data <= s_write_data;


  always @(posedge clk)
  begin: RAM_WRITE
    if (wr_addr_v)
      mem[wr_addr] <= wr_data;
  end

  always @(posedge clk)
  begin: RAM_READ
    if (reset)
      s_read_data <= 0;
    else if (rd_addr_v)
      s_read_data <= mem[rd_addr];
  end
endmodule
