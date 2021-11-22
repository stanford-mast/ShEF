//Mark Zhao
//6/24/2020

`ifndef FREE_INTERFACES_PKG
`define FREE_INTERFACES_PKG

  interface axi_bus_t;
    logic[15:0] awid;
    logic[63:0] awaddr;
    logic[7:0] awlen;
    logic [2:0] awsize;
    logic awvalid;
    logic awready;

    logic[15:0] wid;
    logic[511:0] wdata;
    logic[63:0] wstrb;
    logic wlast;
    logic wvalid;
    logic wready;

    logic[15:0] bid;
    logic[1:0] bresp;
    logic bvalid;
    logic bready;

    logic[15:0] arid;
    logic[63:0] araddr;
    logic[7:0] arlen;
    logic [2:0] arsize;
    logic arvalid;
    logic arready;

    logic[15:0] rid;
    logic[511:0] rdata;
    logic[1:0] rresp;
    logic rlast;
    logic rvalid;
    logic rready;

    modport master (input awid, awaddr, awlen, awsize, awvalid, output awready,
      input wid, wdata, wstrb, wlast, wvalid, output wready,
      output bid, bresp, bvalid, input bready,
      input arid, araddr, arlen, arsize, arvalid, output arready,
      output rid, rdata, rresp, rlast, rvalid, input rready);

    modport slave (output awid, awaddr, awlen, awsize, awvalid, input awready,
      output wid, wdata, wstrb, wlast, wvalid, input wready,
      input bid, bresp, bvalid, output bready,
      output arid, araddr, arlen, arsize, arvalid, input arready,
      input rid, rdata, rresp, rlast, rvalid, output rready);
  endinterface

`endif //FREE_INTERFACES_PKG
