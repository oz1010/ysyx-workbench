// 单流水线多周期处理器
module riscv32e_core #(
    parameter INST_WIDTH = 32,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input  wire         clk,
    input  wire         rst,

    /* 外部中断 */
    input  wire         io_interrupt,
    /* AXI4 Master总线 */
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

    output wire [INST_WIDTH-1:0] pc,
    output wire         valid
);

/* 模块通信消息 */
wire if_ready;
wire if_valid;
wire id_ready;
wire id_valid;
wire ex_ready;
wire ex_valid;
wire ls_ready;
wire ls_valid;
wire wb_ready;
wire wb_valid;
wire ex_enable;
wire ls_enable;
wire ex_ls_valid;
wire ex_ls_ready;

/* ifu axi4 信号 */
wire                        if_awready;
wire                        if_awvalid;
wire [ADDR_WIDTH-1:0]       if_awaddr;
wire [3:0]                  if_awid;
wire [7:0]                  if_awlen;
wire [2:0]                  if_awsize;
wire [1:0]                  if_awburst;
wire                        if_wready;
wire                        if_wvalid;
wire [DATA_WIDTH-1:0]       if_wdata;
wire [DATA_WIDTH/8-1:0]     if_wstrb;
wire                        if_wlast;
wire                        if_bready;
wire                        if_bvalid;
wire [BRESP_WIDTH-1:0]      if_bresp;
wire [3:0]                  if_bid;
wire                        if_arready;
wire                        if_arvalid;
wire [ADDR_WIDTH-1:0]       if_araddr;
wire [3:0]                  if_arid;
wire [7:0]                  if_arlen;
wire [2:0]                  if_arsize;
wire [1:0]                  if_arburst;
wire                        if_rready;
wire                        if_rvalid;
wire [RRESP_WIDTH-1:0]      if_rresp;
wire [DATA_WIDTH-1:0]       if_rdata;
wire                        if_rlast;
wire [3:0]                  if_rid;
/* lsu axi4 信号 */
wire                        ls_awready;
wire                        ls_awvalid;
wire [ADDR_WIDTH-1:0]       ls_awaddr;
wire [3:0]                  ls_awid;
wire [7:0]                  ls_awlen;
wire [2:0]                  ls_awsize;
wire [1:0]                  ls_awburst;
wire                        ls_wready;
wire                        ls_wvalid;
wire [DATA_WIDTH-1:0]       ls_wdata;
wire [DATA_WIDTH/8-1:0]     ls_wstrb;
wire                        ls_wlast;
wire                        ls_bready;
wire                        ls_bvalid;
wire [BRESP_WIDTH-1:0]      ls_bresp;
wire [3:0]                  ls_bid;
wire                        ls_arready;
wire                        ls_arvalid;
wire [ADDR_WIDTH-1:0]       ls_araddr;
wire [3:0]                  ls_arid;
wire [7:0]                  ls_arlen;
wire [2:0]                  ls_arsize;
wire [1:0]                  ls_arburst;
wire                        ls_rready;
wire                        ls_rvalid;
wire [RRESP_WIDTH-1:0]      ls_rresp;
wire [DATA_WIDTH-1:0]       ls_rdata;
wire                        ls_rlast;
wire [3:0]                  ls_rid;
/* 仲裁后的 axi4信号 */
wire                        m_awready;
wire                        m_awvalid;
wire [31:0]                 m_awaddr;
wire [3:0]                  m_awid;
wire [7:0]                  m_awlen;
wire [2:0]                  m_awsize;
wire [1:0]                  m_awburst;
wire                        m_wready;
wire                        m_wvalid;
wire [31:0]                 m_wdata;
wire [3:0]                  m_wstrb;
wire                        m_wlast;
wire                        m_bready;
wire                        m_bvalid;
wire [1:0]                  m_bresp;
wire [3:0]                  m_bid;
wire                        m_arready;
wire                        m_arvalid;
wire [31:0]                 m_araddr;
wire [3:0]                  m_arid;
wire [7:0]                  m_arlen;
wire [2:0]                  m_arsize;
wire [1:0]                  m_arburst;
wire                        m_rready;
wire                        m_rvalid;
wire [1:0]                  m_rresp;
wire [31:0]                 m_rdata;
wire                        m_rlast;
wire [3:0]                  m_rid;
/* 指令缓存后的 axi4信号 */
wire                        icache_awready;
wire                        icache_awvalid;
wire [31:0]                 icache_awaddr;
wire [3:0]                  icache_awid;
wire [7:0]                  icache_awlen;
wire [2:0]                  icache_awsize;
wire [1:0]                  icache_awburst;
wire                        icache_wready;
wire                        icache_wvalid;
wire [31:0]                 icache_wdata;
wire [3:0]                  icache_wstrb;
wire                        icache_wlast;
wire                        icache_bready;
wire                        icache_bvalid;
wire [1:0]                  icache_bresp;
wire [3:0]                  icache_bid;
wire                        icache_arready;
wire                        icache_arvalid;
wire [31:0]                 icache_araddr;
wire [3:0]                  icache_arid;
wire [7:0]                  icache_arlen;
wire [2:0]                  icache_arsize;
wire [1:0]                  icache_arburst;
wire                        icache_rready;
wire                        icache_rvalid;
wire [1:0]                  icache_rresp;
wire [31:0]                 icache_rdata;
wire                        icache_rlast;
wire [3:0]                  icache_rid;
/* 数据缓存后的 axi4信号 */
wire                        dcache_awready;
wire                        dcache_awvalid;
wire [31:0]                 dcache_awaddr;
wire [3:0]                  dcache_awid;
wire [7:0]                  dcache_awlen;
wire [2:0]                  dcache_awsize;
wire [1:0]                  dcache_awburst;
wire                        dcache_wready;
wire                        dcache_wvalid;
wire [31:0]                 dcache_wdata;
wire [3:0]                  dcache_wstrb;
wire                        dcache_wlast;
wire                        dcache_bready;
wire                        dcache_bvalid;
wire [1:0]                  dcache_bresp;
wire [3:0]                  dcache_bid;
wire                        dcache_arready;
wire                        dcache_arvalid;
wire [31:0]                 dcache_araddr;
wire [3:0]                  dcache_arid;
wire [7:0]                  dcache_arlen;
wire [2:0]                  dcache_arsize;
wire [1:0]                  dcache_arburst;
wire                        dcache_rready;
wire                        dcache_rvalid;
wire [1:0]                  dcache_rresp;
wire [31:0]                 dcache_rdata;
wire                        dcache_rlast;
wire [3:0]                  dcache_rid;
/**
    0 -- clint
    1 -- exter dev
    last -- io master
*/
localparam AXI4_SLAVE_COUNT = 3;
/* salve axi4信号 */
wire                        s_awready[AXI4_SLAVE_COUNT-1:0];
wire                        s_awvalid[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 s_awaddr[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  s_awid[AXI4_SLAVE_COUNT-1:0];
wire [7:0]                  s_awlen[AXI4_SLAVE_COUNT-1:0];
wire [2:0]                  s_awsize[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  s_awburst[AXI4_SLAVE_COUNT-1:0];
wire                        s_wready[AXI4_SLAVE_COUNT-1:0];
wire                        s_wvalid[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 s_wdata[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  s_wstrb[AXI4_SLAVE_COUNT-1:0];
wire                        s_wlast[AXI4_SLAVE_COUNT-1:0];
wire                        s_bready[AXI4_SLAVE_COUNT-1:0];
wire                        s_bvalid[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  s_bresp[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  s_bid[AXI4_SLAVE_COUNT-1:0];
wire                        s_arready[AXI4_SLAVE_COUNT-1:0];
wire                        s_arvalid[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 s_araddr[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  s_arid[AXI4_SLAVE_COUNT-1:0];
wire [7:0]                  s_arlen[AXI4_SLAVE_COUNT-1:0];
wire [2:0]                  s_arsize[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  s_arburst[AXI4_SLAVE_COUNT-1:0];
wire                        s_rready[AXI4_SLAVE_COUNT-1:0];
wire                        s_rvalid[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  s_rresp[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 s_rdata[AXI4_SLAVE_COUNT-1:0];
wire                        s_rlast[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  s_rid[AXI4_SLAVE_COUNT-1:0];
/* io master */
assign s_awready[AXI4_SLAVE_COUNT-1] = io_master_awready;
assign io_master_awvalid = s_awvalid[AXI4_SLAVE_COUNT-1];
assign io_master_awaddr = s_awaddr[AXI4_SLAVE_COUNT-1];
assign io_master_awid = s_awid[AXI4_SLAVE_COUNT-1];
assign io_master_awlen = s_awlen[AXI4_SLAVE_COUNT-1];
assign io_master_awsize = s_awsize[AXI4_SLAVE_COUNT-1];
assign io_master_awburst = s_awburst[AXI4_SLAVE_COUNT-1];
assign s_wready[AXI4_SLAVE_COUNT-1] = io_master_wready;
assign io_master_wvalid = s_wvalid[AXI4_SLAVE_COUNT-1];
assign io_master_wdata = s_wdata[AXI4_SLAVE_COUNT-1];
assign io_master_wstrb = s_wstrb[AXI4_SLAVE_COUNT-1];
assign io_master_wlast = s_wlast[AXI4_SLAVE_COUNT-1];
assign io_master_bready = s_bready[AXI4_SLAVE_COUNT-1];
assign s_bvalid[AXI4_SLAVE_COUNT-1] = io_master_bvalid;
assign s_bresp[AXI4_SLAVE_COUNT-1] = io_master_bresp;
assign s_bid[AXI4_SLAVE_COUNT-1] = io_master_bid;
assign s_arready[AXI4_SLAVE_COUNT-1] = io_master_arready;
assign io_master_arvalid = s_arvalid[AXI4_SLAVE_COUNT-1];
assign io_master_araddr = s_araddr[AXI4_SLAVE_COUNT-1];
assign io_master_arid = s_arid[AXI4_SLAVE_COUNT-1];
assign io_master_arlen = s_arlen[AXI4_SLAVE_COUNT-1];
assign io_master_arsize = s_arsize[AXI4_SLAVE_COUNT-1];
assign io_master_arburst = s_arburst[AXI4_SLAVE_COUNT-1];
assign io_master_rready = s_rready[AXI4_SLAVE_COUNT-1];
assign s_rvalid[AXI4_SLAVE_COUNT-1] = io_master_rvalid;
assign s_rresp[AXI4_SLAVE_COUNT-1] = io_master_rresp;
assign s_rdata[AXI4_SLAVE_COUNT-1] = io_master_rdata;
assign s_rlast[AXI4_SLAVE_COUNT-1] = io_master_rlast;
assign s_rid[AXI4_SLAVE_COUNT-1] = io_master_rid;

/* 常用处理器信号 */
wire [INST_WIDTH*`RISCV_CSR_COUNT-1:0] x;
wire [INST_WIDTH-1:0] inst;
reg [63:0] execute_time;

assign valid = wb_valid;
// assign w_pc = pc;

always @(posedge clk) begin
    if (rst) begin
        execute_time <= 0;
        func_cpu_stat_ctrl(`HW_CPU_STAT_TICK, 0);
    end else begin
        execute_time <= execute_time + 1;
        func_cpu_stat_ctrl(`HW_CPU_STAT_TICK, 1);
    end
end

/* 性能监控 */
perf_monitor m_perf_monitor (
    .clk(clk),
    .rst(rst),
    .pc(pc),
    .inst(inst),
    .if_valid(if_valid),
    .id_ready(id_ready),
    .id_valid(id_valid),
    .ex_ready(ex_ready),
    .ex_valid(ex_valid),
    .ls_ready(ls_ready),
    .ls_valid(ls_valid),
    .wb_ready(wb_ready),
    .inst_code(inst_code),
    .done()
);

/* 指令缓存 */
icache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
`ifdef CONFIG_ICACHE
    .W(`CONFIG_ICACHE_PARAMETER_W),
    .N(`CONFIG_ICACHE_PARAMETER_N),
    .M(`CONFIG_ICACHE_PARAMETER_M),
`endif
    .INST_WIDTH(INST_WIDTH)
) m_icache (
    .clk(clk),
    .rst(rst||fence_enable_trigger), // 采用方案3，执行fence指令，清空整个icache

    .m_awready(if_awready),
    .m_awvalid(if_awvalid),
    .m_awaddr(if_awaddr),
    .m_awid(if_awid),
    .m_awlen(if_awlen),
    .m_awsize(if_awsize),
    .m_awburst(if_awburst),
    .m_wready(if_wready),
    .m_wvalid(if_wvalid),
    .m_wdata(if_wdata),
    .m_wstrb(if_wstrb),
    .m_wlast(if_wlast),
    .m_bready(if_bready),
    .m_bvalid(if_bvalid),
    .m_bresp(if_bresp),
    .m_bid(if_bid),
    .m_arready(if_arready),
    .m_arvalid(if_arvalid),
    .m_araddr(if_araddr),
    .m_arid(if_arid),
    .m_arlen(if_arlen),
    .m_arsize(if_arsize),
    .m_arburst(if_arburst),
    .m_rready(if_rready),
    .m_rvalid(if_rvalid),
    .m_rresp(if_rresp),
    .m_rdata(if_rdata),
    .m_rlast(if_rlast),
    .m_rid(if_rid),

    .s_awready(icache_awready),
    .s_awvalid(icache_awvalid),
    .s_awaddr(icache_awaddr),
    .s_awid(icache_awid),
    .s_awlen(icache_awlen),
    .s_awsize(icache_awsize),
    .s_awburst(icache_awburst),
    .s_wready(icache_wready),
    .s_wvalid(icache_wvalid),
    .s_wdata(icache_wdata),
    .s_wstrb(icache_wstrb),
    .s_wlast(icache_wlast),
    .s_bready(icache_bready),
    .s_bvalid(icache_bvalid),
    .s_bresp(icache_bresp),
    .s_bid(icache_bid),
    .s_arready(icache_arready),
    .s_arvalid(icache_arvalid),
    .s_araddr(icache_araddr),
    .s_arid(icache_arid),
    .s_arlen(icache_arlen),
    .s_arsize(icache_arsize),
    .s_arburst(icache_arburst),
    .s_rready(icache_rready),
    .s_rvalid(icache_rvalid),
    .s_rresp(icache_rresp),
    .s_rdata(icache_rdata),
    .s_rlast(icache_rlast),
    .s_rid(icache_rid)
);

/* 数据缓存 */
dcache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
`ifdef CONFIG_DCACHE
    .W(`CONFIG_DCACHE_PARAMETER_W),
    .N(`CONFIG_DCACHE_PARAMETER_N),
    .M(`CONFIG_DCACHE_PARAMETER_M),
`endif
    .INST_WIDTH(INST_WIDTH)
) m_dcache (
    .clk(clk),
    .rst(rst),

    .m_awready(ls_awready),
    .m_awvalid(ls_awvalid),
    .m_awaddr(ls_awaddr),
    .m_awid(ls_awid),
    .m_awlen(ls_awlen),
    .m_awsize(ls_awsize),
    .m_awburst(ls_awburst),
    .m_wready(ls_wready),
    .m_wvalid(ls_wvalid),
    .m_wdata(ls_wdata),
    .m_wstrb(ls_wstrb),
    .m_wlast(ls_wlast),
    .m_bready(ls_bready),
    .m_bvalid(ls_bvalid),
    .m_bresp(ls_bresp),
    .m_bid(ls_bid),
    .m_arready(ls_arready),
    .m_arvalid(ls_arvalid),
    .m_araddr(ls_araddr),
    .m_arid(ls_arid),
    .m_arlen(ls_arlen),
    .m_arsize(ls_arsize),
    .m_arburst(ls_arburst),
    .m_rready(ls_rready),
    .m_rvalid(ls_rvalid),
    .m_rresp(ls_rresp),
    .m_rdata(ls_rdata),
    .m_rlast(ls_rlast),
    .m_rid(ls_rid),

    .s_awready(dcache_awready),
    .s_awvalid(dcache_awvalid),
    .s_awaddr(dcache_awaddr),
    .s_awid(dcache_awid),
    .s_awlen(dcache_awlen),
    .s_awsize(dcache_awsize),
    .s_awburst(dcache_awburst),
    .s_wready(dcache_wready),
    .s_wvalid(dcache_wvalid),
    .s_wdata(dcache_wdata),
    .s_wstrb(dcache_wstrb),
    .s_wlast(dcache_wlast),
    .s_bready(dcache_bready),
    .s_bvalid(dcache_bvalid),
    .s_bresp(dcache_bresp),
    .s_bid(dcache_bid),
    .s_arready(dcache_arready),
    .s_arvalid(dcache_arvalid),
    .s_araddr(dcache_araddr),
    .s_arid(dcache_arid),
    .s_arlen(dcache_arlen),
    .s_arsize(dcache_arsize),
    .s_arburst(dcache_arburst),
    .s_rready(dcache_rready),
    .s_rvalid(dcache_rvalid),
    .s_rresp(dcache_rresp),
    .s_rdata(dcache_rdata),
    .s_rlast(dcache_rlast),
    .s_rid(dcache_rid)
);

/* arbiter模块 */
arbiter_axi4 #(
    .USER_M_COUNT(2),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_arbiter_axi4(
    .clk(clk),
    .rst(rst),
    .u_awreadys(   {icache_awready,     dcache_awready   }),
    .u_awvalids(   {icache_awvalid,     dcache_awvalid   }),
    .u_awaddrs(    {icache_awaddr,      dcache_awaddr    }),
    .u_awids(      {icache_awid,        dcache_awid      }),
    .u_awlens(     {icache_awlen,       dcache_awlen     }),
    .u_awsizes(    {icache_awsize,      dcache_awsize    }),
    .u_awbursts(   {icache_awburst,     dcache_awburst   }),
    .u_wreadys(    {icache_wready,      dcache_wready    }),
    .u_wvalids(    {icache_wvalid,      dcache_wvalid    }),
    .u_wdatas(     {icache_wdata,       dcache_wdata     }),
    .u_wstrbs(     {icache_wstrb,       dcache_wstrb     }),
    .u_wlasts(     {icache_wlast,       dcache_wlast     }),
    .u_breadys(    {icache_bready,      dcache_bready    }),
    .u_bvalids(    {icache_bvalid,      dcache_bvalid    }),
    .u_bresps(     {icache_bresp,       dcache_bresp     }),
    .u_bids(       {icache_bid,         dcache_bid       }),
    .u_arreadys(   {icache_arready,     dcache_arready   }),
    .u_arvalids(   {icache_arvalid,     dcache_arvalid   }),
    .u_araddrs(    {icache_araddr,      dcache_araddr    }),
    .u_arids(      {icache_arid,        dcache_arid      }),
    .u_arlens(     {icache_arlen,       dcache_arlen     }),
    .u_arsizes(    {icache_arsize,      dcache_arsize    }),
    .u_arbursts(   {icache_arburst,     dcache_arburst   }),
    .u_rreadys(    {icache_rready,      dcache_rready    }),
    .u_rvalids(    {icache_rvalid,      dcache_rvalid    }),
    .u_rresps(     {icache_rresp,       dcache_rresp     }),
    .u_rdatas(     {icache_rdata,       dcache_rdata     }),
    .u_rlasts(     {icache_rlast,       dcache_rlast     }),
    .u_rids(       {icache_rid,         dcache_rid       }),

    .awready(m_awready),
    .awvalid(m_awvalid),
    .awaddr(m_awaddr),
    .awid(m_awid),
    .awlen(m_awlen),
    .awsize(m_awsize),
    .awburst(m_awburst),
    .wready(m_wready),
    .wvalid(m_wvalid),
    .wdata(m_wdata),
    .wstrb(m_wstrb),
    .wlast(m_wlast),
    .bready(m_bready),
    .bvalid(m_bvalid),
    .bresp(m_bresp),
    .bid(m_bid),
    .arready(m_arready),
    .arvalid(m_arvalid),
    .araddr(m_araddr),
    .arid(m_arid),
    .arlen(m_arlen),
    .arsize(m_arsize),
    .arburst(m_arburst),
    .rready(m_rready),
    .rvalid(m_rvalid),
    .rresp(m_rresp),
    .rdata(m_rdata),
    .rlast(m_rlast),
    .rid(m_rid),

    .grant_idx()
);

/* xbar模块 */
xbar_axi4 #(
    .USER_S_COUNT(AXI4_SLAVE_COUNT),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_xbar_axi4 (
    .clk(clk),
    .rst(rst),
    .awready(m_awready),
    .awvalid(m_awvalid),
    .awaddr(m_awaddr),
    .awid(m_awid),
    .awlen(m_awlen),
    .awsize(m_awsize),
    .awburst(m_awburst),
    .wready(m_wready),
    .wvalid(m_wvalid),
    .wdata(m_wdata),
    .wstrb(m_wstrb),
    .wlast(m_wlast),
    .bready(m_bready),
    .bvalid(m_bvalid),
    .bresp(m_bresp),
    .bid(m_bid),
    .arready(m_arready),
    .arvalid(m_arvalid),
    .araddr(m_araddr),
    .arid(m_arid),
    .arlen(m_arlen),
    .arsize(m_arsize),
    .arburst(m_arburst),
    .rready(m_rready),
    .rvalid(m_rvalid),
    .rresp(m_rresp),
    .rdata(m_rdata),
    .rlast(m_rlast),
    .rid(m_rid),

    .u_awreadys(   {   s_awready[0],       s_awready[1],       s_awready[AXI4_SLAVE_COUNT-1]       } ),
    .u_awvalids(   {   s_awvalid[0],       s_awvalid[1],       s_awvalid[AXI4_SLAVE_COUNT-1]       } ),
    .u_awaddrs(    {   s_awaddr[0],        s_awaddr[1],        s_awaddr[AXI4_SLAVE_COUNT-1]        } ),
    .u_awids(      {   s_awid[0],          s_awid[1],          s_awid[AXI4_SLAVE_COUNT-1]          } ),
    .u_awlens(     {   s_awlen[0],         s_awlen[1],         s_awlen[AXI4_SLAVE_COUNT-1]         } ),
    .u_awsizes(    {   s_awsize[0],        s_awsize[1],        s_awsize[AXI4_SLAVE_COUNT-1]        } ),
    .u_awbursts(   {   s_awburst[0],       s_awburst[1],       s_awburst[AXI4_SLAVE_COUNT-1]       } ),
    .u_wreadys(    {   s_wready[0],        s_wready[1],        s_wready[AXI4_SLAVE_COUNT-1]        } ),
    .u_wvalids(    {   s_wvalid[0],        s_wvalid[1],        s_wvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_wdatas(     {   s_wdata[0],         s_wdata[1],         s_wdata[AXI4_SLAVE_COUNT-1]         } ),
    .u_wstrbs(     {   s_wstrb[0],         s_wstrb[1],         s_wstrb[AXI4_SLAVE_COUNT-1]         } ),
    .u_wlasts(     {   s_wlast[0],         s_wlast[1],         s_wlast[AXI4_SLAVE_COUNT-1]         } ),
    .u_breadys(    {   s_bready[0],        s_bready[1],        s_bready[AXI4_SLAVE_COUNT-1]        } ),
    .u_bvalids(    {   s_bvalid[0],        s_bvalid[1],        s_bvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_bresps(     {   s_bresp[0],         s_bresp[1],         s_bresp[AXI4_SLAVE_COUNT-1]         } ),
    .u_bids(       {   s_bid[0],           s_bid[1],           s_bid[AXI4_SLAVE_COUNT-1]           } ),
    .u_arreadys(   {   s_arready[0],       s_arready[1],       s_arready[AXI4_SLAVE_COUNT-1]       } ),
    .u_arvalids(   {   s_arvalid[0],       s_arvalid[1],       s_arvalid[AXI4_SLAVE_COUNT-1]       } ),
    .u_araddrs(    {   s_araddr[0],        s_araddr[1],        s_araddr[AXI4_SLAVE_COUNT-1]        } ),
    .u_arids(      {   s_arid[0],          s_arid[1],          s_arid[AXI4_SLAVE_COUNT-1]          } ),
    .u_arlens(     {   s_arlen[0],         s_arlen[1],         s_arlen[AXI4_SLAVE_COUNT-1]         } ),
    .u_arsizes(    {   s_arsize[0],        s_arsize[1],        s_arsize[AXI4_SLAVE_COUNT-1]        } ),
    .u_arbursts(   {   s_arburst[0],       s_arburst[1],       s_arburst[AXI4_SLAVE_COUNT-1]       } ),
    .u_rreadys(    {   s_rready[0],        s_rready[1],        s_rready[AXI4_SLAVE_COUNT-1]        } ),
    .u_rvalids(    {   s_rvalid[0],        s_rvalid[1],        s_rvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_rresps(     {   s_rresp[0],         s_rresp[1],         s_rresp[AXI4_SLAVE_COUNT-1]         } ),
    .u_rdatas(     {   s_rdata[0],         s_rdata[1],         s_rdata[AXI4_SLAVE_COUNT-1]         } ),
    .u_rlasts(     {   s_rlast[0],         s_rlast[1],         s_rlast[AXI4_SLAVE_COUNT-1]         } ),
    .u_rids(       {   s_rid[0],           s_rid[1],           s_rid[AXI4_SLAVE_COUNT-1]           } ),
    .u_slave_addrs({
        32'h0200_0000, 32'h0200_ffff, // clint
        32'h2200_0000, 32'h2200_0fff, // exter dev
        32'h0000_0004, 32'hffff_ffff // io master
    }),

    .grant_idx()
);

/* clint 模块 */
clint #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_clint(
    .clk(clk),
    .rst(rst),
    .awready(s_awready[0]),
    .awvalid(s_awvalid[0]),
    .awaddr(s_awaddr[0]),
    .awid(s_awid[0]),
    .awlen(s_awlen[0]),
    .awsize(s_awsize[0]),
    .awburst(s_awburst[0]),
    .wready(s_wready[0]),
    .wvalid(s_wvalid[0]),
    .wdata(s_wdata[0]),
    .wstrb(s_wstrb[0]),
    .wlast(s_wlast[0]),
    .bready(s_bready[0]),
    .bvalid(s_bvalid[0]),
    .bresp(s_bresp[0]),
    .bid(s_bid[0]),
    .arready(s_arready[0]),
    .arvalid(s_arvalid[0]),
    .araddr(s_araddr[0]),
    .arid(s_arid[0]),
    .arlen(s_arlen[0]),
    .arsize(s_arsize[0]),
    .arburst(s_arburst[0]),
    .rready(s_rready[0]),
    .rvalid(s_rvalid[0]),
    .rresp(s_rresp[0]),
    .rdata(s_rdata[0]),
    .rlast(s_rlast[0]),
    .rid(s_rid[0])
);
/* exter dev 模块 */
exter_dev #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_exter_dev(
    .clk(clk),
    .rst(rst),
    .awready(s_awready[1]),
    .awvalid(s_awvalid[1]),
    .awaddr(s_awaddr[1]),
    .awid(s_awid[1]),
    .awlen(s_awlen[1]),
    .awsize(s_awsize[1]),
    .awburst(s_awburst[1]),
    .wready(s_wready[1]),
    .wvalid(s_wvalid[1]),
    .wdata(s_wdata[1]),
    .wstrb(s_wstrb[1]),
    .wlast(s_wlast[1]),
    .bready(s_bready[1]),
    .bvalid(s_bvalid[1]),
    .bresp(s_bresp[1]),
    .bid(s_bid[1]),
    .arready(s_arready[1]),
    .arvalid(s_arvalid[1]),
    .araddr(s_araddr[1]),
    .arid(s_arid[1]),
    .arlen(s_arlen[1]),
    .arsize(s_arsize[1]),
    .arburst(s_arburst[1]),
    .rready(s_rready[1]),
    .rvalid(s_rvalid[1]),
    .rresp(s_rresp[1]),
    .rdata(s_rdata[1]),
    .rlast(s_rlast[1]),
    .rid(s_rid[1])
);

/* 取指if */
inst_fetch #(
    .SRAM_TYPE(`SRAM_TYPE_AXI4),
    .INST_WIDTH(INST_WIDTH)
) ifu(
    .clk(clk),
    .rst(rst),

    .awready(if_awready),
    .awvalid(if_awvalid),
    .awaddr(if_awaddr),
    .awid(if_awid),
    .awlen(if_awlen),
    .awsize(if_awsize),
    .awburst(if_awburst),
    .wready(if_wready),
    .wvalid(if_wvalid),
    .wdata(if_wdata),
    .wstrb(if_wstrb),
    .wlast(if_wlast),
    .bready(if_bready),
    .bvalid(if_bvalid),
    .bresp(if_bresp),
    .bid(if_bid),
    .arready(if_arready),
    .arvalid(if_arvalid),
    .araddr(if_araddr),
    .arid(if_arid),
    .arlen(if_arlen),
    .arsize(if_arsize),
    .arburst(if_arburst),
    .rready(if_rready),
    .rvalid(if_rvalid),
    .rresp(if_rresp),
    .rdata(if_rdata),
    .rlast(if_rlast),
    .rid(if_rid),

    .in_ready(if_ready),
    .in_valid(!rst && (execute_time==0 || valid)),
    .pc(pc),

    .out_ready(id_ready),
    .out_valid(if_valid),
    .inst(inst)
);

/* 译码id */
wire [4:0] rd;
wire [4:0] rs1;
wire [4:0] rs2;
wire [INST_WIDTH-1:0] imm;
wire [15:0] inst_code;
inst_decode #(
    .INST_WIDTH(INST_WIDTH)
) idu(
    .clk(clk),
    .rst(rst),

    .in_ready(id_ready),
    .in_valid(if_valid),
    .inst(inst),

    .out_ready(ex_ls_ready),
    .out_valid(id_valid),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .icode(inst_code)
);
wire fence_enable = (inst_code == `INST_FENCE) || (inst_code == `INST_FENCE_I);
reg last_fence_enable;
always @(posedge clk ) last_fence_enable <= fence_enable;
wire fence_enable_trigger = fence_enable && !last_fence_enable;
assign ls_enable = 
(inst_code == `INST_LB) ||
(inst_code == `INST_LH) ||
(inst_code == `INST_LW) ||
(inst_code == `INST_LBU) ||
(inst_code == `INST_LHU) ||
(inst_code == `INST_SB) ||
(inst_code == `INST_SH) ||
(inst_code == `INST_SW) ||
fence_enable
;
assign ex_enable = !ls_enable;
assign ex_ls_ready = ({1{ex_enable}} & ex_ready) | ({1{ls_enable}} & ls_ready);

/* 执行ex */
wire [INST_WIDTH-1:0] ex_dnpc, ex_result;
wire [7:0] ex_mem_result_width;
wire ex_result_update_csr;
execute #(
    .INST_WIDTH(INST_WIDTH)
) exu(
    .clk(clk),
    .rst(rst),

    .in_ready(ex_ready),
    .in_valid(id_valid && ex_enable),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .x(x),

    .out_ready(wb_ready),
    .out_valid(ex_valid),
    .dnpc(ex_dnpc),
    .result(ex_result),
    .mem_result_width(ex_mem_result_width),
    .result_update_csr(ex_result_update_csr)
);

/* 读存储ls */
wire [INST_WIDTH-1:0] ls_dnpc, ls_result;
wire [7:0] ls_mem_result_width;
wire ls_result_update_csr;
load_store #(
    .INST_WIDTH(INST_WIDTH)
) lsu(
    .clk(clk),
    .rst(rst),

    .awready(ls_awready),
    .awvalid(ls_awvalid),
    .awaddr(ls_awaddr),
    .awid(ls_awid),
    .awlen(ls_awlen),
    .awsize(ls_awsize),
    .awburst(ls_awburst),
    .wready(ls_wready),
    .wvalid(ls_wvalid),
    .wdata(ls_wdata),
    .wstrb(ls_wstrb),
    .wlast(ls_wlast),
    .bready(ls_bready),
    .bvalid(ls_bvalid),
    .bresp(ls_bresp),
    .bid(ls_bid),
    .arready(ls_arready),
    .arvalid(ls_arvalid),
    .araddr(ls_araddr),
    .arid(ls_arid),
    .arlen(ls_arlen),
    .arsize(ls_arsize),
    .arburst(ls_arburst),
    .rready(ls_rready),
    .rvalid(ls_rvalid),
    .rresp(ls_rresp),
    .rdata(ls_rdata),
    .rlast(ls_rlast),
    .rid(ls_rid),

    .in_ready(ls_ready),
    .in_valid(id_valid && ls_enable),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .x(x),

    .out_ready(wb_ready),
    .out_valid(ls_valid),
    .dnpc(ls_dnpc),
    .result(ls_result),
    .mem_result_width(ls_mem_result_width),
    .result_update_csr(ls_result_update_csr)
);

/* 回写wb */
wire [INST_WIDTH-1:0] dnpc, result;
wire [7:0] mem_result_width;
wire result_update_csr;
assign dnpc = ({INST_WIDTH{ex_enable}} & ex_dnpc) | ({INST_WIDTH{ls_enable}} & ls_dnpc);
assign result = ({INST_WIDTH{ex_enable}} & ex_result) | ({INST_WIDTH{ls_enable}} & ls_result);
assign mem_result_width = ({8{ex_enable}} & ex_mem_result_width) | ({8{ls_enable}} & ls_mem_result_width);
assign result_update_csr = ({1{ex_enable}} & ex_result_update_csr) | ({1{ls_enable}} & ls_result_update_csr);
assign ex_ls_valid = ({1{ex_enable}} & ex_valid) | ({1{ls_enable}} & ls_valid);
write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .w_x(x),

    .in_ready(wb_ready),
    .in_valid(ex_ls_valid),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .result(result),
    .mem_result_width(mem_result_width),
    .result_update_csr(result_update_csr),
    .dnpc(dnpc),

    .out_ready(),
    .out_valid(wb_valid),
    .w_pc(pc)
);

endmodule
