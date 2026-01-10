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
wire if_valid;
wire id_ready;
wire id_valid;
wire ex_ready;
wire ex_valid;
wire ls_ready;
wire ls_valid;
wire wb_ready;
wire ex_enable;
wire ls_enable;
wire ex_ls_valid;
wire ex_ls_ready;

/* ifu axi4 信号 */
wire                        awready1;
wire                        awvalid1;
wire [ADDR_WIDTH-1:0]       awaddr1;
wire [3:0]                  awid1;
wire [7:0]                  awlen1;
wire [2:0]                  awsize1;
wire [1:0]                  awburst1;
wire                        wready1;
wire                        wvalid1;
wire [DATA_WIDTH-1:0]       wdata1;
wire [DATA_WIDTH/8-1:0]     wstrb1;
wire                        wlast1;
wire                        bready1;
wire                        bvalid1;
wire [BRESP_WIDTH-1:0]      bresp1;
wire [3:0]                  bid1;
wire                        arready1;
wire                        arvalid1;
wire [ADDR_WIDTH-1:0]       araddr1;
wire [3:0]                  arid1;
wire [7:0]                  arlen1;
wire [2:0]                  arsize1;
wire [1:0]                  arburst1;
wire                        rready1;
wire                        rvalid1;
wire [RRESP_WIDTH-1:0]      rresp1;
wire [DATA_WIDTH-1:0]       rdata1;
wire                        rlast1;
wire [3:0]                  rid1;
/* lsu axi4 信号 */
wire                        awready2;
wire                        awvalid2;
wire [ADDR_WIDTH-1:0]       awaddr2;
wire [3:0]                  awid2;
wire [7:0]                  awlen2;
wire [2:0]                  awsize2;
wire [1:0]                  awburst2;
wire                        wready2;
wire                        wvalid2;
wire [DATA_WIDTH-1:0]       wdata2;
wire [DATA_WIDTH/8-1:0]     wstrb2;
wire                        wlast2;
wire                        bready2;
wire                        bvalid2;
wire [BRESP_WIDTH-1:0]      bresp2;
wire [3:0]                  bid2;
wire                        arready2;
wire                        arvalid2;
wire [ADDR_WIDTH-1:0]       araddr2;
wire [3:0]                  arid2;
wire [7:0]                  arlen2;
wire [2:0]                  arsize2;
wire [1:0]                  arburst2;
wire                        rready2;
wire                        rvalid2;
wire [RRESP_WIDTH-1:0]      rresp2;
wire [DATA_WIDTH-1:0]       rdata2;
wire                        rlast2;
wire [3:0]                  rid2;
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

assign valid = wb_ready;
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

    .m_awready(awready1),
    .m_awvalid(awvalid1),
    .m_awaddr(awaddr1),
    .m_awid(awid1),
    .m_awlen(awlen1),
    .m_awsize(awsize1),
    .m_awburst(awburst1),
    .m_wready(wready1),
    .m_wvalid(wvalid1),
    .m_wdata(wdata1),
    .m_wstrb(wstrb1),
    .m_wlast(wlast1),
    .m_bready(bready1),
    .m_bvalid(bvalid1),
    .m_bresp(bresp1),
    .m_bid(bid1),
    .m_arready(arready1),
    .m_arvalid(arvalid1),
    .m_araddr(araddr1),
    .m_arid(arid1),
    .m_arlen(arlen1),
    .m_arsize(arsize1),
    .m_arburst(arburst1),
    .m_rready(rready1),
    .m_rvalid(rvalid1),
    .m_rresp(rresp1),
    .m_rdata(rdata1),
    .m_rlast(rlast1),
    .m_rid(rid1),

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
    .u_awreadys(   {icache_awready,     awready2   }),
    .u_awvalids(   {icache_awvalid,     awvalid2   }),
    .u_awaddrs(    {icache_awaddr,      awaddr2    }),
    .u_awids(      {icache_awid,        awid2      }),
    .u_awlens(     {icache_awlen,       awlen2     }),
    .u_awsizes(    {icache_awsize,      awsize2    }),
    .u_awbursts(   {icache_awburst,     awburst2   }),
    .u_wreadys(    {icache_wready,      wready2    }),
    .u_wvalids(    {icache_wvalid,      wvalid2    }),
    .u_wdatas(     {icache_wdata,       wdata2     }),
    .u_wstrbs(     {icache_wstrb,       wstrb2     }),
    .u_wlasts(     {icache_wlast,       wlast2     }),
    .u_breadys(    {icache_bready,      bready2    }),
    .u_bvalids(    {icache_bvalid,      bvalid2    }),
    .u_bresps(     {icache_bresp,       bresp2     }),
    .u_bids(       {icache_bid,         bid2       }),
    .u_arreadys(   {icache_arready,     arready2   }),
    .u_arvalids(   {icache_arvalid,     arvalid2   }),
    .u_araddrs(    {icache_araddr,      araddr2    }),
    .u_arids(      {icache_arid,        arid2      }),
    .u_arlens(     {icache_arlen,       arlen2     }),
    .u_arsizes(    {icache_arsize,      arsize2    }),
    .u_arbursts(   {icache_arburst,     arburst2   }),
    .u_rreadys(    {icache_rready,      rready2    }),
    .u_rvalids(    {icache_rvalid,      rvalid2    }),
    .u_rresps(     {icache_rresp,       rresp2     }),
    .u_rdatas(     {icache_rdata,       rdata2     }),
    .u_rlasts(     {icache_rlast,       rlast2     }),
    .u_rids(       {icache_rid,         rid2       }),

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

    .pc(pc),
    .inst(inst),

    .awready(awready1),
    .awvalid(awvalid1),
    .awaddr(awaddr1),
    .awid(awid1),
    .awlen(awlen1),
    .awsize(awsize1),
    .awburst(awburst1),
    .wready(wready1),
    .wvalid(wvalid1),
    .wdata(wdata1),
    .wstrb(wstrb1),
    .wlast(wlast1),
    .bready(bready1),
    .bvalid(bvalid1),
    .bresp(bresp1),
    .bid(bid1),
    .arready(arready1),
    .arvalid(arvalid1),
    .araddr(araddr1),
    .arid(arid1),
    .arlen(arlen1),
    .arsize(arsize1),
    .arburst(arburst1),
    .rready(rready1),
    .rvalid(rvalid1),
    .rresp(rresp1),
    .rdata(rdata1),
    .rlast(rlast1),
    .rid(rid1),

    .enable(execute_time<=1 || valid),
    .next_ready(id_ready),
    .next_valid(if_valid)
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

    .inst(inst),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .icode(inst_code),

    .prev_ready(id_ready),
    .prev_valid(if_valid),
    .next_ready(ex_ls_ready),
    .next_valid(id_valid)
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

    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .dnpc(ex_dnpc),
    .x(x),
    .result(ex_result),
    .mem_result_width(ex_mem_result_width),
    .result_update_csr(ex_result_update_csr),

    .prev_ready(ex_ready),
    .prev_valid(id_valid && ex_enable),
    .next_ready(wb_ready),
    .next_valid(ex_valid)
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

    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .dnpc(ls_dnpc),
    .x(x),
    .result(ls_result),
    .mem_result_width(ls_mem_result_width),
    .result_update_csr(ls_result_update_csr),

    .awready(awready2),
    .awvalid(awvalid2),
    .awaddr(awaddr2),
    .awid(awid2),
    .awlen(awlen2),
    .awsize(awsize2),
    .awburst(awburst2),
    .wready(wready2),
    .wvalid(wvalid2),
    .wdata(wdata2),
    .wstrb(wstrb2),
    .wlast(wlast2),
    .bready(bready2),
    .bvalid(bvalid2),
    .bresp(bresp2),
    .bid(bid2),
    .arready(arready2),
    .arvalid(arvalid2),
    .araddr(araddr2),
    .arid(arid2),
    .arlen(arlen2),
    .arsize(arsize2),
    .arburst(arburst2),
    .rready(rready2),
    .rvalid(rvalid2),
    .rresp(rresp2),
    .rdata(rdata2),
    .rlast(rlast2),
    .rid(rid2),

    .prev_ready(ls_ready),
    .prev_valid(id_valid && ls_enable),
    .next_ready(wb_ready),
    .next_valid(ls_valid)
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

    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .w_x(x),
    .result(result),
    .mem_result_width(mem_result_width),
    .result_update_csr(result_update_csr),
    .dnpc(dnpc),
    .w_pc(pc),

    .prev_ready(wb_ready),
    .prev_valid(ex_ls_valid)
);

endmodule
