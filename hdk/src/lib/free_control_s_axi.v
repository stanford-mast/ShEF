// /*******************************************************************************
// Copyright (c) 2018, Xilinx, Inc.
// All rights reserved.
// Modified by Mark Zhao
// 4/25/2019
// 
// Redistribution and use in source and binary forms, with or without modification,
// are permitted provided that the following conditions are met:
// 
// 1. Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
// 
// 
// 2. Redistributions in binary form must reproduce the above copyright notice,
// this list of conditions and the following disclaimer in the documentation
// and/or other materials provided with the distribution.
// 
// 
// 3. Neither the name of the copyright holder nor the names of its contributors
// may be used to endorse or promote products derived from this software
// without specific prior written permission.
// 
// 
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
// ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,THE IMPLIED 
// WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
// INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
// BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY 
// OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
// NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
// *******************************************************************************/

`timescale 1ns/1ps
module free_control_s_axi
#(parameter
    C_S_AXI_ADDR_WIDTH = 32,
    C_S_AXI_DATA_WIDTH = 32
)(
    // axi4 lite slave signals
    input  wire                          ACLK,
    input  wire                          ARESET,
    input  wire                          ACLK_EN,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] AWADDR,
    input  wire                          AWVALID,
    output wire                          AWREADY,
    input  wire [C_S_AXI_DATA_WIDTH-1:0] WDATA,
    input  wire [C_S_AXI_DATA_WIDTH/8-1:0] WSTRB,
    input  wire                          WVALID,
    output wire                          WREADY,
    output wire [1:0]                    BRESP,
    output wire                          BVALID,
    input  wire                          BREADY,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] ARADDR,
    input  wire                          ARVALID,
    output wire                          ARREADY,
    output wire [C_S_AXI_DATA_WIDTH-1:0] RDATA,
    output wire [1:0]                    RRESP,
    output wire                          RVALID,
    input  wire                          RREADY,
    // user signals
    output wire [31:0]                   control_reg0 ,
    output wire [31:0]                   control_reg1 ,
    output wire [31:0]                   control_reg2 ,
    output wire [31:0]                   control_reg3 ,
    output wire [31:0]                   control_reg4 ,
    output wire [31:0]                   control_reg5 ,
    output wire [31:0]                   control_reg6 ,
    output wire [31:0]                   control_reg7 ,
    output wire [31:0]                   control_reg8 ,
    output wire [31:0]                   control_reg9 ,
    output wire [31:0]                   control_reg10,
    output wire [31:0]                   control_reg11,
    output wire [31:0]                   control_reg12,
    output wire [31:0]                   control_reg13,
    output wire [31:0]                   control_reg14,
    output wire [31:0]                   control_reg15,
    input  wire [31:0]                   status_reg0  ,
    input  wire [31:0]                   status_reg1  ,
    input  wire [31:0]                   status_reg2  ,
    input  wire [31:0]                   status_reg3  ,
    input  wire [31:0]                   status_reg4  ,
    input  wire [31:0]                   status_reg5  ,
    input  wire [31:0]                   status_reg6  ,
    input  wire [31:0]                   status_reg7  ,
    input  wire [31:0]                   status_reg8  ,
    input  wire [31:0]                   status_reg9  ,
    input  wire [31:0]                   status_reg10 ,
    input  wire [31:0]                   status_reg11 ,
    input  wire [31:0]                   status_reg12 ,
    input  wire [31:0]                   status_reg13 ,
    input  wire [31:0]                   status_reg14 ,
    input  wire [31:0]                   status_reg15 
);

  //------------------------Parameters----------------------
  `include "free_control_addrs.vh"
  localparam
    WRIDLE               		= 2'd0,
    WRDATA               		= 2'd1,
    WRRESP               		= 2'd2,
    RDIDLE               		= 2'd0,
    RDDATA               		= 2'd1;
  
  //------------------------Local signal-------------------
  reg  [1:0]                     wstate = WRIDLE;
  reg  [1:0]                     wnext;
  reg  [C_S_AXI_ADDR_WIDTH-1:0]  waddr;
  wire [31:0]                    wmask;
  wire                           aw_hs;
  wire                           w_hs;
  reg  [1:0]                     rstate = RDIDLE;
  reg  [1:0]                     rnext;
  reg  [31:0]                    rdata;
  wire                           ar_hs;
  wire [C_S_AXI_ADDR_WIDTH-1:0]  raddr;
  // internal registers
  reg  [31:0]                   int_control_r0;
  reg  [31:0]                   int_control_r1;
  reg  [31:0]                   int_control_r2;
  reg  [31:0]                   int_control_r3;
  reg  [31:0]                   int_control_r4;
  reg  [31:0]                   int_control_r5;
  reg  [31:0]                   int_control_r6;
  reg  [31:0]                   int_control_r7;
  reg  [31:0]                   int_control_r8;
  reg  [31:0]                   int_control_r9;
  reg  [31:0]                   int_control_r10;
  reg  [31:0]                   int_control_r11;
  reg  [31:0]                   int_control_r12;
  reg  [31:0]                   int_control_r13;
  reg  [31:0]                   int_control_r14;
  reg  [31:0]                   int_control_r15;
  wire [31:0]                   int_status_0;
  wire [31:0]                   int_status_1;
  wire [31:0]                   int_status_2;
  wire [31:0]                   int_status_3;
  wire [31:0]                   int_status_4;
  wire [31:0]                   int_status_5;
  wire [31:0]                   int_status_6;
  wire [31:0]                   int_status_7;
  wire [31:0]                   int_status_8;
  wire [31:0]                   int_status_9;
  wire [31:0]                   int_status_10;
  wire [31:0]                   int_status_11;
  wire [31:0]                   int_status_12;
  wire [31:0]                   int_status_13;
  wire [31:0]                   int_status_14;
  wire [31:0]                   int_status_15;
  
  //------------------------Instantiation------------------
  
  //------------------------AXI write fsm------------------
  assign AWREADY = (~ARESET) & (wstate == WRIDLE);
  assign WREADY  = (wstate == WRDATA);
  assign BRESP   = 2'b00;  // OKAY
  assign BVALID  = (wstate == WRRESP);
  assign wmask   = { {8{WSTRB[3]}}, {8{WSTRB[2]}}, {8{WSTRB[1]}}, {8{WSTRB[0]}} };
  assign aw_hs   = AWVALID & AWREADY;
  assign w_hs    = WVALID & WREADY;
  
  // wstate
  always @(posedge ACLK) begin
      if (ARESET)
          wstate <= WRIDLE;
      else if (ACLK_EN)
          wstate <= wnext;
  end
  
  // wnext
  always @(*) begin
      case (wstate)
          WRIDLE:
              if (AWVALID)
                  wnext = WRDATA;
              else
                  wnext = WRIDLE;
          WRDATA:
              if (WVALID)
                  wnext = WRRESP;
              else
                  wnext = WRDATA;
          WRRESP:
              if (BREADY)
                  wnext = WRIDLE;
              else
                  wnext = WRRESP;
          default:
              wnext = WRIDLE;
      endcase
  end
  
  // waddr
  always @(posedge ACLK) begin
      if (ACLK_EN) begin
          if (aw_hs)
              waddr <= AWADDR[C_S_AXI_ADDR_WIDTH-1:0];
      end
  end
  
  //------------------------AXI read fsm-------------------
  assign ARREADY = (~ARESET) && (rstate == RDIDLE);
  assign RDATA   = rdata;
  assign RRESP   = 2'b00;  // OKAY
  assign RVALID  = (rstate == RDDATA);
  assign ar_hs   = ARVALID & ARREADY;
  assign raddr   = ARADDR[C_S_AXI_ADDR_WIDTH-1:0];
  
  // rstate
  always @(posedge ACLK) begin
      if (ARESET)
          rstate <= RDIDLE;
      else if (ACLK_EN)
          rstate <= rnext;
  end
  
  // rnext
  always @(*) begin
      case (rstate)
          RDIDLE:
              if (ARVALID)
                  rnext = RDDATA;
              else
                  rnext = RDIDLE;
          RDDATA:
              if (RREADY & RVALID)
                  rnext = RDIDLE;
              else
                  rnext = RDDATA;
          default:
              rnext = RDIDLE;
      endcase
  end
  
  // rdata
  always @(posedge ACLK) begin
      if (ACLK_EN) begin
          if (ar_hs) begin
              rdata <= 1'b0;
              case (raddr)
                `FREE_CONTROL_REG0_ADDR: begin
                  rdata <= int_control_r0;
                end
                `FREE_CONTROL_REG1_ADDR: begin
                  rdata <= int_control_r1;
                end
                `FREE_CONTROL_REG2_ADDR: begin
                  rdata <= int_control_r2;
                end
                `FREE_CONTROL_REG3_ADDR: begin
                  rdata <= int_control_r3;
                end
                `FREE_CONTROL_REG4_ADDR: begin
                  rdata <= int_control_r4;
                end
                `FREE_CONTROL_REG5_ADDR: begin
                  rdata <= int_control_r5;
                end
                `FREE_CONTROL_REG6_ADDR: begin
                  rdata <= int_control_r6;
                end
                `FREE_CONTROL_REG7_ADDR: begin
                  rdata <= int_control_r7;
                end
                `FREE_CONTROL_REG8_ADDR: begin
                  rdata <= int_control_r8;
                end
                `FREE_CONTROL_REG9_ADDR: begin
                  rdata <= int_control_r9;
                end
                `FREE_CONTROL_REG10_ADDR: begin
                  rdata <= int_control_r10;
                end
                `FREE_CONTROL_REG11_ADDR: begin
                  rdata <= int_control_r11;
                end
                `FREE_CONTROL_REG12_ADDR: begin
                  rdata <= int_control_r12;
                end
                `FREE_CONTROL_REG13_ADDR: begin
                  rdata <= int_control_r13;
                end
                `FREE_CONTROL_REG14_ADDR: begin
                  rdata <= int_control_r14;
                end
                `FREE_CONTROL_REG15_ADDR: begin
                  rdata <= int_control_r15;
                end
                `FREE_STATUS_REG0_ADDR: begin
                  rdata <= int_status_0;
                end
                `FREE_STATUS_REG1_ADDR: begin
                  rdata <= int_status_1;
                end
                `FREE_STATUS_REG2_ADDR: begin
                  rdata <= int_status_2;
                end
                `FREE_STATUS_REG3_ADDR: begin
                  rdata <= int_status_3;
                end
                `FREE_STATUS_REG4_ADDR: begin
                  rdata <= int_status_4;
                end
                `FREE_STATUS_REG5_ADDR: begin
                  rdata <= int_status_5;
                end
                `FREE_STATUS_REG6_ADDR: begin
                  rdata <= int_status_6;
                end
                `FREE_STATUS_REG7_ADDR: begin
                  rdata <= int_status_7;
                end
                `FREE_STATUS_REG8_ADDR: begin
                  rdata <= int_status_8;
                end
                `FREE_STATUS_REG9_ADDR: begin
                  rdata <= int_status_9;
                end
                `FREE_STATUS_REG10_ADDR: begin
                  rdata <= int_status_10;
                end
                `FREE_STATUS_REG11_ADDR: begin
                  rdata <= int_status_11;
                end
                `FREE_STATUS_REG12_ADDR: begin
                  rdata <= int_status_12;
                end
                `FREE_STATUS_REG13_ADDR: begin
                  rdata <= int_status_13;
                end
                `FREE_STATUS_REG14_ADDR: begin
                  rdata <= int_status_14;
                end
                `FREE_STATUS_REG15_ADDR: begin
                  rdata <= int_status_15;
                end
                default: begin
                  rdata <= 32'hdeadbeef;
                end
              endcase
          end
      end
  end


  //------------------------Register logic-----------------
  //Connect inputs to internal wires
  assign int_status_0    = status_reg0;
  assign int_status_1    = status_reg1;
  assign int_status_2    = status_reg2;
  assign int_status_3    = status_reg3;
  assign int_status_4    = status_reg4;
  assign int_status_5    = status_reg5;
  assign int_status_6    = status_reg6;
  assign int_status_7    = status_reg7;
  assign int_status_8    = status_reg8;
  assign int_status_9    = status_reg9;
  assign int_status_10   = status_reg10;
  assign int_status_11   = status_reg11;
  assign int_status_12   = status_reg12;
  assign int_status_13   = status_reg13;
  assign int_status_14   = status_reg14;
  assign int_status_15   = status_reg15;
  
  //Connect internal regs to outputs
  assign control_reg0  = int_control_r0 ;
  assign control_reg1  = int_control_r1 ;
  assign control_reg2  = int_control_r2 ;
  assign control_reg3  = int_control_r3 ;
  assign control_reg4  = int_control_r4 ;
  assign control_reg5  = int_control_r5 ;
  assign control_reg6  = int_control_r6 ;
  assign control_reg7  = int_control_r7 ;
  assign control_reg8  = int_control_r8 ;
  assign control_reg9  = int_control_r9 ;
  assign control_reg10 = int_control_r10;
  assign control_reg11 = int_control_r11;
  assign control_reg12 = int_control_r12;
  assign control_reg13 = int_control_r13;
  assign control_reg14 = int_control_r14;
  assign control_reg15 = int_control_r15;

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r0  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG0_ADDR)
        int_control_r0 <= (WDATA[31:0] & wmask) | (int_control_r0 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r1  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG1_ADDR)
        int_control_r1 <= (WDATA[31:0] & wmask) | (int_control_r1 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r2  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG2_ADDR)
        int_control_r2 <= (WDATA[31:0] & wmask) | (int_control_r2 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r3  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG3_ADDR)
        int_control_r3 <= (WDATA[31:0] & wmask) | (int_control_r3 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r4  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG4_ADDR)
        int_control_r4 <= (WDATA[31:0] & wmask) | (int_control_r4 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r5  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG5_ADDR)
        int_control_r5 <= (WDATA[31:0] & wmask) | (int_control_r5 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r6  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG6_ADDR)
        int_control_r6 <= (WDATA[31:0] & wmask) | (int_control_r6 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r7  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG7_ADDR)
        int_control_r7 <= (WDATA[31:0] & wmask) | (int_control_r7 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r8  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG8_ADDR)
        int_control_r8 <= (WDATA[31:0] & wmask) | (int_control_r8 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r9  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG9_ADDR)
        int_control_r9 <= (WDATA[31:0] & wmask) | (int_control_r9 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r10 <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG10_ADDR)
        int_control_r10 <= (WDATA[31:0] & wmask) | (int_control_r10 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r11  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG11_ADDR)
        int_control_r11 <= (WDATA[31:0] & wmask) | (int_control_r11 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r12  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG12_ADDR)
        int_control_r12 <= (WDATA[31:0] & wmask) | (int_control_r12 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r13  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG13_ADDR)
        int_control_r13 <= (WDATA[31:0] & wmask) | (int_control_r13 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r14  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG14_ADDR)
        int_control_r14 <= (WDATA[31:0] & wmask) | (int_control_r14 & ~wmask);
    end
  end

  always @(posedge ACLK) begin
    if (ARESET)
      int_control_r15  <= 32'd0;
    else if (ACLK_EN) begin
      if (w_hs && waddr == `FREE_CONTROL_REG15_ADDR)
        int_control_r15 <= (WDATA[31:0] & wmask) | (int_control_r15 & ~wmask);
    end
  end
//assign ap_start     = int_ap_start;
//assign int_ap_idle  = ap_idle;
//assign int_ap_ready = ap_ready;
//assign input_r			= int_input_r;
//assign input_len_r  = int_input_len_r;
//assign chunk_len_r  = int_chunk_len_r;
//assign p_xcl_gv_p0  = int_p_xcl_gv_p0;
// int_ap_start
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_ap_start <= 1'b0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_AP_CTRL && WSTRB[0] && WDATA[0])
//            int_ap_start <= 1'b1;
//        else if (int_ap_ready)
//            int_ap_start <= int_auto_restart; // clear on handshake/auto restart
//    end
//end
//
//// int_ap_done
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_ap_done <= 1'b0;
//    else if (ACLK_EN) begin
//        if (ap_done)
//            int_ap_done <= 1'b1;
//        else if (ar_hs && raddr == ADDR_AP_CTRL)
//            int_ap_done <= 1'b0; // clear on read
//    end
//end
//
//// int_auto_restart
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_auto_restart <= 1'b0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_AP_CTRL && WSTRB[0])
//            int_auto_restart <=  WDATA[7];
//    end
//end
//
//// int_gie
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_gie <= 1'b0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_GIE && WSTRB[0])
//            int_gie <= WDATA[0];
//    end
//end
//
//// int_ier
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_ier <= 1'b0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_IER && WSTRB[0])
//            int_ier <= WDATA[1:0];
//    end
//end
//
//// int_isr[0]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_isr[0] <= 1'b0;
//    else if (ACLK_EN) begin
//        if (int_ier[0] & ap_done)
//            int_isr[0] <= 1'b1;
//        else if (w_hs && waddr == ADDR_ISR && WSTRB[0])
//            int_isr[0] <= int_isr[0] ^ WDATA[0]; // toggle on write
//    end
//end
//
//// int_isr[1]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_isr[1] <= 1'b0;
//    else if (ACLK_EN) begin
//        if (int_ier[1] & ap_ready)
//            int_isr[1] <= 1'b1;
//        else if (w_hs && waddr == ADDR_ISR && WSTRB[0])
//            int_isr[1] <= int_isr[1] ^ WDATA[1]; // toggle on write
//    end
//end
//
//// int_input_r[31:0]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_input_r[31:0] <= 0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_INPUT_R_DATA_0)
//            int_input_r[31:0] <= (WDATA[31:0] & wmask) | (int_input_r[31:0] & ~wmask);
//    end
//end
//
//// int_input_r[63:32]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_input_r[63:32] <= 0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_INPUT_R_DATA_1)
//            int_input_r[63:32] <= (WDATA[31:0] & wmask) | (int_input_r[63:32] & ~wmask);
//    end
//end
//
//// int_input_len_r[31:0]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_input_len_r[31:0] <= 0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_INPUT_LEN_R_DATA_0)
//            int_input_len_r[31:0] <= (WDATA[31:0] & wmask) | (int_input_len_r[31:0] & ~wmask);
//    end
//end
//
//// int_chunk_len_r[31:0]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_chunk_len_r[31:0] <= 0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_CHUNK_LEN_R_DATA_0)
//            int_chunk_len_r[31:0] <= (WDATA[31:0] & wmask) | (int_chunk_len_r[31:0] & ~wmask);
//    end
//end
//
//// int_p_xcl_gv_p0[31:0]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_p_xcl_gv_p0[31:0] <= 0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_P_XCL_GV_P0_DATA_0)
//            int_p_xcl_gv_p0[31:0] <= (WDATA[31:0] & wmask) | (int_p_xcl_gv_p0[31:0] & ~wmask);
//    end
//end
//
//// int_p_xcl_gv_p0[63:32]
//always @(posedge ACLK) begin
//    if (ARESET)
//        int_p_xcl_gv_p0[63:32] <= 0;
//    else if (ACLK_EN) begin
//        if (w_hs && waddr == ADDR_P_XCL_GV_P0_DATA_1)
//            int_p_xcl_gv_p0[63:32] <= (WDATA[31:0] & wmask) | (int_p_xcl_gv_p0[63:32] & ~wmask);
//    end
//end

//------------------------Memory logic-------------------

endmodule
