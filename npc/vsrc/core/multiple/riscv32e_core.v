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
wire                        aw_ready1;
wire                        aw_valid1;
wire [ADDR_WIDTH-1:0]       aw_addr1;
wire [3:0]                  aw_id1;
wire [7:0]                  aw_len1;
wire [2:0]                  aw_size1;
wire [1:0]                  aw_burst1;
wire                        w_ready1;
wire                        w_valid1;
wire [DATA_WIDTH-1:0]       w_data1;
wire [DATA_WIDTH/8-1:0]     w_strb1;
wire                        w_last1;
wire                        b_ready1;
wire                        b_valid1;
wire [BRESP_WIDTH-1:0]      b_resp1;
wire [3:0]                  b_id1;
wire                        ar_ready1;
wire                        ar_valid1;
wire [ADDR_WIDTH-1:0]       ar_addr1;
wire [3:0]                  ar_id1;
wire [7:0]                  ar_len1;
wire [2:0]                  ar_size1;
wire [1:0]                  ar_burst1;
wire                        r_ready1;
wire                        r_valid1;
wire [RRESP_WIDTH-1:0]      r_resp1;
wire [DATA_WIDTH-1:0]       r_data1;
wire                        r_last1;
wire [3:0]                  r_id1;
/* lsu axi4 信号 */
wire                        aw_ready2;
wire                        aw_valid2;
wire [ADDR_WIDTH-1:0]       aw_addr2;
wire [3:0]                  aw_id2;
wire [7:0]                  aw_len2;
wire [2:0]                  aw_size2;
wire [1:0]                  aw_burst2;
wire                        w_ready2;
wire                        w_valid2;
wire [DATA_WIDTH-1:0]       w_data2;
wire [DATA_WIDTH/8-1:0]     w_strb2;
wire                        w_last2;
wire                        b_ready2;
wire                        b_valid2;
wire [BRESP_WIDTH-1:0]      b_resp2;
wire [3:0]                  b_id2;
wire                        ar_ready2;
wire                        ar_valid2;
wire [ADDR_WIDTH-1:0]       ar_addr2;
wire [3:0]                  ar_id2;
wire [7:0]                  ar_len2;
wire [2:0]                  ar_size2;
wire [1:0]                  ar_burst2;
wire                        r_ready2;
wire                        r_valid2;
wire [RRESP_WIDTH-1:0]      r_resp2;
wire [DATA_WIDTH-1:0]       r_data2;
wire                        r_last2;
wire [3:0]                  r_id2;
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
        func_execute_time_ctrl(0);
    end else begin
        execute_time <= execute_time + 1;
        func_execute_time_ctrl(1);
    end
end

/* 性能监控 */
perf_monitor m_perf_monitor (
    .clk(clk),
    .rst(rst),
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
    .u_aw_readys(   {aw_ready1,     aw_ready2   }),
    .u_aw_valids(   {aw_valid1,     aw_valid2   }),
    .u_aw_addrs(    {aw_addr1,      aw_addr2    }),
    .u_aw_ids(      {aw_id1,        aw_id2      }),
    .u_aw_lens(     {aw_len1,       aw_len2     }),
    .u_aw_sizes(    {aw_size1,      aw_size2    }),
    .u_aw_bursts(   {aw_burst1,     aw_burst2   }),
    .u_w_readys(    {w_ready1,      w_ready2    }),
    .u_w_valids(    {w_valid1,      w_valid2    }),
    .u_w_datas(     {w_data1,       w_data2     }),
    .u_w_strbs(     {w_strb1,       w_strb2     }),
    .u_w_lasts(     {w_last1,       w_last2     }),
    .u_b_readys(    {b_ready1,      b_ready2    }),
    .u_b_valids(    {b_valid1,      b_valid2    }),
    .u_b_resps(     {b_resp1,       b_resp2     }),
    .u_b_ids(       {b_id1,         b_id2       }),
    .u_ar_readys(   {ar_ready1,     ar_ready2   }),
    .u_ar_valids(   {ar_valid1,     ar_valid2   }),
    .u_ar_addrs(    {ar_addr1,      ar_addr2    }),
    .u_ar_ids(      {ar_id1,        ar_id2      }),
    .u_ar_lens(     {ar_len1,       ar_len2     }),
    .u_ar_sizes(    {ar_size1,      ar_size2    }),
    .u_ar_bursts(   {ar_burst1,     ar_burst2   }),
    .u_r_readys(    {r_ready1,      r_ready2    }),
    .u_r_valids(    {r_valid1,      r_valid2    }),
    .u_r_resps(     {r_resp1,       r_resp2     }),
    .u_r_datas(     {r_data1,       r_data2     }),
    .u_r_lasts(     {r_last1,       r_last2     }),
    .u_r_ids(       {r_id1,         r_id2       }),

    .aw_ready(m_awready),
    .aw_valid(m_awvalid),
    .aw_addr(m_awaddr),
    .aw_id(m_awid),
    .aw_len(m_awlen),
    .aw_size(m_awsize),
    .aw_burst(m_awburst),
    .w_ready(m_wready),
    .w_valid(m_wvalid),
    .w_data(m_wdata),
    .w_strb(m_wstrb),
    .w_last(m_wlast),
    .b_ready(m_bready),
    .b_valid(m_bvalid),
    .b_resp(m_bresp),
    .b_id(m_bid),
    .ar_ready(m_arready),
    .ar_valid(m_arvalid),
    .ar_addr(m_araddr),
    .ar_id(m_arid),
    .ar_len(m_arlen),
    .ar_size(m_arsize),
    .ar_burst(m_arburst),
    .r_ready(m_rready),
    .r_valid(m_rvalid),
    .r_resp(m_rresp),
    .r_data(m_rdata),
    .r_last(m_rlast),
    .r_id(m_rid),

    .grant_idx()
);

/* 指令缓存 */
icache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
    .INST_WIDTH(INST_WIDTH),
    .BLOCK_SIZE(16)
) m_icache (
    .clk(clk),
    .rst(rst),

    .m_awready(m_awready),
    .m_awvalid(m_awvalid),
    .m_awaddr(m_awaddr),
    .m_awid(m_awid),
    .m_awlen(m_awlen),
    .m_awsize(m_awsize),
    .m_awburst(m_awburst),
    .m_wready(m_wready),
    .m_wvalid(m_wvalid),
    .m_wdata(m_wdata),
    .m_wstrb(m_wstrb),
    .m_wlast(m_wlast),
    .m_bready(m_bready),
    .m_bvalid(m_bvalid),
    .m_bresp(m_bresp),
    .m_bid(m_bid),
    .m_arready(m_arready),
    .m_arvalid(m_arvalid),
    .m_araddr(m_araddr),
    .m_arid(m_arid),
    .m_arlen(m_arlen),
    .m_arsize(m_arsize),
    .m_arburst(m_arburst),
    .m_rready(m_rready),
    .m_rvalid(m_rvalid),
    .m_rresp(m_rresp),
    .m_rdata(m_rdata),
    .m_rlast(m_rlast),
    .m_rid(m_rid),

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
    .s_rid(icache_rid),

    .hit_count(),
    .miss_count()
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
    .aw_ready(icache_awready),
    .aw_valid(icache_awvalid),
    .aw_addr(icache_awaddr),
    .aw_id(icache_awid),
    .aw_len(icache_awlen),
    .aw_size(icache_awsize),
    .aw_burst(icache_awburst),
    .w_ready(icache_wready),
    .w_valid(icache_wvalid),
    .w_data(icache_wdata),
    .w_strb(icache_wstrb),
    .w_last(icache_wlast),
    .b_ready(icache_bready),
    .b_valid(icache_bvalid),
    .b_resp(icache_bresp),
    .b_id(icache_bid),
    .ar_ready(icache_arready),
    .ar_valid(icache_arvalid),
    .ar_addr(icache_araddr),
    .ar_id(icache_arid),
    .ar_len(icache_arlen),
    .ar_size(icache_arsize),
    .ar_burst(icache_arburst),
    .r_ready(icache_rready),
    .r_valid(icache_rvalid),
    .r_resp(icache_rresp),
    .r_data(icache_rdata),
    .r_last(icache_rlast),
    .r_id(icache_rid),

    .u_aw_readys(   {   s_awready[0],       s_awready[1],       s_awready[AXI4_SLAVE_COUNT-1]       } ),
    .u_aw_valids(   {   s_awvalid[0],       s_awvalid[1],       s_awvalid[AXI4_SLAVE_COUNT-1]       } ),
    .u_aw_addrs(    {   s_awaddr[0],        s_awaddr[1],        s_awaddr[AXI4_SLAVE_COUNT-1]        } ),
    .u_aw_ids(      {   s_awid[0],          s_awid[1],          s_awid[AXI4_SLAVE_COUNT-1]          } ),
    .u_aw_lens(     {   s_awlen[0],         s_awlen[1],         s_awlen[AXI4_SLAVE_COUNT-1]         } ),
    .u_aw_sizes(    {   s_awsize[0],        s_awsize[1],        s_awsize[AXI4_SLAVE_COUNT-1]        } ),
    .u_aw_bursts(   {   s_awburst[0],       s_awburst[1],       s_awburst[AXI4_SLAVE_COUNT-1]       } ),
    .u_w_readys(    {   s_wready[0],        s_wready[1],        s_wready[AXI4_SLAVE_COUNT-1]        } ),
    .u_w_valids(    {   s_wvalid[0],        s_wvalid[1],        s_wvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_w_datas(     {   s_wdata[0],         s_wdata[1],         s_wdata[AXI4_SLAVE_COUNT-1]         } ),
    .u_w_strbs(     {   s_wstrb[0],         s_wstrb[1],         s_wstrb[AXI4_SLAVE_COUNT-1]         } ),
    .u_w_lasts(     {   s_wlast[0],         s_wlast[1],         s_wlast[AXI4_SLAVE_COUNT-1]         } ),
    .u_b_readys(    {   s_bready[0],        s_bready[1],        s_bready[AXI4_SLAVE_COUNT-1]        } ),
    .u_b_valids(    {   s_bvalid[0],        s_bvalid[1],        s_bvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_b_resps(     {   s_bresp[0],         s_bresp[1],         s_bresp[AXI4_SLAVE_COUNT-1]         } ),
    .u_b_ids(       {   s_bid[0],           s_bid[1],           s_bid[AXI4_SLAVE_COUNT-1]           } ),
    .u_ar_readys(   {   s_arready[0],       s_arready[1],       s_arready[AXI4_SLAVE_COUNT-1]       } ),
    .u_ar_valids(   {   s_arvalid[0],       s_arvalid[1],       s_arvalid[AXI4_SLAVE_COUNT-1]       } ),
    .u_ar_addrs(    {   s_araddr[0],        s_araddr[1],        s_araddr[AXI4_SLAVE_COUNT-1]        } ),
    .u_ar_ids(      {   s_arid[0],          s_arid[1],          s_arid[AXI4_SLAVE_COUNT-1]          } ),
    .u_ar_lens(     {   s_arlen[0],         s_arlen[1],         s_arlen[AXI4_SLAVE_COUNT-1]         } ),
    .u_ar_sizes(    {   s_arsize[0],        s_arsize[1],        s_arsize[AXI4_SLAVE_COUNT-1]        } ),
    .u_ar_bursts(   {   s_arburst[0],       s_arburst[1],       s_arburst[AXI4_SLAVE_COUNT-1]       } ),
    .u_r_readys(    {   s_rready[0],        s_rready[1],        s_rready[AXI4_SLAVE_COUNT-1]        } ),
    .u_r_valids(    {   s_rvalid[0],        s_rvalid[1],        s_rvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_r_resps(     {   s_rresp[0],         s_rresp[1],         s_rresp[AXI4_SLAVE_COUNT-1]         } ),
    .u_r_datas(     {   s_rdata[0],         s_rdata[1],         s_rdata[AXI4_SLAVE_COUNT-1]         } ),
    .u_r_lasts(     {   s_rlast[0],         s_rlast[1],         s_rlast[AXI4_SLAVE_COUNT-1]         } ),
    .u_r_ids(       {   s_rid[0],           s_rid[1],           s_rid[AXI4_SLAVE_COUNT-1]           } ),
    .u_slave_addrs({
        32'h0200_0000, 32'h0200_ffff, // clint
        32'h2200_0000, 32'h2200_0fff, // exter dev
        32'h0000_0000, 32'hffff_ffff // io master
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
    .aw_ready(s_awready[0]),
    .aw_valid(s_awvalid[0]),
    .aw_addr(s_awaddr[0]),
    .aw_id(s_awid[0]),
    .aw_len(s_awlen[0]),
    .aw_size(s_awsize[0]),
    .aw_burst(s_awburst[0]),
    .w_ready(s_wready[0]),
    .w_valid(s_wvalid[0]),
    .w_data(s_wdata[0]),
    .w_strb(s_wstrb[0]),
    .w_last(s_wlast[0]),
    .b_ready(s_bready[0]),
    .b_valid(s_bvalid[0]),
    .b_resp(s_bresp[0]),
    .b_id(s_bid[0]),
    .ar_ready(s_arready[0]),
    .ar_valid(s_arvalid[0]),
    .ar_addr(s_araddr[0]),
    .ar_id(s_arid[0]),
    .ar_len(s_arlen[0]),
    .ar_size(s_arsize[0]),
    .ar_burst(s_arburst[0]),
    .r_ready(s_rready[0]),
    .r_valid(s_rvalid[0]),
    .r_resp(s_rresp[0]),
    .r_data(s_rdata[0]),
    .r_last(s_rlast[0]),
    .r_id(s_rid[0])
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
    .aw_ready(s_awready[1]),
    .aw_valid(s_awvalid[1]),
    .aw_addr(s_awaddr[1]),
    .aw_id(s_awid[1]),
    .aw_len(s_awlen[1]),
    .aw_size(s_awsize[1]),
    .aw_burst(s_awburst[1]),
    .w_ready(s_wready[1]),
    .w_valid(s_wvalid[1]),
    .w_data(s_wdata[1]),
    .w_strb(s_wstrb[1]),
    .w_last(s_wlast[1]),
    .b_ready(s_bready[1]),
    .b_valid(s_bvalid[1]),
    .b_resp(s_bresp[1]),
    .b_id(s_bid[1]),
    .ar_ready(s_arready[1]),
    .ar_valid(s_arvalid[1]),
    .ar_addr(s_araddr[1]),
    .ar_id(s_arid[1]),
    .ar_len(s_arlen[1]),
    .ar_size(s_arsize[1]),
    .ar_burst(s_arburst[1]),
    .r_ready(s_rready[1]),
    .r_valid(s_rvalid[1]),
    .r_resp(s_rresp[1]),
    .r_data(s_rdata[1]),
    .r_last(s_rlast[1]),
    .r_id(s_rid[1])
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

    .aw_ready(aw_ready1),
    .aw_valid(aw_valid1),
    .aw_addr(aw_addr1),
    .aw_id(aw_id1),
    .aw_len(aw_len1),
    .aw_size(aw_size1),
    .aw_burst(aw_burst1),
    .w_ready(w_ready1),
    .w_valid(w_valid1),
    .w_data(w_data1),
    .w_strb(w_strb1),
    .w_last(w_last1),
    .b_ready(b_ready1),
    .b_valid(b_valid1),
    .b_resp(b_resp1),
    .b_id(b_id1),
    .ar_ready(ar_ready1),
    .ar_valid(ar_valid1),
    .ar_addr(ar_addr1),
    .ar_id(ar_id1),
    .ar_len(ar_len1),
    .ar_size(ar_size1),
    .ar_burst(ar_burst1),
    .r_ready(r_ready1),
    .r_valid(r_valid1),
    .r_resp(r_resp1),
    .r_data(r_data1),
    .r_last(r_last1),
    .r_id(r_id1),

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
assign ls_enable = 
(inst_code == `INST_LB) ||
(inst_code == `INST_LH) ||
(inst_code == `INST_LW) ||
(inst_code == `INST_LBU) ||
(inst_code == `INST_LHU) ||
(inst_code == `INST_SB) ||
(inst_code == `INST_SH) ||
(inst_code == `INST_SW)
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

    .aw_ready(aw_ready2),
    .aw_valid(aw_valid2),
    .aw_addr(aw_addr2),
    .aw_id(aw_id2),
    .aw_len(aw_len2),
    .aw_size(aw_size2),
    .aw_burst(aw_burst2),
    .w_ready(w_ready2),
    .w_valid(w_valid2),
    .w_data(w_data2),
    .w_strb(w_strb2),
    .w_last(w_last2),
    .b_ready(b_ready2),
    .b_valid(b_valid2),
    .b_resp(b_resp2),
    .b_id(b_id2),
    .ar_ready(ar_ready2),
    .ar_valid(ar_valid2),
    .ar_addr(ar_addr2),
    .ar_id(ar_id2),
    .ar_len(ar_len2),
    .ar_size(ar_size2),
    .ar_burst(ar_burst2),
    .r_ready(r_ready2),
    .r_valid(r_valid2),
    .r_resp(r_resp2),
    .r_data(r_data2),
    .r_last(r_last2),
    .r_id(r_id2),

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
