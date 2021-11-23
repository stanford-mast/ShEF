module wburst_counter #(
  parameter integer WBURST_COUNTER_LEN    = 16,
  parameter integer WBURST_LEN            = 4,
  parameter integer MAX_BURST_LEN         = 16
)(
  input  wire                             clk,
  input  wire                             resetn,
  input  wire                             write_valid,
  input  wire                             write_flush,

  output wire [WBURST_LEN-1:0]            wburst_len,
  output wire                             wburst_ready,

  input  wire                             wburst_issued,
  input  wire [WBURST_LEN-1:0]            wburst_issued_len
);


  reg  [WBURST_COUNTER_LEN-1:0] write_count;
  wire burst_ready;

  assign burst_ready = ((write_count >= MAX_BURST_LEN));
  assign wburst_len = write_count >= MAX_BURST_LEN ? MAX_BURST_LEN - 1 :
                      write_count != 0 ? write_count - 1 : 0;

  always @(posedge clk)
  begin
    if (!resetn)
      write_count <= 0;
    else if (write_valid)
    begin
      if (wburst_issued)
        write_count <= write_count - wburst_issued_len;
      else
        write_count <= write_count + 1;
    end else begin
      if (wburst_issued)
        write_count <= write_count - wburst_issued_len - 1;
      else
        write_count <= write_count + 0;
    end
  end

/* FSM for write counter */

reg state;
reg next_state;

localparam integer IDLE=0, READY=1;

always @(*)
begin
  next_state = state;
  case(state)
    IDLE: begin
      if (burst_ready)
        next_state = READY;
    end
    READY: begin
      if (wburst_issued)
        next_state = IDLE;
    end
  endcase
end

always @(posedge clk)
  if (resetn)
    state <= next_state;
  else
    state <= 1'b0;

assign wburst_ready = (state == READY);

endmodule
