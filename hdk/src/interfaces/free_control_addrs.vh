//Defines for control addresses

`ifndef FREE_CONTROL_ADDRS
`define FREE_CONTROL_ADDRS

  //------------------------Address Info-------------------
  // 0x500 : Control signals
  //        bit 0  - ap_start (Read/Write/COH)
  //        bit 1  - ap_done (Read/COR)
  //        bit 2  - ap_idle (Read)
  //        bit 3  - ap_ready (Read)
  //        bit 7  - auto_restart (Read/Write)
  //        others - reserved
  // 0x04 : Global Interrupt Enable Register
  //        bit 0  - Global Interrupt Enable (Read/Write)
  //        others - reserved
  // 0x08 : IP Interrupt Enable Register (Read/Write)
  //        bit 0  - Channel 0 (ap_done)
  //        bit 1  - Channel 1 (ap_ready)
  //        others - reserved
  // 0x0c : IP Interrupt Status Register (Read/TOW)
  //        bit 0  - Channel 0 (ap_done)
  //        bit 1  - Channel 1 (ap_ready)
  //        others - reserved
  // 0x10 : Data signal of input_r
  //        bit 31~0 - a[31:0] (Read/Write)
  // 0x14 : Data signal of input_r
  //        bit 31~0 - a[63:32] (Read/Write)
  // 0x18 : reserved
  // 0x1c : Data signal of input_len_r
  //        bit 31~0 - input_len_r[31:0] (Read/Write)
  // 0x20 : reserved
  // 0x24 : Data signal of chunk_len_r
  //        bit 31~0 - chunk_len_r[31:0] (R/W)
  // 0x28 : Reserved
  // 0x2C : Data signal of p_xcl_gv_p0
  // 				bit 31~0 - p_xcl_gv_p0[31:0] (R/W)
  // 0x30 : Data signal of p_xcl_gv_p0
  // 				bit 31~0 - p_xcl_gv_p0[63:32] (R/W)
  // 0x34 : reserved
  // (SC = Self Clear, COR = Clear on Read, TOW = Toggle on Write, COH = Clear on Handshake)
  `define FREE_CONTROL_REG0_ADDR    32'h0000_0500
  `define FREE_CONTROL_REG1_ADDR    32'h0000_0504
  `define FREE_CONTROL_REG2_ADDR    32'h0000_0508
  `define FREE_CONTROL_REG3_ADDR    32'h0000_050C
  `define FREE_CONTROL_REG4_ADDR    32'h0000_0510
  `define FREE_CONTROL_REG5_ADDR    32'h0000_0514
  `define FREE_CONTROL_REG6_ADDR    32'h0000_0518
  `define FREE_CONTROL_REG7_ADDR    32'h0000_051C
  `define FREE_CONTROL_REG8_ADDR    32'h0000_0520
  `define FREE_CONTROL_REG9_ADDR    32'h0000_0524
  `define FREE_CONTROL_REG10_ADDR   32'h0000_0528
  `define FREE_CONTROL_REG11_ADDR   32'h0000_052C
  `define FREE_CONTROL_REG12_ADDR   32'h0000_0530
  `define FREE_CONTROL_REG13_ADDR   32'h0000_0534
  `define FREE_CONTROL_REG14_ADDR   32'h0000_0538
  `define FREE_CONTROL_REG15_ADDR   32'h0000_053C
  `define FREE_STATUS_REG0_ADDR     32'h0000_0600
  `define FREE_STATUS_REG1_ADDR     32'h0000_0604
  `define FREE_STATUS_REG2_ADDR     32'h0000_0608
  `define FREE_STATUS_REG3_ADDR     32'h0000_060C
  `define FREE_STATUS_REG4_ADDR     32'h0000_0610
  `define FREE_STATUS_REG5_ADDR     32'h0000_0614
  `define FREE_STATUS_REG6_ADDR     32'h0000_0618
  `define FREE_STATUS_REG7_ADDR     32'h0000_061C
  `define FREE_STATUS_REG8_ADDR     32'h0000_0620
  `define FREE_STATUS_REG9_ADDR     32'h0000_0624
  `define FREE_STATUS_REG10_ADDR    32'h0000_0628
  `define FREE_STATUS_REG11_ADDR    32'h0000_062C
  `define FREE_STATUS_REG12_ADDR    32'h0000_0630
  `define FREE_STATUS_REG13_ADDR    32'h0000_0634
  `define FREE_STATUS_REG14_ADDR    32'h0000_0638
  `define FREE_STATUS_REG15_ADDR    32'h0000_063C



`endif
