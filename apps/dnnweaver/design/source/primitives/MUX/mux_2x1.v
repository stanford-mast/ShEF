module mux_2x1 #(
    parameter DATA_WIDTH = 16,
    parameter REGISTERED = "yes"
)(
    input  wire                         clk,
    input  wire                         reset,
    input  wire [DATA_WIDTH-1:0]        in_0, 
    input  wire [DATA_WIDTH-1:0]        in_1, 
    input  wire                         sel, 
    output wire [DATA_WIDTH-1:0]        out
);

    wire [DATA_WIDTH-1:0]   mux_out;
    assign mux_out = sel ? in_1 : in_0;

generate 
    if (REGISTERED == "no" || REGISTERED == "NO") begin
        assign out = mux_out;
    end else begin
        reg  [DATA_WIDTH-1:0] mux_out_reg;
        assign out = mux_out_reg;
        always @(posedge clk) begin
            if (reset)
                mux_out_reg <= 0;
            else
                mux_out_reg <= mux_out;
        end
    end
endgenerate

endmodule
