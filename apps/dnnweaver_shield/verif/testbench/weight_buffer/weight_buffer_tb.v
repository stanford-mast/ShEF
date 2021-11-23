module weight_buffer_tb;
// ******************************************************************
// local parameters
// ******************************************************************
  parameter integer RD_WIDTH      = 16;
  parameter integer WR_WIDTH      = 64;
  parameter integer RD_ADDR_WIDTH = 7;
  parameter integer WR_ADDR_WIDTH = 5;
// ******************************************************************
// ******************************************************************
// IO
// ******************************************************************
  wire                           clk;
  wire                           reset;

  wire                           read_req;
  wire [ RD_WIDTH      -1 : 0 ]  read_data;
  wire [ RD_ADDR_WIDTH -1 : 0 ]  read_addr;

  wire                           write_req;
  wire [ WR_WIDTH      -1 : 0 ]  write_data;
  wire [ WR_ADDR_WIDTH -1 : 0 ]  write_addr;
// ******************************************************************

// ******************************************************************
  initial
  begin
    $dumpfile("weight_buffer_tb.vcd");
    $dumpvars(0,weight_buffer_tb);
  end

  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );

  initial begin
    #1000 $finish;
  end
// ******************************************************************

  weight_buffer #(
    .RD_WIDTH                 ( RD_WIDTH                 ),
    .WR_WIDTH                 ( WR_WIDTH                 ),
    .RD_ADDR_WIDTH            ( RD_ADDR_WIDTH            ),
    .WR_ADDR_WIDTH            ( WR_ADDR_WIDTH            )
  )
  u_wb
  (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),

    .read_req                 ( read_req                 ),
    .read_data                ( read_data                ),
    .read_addr                ( read_addr                ),

    .write_req                ( write_req                ),
    .write_data               ( write_data               ),
    .write_addr               ( write_addr               )
  );



  weight_buffer_tb_driver #(
    .RD_WIDTH                 ( RD_WIDTH                 ),
    .WR_WIDTH                 ( WR_WIDTH                 ),
    .RD_ADDR_WIDTH            ( RD_ADDR_WIDTH            ),
    .WR_ADDR_WIDTH            ( WR_ADDR_WIDTH            )
  )
  u_driver
  (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),

    .read_req                 ( read_req                 ),
    .read_data                ( read_data                ),
    .read_addr                ( read_addr                ),

    .write_req                ( write_req                ),
    .write_data               ( write_data               ),
    .write_addr               ( write_addr               )
  );

endmodule
