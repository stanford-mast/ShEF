//Common defines

`ifndef FREE_COMMON_DEFINES
`define FREE_COMMON_DEFINES

  //Unimplemented register value
  `define UNIMPLEMENTED_REG_VALUE 32'hdeaddead

  //Choose aes sbox parallelism comment to use 4x
  `define AES_SBOX_16

  `define NUM_AES_PARALLEL_4
  //`define NUM_AES_PARALLEL_8

  `define AES_KEY_128
  `define AES_KEY 256'h2b7e151628aed2a6abf7158809cf4f3c00000000000000000000000000000000
  
  `define HMAC_KEY 128'h2b7e151628aed2a6abf7158809cf4f3c
  //`define USE_HMAC

  `define AES_IV 64'd0

  `define TAG_BASE_ADDR 64'h80000000; //Assign this to an unused region of memory
  //`define TAG_BASE_ADDR 64'h40000000 //Assign this to an unused region of memory USE FOR non C_TEST sim
  //
  //`define NO_ENCRYPT

  `define NO_TAG_CHECK
  //`define NO_TAG_CHECK_FIRST
  //
  //`define AES_STREAM_IV 96'd0

  `define STREAM_BOUND_ADDR 64'h01000000 //upper bound of streaming range use for lenet and sim
  //`define STREAM_BOUND_ADDR 64'h10000000 //upper bound of streaming range use for alexnet
  // `define STREAM_BOUND_ADDR 64'h70000000 //Use streaming for everything
  
  `define ENABLE_STREAMING

  //PMAC stuff
  `define PMAC_KEY 256'h000102030405060708090a0b0c0d0e0f00000000000000000000000000000000
  `define USE_PMAC
  `define NUM_PMAC_PARALLEL_4

  //CHANGES: for sim - stream bound address and tag base addr
`endif
