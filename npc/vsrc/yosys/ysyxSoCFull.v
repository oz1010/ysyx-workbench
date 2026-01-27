`include "riscv32e_defines.v"

module ysyxSoCFull (
    input  wire         clk,
    input  wire         rst,
    input  wire         io_interrupt,
    input  wire         io_master_awready,
    output wire         io_master_awvalid,
    output wire [31:0]  io_master_awaddr,
    output wire [3:0]   io_master_awid,
    output wire [7:0]   io_master_awlen,
    output wire [2:0]   io_master_awsize,
    output wire [1:0]   io_master_awburst,
    input  wire         io_master_wready,
    output wire         io_master_wvalid,
    output wire [31:0]  io_master_wdata,
    output wire [3:0]   io_master_wstrb,
    output wire         io_master_wlast,
    output wire         io_master_bready,
    input  wire         io_master_bvalid,
    input  wire [1:0]   io_master_bresp,
    input  wire [3:0]   io_master_bid,
    input  wire         io_master_arready,
    output wire         io_master_arvalid,
    output wire [31:0]  io_master_araddr,
    output wire [3:0]   io_master_arid,
    output wire [7:0]   io_master_arlen,
    output wire [2:0]   io_master_arsize,
    output wire [1:0]   io_master_arburst,
    output wire         io_master_rready,
    input  wire         io_master_rvalid,
    input  wire [1:0]   io_master_rresp,
    input  wire [31:0]  io_master_rdata,
    input  wire         io_master_rlast,
    input  wire [3:0]   io_master_rid,
    output wire         io_slave_awready,
    input  wire         io_slave_awvalid,
    input  wire [31:0]  io_slave_awaddr,
    input  wire [3:0]   io_slave_awid,
    input  wire [7:0]   io_slave_awlen,
    input  wire [2:0]   io_slave_awsize,
    input  wire [1:0]   io_slave_awburst,
    output wire         io_slave_wready,
    input  wire         io_slave_wvalid,
    input  wire [31:0]  io_slave_wdata,
    input  wire [3:0]   io_slave_wstrb,
    input  wire         io_slave_wlast,
    input  wire         io_slave_bready,
    output wire         io_slave_bvalid,
    output wire [1:0]   io_slave_bresp,
    output wire [3:0]   io_slave_bid,
    output wire         io_slave_arready,
    input  wire         io_slave_arvalid,
    input  wire [31:0]  io_slave_araddr,
    input  wire [3:0]   io_slave_arid,
    input  wire [7:0]   io_slave_arlen,
    input  wire [2:0]   io_slave_arsize,
    input  wire [1:0]   io_slave_arburst,
    input  wire         io_slave_rready,
    output wire         io_slave_rvalid,
    output wire [1:0]   io_slave_rresp,
    output wire [31:0]  io_slave_rdata,
    output wire         io_slave_rlast,
    output wire [3:0]   io_slave_rid
);

`ifdef IN_YOSYS_STA
reg [31:0] global_csrs[0:7];
reg [3:0] gloabl_csr_write_addr;
reg [31:0] gloabl_csr_write_value;
reg [31:0] global_ret_pc;
reg [31:0] global_pc;

always @(posedge clk or posedge rst) begin
    if (rst) begin
    end else begin
        global_csrs[gloabl_csr_write_addr] <= gloabl_csr_write_value;
    end
end

wire         w_interrupt;
wire         w_master_awready;
wire         w_master_awvalid;
wire [31:0]  w_master_awaddr;
wire [3:0]   w_master_awid;
wire [7:0]   w_master_awlen;
wire [2:0]   w_master_awsize;
wire [1:0]   w_master_awburst;
wire         w_master_wready;
wire         w_master_wvalid;
wire [31:0]  w_master_wdata;
wire [3:0]   w_master_wstrb;
wire         w_master_wlast;
wire         w_master_bready;
wire         w_master_bvalid;
wire [1:0]   w_master_bresp;
wire [3:0]   w_master_bid;
wire         w_master_arready;
wire         w_master_arvalid;
wire [31:0]  w_master_araddr;
wire [3:0]   w_master_arid;
wire [7:0]   w_master_arlen;
wire [2:0]   w_master_arsize;
wire [1:0]   w_master_arburst;
wire         w_master_rready;
wire         w_master_rvalid;
wire [1:0]   w_master_rresp;
wire [31:0]  w_master_rdata;
wire         w_master_rlast;
wire [3:0]   w_master_rid;
wire         w_slave_awready;
wire         w_slave_awvalid;
wire [31:0]  w_slave_awaddr;
wire [3:0]   w_slave_awid;
wire [7:0]   w_slave_awlen;
wire [2:0]   w_slave_awsize;
wire [1:0]   w_slave_awburst;
wire         w_slave_wready;
wire         w_slave_wvalid;
wire [31:0]  w_slave_wdata;
wire [3:0]   w_slave_wstrb;
wire         w_slave_wlast;
wire         w_slave_bready;
wire         w_slave_bvalid;
wire [1:0]   w_slave_bresp;
wire [3:0]   w_slave_bid;
wire         w_slave_arready;
wire         w_slave_arvalid;
wire [31:0]  w_slave_araddr;
wire [3:0]   w_slave_arid;
wire [7:0]   w_slave_arlen;
wire [2:0]   w_slave_arsize;
wire [1:0]   w_slave_arburst;
wire         w_slave_rready;
wire         w_slave_rvalid;
wire [1:0]   w_slave_rresp;
wire [31:0]  w_slave_rdata;
wire         w_slave_rlast;
wire [3:0]   w_slave_rid;

reg         r_interrupt;
reg         r_master_awready;
reg         r_master_awvalid;
reg [31:0]  r_master_awaddr;
reg [3:0]   r_master_awid;
reg [7:0]   r_master_awlen;
reg [2:0]   r_master_awsize;
reg [1:0]   r_master_awburst;
reg         r_master_wready;
reg         r_master_wvalid;
reg [31:0]  r_master_wdata;
reg [3:0]   r_master_wstrb;
reg         r_master_wlast;
reg         r_master_bready;
reg         r_master_bvalid;
reg [1:0]   r_master_bresp;
reg [3:0]   r_master_bid;
reg         r_master_arready;
reg         r_master_arvalid;
reg [31:0]  r_master_araddr;
reg [3:0]   r_master_arid;
reg [7:0]   r_master_arlen;
reg [2:0]   r_master_arsize;
reg [1:0]   r_master_arburst;
reg         r_master_rready;
reg         r_master_rvalid;
reg [1:0]   r_master_rresp;
reg [31:0]  r_master_rdata;
reg         r_master_rlast;
reg [3:0]   r_master_rid;
reg         r_slave_awready;
reg         r_slave_awvalid;
reg [31:0]  r_slave_awaddr;
reg [3:0]   r_slave_awid;
reg [7:0]   r_slave_awlen;
reg [2:0]   r_slave_awsize;
reg [1:0]   r_slave_awburst;
reg         r_slave_wready;
reg         r_slave_wvalid;
reg [31:0]  r_slave_wdata;
reg [3:0]   r_slave_wstrb;
reg         r_slave_wlast;
reg         r_slave_bready;
reg         r_slave_bvalid;
reg [1:0]   r_slave_bresp;
reg [3:0]   r_slave_bid;
reg         r_slave_arready;
reg         r_slave_arvalid;
reg [31:0]  r_slave_araddr;
reg [3:0]   r_slave_arid;
reg [7:0]   r_slave_arlen;
reg [2:0]   r_slave_arsize;
reg [1:0]   r_slave_arburst;
reg         r_slave_rready;
reg         r_slave_rvalid;
reg [1:0]   r_slave_rresp;
reg [31:0]  r_slave_rdata;
reg         r_slave_rlast;
reg [3:0]   r_slave_rid;

always @(posedge clk) begin
    /* input */
    r_interrupt <= io_interrupt;
    r_master_awready <= io_master_awready;
    r_master_wready <= io_master_wready;
    r_master_bvalid <= io_master_bvalid;
    r_master_bresp <= io_master_bresp;
    r_master_bid <= io_master_bid;
    r_master_arready <= io_master_arready;
    r_master_rvalid <= io_master_rvalid;
    r_master_rresp <= io_master_rresp;
    r_master_rdata <= io_master_rdata;
    r_master_rlast <= io_master_rlast;
    r_master_rid <= io_master_rid;
    r_slave_awvalid <= io_slave_awvalid;
    r_slave_awaddr <= io_slave_awaddr;
    r_slave_awid <= io_slave_awid;
    r_slave_awlen <= io_slave_awlen;
    r_slave_awsize <= io_slave_awsize;
    r_slave_awburst <= io_slave_awburst;
    r_slave_wvalid <= io_slave_wvalid;
    r_slave_wdata <= io_slave_wdata;
    r_slave_wstrb <= io_slave_wstrb;
    r_slave_wlast <= io_slave_wlast;
    r_slave_bready <= io_slave_bready;
    r_slave_arvalid <= io_slave_arvalid;
    r_slave_araddr <= io_slave_araddr;
    r_slave_arid <= io_slave_arid;
    r_slave_arlen <= io_slave_arlen;
    r_slave_arsize <= io_slave_arsize;
    r_slave_arburst <= io_slave_arburst;
    r_slave_rready <= io_slave_rready;

    /* output */
    r_master_awvalid <= w_master_awvalid;
    r_master_awaddr <= w_master_awaddr;
    r_master_awid <= w_master_awid;
    r_master_awlen <= w_master_awlen;
    r_master_awsize <= w_master_awsize;
    r_master_awburst <= w_master_awburst;
    r_master_wvalid <= w_master_wvalid;
    r_master_wdata <= w_master_wdata;
    r_master_wstrb <= w_master_wstrb;
    r_master_wlast <= w_master_wlast;
    r_master_bready <= w_master_bready;
    r_master_arvalid <= w_master_arvalid;
    r_master_araddr <= w_master_araddr;
    r_master_arid <= w_master_arid;
    r_master_arlen <= w_master_arlen;
    r_master_arsize <= w_master_arsize;
    r_master_arburst <= w_master_arburst;
    r_master_rready <= w_master_rready;
    r_slave_awready <= w_slave_awready;
    r_slave_wready <= w_slave_wready;
    r_slave_bvalid <= w_slave_bvalid;
    r_slave_bresp <= w_slave_bresp;
    r_slave_bid <= w_slave_bid;
    r_slave_arready <= w_slave_arready;
    r_slave_rvalid <= w_slave_rvalid;
    r_slave_rresp <= w_slave_rresp;
    r_slave_rdata <= w_slave_rdata;
    r_slave_rlast <= w_slave_rlast;
    r_slave_rid <= w_slave_rid;
end

assign w_interrupt = r_interrupt;
assign w_master_awready = r_master_awready;
assign w_master_wready = r_master_wready;
assign w_master_bvalid = r_master_bvalid;
assign w_master_bresp = r_master_bresp;
assign w_master_bid = r_master_bid;
assign w_master_arready = r_master_arready;
assign w_master_rvalid = r_master_rvalid;
assign w_master_rresp = r_master_rresp;
assign w_master_rdata = r_master_rdata;
assign w_master_rlast = r_master_rlast;
assign w_master_rid = r_master_rid;
assign w_slave_awvalid = r_slave_awvalid;
assign w_slave_awaddr = r_slave_awaddr;
assign w_slave_awid = r_slave_awid;
assign w_slave_awlen = r_slave_awlen;
assign w_slave_awsize = r_slave_awsize;
assign w_slave_awburst = r_slave_awburst;
assign w_slave_wvalid = r_slave_wvalid;
assign w_slave_wdata = r_slave_wdata;
assign w_slave_wstrb = r_slave_wstrb;
assign w_slave_wlast = r_slave_wlast;
assign w_slave_bready = r_slave_bready;
assign w_slave_arvalid = r_slave_arvalid;
assign w_slave_araddr = r_slave_araddr;
assign w_slave_arid = r_slave_arid;
assign w_slave_arlen = r_slave_arlen;
assign w_slave_arsize = r_slave_arsize;
assign w_slave_arburst = r_slave_arburst;
assign w_slave_rready = r_slave_rready;

assign io_master_awvalid = r_master_awvalid;
assign io_master_awaddr = r_master_awaddr;
assign io_master_awid = r_master_awid;
assign io_master_awlen = r_master_awlen;
assign io_master_awsize = r_master_awsize;
assign io_master_awburst = r_master_awburst;
assign io_master_wvalid = r_master_wvalid;
assign io_master_wdata = r_master_wdata;
assign io_master_wstrb = r_master_wstrb;
assign io_master_wlast = r_master_wlast;
assign io_master_bready = r_master_bready;
assign io_master_arvalid = r_master_arvalid;
assign io_master_araddr = r_master_araddr;
assign io_master_arid = r_master_arid;
assign io_master_arlen = r_master_arlen;
assign io_master_arsize = r_master_arsize;
assign io_master_arburst = r_master_arburst;
assign io_master_rready = r_master_rready;
assign io_slave_awready = r_slave_awready;
assign io_slave_wready = r_slave_wready;
assign io_slave_bvalid = r_slave_bvalid;
assign io_slave_bresp = r_slave_bresp;
assign io_slave_bid = r_slave_bid;
assign io_slave_arready = r_slave_arready;
assign io_slave_rvalid = r_slave_rvalid;
assign io_slave_rresp = r_slave_rresp;
assign io_slave_rdata = r_slave_rdata;
assign io_slave_rlast = r_slave_rlast;
assign io_slave_rid = r_slave_rid;


`endif

ysyx_23060295 m_core0(
    .clock(clk),
    .reset(rst),
    .io_interrupt(w_interrupt),
    .io_master_awready(w_master_awready),
    .io_master_awvalid(w_master_awvalid),
    .io_master_awaddr(w_master_awaddr),
    .io_master_awid(w_master_awid),
    .io_master_awlen(w_master_awlen),
    .io_master_awsize(w_master_awsize),
    .io_master_awburst(w_master_awburst),
    .io_master_wready(w_master_wready),
    .io_master_wvalid(w_master_wvalid),
    .io_master_wdata(w_master_wdata),
    .io_master_wstrb(w_master_wstrb),
    .io_master_wlast(w_master_wlast),
    .io_master_bready(w_master_bready),
    .io_master_bvalid(w_master_bvalid),
    .io_master_bresp(w_master_bresp),
    .io_master_bid(w_master_bid),
    .io_master_arready(w_master_arready),
    .io_master_arvalid(w_master_arvalid),
    .io_master_araddr(w_master_araddr),
    .io_master_arid(w_master_arid),
    .io_master_arlen(w_master_arlen),
    .io_master_arsize(w_master_arsize),
    .io_master_arburst(w_master_arburst),
    .io_master_rready(w_master_rready),
    .io_master_rvalid(w_master_rvalid),
    .io_master_rresp(w_master_rresp),
    .io_master_rdata(w_master_rdata),
    .io_master_rlast(w_master_rlast),
    .io_master_rid(w_master_rid),
    .io_slave_awready(w_slave_awready),
    .io_slave_awvalid(w_slave_awvalid),
    .io_slave_awaddr(w_slave_awaddr),
    .io_slave_awid(w_slave_awid),
    .io_slave_awlen(w_slave_awlen),
    .io_slave_awsize(w_slave_awsize),
    .io_slave_awburst(w_slave_awburst),
    .io_slave_wready(w_slave_wready),
    .io_slave_wvalid(w_slave_wvalid),
    .io_slave_wdata(w_slave_wdata),
    .io_slave_wstrb(w_slave_wstrb),
    .io_slave_wlast(w_slave_wlast),
    .io_slave_bready(w_slave_bready),
    .io_slave_bvalid(w_slave_bvalid),
    .io_slave_bresp(w_slave_bresp),
    .io_slave_bid(w_slave_bid),
    .io_slave_arready(w_slave_arready),
    .io_slave_arvalid(w_slave_arvalid),
    .io_slave_araddr(w_slave_araddr),
    .io_slave_arid(w_slave_arid),
    .io_slave_arlen(w_slave_arlen),
    .io_slave_arsize(w_slave_arsize),
    .io_slave_arburst(w_slave_arburst),
    .io_slave_rready(w_slave_rready),
    .io_slave_rvalid(w_slave_rvalid),
    .io_slave_rresp(w_slave_rresp),
    .io_slave_rdata(w_slave_rdata),
    .io_slave_rlast(w_slave_rlast),
    .io_slave_rid(w_slave_rid)
);

endmodule
