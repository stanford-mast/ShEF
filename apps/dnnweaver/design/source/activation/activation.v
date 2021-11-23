module activation #(
  parameter OP_WIDTH  = 16,
  parameter TYPE        = "ReLU"
) (
  input  wire                                         clk,
  input  wire                                         reset,
  input  wire                                         enable,
  input  signed [ OP_WIDTH           -1 : 0 ]         in,
  output signed [ OP_WIDTH           -1 : 0 ]         out
);

reg [OP_WIDTH-1:0] activation_data;

always @(posedge clk)
begin
  if (reset)
    activation_data <= 0;
  else begin
    if (enable)
      activation_data <= in > 0 ? in : 0;
    else
      activation_data <= in;
  end
end

assign out = activation_data;


endmodule
