`include "common.vh"
`timescale 1ns/1ps
//TODO::
//ADD checker for pooling module output
module pooling_tb_driver
#(
  parameter integer NUM_PE       = 4,
  parameter integer DATA_WIDTH   = 16,
  parameter integer CFG_WIDTH    = 3,
  parameter integer CTRL_WIDTH   = 6
)
(
  //System Signals
  input  wire                        clk,
  input  wire                        reset,

  output reg                         enable,
  output reg  [ CFG_WIDTH   -1 : 0 ] cfg,

  output wire [ CTRL_WIDTH  -1 : 0 ] ctrl,

  input  wire                        ready,

  output reg  [ DATA_IN     -1 : 0 ] write_data,
  output reg                         write_req,
  input  wire                        write_ready,

  input  wire [ DATA_OUT    -1 : 0 ] read_data,
  input  wire                        read_req,
  output reg                         read_ready
);

//localparam
localparam DATA_IN = DATA_WIDTH * NUM_PE;
localparam DATA_OUT = DATA_WIDTH * NUM_PE;

integer _kernel_width,
        _kernel_height,
        _kernel_stride,
        _input_width,
        _input_height,
        _output_width,
        _output_height;

integer data_in [0: 100000];
integer data_out [0: 100000];
integer read_count;
integer max_reads;
integer write_count;
integer max_writes;

task initialize_input;
  input integer input_width;
  input integer input_height;
  integer ii, jj;
  integer input_index;
  begin
    _input_width = input_width;
    _input_height = input_height;
    read_count = 0;
    max_reads = ceil_a_by_b(_input_height*_input_width, NUM_PE);
    for (ii=0; ii<_input_width; ii=ii+1)
    begin
      for (jj=0; jj<_input_height; jj=jj+1)
      begin
        input_index = ii*_input_height + jj;
        data_in[input_index] = $random%32+32;//_input_height * input_width - input_index;
      end
    end
  end
endtask

task print_input;
  integer ii, jj, input_index;
  begin
    $display ("Input  Dimensions = %d x %d", _input_width, _input_height);
    for (ii=0; ii<_input_width; ii=ii+1)
    begin
      for (jj=0; jj<_input_height; jj=jj+1)
      begin
        input_index = ii*_input_height + jj;
        $write("%4d", data_in[input_index]);
      end
      $display;
    end
    $display;
  end
endtask

task initialize_expected_output;
  input integer kernel_width;
  input integer kernel_height;
  input integer kernel_stride;
  integer ii, jj, kw, kh, ks;
  integer max;
  integer input_index, output_index;
  integer input_w, input_h;
  begin
    _kernel_width = kernel_width;
    _kernel_height = kernel_height;
    _kernel_stride = kernel_stride;
    _output_width = ceil_a_by_b(_input_width-_kernel_width, _kernel_stride)+1;
    _output_height = ceil_a_by_b(_input_height-_kernel_height, _kernel_stride)+1;
    write_count = 0;
    max_writes = ceil_a_by_b(_output_width*_output_height, NUM_PE);
    for (ii=0; ii<_output_height; ii=ii+1)
    begin
      for (jj=0; jj<_output_width; jj=jj+1)
      begin
        output_index = jj+ii*_output_width;
        input_index = (ii*_kernel_stride)*_input_width +
          jj*_kernel_stride;
        max = data_in[input_index];
        for (kh=0; kh<_kernel_height; kh=kh+1)
        begin
          for (kw=0; kw<_kernel_width; kw=kw+1)
          begin
            input_w = jj*_kernel_stride+kw;
            input_h = ii*_kernel_stride+kh;
            input_index = input_h*_input_width + input_w;
            if (input_w < _input_width && input_h < _input_height)
              max = max < data_in[input_index] ? data_in[input_index] : max;
          end
        end
        data_out[output_index] = max;
      end
    end
  end
endtask

task print_output;
  integer ii, jj, idx;
  begin
    $display ("Output  Dimensions = %d x %d", _output_width, _output_height);
    for (ii=0; ii<_output_width; ii=ii+1)
    begin
      for (jj=0; jj<_output_height; jj=jj+1)
      begin
        idx = ii*_output_height + jj;
        $write("%7d", data_out[idx]);
      end
      $display;
    end
    $display;
  end
endtask

task send_inputs;
  integer ii, jj, n;
  begin
    wait(write_ready);
    @(negedge clk);
    for (ii=0; ii<_input_height; ii=ii+1)
    begin
      for (jj=0; jj<_input_width; jj+=NUM_PE)
      begin
        wait(write_ready);
        @(negedge clk);
        write_req = 1'b1;
        for (n=0; n<NUM_PE; n=n+1)
        begin
          write_data[n*DATA_WIDTH+:DATA_WIDTH] = data_in[(ii*_input_width)+jj+n];
        end
        @(negedge clk);
        write_req = 1'b0;
      end
    end
    write_req = 1'b1;
    @(negedge clk);
    write_req = 1'b0;
  end
endtask

initial begin
  write_req = 1'b0;
  write_data = 0;
end

test_status #(
  .PREFIX                   ( "POOLING"                ),
  .TIMEOUT                  ( 100000                   )
) status (
  .clk                      ( clk                      ),
  .reset                    ( reset                    ),
  .pass                     ( pass                     ),
  .fail                     ( fail                     )
);

always @(posedge clk)
begin
  if (read_req)
    pool_read;
end
task pool_read;
  integer ii;
  begin
    $write ("Read: ");
    for (ii=0; ii<NUM_PE; ii=ii+1)
    begin
      $write ("%4d", read_data[ii*DATA_WIDTH+:DATA_WIDTH]);
      if (data_out[read_count] != read_data[ii*DATA_WIDTH+:DATA_WIDTH])
        $error ("Un matched");
      read_count = read_count +1;
    end
    $display;
  end
endtask

wire _pop;
reg iw_inc_d;
always @(posedge clk) iw_inc_d <= iw_inc;
assign _pop = stride_count == 0 && ready;
reg pop, pop_d, pop_dd, pop_ddd;
always @(posedge clk) pop <= _pop;
wire _shift;
reg shift, shift_d, shift_dd;

assign iw_inc = stride_count == stride_max && stride_inc;
assign _shift = !pop && stride_inc;
always@(posedge clk) shift <= _shift;
always@(posedge clk) shift_d <= shift;
always@(posedge clk) shift_dd <= shift_d;

wire _row_fifo_push,
      row_fifo_push;
wire _row_fifo;
assign _row_fifo = (shift || pop_d && ready) &&
                   !(kernel_size == 2 && kh_count == 1);
assign _row_fifo_push = _row_fifo && !(ih_count_d == ih_max);

register #(3, 1) row_fifo_push_delay
(clk, reset, _row_fifo_push, row_fifo_push);

wire _row_fifo_pop, row_fifo_pop;
assign _row_fifo_pop = _row_fifo && (ih_count != 0);

register #(3, 1) row_fifo_pop_delay
(clk, reset, _row_fifo_pop, row_fifo_pop);

always @(posedge clk)
  pop_d <= pop;
always @(posedge clk)
  pop_dd <= pop_d;
always @(posedge clk)
  pop_ddd <= pop_dd;

assign ctrl = {pool_valid, row_fifo_mux_sel, row_fifo_pop, row_fifo_push, pop, shift_d};
wire [2-1:0] stride = 2;
wire [2-1:0] kernel_size = 3;
wire endrow = (iw_count == iw_max && stride_count == stride_max);

wire _kernel_size_switch, kernel_size_switch;
assign _kernel_size_switch = (kernel_size == 3 && !endrow);
register #(4, 1) kernel_size_switch_delay
(clk, reset, _kernel_size_switch, kernel_size_switch);


assign cfg = {kernel_size_switch, stride};

assign _row_fifo_mux_sel = kh_count == 0;
register #(4, 1) row_fifo_mux_sel_delay
(clk, reset, _row_fifo_mux_sel, row_fifo_mux_sel);

integer stride_count;
wire [31:0] stride_max = 1;

wire stride_inc;
assign stride_inc = stride_count != 0 || ready;

always @(posedge clk)
begin
  if (reset)
    stride_count <= 0;
  else begin
    if (stride_count == stride_max && stride_inc)
      stride_count <= 0;
    else if (stride_inc)
      stride_count <= stride_count + 1;
  end
end

wire iw_clear;
assign iw_clear = iw_count == iw_max && iw_inc;

integer iw_count;
wire [31:0] iw_max;
assign iw_inc = stride_inc && stride_count == stride_max;
assign iw_max =_input_width/NUM_PE-1;
always @(posedge clk)
begin
  if (reset)
    iw_count <= 0;
  else
  begin
    if (iw_clear)
      iw_count <= 0;
    else if (iw_inc)
      iw_count <= iw_count + 1;
  end
end

integer ih_count;
integer ih_count_d;
wire ih_inc;
assign ih_inc = iw_count == iw_max && iw_inc;
wire ih_clear;
assign ih_clear = ih_count == ih_max && ih_inc;
wire [31:0] ih_max = _input_height-1;

always@(posedge clk)
  ih_count_d <= ih_count;

always @(posedge clk)
begin
  if (reset)
    ih_count <= 0;
  else
  begin
    if (ih_clear)
      ih_count <= 0;
    else if (ih_inc)
      ih_count <= ih_count + 1;
  end
end

wire [31:0] kh_count;
assign kh_count = ih_count % 2;

wire _pool_valid, pool_valid;
register#(4, 1) pool_v_delay (clk, reset, _pool_valid, pool_valid);
assign _pool_valid = (ih_count == ih_max) ||
  ((kernel_size == 3) ?
  (kh_count == 0 && ih_count != 0) :
  (kh_count == 1));

endmodule
