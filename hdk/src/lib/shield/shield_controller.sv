`default_nettype none
`timescale 1ns/1ps

//NOTE:
//32-bit addresses by default.
//ARSIZE must be equal to CLOG2(CL_DATA_WIDTH/8)

module shield_controller #(
  parameter integer CL_DATA_WIDTH = 64,
  parameter integer CL_ID_WIDTH = 6,
  parameter integer SHIELD_ADDR_WIDTH = 32,
  parameter integer AXI_ADDR_WIDTH = 64,
  parameter integer LINE_WIDTH = 512,
  parameter integer CACHE_DEPTH = 256,
  parameter integer OFFSET_WIDTH = 6,
  parameter integer INDEX_WIDTH = 8,
  parameter integer TAG_WIDTH = 18
)
(
  input  wire clk,
  input  wire rst_n,

  //Control signals
  output wire req_type,
  output wire req_en, //Signal to register request
  output wire cl_read_req_rdy,
  output wire req_rw_mux_sel, //select read or write req from cl
  output wire req_cycle_mux_sel, //Select between cycles of a request
  output wire array_read_index_mux_sel, //index into cache rams
  output wire tag_array_wr_en, 
  output wire data_array_wr_en,
  output wire shield_read_slv_input_val, //input to shield read slave valid
  output wire shield_read_mstr_req_val,
  output wire shield_read_mstr_resp_rdy,
  output wire cl_write_req_rdy,
  output wire shield_write_slv_req_val,
  output wire shield_write_slv_cache_line_rdy,
  output wire data_array_data_mux_sel, //write data from dram or cl
  output wire cl_write_resp_val,
  output wire shield_write_mstr_req_val,
  output wire stream_axi_read_mux_sel,
  output wire stream_axi_write_mux_sel,
  output wire stream_read_req_val,
  output wire stream_write_req_val,

  //Status signals
  input wire                         cl_read_req_val,
  input wire                         tag_match,
  input wire [SHIELD_ADDR_WIDTH-1:0] req_addr_r,
  input wire                         req_type_r,
  input wire                         shield_read_slv_input_rdy,
  input wire                         req_last,
  input wire                         shield_read_mstr_req_rdy,
  input wire                         shield_read_mstr_resp_val,
  input wire [INDEX_WIDTH-1:0]       array_refill_index,
  input wire                         cl_write_req_val,
  input wire                         shield_write_slv_req_rdy,
  input wire                         shield_write_slv_cache_line_val,
  input wire                         cl_write_resp_rdy,
  input wire                         shield_write_mstr_req_rdy,
  input wire                         stream_read_req_rdy,
  input wire                         stream_write_req_rdy,
  input wire                         read_addr_stream_bound,
  input wire                         write_addr_stream_bound,
  input wire                         stream_read_busy,
  input wire                         stream_write_busy,
  input wire                         shield_read_busy,
  input wire                         shield_write_busy,

  //Debug signals
  output wire [3:0]                  shield_state

);
  //////////////////////////////////////////////////////////////////////////////
  // localparams
  //////////////////////////////////////////////////////////////////////////////
  localparam STATE_IDLE          = 5'd0,
             STATE_TAG_CHECK     = 5'd1,
             STATE_RD_TXFER      = 5'd2,
             STATE_RD_NEXT       = 5'd3,
             STATE_REFILL_REQ    = 5'd4,
             STATE_REFILL_WAIT   = 5'd5,
             STATE_REFILL_UPDATE = 5'd6,
             STATE_EVICT         = 5'd7,
             STATE_WR_PREPARE    = 5'd8, 
             STATE_WR_INIT       = 5'd9, 
             STATE_WR_RXFER      = 5'd10, 
             STATE_WR_UPDATE     = 5'd11, 
             STATE_WR_NEXT       = 5'd12, 
             STATE_WR_FINALIZE   = 5'd13;
             //STATE_STREAM_RD_REQ = 5'd14, 
             //STATE_STREAM_RD_NEXT= 5'd15,
             //STATE_STREAM_RD_FINALIZE = 5'd16;


  //////////////////////////////////////////////////////////////////////////////
  // declaration
  //////////////////////////////////////////////////////////////////////////////
  logic [4:0] state_r;
  logic [4:0] next_state;


  //Control signals
  logic cs_read_req_rdy;
  logic cs_req_en; //Signal to register request
  logic cs_rw_mux_sel;
  logic cs_req_cycle_mux_sel; //Select between cycles of a request
  logic cs_array_read_index_mux_sel; //index into cache rams
  logic cs_tag_array_wr_en; 
  logic cs_data_array_wr_en;
  logic cs_shield_read_slv_input_val; //input to shield read slave valid
  logic cs_shield_read_mstr_req_val;
  logic cs_shield_read_mstr_resp_rdy;
  logic cs_req_type;
  logic cs_write_req_rdy;
  logic cs_shield_write_slv_req_val;
  logic cs_shield_write_slv_cache_line_rdy;
  logic cs_data_array_data_mux_sel;
  logic cs_write_resp_val;
  logic cs_shield_write_mstr_req_val;
  logic cs_stream_read_req_val;
  logic cs_stream_write_req_val;

  logic shield_stream_read_sel;
  logic shield_stream_read_sel_we;
  logic shield_stream_write_sel;
  logic shield_stream_write_sel_we;



  //////////////////////////////////////////////////////////////////////////////
  // Register files
  //////////////////////////////////////////////////////////////////////////////
  logic [INDEX_WIDTH-1:0] valid_dirty_read_addr;
  logic [INDEX_WIDTH-1:0] valid_dirty_write_addr;
  logic [INDEX_WIDTH-1:0] req_addr_r_index;
  logic valid_dirty_write_index_mux_sel;

  logic                   valid_read_data;
  logic                   valid_write_data;
  logic                   valid_write_en;
  //Valid bit
  shield_resetregfile #(.DATA_WIDTH(1), .ADDR_WIDTH(INDEX_WIDTH)) valid_regfile(
    .clk       (clk),
    .rst_n     (rst_n),
    .read_addr (valid_dirty_read_addr),
    .read_data (valid_read_data),
    .write_en  (valid_write_en),
    .write_addr(valid_dirty_write_addr),
    .write_data(valid_write_data)
  );
  //Dirty bit
  logic                   dirty_read_data;
  logic                   dirty_write_data;
  logic                   dirty_write_en;
  //Valid bit
  shield_resetregfile #(.DATA_WIDTH(1), .ADDR_WIDTH(INDEX_WIDTH)) dirty_regfile(
    .clk       (clk),
    .rst_n     (rst_n),
    .read_addr (valid_dirty_read_addr),
    .read_data (dirty_read_data),
    .write_en  (dirty_write_en),
    .write_addr(valid_dirty_write_addr),
    .write_data(dirty_write_data)
  );

  assign req_addr_r_index = req_addr_r[SHIELD_ADDR_WIDTH-TAG_WIDTH-1 -: INDEX_WIDTH];
  assign valid_dirty_read_addr = req_addr_r_index;

  //Mux for val/dirty write address
  shield_mux2 #(.WIDTH(INDEX_WIDTH)) valid_dirty_write_index_mux(
    .in0(req_addr_r_index),
    .in1(array_refill_index),
    .sel(valid_dirty_write_index_mux_sel),
    .out(valid_dirty_write_addr)
  );

  //register for stream/shield
  shield_enrstreg #(.WIDTH(1)) read_shield_stream_sel_reg(
    .clk(clk),
    .rst_n(rst_n),
    .q(stream_axi_read_mux_sel),
    .d(shield_stream_read_sel),
    .en(shield_stream_read_sel_we)
  );
  shield_enrstreg #(.WIDTH(1)) write_shield_stream_sel_reg(
    .clk(clk),
    .rst_n(rst_n),
    .q(stream_axi_write_mux_sel),
    .d(shield_stream_write_sel),
    .en(shield_stream_write_sel_we)
  );


  //////////////////////////////////////////////////////////////////////////////
  // Logic
  //////////////////////////////////////////////////////////////////////////////
  //State assignment
  always_ff @(posedge clk) begin
    if(!rst_n) begin
      state_r <= STATE_IDLE;
    end
    else begin
      state_r <= next_state;
    end
  end

  //next state transition
  always_comb begin
    next_state = state_r; //default to same state
    case (state_r)
      STATE_IDLE: begin //Wait for read request to come
        if(cl_read_req_val) begin
          if(((stream_axi_read_mux_sel == 1'b0) && (!read_addr_stream_bound)) ||
             ((stream_axi_read_mux_sel == 1'b1) && (!read_addr_stream_bound) && (!stream_read_busy))) begin
            next_state = STATE_TAG_CHECK; 
          end
          //Handle the case where read blocked targeting stream, but write targets shield
          else if(read_addr_stream_bound && cl_write_req_val && 
            (((stream_axi_write_mux_sel == 1'b0) && (!write_addr_stream_bound)) ||
             ((stream_axi_write_mux_sel == 1'b1) && (!write_addr_stream_bound) && (!stream_write_busy)))) begin
            next_state = STATE_WR_PREPARE;
          end
        end
        else if(cl_write_req_val) begin
          if(((stream_axi_write_mux_sel == 1'b0) && (!write_addr_stream_bound)) ||
             ((stream_axi_write_mux_sel == 1'b1) && (!write_addr_stream_bound) && (!stream_write_busy))) begin
            next_state = STATE_WR_PREPARE;
          end
        end

        //if(cl_read_req_val) begin
        //  if(req_addr_stream_bound) begin
        //    next_state = STATE_STREAM_RD_REQ;
        //  end
        //  else begin
        //    next_state = STATE_TAG_CHECK;
        //  end
        //end
        //else if(cl_write_req_val) begin //if no read, but write asserted, do write
        //  next_state = STATE_WR_PREPARE;
        //end
      end
      STATE_TAG_CHECK: begin //Send the tag read command
        if(valid_read_data) begin //valid
          if(dirty_read_data) begin //and dirty
            if(tag_match) begin //valid, dirty, hit
              if(req_type_r == 1'b1) begin //Write hit
                next_state = STATE_WR_RXFER;
              end
              else begin //Read it
                next_state = STATE_RD_TXFER;
              end
            end
            else begin //valid, dirty, miss
              next_state = STATE_EVICT;
            end
          end
          else begin 
            if(tag_match) begin //valid, not dirty, hit
              if(req_type_r == 1'b1) begin
                next_state = STATE_WR_RXFER;
              end
              else begin
                next_state = STATE_RD_TXFER;
              end
            end
            else begin //valid, not dirty, miss
              next_state = STATE_REFILL_REQ;
            end
          end
        end 
        else begin //not valid (miss and not dirty)
          next_state = STATE_REFILL_REQ;
        end
      end
      STATE_RD_TXFER: begin //Send the read data back to the CL
        if(shield_read_slv_input_rdy && req_last) begin
          //transmission - Go to next stage
          next_state = STATE_IDLE;
        end
        else if(shield_read_slv_input_rdy && (!req_last)) begin
          next_state = STATE_RD_NEXT;
        end
      end
      STATE_RD_NEXT: begin
        next_state = STATE_TAG_CHECK;
      end
      STATE_REFILL_REQ: begin //Make req to memory for refill
        if(stream_axi_read_mux_sel == 1'b0) begin
          if(shield_read_mstr_req_rdy) begin
            next_state = STATE_REFILL_WAIT;
          end
        end
        else begin
          if(!stream_read_busy) begin
            if(shield_read_mstr_req_rdy) begin
              next_state = STATE_REFILL_WAIT;
            end
          end
        end
      end
      STATE_REFILL_WAIT: begin //Wait for read to dram to be valid
        if(shield_read_mstr_resp_val) begin
          next_state = STATE_REFILL_UPDATE;
        end
      end
      STATE_REFILL_UPDATE: begin //Write to arrays
        if(req_type_r == 1'b0) begin //read req
          next_state = STATE_RD_TXFER;
        end
        else begin
          next_state = STATE_WR_RXFER;
        end
      end
      STATE_WR_PREPARE: begin //register the axi write request
        next_state = STATE_WR_INIT;
      end
      STATE_WR_INIT: begin //Wait for write slave to be ready
        if(shield_write_slv_req_rdy) begin
          next_state = STATE_TAG_CHECK;
        end
      end
      STATE_WR_RXFER: begin //Read write data from CL
        if(shield_write_slv_cache_line_val) begin
          next_state = STATE_WR_UPDATE;
        end
      end
      STATE_WR_UPDATE: begin
        if(req_last) begin
          next_state = STATE_WR_FINALIZE;
        end
        else begin 
          next_state = STATE_WR_NEXT;
        end
      end
      STATE_WR_NEXT: begin
        next_state = STATE_WR_INIT;
      end
      STATE_WR_FINALIZE: begin
        //Wait for master to signal write response before continuing
        if(cl_write_resp_rdy) begin
          next_state = STATE_IDLE;
        end
      end
      STATE_EVICT: begin
        if(stream_axi_write_mux_sel == 1'b0) begin // already in shield mode
          if(shield_write_mstr_req_rdy) begin
            next_state = STATE_REFILL_REQ;
          end
        end
        else begin //in stream mode - need to switch
          if(!stream_write_busy) begin
            if(shield_write_mstr_req_rdy) begin
              next_state = STATE_REFILL_REQ;
            end
          end
        end
      end
      //STATE_STREAM_RD_REQ: begin
      //  if(stream_read_req_rdy && stream_req_last) begin
      //    next_state = STATE_STREAM_RD_FINALIZE;
      //  end
      //  else if(stream_read_req_rdy && (!stream_req_last)) begin
      //    next_state = STATE_STREAM_RD_NEXT;
      //  end
      //end
      //STATE_STREAM_RD_NEXT: begin
      //  next_state = STATE_STREAM_RD_REQ;
      //end
      //STATE_STREAM_RD_FINALIZE: begin //Wait until the stream module is done with AXI
      //  //This handles the case where the final req. triggers a page load from dram
      //  if(stream_read_req_rdy) begin
      //    next_state = STATE_IDLE;
      //  end
      //end
    endcase
  end

  //Outputs
  always_comb begin
    //default outputs
    cs_read_req_rdy = 0;
    cs_req_type = 0; //0 if req is read, 1 if write
    cs_req_en = 0; //Signal to register request
    cs_rw_mux_sel = 0;
    cs_req_cycle_mux_sel = 0; //Select between cycles of a request
    cs_array_read_index_mux_sel = 0; //index into cache rams
    cs_tag_array_wr_en = 0; 
    cs_data_array_wr_en = 0;
    cs_shield_read_slv_input_val = 0; //input to shield read slave valid
    cs_shield_read_mstr_req_val = 0;
    cs_shield_read_mstr_resp_rdy = 0;
    cs_req_type = 0; //0 if req is read, 1 if write
    cs_write_req_rdy = 0;
    cs_shield_write_slv_req_val = 0;
    cs_shield_write_slv_cache_line_rdy = 0;
    cs_data_array_data_mux_sel = 0;
    cs_write_resp_val = 0;
    cs_shield_write_mstr_req_val = 0;
    cs_stream_read_req_val = 0;
    cs_stream_write_req_val = 0;

    //Valid/dirty
    valid_dirty_write_index_mux_sel = 0; //0 for req index, 1 for refill index
    valid_write_data = 0;
    valid_write_en = 0;
    dirty_write_data = 0;
    dirty_write_en = 0;

    //sheield vs stream select
    shield_stream_read_sel = 0;
    shield_stream_read_sel_we = 0;
    shield_stream_write_sel = 0;
    shield_stream_write_sel_we = 0;

    case(state_r)
      STATE_IDLE: begin
        if(cl_read_req_val) begin //valid read req
          if(stream_axi_read_mux_sel == 1'b0) begin //in shield mode
            if(!read_addr_stream_bound) begin //shield read
              cs_read_req_rdy = 1'b1;
              cs_req_en = 1'b1;
            end
            else begin //stream read
              if(!shield_read_busy && stream_read_req_rdy) begin //ready to accept stream read
                cs_read_req_rdy = 1'b1;
                shield_stream_read_sel = 1'b1;
                shield_stream_read_sel_we = 1'b1; //switch read mode
                cs_stream_read_req_val = 1'b1;
              end
            end
          end
          else begin //in stream mode
            if(!read_addr_stream_bound) begin  //shield read
              if(!stream_read_busy) begin
                cs_read_req_rdy = 1'b1;
                cs_req_en = 1'b1;
                shield_stream_read_sel = 1'b0;
                shield_stream_read_sel_we = 1'b1; //switch read mode
              end
            end
            else begin //stream read
              if(stream_read_req_rdy) begin //ready to accept stream read
                cs_read_req_rdy = 1'b1;
                cs_stream_read_req_val = 1'b1;
              end
            end
          end
        end

        if(cl_write_req_val) begin //valid write req. just check for streams
          if(stream_axi_write_mux_sel == 1'b0) begin //in shield mode
            if(write_addr_stream_bound && (!shield_write_busy) && stream_write_req_rdy) begin
              cs_write_req_rdy = 1'b1;
              shield_stream_write_sel = 1'b1;
              shield_stream_write_sel_we = 1'b1;
              cs_stream_write_req_val = 1'b1;
            end
          end
          else begin //stream mode
            if (write_addr_stream_bound) begin
              cs_stream_write_req_val = 1'b1;
              if (stream_write_req_rdy) begin
                cs_write_req_rdy = 1'b1;
              end
            end
            //if(write_addr_stream_bound && stream_write_req_rdy) begin
            //  cs_write_req_rdy = 1'b1;
            //  cs_stream_write_req_val = 1'b1;
            //end
          end
        end
        //cs_read_req_rdy = 1'b1; //Signal ready for read
        //cs_req_type = 1'b0; //read request --important when req_en is set
        //cs_req_en = 1'b1; //Enable registers
        //cs_rw_mux_sel = 1'b0; //read input
        //cs_req_cycle_mux_sel = 1'b0;
        //cs_array_read_index_mux_sel = 1'b0; //Use input address
      end
      STATE_TAG_CHECK: begin
        cs_array_read_index_mux_sel = 1'b1; //Use registered address

      end
      STATE_RD_TXFER: begin
        cs_req_cycle_mux_sel = 1'b0;   
        cs_array_read_index_mux_sel = 1'b1; 
        cs_shield_read_slv_input_val = 1'b1; //input to shield read slave valid
      end
      STATE_RD_NEXT: begin
        cs_req_type = 1'b0; //read request
        cs_req_en = 1'b1;  //Enable registers to store next addr
        cs_req_cycle_mux_sel = 1'b1;    //Use registered next address
        cs_array_read_index_mux_sel = 1'b0;  //Index using stored address
      end
      STATE_REFILL_REQ: begin
        cs_array_read_index_mux_sel = 1'b1; //Use registered address
        if(stream_axi_read_mux_sel == 1'b0) begin //in shield mode, ok to read
          cs_shield_read_mstr_req_val = 1'b1;
        end
        else begin //in stream mode - need to wait
          if(!stream_read_busy) begin
            shield_stream_read_sel = 1'b0;
            shield_stream_read_sel_we = 1'b1;
            cs_shield_read_mstr_req_val = 1'b1;
          end
        end
        
        valid_write_data = 1'b0; //invalidate cache line
        valid_write_en = 1'b1;
      end
      STATE_REFILL_WAIT: begin
        cs_array_read_index_mux_sel = 1'b1;
        //Do the write here - since it takes 2 cycles for output to appear
        cs_shield_read_mstr_resp_rdy = 1'b1;
        cs_tag_array_wr_en = 1'b1;
        cs_data_array_wr_en = 1'b1;
      end
      STATE_REFILL_UPDATE: begin
        cs_array_read_index_mux_sel = 1'b1; //use registered address

        //Validate the cache line
        valid_dirty_write_index_mux_sel = 1'b1;
        valid_write_data = 1'b1;
        valid_write_en = 1'b1;
        dirty_write_data = 1'b0;
        dirty_write_en = 1'b1;
      end
      STATE_WR_PREPARE: begin
        cs_write_req_rdy = 1'b1;
        cs_req_type = 1'b1; //store write req type
        cs_req_en = 1'b1;
        cs_rw_mux_sel = 1'b1; //set the input address as awaddr

        shield_stream_write_sel = 1'b0;
        shield_stream_write_sel_we = 1'b1;
      end
      STATE_WR_INIT: begin
        cs_array_read_index_mux_sel = 1'b1; //read index using registered req
        cs_shield_write_slv_req_val = 1'b1;
      end
      STATE_WR_RXFER: begin
        cs_array_read_index_mux_sel = 1'b1; //read index using registered req
        cs_data_array_data_mux_sel = 1'b1;
      end
      STATE_WR_UPDATE: begin
        cs_array_read_index_mux_sel = 1'b1; //read index using registered req
        cs_data_array_data_mux_sel = 1'b1;
        cs_shield_write_slv_cache_line_rdy = 1'b1;
        cs_data_array_wr_en = 1'b1;

        //Dirty
        valid_dirty_write_index_mux_sel = 1'b0; //use request address
        dirty_write_data = 1'b1;
        dirty_write_en = 1'b1;
      end
      STATE_WR_NEXT: begin
        cs_req_type = 1'b1;
        cs_req_en = 1'b1;
        cs_req_cycle_mux_sel = 1'b1;
        cs_array_read_index_mux_sel = 1'b0; //Read using the stored next address
      end
      STATE_WR_FINALIZE: begin
        cs_write_resp_val = 1'b1;
      end
      STATE_EVICT: begin //read tag and data
        cs_array_read_index_mux_sel = 1'b1; //Use registered address
        if(stream_axi_write_mux_sel == 1'b0) begin //in shield mode, ok to write
          cs_shield_write_mstr_req_val = 1'b1;
        end
        else begin //o/w wait for stream to finish writing
          if(!stream_write_busy) begin
            shield_stream_write_sel = 1'b0;
            shield_stream_write_sel_we = 1'b1;
            cs_shield_write_mstr_req_val = 1'b1;
          end
        end

        //invalidate and clean cache line
        valid_dirty_write_index_mux_sel = 1'b0;
        valid_write_data = 1'b0;
        valid_write_en = 1'b1;
        dirty_write_data = 1'b0;
        dirty_write_en = 1'b1;
      end
      //STATE_STREAM_RD_REQ: begin
      //  //Signal the stream read to start
      //  cs_stream_read_req_val = 1'b1;
      //end
      //STATE_STREAM_RD_NEXT: begin
      //  cs_req_type = 1'b0; //read request
      //  cs_req_en = 1'b1;  //Enable registers to store next addr
      //end
      //STATE_STREAM_RD_FINALIZE: begin
      //end
    endcase
  end



  //Assign outputs to wires
  assign req_type                         = cs_req_type                       ;
  assign req_en                           = cs_req_en                         ;
  assign cl_read_req_rdy                  = cs_read_req_rdy                   ;
  assign req_rw_mux_sel                   = cs_rw_mux_sel                     ;
  assign req_cycle_mux_sel                = cs_req_cycle_mux_sel              ;
  assign array_read_index_mux_sel         = cs_array_read_index_mux_sel       ;
  assign tag_array_wr_en                  = cs_tag_array_wr_en                ;
  assign data_array_wr_en                 = cs_data_array_wr_en               ;
  assign shield_read_slv_input_val        = cs_shield_read_slv_input_val      ;
  assign shield_read_mstr_req_val         = cs_shield_read_mstr_req_val       ;
  assign shield_read_mstr_resp_rdy        = cs_shield_read_mstr_resp_rdy      ;
  assign cl_write_req_rdy                 = cs_write_req_rdy                  ;
  assign shield_write_slv_req_val         = cs_shield_write_slv_req_val       ;
  assign shield_write_slv_cache_line_rdy  = cs_shield_write_slv_cache_line_rdy;
  assign data_array_data_mux_sel          = cs_data_array_data_mux_sel        ;
  assign cl_write_resp_val                = cs_write_resp_val                 ;
  assign shield_write_mstr_req_val        = cs_shield_write_mstr_req_val      ;
  assign stream_read_req_val              = cs_stream_read_req_val            ;
  assign stream_write_req_val             = cs_stream_write_req_val           ;

  //Assign debug
  assign shield_state = state_r;

endmodule : shield_controller

`default_nettype wire
