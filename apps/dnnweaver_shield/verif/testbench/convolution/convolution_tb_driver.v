`include "common.vh"
module convolution_tb_driver
#(
  parameter integer OP_WIDTH    = 16,    // Operand width. Supported : 16
  parameter integer NUM_PE      = 1,
  parameter integer VERBOSE     = 0
)
(
  output wire                   clk,
  output wire                   reset,
  input  wire                   pu_rd_req,
  output reg                    pu_rd_ready,
  input  wire                   pu_wr_req,
  input  wire [DATA_WIDTH-1:0]  pu_data_out,
  output reg  [DATA_WIDTH-1:0]  pu_data_in,
  output reg                    pass,
  output reg                    fail
);
// ******************************************************************
// local parameters
// ******************************************************************
  localparam integer DATA_WIDTH   = OP_WIDTH * NUM_PE;
// ******************************************************************
// Wires and Regs
// ******************************************************************
  reg  [OP_WIDTH-1:0] data_in  [0:32767];
  reg  [OP_WIDTH-1:0] weight   [0:32767];
  reg  [OP_WIDTH-1:0] expected_out [0:32767];
  integer expected_writes;
// ******************************************************************
// Test Configuration
// ******************************************************************
  integer input_fm_dimensions  [3:0];
  integer output_fm_dimensions [3:0];
  integer weight_dimensions    [4:0];

  test_status #(
    .PREFIX                   ( "Convolution"            ),
    .TIMEOUT                  ( 1000000                  )
  ) status (
    .clk                      ( clk                      ),
    .reset                    ( reset                    ),
    .pass                     ( pass                     ),
    .fail                     ( fail                     )
  );

  clk_rst_driver
  clkgen(
    .clk                      ( clk                      ),
    .reset_n                  (                          ),
    .reset                    ( reset                    )
  );


  task expected_output;
    input integer input_width;
    input integer input_height;
    input integer input_channels;

    input integer batchsize;

    input integer kernel_width;
    input integer kernel_height;
    input integer kernel_stride;

    input integer output_channels;

    input integer padding;

    integer output_width;
    integer output_height;

    integer iw, ih, ic, b, kw, kh, ow, oh;

    integer input_index, output_index, kernel_index;

    integer in, in_w, in_h;

    begin
      write_count = 0;
      output_fm_dimensions[0] = output_width;
      output_fm_dimensions[1] = output_height;
      output_fm_dimensions[2] = output_channels;
      output_fm_dimensions[3] = batchsize;
      ow = (input_width-kernel_width+1+2*padding)/kernel_stride;
      output_width = ceil_a_by_b(
        ceil_a_by_b((input_width - kernel_width+1+2*padding), kernel_stride),
        NUM_PE) * NUM_PE;
      //output_width = ((input_width - kernel_width+1+2*padding)/ kernel_stride);
      output_height = (input_height - kernel_height+1+2*padding)/ kernel_stride;
      $display ("Expected output size %d x %d x %d x %d\n",
        output_width,output_height,output_channels,batchsize);
      for (ih=0; ih<output_height; ih=ih+1)
      begin
        for (iw=0; iw<output_width; iw=iw+1)
        begin
          output_index = ih*output_width + iw;
          expected_out[output_index] = 0;
          for (ic=0; ic<input_channels; ic=ic+1)
          begin
            for (kh=0; kh<kernel_height; kh=kh+1)
            begin
              if (VERBOSE == 1) $write("%6d + ",
                expected_out[output_index]);
              for (kw=0; kw<kernel_width && iw < ow; kw=kw+1)
              begin
                in_h = (ih+kh-padding);
                in_w = (iw+kw-padding);
                input_index = (ic * input_height + in_h) * input_width + in_w;
                in = data_in[input_index];
                if (in_h < 0 || in_h >= input_height ||
                  in_w < 0 || in_w >= input_width)
                  in = 0;
                kernel_index = (ic*kernel_height+kh)*kernel_width+kw;
                expected_out[output_index] = weight[kernel_index] * in + expected_out[output_index];
                //$write("%8d x ", weight[kernel_index]);
                //$write("%-8d + ", in);
              end
              if (VERBOSE == 1) $display;
            end
            if (VERBOSE == 1) 
            begin
              $write(" = %6d",
                expected_out[output_index]);
              $display;
              $display;
            end
          end
          if (VERBOSE == 1) $display;
        end
      end
      expected_writes = (output_width/NUM_PE) * output_height;
      if (VERBOSE == 1) $display("Expected number of writes = %6d", expected_writes);
    end
  endtask

  integer max_data_in_count;
  task initialize_input;
    input integer width;
    input integer height;
    input integer channels;
    input integer batchsize;
    integer i, j, c;
    integer idx;
    begin
      pu_rd_ready = 1'b1;
      data_in_counter = 0;
      input_fm_dimensions[0] = width;
      input_fm_dimensions[1] = height;
      input_fm_dimensions[2] = channels;
      input_fm_dimensions[3] = batchsize;
      max_data_in_count = width * height * channels * batchsize;
      $display ("# Input Neurons = %d", max_data_in_count);
      for (c=0; c<channels; c=c+1)
      begin
        for (i=0; i<height; i=i+1)
        begin
          for (j=0; j<width; j=j+1)
          begin
            idx = j + width * (i + height * c);
            data_in[idx] = idx;
          end
          //$display ("Index %d, %d;\t Value %d",
            //i, j, j+i*width);
        end
      end
    end
  endtask

  task initialize_weight;
    input integer width;
    input integer height;
    input integer input_channels;
    input integer output_channels;
    integer i, j, k, l;
    integer index;
    begin
      weight_dimensions[0] = width;
      weight_dimensions[1] = height;
      weight_dimensions[2] = input_channels;
      weight_dimensions[3] = output_channels;
      for (k=0; k<input_channels; k=k+1)
      begin
        for (l=0; l<output_channels; l=l+1)
        begin
          for (i=0; i<height; i=i+1)
          begin
            for (j=0; j<width; j=j+1)
            begin
              index = (((l*output_channels + k)* height + i) * width + j);
              weight[index] = index+1;
              if (VERBOSE == 1) 
                $display ("Index %d;\t Value %d",
                  index, weight[index]);
            end
          end
        end
      end
    end
  endtask

  integer data_in_counter;
  task pu_read;
    integer i;
    begin
      //$display("PU Read Request");
      for (i=0; i<NUM_PE; i=i+1)
      begin
        if ((data_in_counter-i)%input_fm_dimensions[0]+i >= input_fm_dimensions[0])
          pu_data_in[i*OP_WIDTH+:OP_WIDTH] = 0;
        else begin
          pu_data_in[i*OP_WIDTH+:OP_WIDTH] = data_in[data_in_counter];
          data_in_counter = data_in_counter+1;
        end
        if (data_in_counter >= max_data_in_count)
          pu_rd_ready = 1'b0;//status.test_fail;
      end
      //$display("PU Read Reponse: %h",
        //pu_data_in);
    end
  endtask

  integer write_count;
  initial write_count = 0;
  task pu_write;
    integer i;
    integer tmp;
    begin
      //$display("PU write Request");
      if (VERBOSE==1) $write("PU write DATA : ");
      for (i=0; i<NUM_PE; i=i+1)
      begin
        tmp = pu_data_out[i*OP_WIDTH+:OP_WIDTH];
        if (VERBOSE==1) $write("%d ", tmp);
      end

      for (i=0; i<NUM_PE; i=i+1)
      begin
        tmp = pu_data_out[i*OP_WIDTH+:OP_WIDTH];
        if (tmp != expected_out[write_count+i])
        begin
          $display ("\nError: PU write data does not match expected");
          $display ("Expected %d, got %d", expected_out[write_count+i], tmp);
          status.test_fail;
        end
      end

      write_count += NUM_PE;

      if (VERBOSE==1) $display;
    end
  endtask

  always @(posedge clk)
  begin
    if (pu_rd_req)
      pu_read;
  end

  always @(posedge clk)
  begin
    if (pu_wr_req)
      pu_write;
  end

  initial begin
    data_in_counter = 0;
  end

endmodule
