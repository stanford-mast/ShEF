module vectorgen_tb_driver
#(
  parameter integer OP_WIDTH      = 16,    // Operand width. Supported : 16
  parameter integer NUM_PE        = 1,
  parameter integer VECGEN_CTRL_W = 9,
  parameter integer TID_WIDTH     = 8,
  parameter integer PAD_WIDTH     = 3,
  parameter integer VECGEN_CFG_W  = TID_WIDTH + PAD_WIDTH
)
(
  output wire                     clk,
  output wire                     reset,

  output wire [VECGEN_CTRL_W-1:0] ctrl,
  output wire [VECGEN_CFG_W -1:0] cfg,
  input  wire                     ready,

  output reg                      read_ready,
  output reg  [DATA_WIDTH  -1 :0] read_data,
  input  wire                     read_req,

  input  wire                     write_valid, // TODO generate this
  input  wire [DATA_WIDTH  -1 :0] write_data,
  input  wire [NUM_PE      -1 :0] write_mask
);
// ******************************************************************
// local parameters
// ******************************************************************
  localparam integer DATA_WIDTH   = OP_WIDTH * NUM_PE;
// ******************************************************************
// Wires and Regs
// ******************************************************************
  reg  [OP_WIDTH-1:0] data_in  [0:1<<20-1];
  reg  [OP_WIDTH-1:0] weight   [0:1<<20-1];
  reg  [OP_WIDTH-1:0] expected_out [0:1<<20-1];
  reg                 readData;
  reg                 nextData;
  reg                 vectorgen_pop;
  reg                 vectorgen_shift;
  reg                 vectorgen_nextrow;
  reg                 vectorgen_start;
  reg                 vectorgen_nextfm;
  reg                 vectorgen_endrow;
  reg                 vectorgen_skip;
  reg                 pass=0, fail=0;
  reg  [TID_WIDTH-1:0]max_threads;
  reg  [PAD_WIDTH-1:0]padding;
// ******************************************************************
// Test Configuration
// ******************************************************************
  integer input_fm_dimensions  [3:0];
  integer output_fm_dimensions [3:0];
  integer weight_dimensions    [4:0];

  integer vecgen_count;
  integer write_index = 0;

  test_status #(
    .PREFIX   ( "VECTORGEN"   ),
    .TIMEOUT  ( 100000        )
  ) status (
    .clk      ( clk           ),
    .reset    ( reset         ),
    .pass     ( pass          ),
    .fail     ( fail          )
  );

  clk_rst_driver
  clkgen(
    .clk      ( clk       ),
    .reset_n  (           ),
    .reset    ( reset     )
  );


  task initialize_expected_output;
    // input fm dimensions
    input integer input_width;
    input integer input_height;
    input integer input_channels;
    // batch size
    input integer batchsize;
    // kernel size
    input integer kernel_width;
    input integer kernel_height;
    input integer kernel_stride;
    // output channels
    input integer output_channels;
    // padding
    input integer pad;
    // output fm dimensions
    integer output_width;
    integer output_height;

    integer iw, ih, ic, b, kw, kh, ow, oh, pe;

    integer input_index, output_index, kernel_index;

    integer tmp, tmp_ih;

    begin

      controller_driver.initialize_layer_params
      (
        input_width,
        input_height,
        input_channels,
        batchsize,
        kernel_width,
        kernel_height,
        kernel_stride,
        output_channels,
        pad
      );

      $display ("IW = %d", input_width);
      $display ("KS = %d", kernel_stride);
      $display ("KW = %d", kernel_width);
      $display ("PAD = %d", pad);

      output_width = ceil_a_by_b(
        ceil_a_by_b((input_width - kernel_width+1+2*pad), kernel_stride),
        NUM_PE) * NUM_PE;
      //output_height = ceil_a_by_b(
      //  ceil_a_by_b((input_height - kernel_height+1+2*pad), kernel_stride),
      //  NUM_PE) * NUM_PE;
      output_height = input_height - kernel_height + 1;
      weight_dimensions[0] = kernel_width;
      weight_dimensions[1] = kernel_height;
      weight_dimensions[2] = input_channels;
      weight_dimensions[3] = output_channels;
      output_fm_dimensions[0] = output_width;
      max_threads = input_width-kernel_width+1+2*pad;
      padding = pad;
      output_fm_dimensions[1] = output_height;
      output_fm_dimensions[2] = output_channels;
      output_fm_dimensions[3] = batchsize;
      $display ("expected output size %d x %d x %d x %d",
        output_width,output_height,output_channels,batchsize);
      $display ("kernel size %d x %d x %d x %d",
        kernel_width,kernel_height,input_channels,output_channels);
      output_index = 0;

      vecgen_count =
        (output_width/NUM_PE) * output_height *
        weight_dimensions[0] * weight_dimensions[1] * weight_dimensions[2] *
        weight_dimensions[3];

      for (ic=0; ic<input_channels; ic=ic+1)
      begin
      for (ih=0; ih<input_height; ih=ih+1)
      begin
        for (iw=0; iw<output_width; iw=iw+NUM_PE)
        begin
          for (kh=0; kh<kernel_height; kh=kh+1)
          begin
            if ((ih+kh)>=(kernel_height-1-padding) && (ih+kh)<input_height+padding)
            begin
              for (kw=0; kw<kernel_width; kw=kw+1)
              begin
                for (pe=0; pe<NUM_PE; pe=pe+1)
                begin
                  input_index  = iw+pe+kw+input_width*(ih+ic*input_height) - padding;
                  tmp = data_in[input_index];
                  tmp = iw+pe >= input_width ? 0 : tmp;
                  tmp = input_index > (ih+1)*input_width-1 ? 0 : tmp;
                  expected_out[output_index] = tmp;
                  $write("%8d",expected_out[output_index]);
                  output_index = output_index + 1;
                end
              end
            end
            $display;
          end
        end
        $display;
        end
        //$display;
      end
    end
  endtask

  always@(negedge clk)
    read_ready = 1'b1;

  integer max_data_in_count;
  task initialize_input;
    input integer width;
    input integer height;
    input integer channels;
    input integer batchsize;
    integer i, j, k;
    integer tmp;
    begin
      input_fm_dimensions[0] = width;
      input_fm_dimensions[1] = height;
      input_fm_dimensions[2] = channels;
      input_fm_dimensions[3] = batchsize;
      max_data_in_count = width * height * channels * batchsize;
      $display ("Max Data In Count = %d", max_data_in_count);
      //read_ready = 1'b1;
      for (k=0; k<channels; k=k+1)
      begin
        for (i=0; i<height; i=i+1)
        begin
          for (j=0; j<width; j=j+1)
          begin
            tmp = (k*height + i)*width + j;
            data_in[tmp] = tmp;
            $display ("Index %d, %d, %d;\t Value %d",
              i, j, k, tmp);
          end
        end
      end
    end
  endtask

  integer data_in_counter;
  task vectorgen_read;
    integer i;
    begin
      //$display("vectorgen read Request");
      for (i=0; i<NUM_PE; i=i+1)
      begin
        $display ("Read data: %d", data_in[data_in_counter]);
        if ((data_in_counter-i)%input_fm_dimensions[0]+i >= input_fm_dimensions[0])
          read_data[i*OP_WIDTH+:OP_WIDTH] = 0;
        else begin
          read_data[i*OP_WIDTH+:OP_WIDTH] = data_in[data_in_counter];
          data_in_counter = data_in_counter+1;
        end
      end
      if (data_in_counter > max_data_in_count)
      begin
        read_ready = 1'b0;
        $error ("Read more than required");
        status.test_fail;
      end
      //$display("vectorgen read Reponse: %h",
        //read_data);
    end
  endtask

  task validate_vectorgen_write;
    integer pe;
    reg state;
    begin
      state = 1;
      // for (pe=0; pe<NUM_PE; pe=pe+1) begin
      //   if (write_data[pe*OP_WIDTH+:OP_WIDTH] != expected_out[write_index+pe])
      //   begin
      //     state = 1;
      //   end
      // end
        $write("%2d ",$time);
        $write("vectorgen write DATA : ");
        for (pe=0; pe<NUM_PE; pe=pe+1) begin
          $write("PE%-4d:", pe);
          $write("%-8d ", write_data[pe*OP_WIDTH+:OP_WIDTH]);
        end
        $display;
        $write("%2d ",$time);
        $write("expected write DATA  : ");
        for (pe=0; pe<NUM_PE; pe=pe+1) begin
          $write("PE%-4d:", pe);
          if (write_mask[pe])
            $write("%-8d ", expected_out[write_index+pe]);
          else
            $write("%-8d", expected_out[write_index+pe]);
          state = state && (expected_out[write_index+pe] == write_data[pe*OP_WIDTH+:OP_WIDTH]);
        end
        $display;
      if (state == 0)
      begin
        $error("Data from vectorgen does not match expected");
        status.test_fail;
      end
      write_index = write_index + NUM_PE;
    end
  endtask

  always @(posedge clk)
  begin
    if (!reset && read_req)
      vectorgen_read;
  end

  always @(posedge clk)
  begin
    if (write_valid)
      validate_vectorgen_write;
  end

  initial begin
    data_in_counter = 0;
  end

  task print_input;
    integer i, j, k, l;
    integer index;
    begin
      for (i=0; i<input_fm_dimensions[3]; i=i+1) begin
        for (j=0; j<input_fm_dimensions[2]; j=j+1) begin
          for (k=0; k<input_fm_dimensions[1]; k=k+1) begin
            for (l=0; l<input_fm_dimensions[0]; l=l+1) begin
              index = l + input_fm_dimensions[0] * ( k + input_fm_dimensions[1] * ( j + input_fm_dimensions[2] * i));
              $write ("%d ", data_in[index]);
            end
            $display;
          end
          $display;
          $display;
        end
        $display;
        $display;
        $display;
        $display;
      end
    end
  endtask

  task generate_vectors;
    integer iw, ih;
    integer ow, oh;
    integer kw, kh;
    reg skip;
    integer kh_min, kh_max;
    begin
      write_index = 0;
      controller_driver.generate_vectors;
      wait (vecgen_count == (write_index/4));
      data_in_counter = 0;
      if (vecgen_count != (write_index/4)) begin
        $display ("Expected %d writes, Got %d", vecgen_count, write_index/4);
        status.test_fail;
      end
    end
  endtask

  reg vectorgen_pop_d, vectorgen_shift_d;
  reg vectorgen_pop_dd, vectorgen_shift_dd;
  reg vectorgen_nextrow_d, vectorgen_nextrow_dd;
  reg vectorgen_skip_d, vectorgen_skip_dd;
  always @(posedge clk)
  begin
    vectorgen_shift_d <= vectorgen_shift;
    vectorgen_pop_d <= vectorgen_pop;
    vectorgen_nextrow_d <= vectorgen_nextrow;
    vectorgen_skip_d <= vectorgen_skip;
  end
  always @(posedge clk)
  begin
    vectorgen_shift_dd <= vectorgen_shift_d;
    vectorgen_pop_dd <= vectorgen_pop_d;
    vectorgen_nextrow_dd <= vectorgen_nextrow_d;
    vectorgen_skip_dd <= vectorgen_skip_d;
  end

  // Control signals for vectorgen
  // assign ctrl = {nextData, readData, vectorgen_pop_dd, vectorgen_shift_dd,
  //   vectorgen_nextrow, vectorgen_skip_dd, vectorgen_endrow,
  //   vectorgen_start, vectorgen_nextfm};
  assign cfg  = {max_threads, padding};
  initial begin
    vectorgen_pop = 1'b0;
    vectorgen_shift = 1'b0;
    vectorgen_nextrow = 1'b0;
    vectorgen_nextfm = 1'b0;
  end

// ==================================================================
// Controller Driver
// ==================================================================
    controller_tb_driver
    #(  // PARAMETERS
        .NUM_PE             ( NUM_PE            ),
        .WEIGHT_ADDR_WIDTH  ( 10                ),
        .PE_CTRL_WIDTH      ( 9                 ),
        .VECGEN_CTRL_W      ( VECGEN_CTRL_W     ),
        .TID_WIDTH          ( TID_WIDTH         ),
        .PAD_WIDTH          ( PAD_WIDTH         )
    ) controller_driver (   // PORTS
        .clk                ( clk               ), //input
        .reset              ( reset             ), //input
        .ready              ( ready             ), //input
        .ctrl               ( ctrl              )  //output
    );
// ==================================================================


endmodule
