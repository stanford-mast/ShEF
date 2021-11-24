`ifndef CL_BITCOIN_DEFINES
`define CL_BITCOIN_DEFINES

  //Module Name
  `define CL_NAME cl_bitcoin

  //For lib FIFO block, use less async reset
  `define FPGA_LESS_RST

  //Define if virtual JTAG is desired
  `define DISABLE_VJTAG_DEBUG


  //Uncomment below to use DDRs
  //`define USE_DRAM //enables DRAM in general. uncomment specific channels below
  //`define USE_DDR_A
  //`define USE_DDR_B
  //`define USE_DDR_C
  //`define USE_DDR_D


`endif
