`include "common.vh"
module controller_tb_driver #(
  parameter integer NUM_PE            = 4,
  parameter integer WEIGHT_ADDR_WIDTH = 4,
  parameter integer PE_CTRL_WIDTH     = 4,
  parameter integer TID_WIDTH         = 8,
  parameter integer PAD_WIDTH         = 3,
  parameter integer VECGEN_CTRL_W     = 9,
  parameter integer VECGEN_CFG_W      = TID_WIDTH + PAD_WIDTH
) (
  input  wire clk,
  input  wire reset,
  input  wire                     ready,
  output wire [VECGEN_CTRL_W-1:0] ctrl
);

// ******************************************************************
// Local variables
// ******************************************************************
  reg                 vectorgen_pop;
  reg                 vectorgen_shift;
  reg                 vectorgen_nextrow;
  reg                 vectorgen_start;
  reg                 vectorgen_nextfm;
  reg                 vectorgen_endrow;
  reg                 vectorgen_skip;
  reg                 readData;
  reg                 nextData;
  reg  [TID_WIDTH-1:0]max_threads;
  reg  [PAD_WIDTH-1:0]padding;

  integer input_fm_dimensions  [3:0];
  integer output_fm_dimensions [3:0];
  integer weight_dimensions    [4:0];
// ******************************************************************

  test_status #(
    .PREFIX   ( "CONTROLLER"  ),
    .TIMEOUT  ( 100000        )
  ) status (
    .clk      ( clk           ),
    .reset    ( reset         ),
    .pass     ( 1'b0          ),
    .fail     ( 1'b0          )
  );

// ==================================================================
  task generate_vectors;
    integer iw, ih;
    integer ow, oh;
    integer kw, kh;
    reg skip;
    integer kh_min, kh_max;
    begin
      kh_min = weight_dimensions[1] - 1;
      kh_max = weight_dimensions[1] - 1;
      readData = 1'b0;
      nextData = 1'b0;
      skip = weight_dimensions[0]-2*padding > NUM_PE;
      vectorgen_start = 1'b1;
      wait(ready);
      vectorgen_start = 1'b0;
      @(negedge clk);
      for (ih=0; ih<input_fm_dimensions[1]; ih=ih+1)
      begin
        kh_min = ih > (weight_dimensions[1]-1) ? 0 :
          (weight_dimensions[1]-1)-ih;
        kh_min = kh_min < 0 ? 0 : kh_min;
        kh_max = ih > (output_fm_dimensions[1]-1) ?  kh_max - 1 :
          weight_dimensions[1] - 1;
        if (ih == 0) vectorgen_nextrow = 1'b0;
        else         vectorgen_nextrow = 1'b1;
        for (ow=0; ow<output_fm_dimensions[0]/NUM_PE; ow=ow+1)
        begin
          if (ow != 0 || ih != 0) begin
            //readData = 1'b1;
            nextData = !((ih == input_fm_dimensions[1] - 1) &&
                   (ow == (output_fm_dimensions[1]/NUM_PE)));
            readData = 1'b1;
            if (ow == output_fm_dimensions[1]/NUM_PE)
              vectorgen_endrow = 1'b1;
            else
              vectorgen_endrow = 1'b0;
          end else begin
            readData = 1'b0;
            nextData = 1'b0;
            vectorgen_endrow = 1'b0;
          end
          for (kh=kh_max; kh>=kh_min; kh=kh-1) begin
            for (kw=0; kw<weight_dimensions[0];kw=kw+1) begin
              vectorgen_pop   = (kw == 0);
              vectorgen_shift = (kw != 0);
              vectorgen_skip = (kw == 0) && (kh == kh_min) &&
                (ow == output_fm_dimensions[0]/NUM_PE - 1) &&
                !(ih == input_fm_dimensions[1] - 1) && skip;
              @(negedge clk);
              vectorgen_shift = 1'b0;
              readData = 1'b0;
              nextData = 1'b0;
              vectorgen_nextrow = 1'b0;
              vectorgen_endrow = 1'b0;
              vectorgen_pop = 1'b0;
            end
          end
        end
      end
      @(negedge clk);
      vectorgen_nextfm = 1'b1;
      @(negedge clk);
      vectorgen_nextfm = 1'b0;
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
      @(negedge clk);
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
  assign ctrl = {nextData, readData, vectorgen_pop_dd, vectorgen_shift_dd,
    vectorgen_nextrow, vectorgen_skip_dd, vectorgen_endrow,
    vectorgen_start, vectorgen_nextfm};
  assign cfg  = {max_threads, padding};
  initial begin
    vectorgen_pop = 1'b0;
    vectorgen_shift = 1'b0;
    vectorgen_nextrow = 1'b0;
    vectorgen_nextfm = 1'b0;
  end
// ==================================================================

  task initialize_layer_params;
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

    begin
      input_fm_dimensions[0] = input_width;
      input_fm_dimensions[1] = input_height;
      input_fm_dimensions[2] = input_channels;
      input_fm_dimensions[3] = batchsize;

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
    end
  endtask

endmodule
