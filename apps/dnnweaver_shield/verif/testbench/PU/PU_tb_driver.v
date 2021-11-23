`include "common.vh"
module PU_tb_driver
#(
  parameter integer OP_WIDTH    = 16,    // Operand width. Supported : 16
  parameter integer NUM_PE      = 1,
  parameter integer VERBOSE     = 2
)
(
  output wire                                         clk,
  output wire                                         reset,
  output reg  [4*OP_WIDTH-1:0]                        buffer_read_data_out,
  output reg                                          buffer_read_empty,
  output reg                                          buffer_read_data_valid,
  input  wire                                         buffer_read_req,
  output reg                                          buffer_read_last,
  input  wire                                         pu_rd_req,
  output wire                                         pu_rd_ready,
  input  wire                                         pu_wr_req,
  input  wire signed [DATA_WIDTH-1:0]                 pu_data_out,
  output reg  [DATA_WIDTH-1:0]                        pu_data_in,
  output reg                                          pass,
  output reg                                          fail
);
// ******************************************************************
// local parameters
// ******************************************************************
  localparam integer DATA_WIDTH   = OP_WIDTH * NUM_PE;
// ******************************************************************
// Wires and Regs
// ******************************************************************
  reg signed  [OP_WIDTH-1:0] data_in  [0:1<<20];
  reg signed  [OP_WIDTH-1:0] weight   [0:1<<20];
  reg signed  [OP_WIDTH-1:0] buffer   [0:1<<20];
  reg signed  [OP_WIDTH-1:0] expected_out [0:1<<20];
  reg signed  [OP_WIDTH-1:0] expected_pool_out [0:1<<20];
  integer expected_writes;
  integer output_fm_size;
  reg signed [OP_WIDTH-1:0] norm_lut [0:1<<6];

  initial
  $readmemb ("hardware/include/norm_lut.vh", norm_lut);
// ******************************************************************
// Test Configuration
// ******************************************************************
  integer input_fm_dimensions  [3:0];
  integer input_fm_size;
  integer output_fm_dimensions [3:0];
  integer pool_fm_dimensions [3:0];
  integer weight_dimensions    [4:0];
  integer buffer_dimensions[4:0];
  reg pool_enabled;

  test_status #(
    .PREFIX                   ( "PU"                     ),
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

  task expected_pooling_output;
    input integer pool_w;
    input integer pool_h;
    input integer stride;
    integer iw, ih, ic;
    integer ow, oh;
    integer ii, jj;
    integer kk, ll;
    integer output_index, input_index;
    integer max;
    integer in_w, in_h;
    integer tmp;
    begin
      pool_enabled = 1'b1;
      $display ("PE output dimensions\t= %d x %d x %d",
        output_fm_dimensions[0],
        output_fm_dimensions[1],
        output_fm_dimensions[2]);
      iw = output_fm_dimensions[0];
      ih = output_fm_dimensions[1];
      ic = output_fm_dimensions[2];
      pool_fm_dimensions[0] = ceil_a_by_b(ceil_a_by_b(iw-pool_w, stride)+1, NUM_PE)*NUM_PE;
      pool_fm_dimensions[1] = ceil_a_by_b(ih-pool_h, stride)+1;
      tmp = ceil_a_by_b(iw-pool_w, stride)+1;
      if (tmp < NUM_PE)
        ow = tmp;
      else
        ow = pool_fm_dimensions[0];
      $display ("Pooling dimensions\t= %d x %d",
        pool_fm_dimensions[0],
        pool_fm_dimensions[1]);
      oh = pool_fm_dimensions[1];
      for (ii=0; ii<oh; ii=ii+1)
      begin
        for (jj=0; jj<ow; jj=jj+1)
        begin
          in_w = jj*stride;
          in_h = ii*stride;
          input_index = (ii*stride)*iw+jj*stride;
          output_index = ii*ow+jj;
          if (in_h < ih && in_w < iw)
            max = expected_out[input_index];
          else
            max = 0;
          for (kk=0; kk<pool_h; kk=kk+1)
          begin
            for (ll=0; ll<pool_w; ll=ll+1)
            begin
              in_w = jj*stride+ll;
              in_h = ii*stride+kk;
              input_index = (in_h)*iw+in_w;
              if (in_h < ih && in_w < iw)
                max = max > expected_out[input_index] ?
                  max : expected_out[input_index];
            end
          end
          expected_pool_out[output_index] = max;
        end
      end
      expected_writes = ceil_a_by_b(ow,NUM_PE) * oh;
      output_fm_size = ceil_a_by_b(ow, NUM_PE) * oh;
      $display("Expected number of pooled writes = %6d",
        expected_writes);
    end
  endtask

  task print_pooled_output;
    integer w, h;
    begin
      for (h=0; h<pool_fm_dimensions[1]; h=h+1)
      begin
        for (w=0; w<pool_fm_dimensions[0]; w=w+1)
        begin
          $write ("%8d", expected_pool_out[h*pool_fm_dimensions[0]+w]);
        end
        $display;
      end
    end
  endtask

  task print_pe_output;
    integer w, h;
    begin
      for (h=0; h<output_fm_dimensions[1]; h=h+1)
      begin
        for (w=0; w<output_fm_dimensions[0]; w=w+1)
        begin
          $write ("%6d", expected_out[h*output_fm_dimensions[0]+w]);
        end
        $display;
      end
    end
  endtask

  task expected_output_fc;
    input integer input_channels;
    input integer output_channels;
    input integer max_threads;
    integer ic, oc;
    integer input_index, output_index, kernel_index;
    integer in;
    reg signed [48-1:0] acc;
    begin
      write_count = 0;
      output_fm_dimensions[0] = 1;
      output_fm_dimensions[1] = 1;
      output_fm_dimensions[2] = output_channels;
      output_fm_dimensions[3] = 1;
      for (oc=0; oc<output_channels; oc=oc+1)
      begin
        output_index = oc;
        expected_out[output_index] = 0;
        acc = 0;
        for (ic=0; ic<input_channels && oc < max_threads; ic=ic+1)
        begin
          input_index = ic;
          if (ic == 0)
            in = 1;
          else
            in = weight[input_index-1];
          kernel_index = ((oc/NUM_PE)*input_channels+ic) * NUM_PE + oc%NUM_PE;
          acc = (data_in[kernel_index] * in) + acc;
          if (VERBOSE > 1) $write("%4d x %-4d + ",
            data_in[kernel_index], in);
        end
        expected_out[output_index] = acc >>> `PRECISION_FRAC;
        if (VERBOSE > 1)
          $display (" = %d\n", expected_out[output_index]);
      end
      expected_writes = ceil_a_by_b(output_channels, NUM_PE);
      output_fm_size = ceil_a_by_b(output_channels, NUM_PE) * NUM_PE;
      if (VERBOSE > 1) $display("Expected number of writes = %6d", expected_writes);
    end
  endtask

  task expected_output_norm;
    input integer input_width;
    input integer input_height;
    input integer input_channels;

    input integer batchsize;

    input integer kernel_width;
    input integer kernel_height;
    input integer kernel_stride;

    input integer output_channels;

    input integer pad_w;
    input integer pad_r_s;
    input integer pad_r_e;

    integer output_width;
    integer output_height;

    integer iw, ih, ic, b, kw, kh, ow, oh;

    integer input_index, output_index, kernel_index;

    integer in, in_w, in_h;

    reg [6-1:0] lrn_weight_index;

    begin
      write_count = 0;
      ow = (input_width-kernel_width+2*pad_w)/kernel_stride+1;
      output_width = (ceil_a_by_b(
        ((input_width - kernel_width+2*pad_w) / kernel_stride)+1,
        NUM_PE)) * NUM_PE;
      //output_width = ((input_width - kernel_width+1+2*pad_w)/ kernel_stride);
      output_height = (input_height - kernel_height+pad_r_s+pad_r_e)/ kernel_stride+1;
      $display ("Expected output size %d x %d x %d x %d\n",
        output_width,output_height,output_channels,batchsize);
      output_fm_dimensions[0] = output_width;
      output_fm_dimensions[1] = output_height;
      output_fm_dimensions[2] = output_channels;
      output_fm_dimensions[3] = batchsize;
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
              if (VERBOSE > 1) $write("%6d + ",
                expected_out[output_index]);
              for (kw=0; kw<kernel_width && iw < ow; kw=kw+1)
              begin
                in_h = (ih*kernel_stride+kh-pad_r_s);
                in_w = (iw*kernel_stride+kw-pad_w);
                input_index = (0 * input_height + in_h) * input_width + in_w;
                in = data_in[input_index];
                if (in_h < 0 || in_h >= input_height ||
                  in_w < 0 || in_w >= input_width)
                  in = 0;
                kernel_index = (0*kernel_height+kh)*kernel_width+kw;
                expected_out[output_index] = ((in * in) >>> `PRECISION_FRAC) + expected_out[output_index];
                if (VERBOSE > 1) $write("%8d x ", in);
                if (VERBOSE > 1) $write("%-8d + ", in);
              end
              if (VERBOSE > 1) $display;
            end
            if (VERBOSE > 1)
            begin
              $write("%6d * %6d",
                expected_out[output_index], data_in[output_index]);
            end
            lrn_weight_index = expected_out[output_index];
            expected_out[output_index] = data_in[output_index] * norm_lut[lrn_weight_index];
            if (VERBOSE > 1)
            begin
              $write(" = %6d",
                expected_out[output_index]);
              $display;
              $display;
            end
          end
          //expected_out[output_index] = expected_out[output_index] >>> `PRECISION_FRAC;
          if (VERBOSE > 1)
          begin
            $write(" = %6d",
              expected_out[output_index]);
            $display;
            $display;
          end
          if (VERBOSE > 1) $display;
        end
      end
      expected_writes = (output_width/NUM_PE) * output_height;
      output_fm_size = ceil_a_by_b(output_width, NUM_PE) * output_height;
      if (VERBOSE == 1) $display("Expected number of writes = %6d", expected_writes);
    end
  endtask

  task expected_output;
    input integer input_width;
    input integer input_height;
    input integer input_channels;

    input integer batchsize;

    input integer kernel_width;
    input integer kernel_height;
    input integer kernel_stride;

    input integer output_channels;

    input integer pad_w;
    input integer pad_r_s;
    input integer pad_r_e;

    integer output_width;
    integer output_height;

    integer iw, ih, ic, b, kw, kh, ow, oh;

    integer input_index, output_index, kernel_index;

    integer in, in_w, in_h;

    begin
      write_count = 0;
      ow = (input_width-kernel_width+2*pad_w)/kernel_stride+1;
      output_width = (ceil_a_by_b(
        ((input_width - kernel_width+2*pad_w) / kernel_stride)+1,
        NUM_PE)) * NUM_PE;
      //output_width = ((input_width - kernel_width+1+2*pad_w)/ kernel_stride);
      output_height = (input_height - kernel_height+pad_r_s+pad_r_e)/ kernel_stride+1;
      $display ("Expected output size %d x %d x %d x %d\n",
        output_width,output_height,output_channels,batchsize);
      output_fm_dimensions[0] = output_width;
      output_fm_dimensions[1] = output_height;
      output_fm_dimensions[2] = output_channels;
      output_fm_dimensions[3] = batchsize;
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
              if (VERBOSE > 1) $write("%6d + ",
                expected_out[output_index]);
              for (kw=0; kw<kernel_width && iw < ow; kw=kw+1)
              begin
                in_h = (ih*kernel_stride+kh-pad_r_s);
                in_w = (iw*kernel_stride+kw-pad_w);
                input_index = (0 * input_height + in_h) * input_width + in_w;
                in = data_in[input_index];
                if (in_h < 0 || in_h >= input_height ||
                  in_w < 0 || in_w >= input_width)
                  in = 0;
                kernel_index = (0*kernel_height+kh)*kernel_width+kw;
                expected_out[output_index] = ((weight[kernel_index] * in) >>> `PRECISION_FRAC) + expected_out[output_index];
                if (VERBOSE > 1) $write("%8d x ", weight[kernel_index]);
                if (VERBOSE > 1) $write("%-8d + ", in);
              end
              if (VERBOSE > 1) $display;
            end
            if (VERBOSE > 1)
            begin
              $write(" = %6d",
                expected_out[output_index]);
              $display;
              $display;
            end
          end
          //expected_out[output_index] = expected_out[output_index] >>> `PRECISION_FRAC;
          if (VERBOSE > 1)
          begin
            $write(" = %6d",
              expected_out[output_index]);
            $display;
            $display;
          end
          if (VERBOSE > 1) $display;
        end
      end
      expected_writes = (output_width/NUM_PE) * output_height;
      output_fm_size = ceil_a_by_b(output_width, NUM_PE) * output_height;
      if (VERBOSE == 1) $display("Expected number of writes = %6d", expected_writes);
    end
  endtask

  integer max_data_in_count;


  task initialize_weight_fc;
    input integer input_channels;
    input integer output_channels;
    integer i, j, k;
    integer idx, val;
    integer width, height;
    begin
      rd_ready = 1'b1;
      data_in_counter = 0;
      width = 1;
      height = 1;
      weight_dimensions[0] = width;
      weight_dimensions[1] = height;
      weight_dimensions[2] = input_channels;
      weight_dimensions[3] = output_channels;
      output_fm_dimensions[0] = width;
      output_fm_dimensions[1] = height;
      output_fm_dimensions[2] = output_channels;
      output_fm_dimensions[3] = 1;
      input_fm_size = input_channels * output_channels;
      max_data_in_count = width * height * input_channels * output_channels;
      $display ("# Input Synapses = %d", max_data_in_count);
      $display ("Weight Dimensions = %d x %d x %d x %d",
        1, 1, input_channels, output_channels);
      for (i=0; i<output_channels; i=i+1)
      begin
        for (j=0; j<input_channels; j=j+1)
        begin
          idx = i*input_channels + j;
          //data_in[idx] = (idx % (4)) << `PRECISION_FRAC;
          data_in[idx] = idx;
        end
      end
    end
  endtask

  task initialize_input_fc;
    input integer input_channels;
    integer i, j, k, l;
    integer index;
    begin
      input_fm_dimensions[0] = 1;
      input_fm_dimensions[1] = 1;
      input_fm_dimensions[2] = input_channels;
      input_fm_dimensions[3] = 1;
      buffer_dimensions[0] = input_channels;
      buffer_dimensions[1] = 1;
      buffer_dimensions[2] = 1;
      buffer_dimensions[3] = 1;
      $display("Initializing inputs for FC layer");
      $display("FC layer inputs = %d", input_channels);
      for (k=0; k<input_channels; k=k+1)
      begin
        index = k;
        weight[index] = (index + 1) << `PRECISION_FRAC;
        buffer[index] = weight[index];
      end
      buffer_read_empty = 1'b0;
    end
  endtask




  task initialize_input;
    input integer width;
    input integer height;
    input integer channels;
    input integer output_channels;
    integer i, j, c;
    integer idx;
    begin
      rd_ready = 1'b1;
      data_in_counter = 0;
      input_fm_dimensions[0] = width;
      input_fm_dimensions[1] = height;
      input_fm_dimensions[2] = channels;
      input_fm_dimensions[3] = output_channels;
      //input_fm_size = ceil_a_by_b(width * height, NUM_PE) * NUM_PE * channels;
      input_fm_size = width * height * channels;
      max_data_in_count = width * height;
      $display ("# Input Neurons = %d", max_data_in_count);
      $display ("Input Dimensions = %d x %d x %d x %d",
        width, height, channels, output_channels);
      for (c=0; c<channels; c=c+1)
      begin
        for (i=0; i<height; i=i+1)
        begin
          for (j=0; j<width; j=j+1)
          begin
            idx = j + width * (i + height * c);
            //data_in[idx] = (idx % 4) << `PRECISION_FRAC;
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
      buffer_dimensions[0] = width;
      buffer_dimensions[1] = height;
      buffer_dimensions[2] = input_channels;
      buffer_dimensions[3] = output_channels;
      buffer[0] = 0;
      buffer[1] = 0;
      buffer[2] = 0;
      buffer[3] = 0;
      for (k=0; k<input_channels; k=k+1)
      begin
        for (l=0; l<output_channels; l=l+1)
        begin
          for (i=0; i<height; i=i+1)
          begin
            for (j=0; j<width; j=j+1)
            begin
              index = (((l*output_channels + k)* height + i) * width + j);
              weight[index] = (index+0) << `PRECISION_FRAC;
              buffer[index+4] = weight[index];
              //if (VERBOSE > 1)
                //$display ("Index %d;\t Value %d",
                  //index, weight[index]);
            end
          end
        end
      end
      buffer_read_empty = 1'b0;
    end
  endtask

  integer data_in_counter;
  task pu_read;
    integer i;
    integer input_idx;
    integer tmp;
    begin
      input_idx = data_in_counter % input_fm_size;
      //if (VERBOSE > 1) $display("PU Read Request");
      for (i=0; i<NUM_PE; i=i+1)
      begin
        tmp = (input_idx+i)%input_fm_dimensions[0];
        if ((input_idx)%input_fm_dimensions[0]+i >= input_fm_dimensions[0] && input_fm_dimensions[0] > 1)
          pu_data_in[i*OP_WIDTH+:OP_WIDTH] = 0;
        else begin
          pu_data_in[i*OP_WIDTH+:OP_WIDTH] = data_in[input_idx+i];
          data_in_counter = data_in_counter+1;
        end
        if (data_in_counter >= max_data_in_count)
          rd_ready = 1'b0;//status.test_fail;
      end
      //if (VERBOSE > 1) $display("PU Read Reponse: %h\n", pu_data_in);
    end
  endtask

  integer write_count;
  initial write_count = 0;
  task pu_write;
    integer i;
    reg signed [OP_WIDTH-1:0] tmp;
    reg signed [OP_WIDTH-1:0] exp_data;
    integer idx;
    begin
      //$display("PU write Request");
      if (VERBOSE > 0) $write("PU write DATA : ");
      for (i=0; i<NUM_PE; i=i+1)
      begin
        tmp = pu_data_out[i*OP_WIDTH+:OP_WIDTH];
        if (VERBOSE > 0) $write("%d ", tmp);
      end
      if (VERBOSE > 0) $display;

      if (VERBOSE > 0) $write("Expected      : ");
      for (i=0; i<NUM_PE; i=i+1)
      begin
        idx = (write_count + i) % (output_fm_size*NUM_PE);
        if (pool_enabled)
          exp_data = expected_pool_out[idx];
        else
          exp_data = expected_out[idx];
        if (VERBOSE > 0) $write("%d ", exp_data);
      end
      if (VERBOSE > 0) $display;

      for (i=0; i<NUM_PE; i=i+1)
      begin
        idx = (write_count + i) % (output_fm_size*NUM_PE);
        tmp = pu_data_out[i*OP_WIDTH+:OP_WIDTH];
        if (pool_enabled)
          exp_data = expected_pool_out[idx];
        else
          exp_data = expected_out[idx];
        if (tmp !== exp_data)
        begin
          $error ("PU write data does not match expected");
          $display ("Expected %d, got %d", exp_data, tmp);
          $display ("Write Count = %d", write_count);
          status.test_fail;
        end
      end
      write_count += NUM_PE;
      if (VERBOSE > 0) $display ("Write Count = %d", write_count);
      if (VERBOSE > 0) $display;

    end
  endtask

  always @(posedge clk)
  begin
    if (pu_rd_req && pu_rd_ready)
      pu_read;
  end

  always @(posedge clk)
  begin
    if (pu_wr_req)
      pu_write;
  end

  initial begin
    data_in_counter = 0;
    rd_ready = 0;
  end

  integer delay_count = 0;
  reg rd_ready;
  always @(negedge clk)
  begin
    if (delay_count != 24)
      delay_count <= delay_count + 1;
    else
      delay_count <= 0;
  end

  assign pu_rd_ready = (delay_count == 0) && rd_ready;
  //assign pu_rd_ready = rd_ready;

  task send_buffer_data;
    integer num_buffer_reads;
    integer num_data;
    integer idx;
    integer ii;
    begin
      wait(!buffer_read_empty);
      repeat(20) @(negedge clk);
      $display ("Buffer Data dimensions are: %d x %d x %d x %d",
        buffer_dimensions[3], buffer_dimensions[2],
        buffer_dimensions[1], buffer_dimensions[0]);
      @(negedge clk);
      @(negedge clk);
      buffer_read_empty = 1'b0;
      num_data = buffer_dimensions[0] * buffer_dimensions[1];
      num_buffer_reads = ceil_a_by_b(num_data, NUM_PE) *
        ceil_a_by_b(NUM_PE,4);
      buffer_read_data_valid = 1;
      //buffer_read_data_out = 0;
      //@(negedge clk);
      idx = 0;
      $display ("Number of Buffer reads = %d",
        num_buffer_reads);
      repeat(num_buffer_reads+0) begin
        for (ii=0; ii<4; ii=ii+1) begin
          buffer_read_data_out[ii*OP_WIDTH+:OP_WIDTH] = buffer[idx];
          idx = idx+1;
        end
      @(negedge clk);
      //$display ("%h", buffer_read_data_out);
      end
      buffer_read_data_valid = 0;
      @(negedge clk);
      buffer_read_last = 1'b1;
      @(negedge clk);
      buffer_read_last = 1'b0;
      buffer_read_empty = 1'b1;
    end
  endtask

  initial begin
    buffer_read_data_valid = 0;
    buffer_read_last = 1'b0;
    buffer_read_empty = 1'b1;
  end

  always @(posedge clk)
  begin
    if (buffer_read_req)
      send_buffer_data;
  end

endmodule
