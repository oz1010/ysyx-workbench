// 单流水线多周期处理器
module riscv32e_core #(
    parameter INST_WIDTH = 32,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input  wire             clk,
    input  wire             rst,

    /* 外部中断 */
    input  wire             io_interrupt,
    /* AXI4 Master总线 */
    input  wire             io_master_awready,
    output wire             io_master_awvalid,
    output wire [31:0]      io_master_awaddr,
    output wire [3:0]       io_master_awid,
    output wire [7:0]       io_master_awlen,
    output wire [2:0]       io_master_awsize,
    output wire [1:0]       io_master_awburst,
    input  wire             io_master_wready,
    output wire             io_master_wvalid,
    output wire [31:0]      io_master_wdata,
    output wire [3:0]       io_master_wstrb,
    output wire             io_master_wlast,
    output wire             io_master_bready,
    input  wire             io_master_bvalid,
    input  wire [1:0]       io_master_bresp,
    input  wire [3:0]       io_master_bid,
    input  wire             io_master_arready,
    output wire             io_master_arvalid,
    output wire [31:0]      io_master_araddr,
    output wire [3:0]       io_master_arid,
    output wire [7:0]       io_master_arlen,
    output wire [2:0]       io_master_arsize,
    output wire [1:0]       io_master_arburst,
    output wire             io_master_rready,
    input  wire             io_master_rvalid,
    input  wire [1:0]       io_master_rresp,
    input  wire [31:0]      io_master_rdata,
    input  wire             io_master_rlast,
    input  wire [3:0]       io_master_rid,

    /* 用于调试和综合避免忽略掉信息 */
    output wire [INST_WIDTH-1:0] pc,
    output wire             valid
);

/* 模块之间的连接信号或数据 */
wire                        con_if_ready;
wire                        con_if_valid;
wire                        con_id_ready;
wire                        con_id_valid;
wire                        con_ex_ready;
wire                        con_ex_valid;
wire                        con_ls_ready;
wire                        con_ls_valid;
wire                        con_wb_ready;
wire                        con_wb_valid;
wire                        con_ex_enable;
wire                        con_ls_enable;
wire                        con_ex_ls_valid;
wire                        con_ex_ls_ready;

/* ifu axi4 信号 */
wire                        axi4_if_awready;
wire                        axi4_if_awvalid;
wire [ADDR_WIDTH-1:0]       axi4_if_awaddr;
wire [3:0]                  axi4_if_awid;
wire [7:0]                  axi4_if_awlen;
wire [2:0]                  axi4_if_awsize;
wire [1:0]                  axi4_if_awburst;
wire                        axi4_if_wready;
wire                        axi4_if_wvalid;
wire [DATA_WIDTH-1:0]       axi4_if_wdata;
wire [DATA_WIDTH/8-1:0]     axi4_if_wstrb;
wire                        axi4_if_wlast;
wire                        axi4_if_bready;
wire                        axi4_if_bvalid;
wire [BRESP_WIDTH-1:0]      axi4_if_bresp;
wire [3:0]                  axi4_if_bid;
wire                        axi4_if_arready;
wire                        axi4_if_arvalid;
wire [ADDR_WIDTH-1:0]       axi4_if_araddr;
wire [3:0]                  axi4_if_arid;
wire [7:0]                  axi4_if_arlen;
wire [2:0]                  axi4_if_arsize;
wire [1:0]                  axi4_if_arburst;
wire                        axi4_if_rready;
wire                        axi4_if_rvalid;
wire [RRESP_WIDTH-1:0]      axi4_if_rresp;
wire [DATA_WIDTH-1:0]       axi4_if_rdata;
wire                        axi4_if_rlast;
wire [3:0]                  axi4_if_rid;
/* lsu axi4 信号 */
wire                        axi4_ls_awready;
wire                        axi4_ls_awvalid;
wire [ADDR_WIDTH-1:0]       axi4_ls_awaddr;
wire [3:0]                  axi4_ls_awid;
wire [7:0]                  axi4_ls_awlen;
wire [2:0]                  axi4_ls_awsize;
wire [1:0]                  axi4_ls_awburst;
wire                        axi4_ls_wready;
wire                        axi4_ls_wvalid;
wire [DATA_WIDTH-1:0]       axi4_ls_wdata;
wire [DATA_WIDTH/8-1:0]     axi4_ls_wstrb;
wire                        axi4_ls_wlast;
wire                        axi4_ls_bready;
wire                        axi4_ls_bvalid;
wire [BRESP_WIDTH-1:0]      axi4_ls_bresp;
wire [3:0]                  axi4_ls_bid;
wire                        axi4_ls_arready;
wire                        axi4_ls_arvalid;
wire [ADDR_WIDTH-1:0]       axi4_ls_araddr;
wire [3:0]                  axi4_ls_arid;
wire [7:0]                  axi4_ls_arlen;
wire [2:0]                  axi4_ls_arsize;
wire [1:0]                  axi4_ls_arburst;
wire                        axi4_ls_rready;
wire                        axi4_ls_rvalid;
wire [RRESP_WIDTH-1:0]      axi4_ls_rresp;
wire [DATA_WIDTH-1:0]       axi4_ls_rdata;
wire                        axi4_ls_rlast;
wire [3:0]                  axi4_ls_rid;
/* 仲裁后的 axi4信号 */
wire                        axi4_arbiter_awready;
wire                        axi4_arbiter_awvalid;
wire [31:0]                 axi4_arbiter_awaddr;
wire [3:0]                  axi4_arbiter_awid;
wire [7:0]                  axi4_arbiter_awlen;
wire [2:0]                  axi4_arbiter_awsize;
wire [1:0]                  axi4_arbiter_awburst;
wire                        axi4_arbiter_wready;
wire                        axi4_arbiter_wvalid;
wire [31:0]                 axi4_arbiter_wdata;
wire [3:0]                  axi4_arbiter_wstrb;
wire                        axi4_arbiter_wlast;
wire                        axi4_arbiter_bready;
wire                        axi4_arbiter_bvalid;
wire [1:0]                  axi4_arbiter_bresp;
wire [3:0]                  axi4_arbiter_bid;
wire                        axi4_arbiter_arready;
wire                        axi4_arbiter_arvalid;
wire [31:0]                 axi4_arbiter_araddr;
wire [3:0]                  axi4_arbiter_arid;
wire [7:0]                  axi4_arbiter_arlen;
wire [2:0]                  axi4_arbiter_arsize;
wire [1:0]                  axi4_arbiter_arburst;
wire                        axi4_arbiter_rready;
wire                        axi4_arbiter_rvalid;
wire [1:0]                  axi4_arbiter_rresp;
wire [31:0]                 axi4_arbiter_rdata;
wire                        axi4_arbiter_rlast;
wire [3:0]                  axi4_arbiter_rid;
/* 指令缓存后的 axi4信号 */
wire                        axi4_icache_awready;
wire                        axi4_icache_awvalid;
wire [31:0]                 axi4_icache_awaddr;
wire [3:0]                  axi4_icache_awid;
wire [7:0]                  axi4_icache_awlen;
wire [2:0]                  axi4_icache_awsize;
wire [1:0]                  axi4_icache_awburst;
wire                        axi4_icache_wready;
wire                        axi4_icache_wvalid;
wire [31:0]                 axi4_icache_wdata;
wire [3:0]                  axi4_icache_wstrb;
wire                        axi4_icache_wlast;
wire                        axi4_icache_bready;
wire                        axi4_icache_bvalid;
wire [1:0]                  axi4_icache_bresp;
wire [3:0]                  axi4_icache_bid;
wire                        axi4_icache_arready;
wire                        axi4_icache_arvalid;
wire [31:0]                 axi4_icache_araddr;
wire [3:0]                  axi4_icache_arid;
wire [7:0]                  axi4_icache_arlen;
wire [2:0]                  axi4_icache_arsize;
wire [1:0]                  axi4_icache_arburst;
wire                        axi4_icache_rready;
wire                        axi4_icache_rvalid;
wire [1:0]                  axi4_icache_rresp;
wire [31:0]                 axi4_icache_rdata;
wire                        axi4_icache_rlast;
wire [3:0]                  axi4_icache_rid;
/* 数据缓存后的 axi4信号 */
wire                        axi4_dcache_awready;
wire                        axi4_dcache_awvalid;
wire [31:0]                 axi4_dcache_awaddr;
wire [3:0]                  axi4_dcache_awid;
wire [7:0]                  axi4_dcache_awlen;
wire [2:0]                  axi4_dcache_awsize;
wire [1:0]                  axi4_dcache_awburst;
wire                        axi4_dcache_wready;
wire                        axi4_dcache_wvalid;
wire [31:0]                 axi4_dcache_wdata;
wire [3:0]                  axi4_dcache_wstrb;
wire                        axi4_dcache_wlast;
wire                        axi4_dcache_bready;
wire                        axi4_dcache_bvalid;
wire [1:0]                  axi4_dcache_bresp;
wire [3:0]                  axi4_dcache_bid;
wire                        axi4_dcache_arready;
wire                        axi4_dcache_arvalid;
wire [31:0]                 axi4_dcache_araddr;
wire [3:0]                  axi4_dcache_arid;
wire [7:0]                  axi4_dcache_arlen;
wire [2:0]                  axi4_dcache_arsize;
wire [1:0]                  axi4_dcache_arburst;
wire                        axi4_dcache_rready;
wire                        axi4_dcache_rvalid;
wire [1:0]                  axi4_dcache_rresp;
wire [31:0]                 axi4_dcache_rdata;
wire                        axi4_dcache_rlast;
wire [3:0]                  axi4_dcache_rid;
/**
    0 -- clint
    1 -- exter dev
    last -- io master
*/
localparam AXI4_SLAVE_COUNT = 3;
/* salve axi4信号组 */
wire                        axi4_s_awready[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_awvalid[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 axi4_s_awaddr[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  axi4_s_awid[AXI4_SLAVE_COUNT-1:0];
wire [7:0]                  axi4_s_awlen[AXI4_SLAVE_COUNT-1:0];
wire [2:0]                  axi4_s_awsize[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  axi4_s_awburst[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_wready[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_wvalid[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 axi4_s_wdata[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  axi4_s_wstrb[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_wlast[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_bready[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_bvalid[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  axi4_s_bresp[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  axi4_s_bid[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_arready[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_arvalid[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 axi4_s_araddr[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  axi4_s_arid[AXI4_SLAVE_COUNT-1:0];
wire [7:0]                  axi4_s_arlen[AXI4_SLAVE_COUNT-1:0];
wire [2:0]                  axi4_s_arsize[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  axi4_s_arburst[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_rready[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_rvalid[AXI4_SLAVE_COUNT-1:0];
wire [1:0]                  axi4_s_rresp[AXI4_SLAVE_COUNT-1:0];
wire [31:0]                 axi4_s_rdata[AXI4_SLAVE_COUNT-1:0];
wire                        axi4_s_rlast[AXI4_SLAVE_COUNT-1:0];
wire [3:0]                  axi4_s_rid[AXI4_SLAVE_COUNT-1:0];
/* io master直接与salve axi4最后一组相连 */
assign axi4_s_awready[AXI4_SLAVE_COUNT-1]   = io_master_awready;
assign io_master_awvalid                    = axi4_s_awvalid[AXI4_SLAVE_COUNT-1];
assign io_master_awaddr                     = axi4_s_awaddr[AXI4_SLAVE_COUNT-1];
assign io_master_awid                       = axi4_s_awid[AXI4_SLAVE_COUNT-1];
assign io_master_awlen                      = axi4_s_awlen[AXI4_SLAVE_COUNT-1];
assign io_master_awsize                     = axi4_s_awsize[AXI4_SLAVE_COUNT-1];
assign io_master_awburst                    = axi4_s_awburst[AXI4_SLAVE_COUNT-1];
assign axi4_s_wready[AXI4_SLAVE_COUNT-1]    = io_master_wready;
assign io_master_wvalid                     = axi4_s_wvalid[AXI4_SLAVE_COUNT-1];
assign io_master_wdata                      = axi4_s_wdata[AXI4_SLAVE_COUNT-1];
assign io_master_wstrb                      = axi4_s_wstrb[AXI4_SLAVE_COUNT-1];
assign io_master_wlast                      = axi4_s_wlast[AXI4_SLAVE_COUNT-1];
assign io_master_bready                     = axi4_s_bready[AXI4_SLAVE_COUNT-1];
assign axi4_s_bvalid[AXI4_SLAVE_COUNT-1]    = io_master_bvalid;
assign axi4_s_bresp[AXI4_SLAVE_COUNT-1]     = io_master_bresp;
assign axi4_s_bid[AXI4_SLAVE_COUNT-1]       = io_master_bid;
assign axi4_s_arready[AXI4_SLAVE_COUNT-1]   = io_master_arready;
assign io_master_arvalid                    = axi4_s_arvalid[AXI4_SLAVE_COUNT-1];
assign io_master_araddr                     = axi4_s_araddr[AXI4_SLAVE_COUNT-1];
assign io_master_arid                       = axi4_s_arid[AXI4_SLAVE_COUNT-1];
assign io_master_arlen                      = axi4_s_arlen[AXI4_SLAVE_COUNT-1];
assign io_master_arsize                     = axi4_s_arsize[AXI4_SLAVE_COUNT-1];
assign io_master_arburst                    = axi4_s_arburst[AXI4_SLAVE_COUNT-1];
assign io_master_rready                     = axi4_s_rready[AXI4_SLAVE_COUNT-1];
assign axi4_s_rvalid[AXI4_SLAVE_COUNT-1]    = io_master_rvalid;
assign axi4_s_rresp[AXI4_SLAVE_COUNT-1]     = io_master_rresp;
assign axi4_s_rdata[AXI4_SLAVE_COUNT-1]     = io_master_rdata;
assign axi4_s_rlast[AXI4_SLAVE_COUNT-1]     = io_master_rlast;
assign axi4_s_rid[AXI4_SLAVE_COUNT-1]       = io_master_rid;

/* 常用处理器信号 */
wire [INST_WIDTH-1:0] inst;
reg [63:0] execute_time;
wire [INST_WIDTH-1:0] src1, src2, a0;
wire wb_gpr_wen;
wire [4:0] wb_gpr_windex;
wire [INST_WIDTH-1:0] wb_gpr_wdata;

assign valid = con_wb_valid;
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

/* 寄存器组 */
gprs #(
    .INST_WIDTH(INST_WIDTH),
    .REG_COUNT(`RISCV_GPR_COUNT)
) m_gprs (
    .clk(clk),
    .rst(rst),
    .rs1(rs1),
    .src1(src1),
    .rs2(rs2),
    .src2(src2),
    .a0(a0),
    .wen(wb_gpr_wen),
    .windex(wb_gpr_windex),
    .wdata(wb_gpr_wdata)
);

/* 性能监控 */
perf_monitor m_perf_monitor (
    .clk(clk),
    .rst(rst),
    .pc(pc),
    .inst(inst),
    .if_valid(con_if_valid),
    .id_ready(con_id_ready),
    .id_valid(con_id_valid),
    .ex_ready(con_ex_ready),
    .ex_valid(con_ex_valid),
    .ls_ready(con_ls_ready),
    .ls_valid(con_ls_valid),
    .wb_ready(con_wb_ready),
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

    .m_awready(axi4_if_awready),
    .m_awvalid(axi4_if_awvalid),
    .m_awaddr(axi4_if_awaddr),
    .m_awid(axi4_if_awid),
    .m_awlen(axi4_if_awlen),
    .m_awsize(axi4_if_awsize),
    .m_awburst(axi4_if_awburst),
    .m_wready(axi4_if_wready),
    .m_wvalid(axi4_if_wvalid),
    .m_wdata(axi4_if_wdata),
    .m_wstrb(axi4_if_wstrb),
    .m_wlast(axi4_if_wlast),
    .m_bready(axi4_if_bready),
    .m_bvalid(axi4_if_bvalid),
    .m_bresp(axi4_if_bresp),
    .m_bid(axi4_if_bid),
    .m_arready(axi4_if_arready),
    .m_arvalid(axi4_if_arvalid),
    .m_araddr(axi4_if_araddr),
    .m_arid(axi4_if_arid),
    .m_arlen(axi4_if_arlen),
    .m_arsize(axi4_if_arsize),
    .m_arburst(axi4_if_arburst),
    .m_rready(axi4_if_rready),
    .m_rvalid(axi4_if_rvalid),
    .m_rresp(axi4_if_rresp),
    .m_rdata(axi4_if_rdata),
    .m_rlast(axi4_if_rlast),
    .m_rid(axi4_if_rid),

    .s_awready(axi4_icache_awready),
    .s_awvalid(axi4_icache_awvalid),
    .s_awaddr(axi4_icache_awaddr),
    .s_awid(axi4_icache_awid),
    .s_awlen(axi4_icache_awlen),
    .s_awsize(axi4_icache_awsize),
    .s_awburst(axi4_icache_awburst),
    .s_wready(axi4_icache_wready),
    .s_wvalid(axi4_icache_wvalid),
    .s_wdata(axi4_icache_wdata),
    .s_wstrb(axi4_icache_wstrb),
    .s_wlast(axi4_icache_wlast),
    .s_bready(axi4_icache_bready),
    .s_bvalid(axi4_icache_bvalid),
    .s_bresp(axi4_icache_bresp),
    .s_bid(axi4_icache_bid),
    .s_arready(axi4_icache_arready),
    .s_arvalid(axi4_icache_arvalid),
    .s_araddr(axi4_icache_araddr),
    .s_arid(axi4_icache_arid),
    .s_arlen(axi4_icache_arlen),
    .s_arsize(axi4_icache_arsize),
    .s_arburst(axi4_icache_arburst),
    .s_rready(axi4_icache_rready),
    .s_rvalid(axi4_icache_rvalid),
    .s_rresp(axi4_icache_rresp),
    .s_rdata(axi4_icache_rdata),
    .s_rlast(axi4_icache_rlast),
    .s_rid(axi4_icache_rid)
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

    .m_awready(axi4_ls_awready),
    .m_awvalid(axi4_ls_awvalid),
    .m_awaddr(axi4_ls_awaddr),
    .m_awid(axi4_ls_awid),
    .m_awlen(axi4_ls_awlen),
    .m_awsize(axi4_ls_awsize),
    .m_awburst(axi4_ls_awburst),
    .m_wready(axi4_ls_wready),
    .m_wvalid(axi4_ls_wvalid),
    .m_wdata(axi4_ls_wdata),
    .m_wstrb(axi4_ls_wstrb),
    .m_wlast(axi4_ls_wlast),
    .m_bready(axi4_ls_bready),
    .m_bvalid(axi4_ls_bvalid),
    .m_bresp(axi4_ls_bresp),
    .m_bid(axi4_ls_bid),
    .m_arready(axi4_ls_arready),
    .m_arvalid(axi4_ls_arvalid),
    .m_araddr(axi4_ls_araddr),
    .m_arid(axi4_ls_arid),
    .m_arlen(axi4_ls_arlen),
    .m_arsize(axi4_ls_arsize),
    .m_arburst(axi4_ls_arburst),
    .m_rready(axi4_ls_rready),
    .m_rvalid(axi4_ls_rvalid),
    .m_rresp(axi4_ls_rresp),
    .m_rdata(axi4_ls_rdata),
    .m_rlast(axi4_ls_rlast),
    .m_rid(axi4_ls_rid),

    .s_awready(axi4_dcache_awready),
    .s_awvalid(axi4_dcache_awvalid),
    .s_awaddr(axi4_dcache_awaddr),
    .s_awid(axi4_dcache_awid),
    .s_awlen(axi4_dcache_awlen),
    .s_awsize(axi4_dcache_awsize),
    .s_awburst(axi4_dcache_awburst),
    .s_wready(axi4_dcache_wready),
    .s_wvalid(axi4_dcache_wvalid),
    .s_wdata(axi4_dcache_wdata),
    .s_wstrb(axi4_dcache_wstrb),
    .s_wlast(axi4_dcache_wlast),
    .s_bready(axi4_dcache_bready),
    .s_bvalid(axi4_dcache_bvalid),
    .s_bresp(axi4_dcache_bresp),
    .s_bid(axi4_dcache_bid),
    .s_arready(axi4_dcache_arready),
    .s_arvalid(axi4_dcache_arvalid),
    .s_araddr(axi4_dcache_araddr),
    .s_arid(axi4_dcache_arid),
    .s_arlen(axi4_dcache_arlen),
    .s_arsize(axi4_dcache_arsize),
    .s_arburst(axi4_dcache_arburst),
    .s_rready(axi4_dcache_rready),
    .s_rvalid(axi4_dcache_rvalid),
    .s_rresp(axi4_dcache_rresp),
    .s_rdata(axi4_dcache_rdata),
    .s_rlast(axi4_dcache_rlast),
    .s_rid(axi4_dcache_rid)
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
    .u_awreadys(   {axi4_icache_awready,    axi4_dcache_awready   }),
    .u_awvalids(   {axi4_icache_awvalid,    axi4_dcache_awvalid   }),
    .u_awaddrs(    {axi4_icache_awaddr,     axi4_dcache_awaddr    }),
    .u_awids(      {axi4_icache_awid,       axi4_dcache_awid      }),
    .u_awlens(     {axi4_icache_awlen,      axi4_dcache_awlen     }),
    .u_awsizes(    {axi4_icache_awsize,     axi4_dcache_awsize    }),
    .u_awbursts(   {axi4_icache_awburst,    axi4_dcache_awburst   }),
    .u_wreadys(    {axi4_icache_wready,     axi4_dcache_wready    }),
    .u_wvalids(    {axi4_icache_wvalid,     axi4_dcache_wvalid    }),
    .u_wdatas(     {axi4_icache_wdata,      axi4_dcache_wdata     }),
    .u_wstrbs(     {axi4_icache_wstrb,      axi4_dcache_wstrb     }),
    .u_wlasts(     {axi4_icache_wlast,      axi4_dcache_wlast     }),
    .u_breadys(    {axi4_icache_bready,     axi4_dcache_bready    }),
    .u_bvalids(    {axi4_icache_bvalid,     axi4_dcache_bvalid    }),
    .u_bresps(     {axi4_icache_bresp,      axi4_dcache_bresp     }),
    .u_bids(       {axi4_icache_bid,        axi4_dcache_bid       }),
    .u_arreadys(   {axi4_icache_arready,    axi4_dcache_arready   }),
    .u_arvalids(   {axi4_icache_arvalid,    axi4_dcache_arvalid   }),
    .u_araddrs(    {axi4_icache_araddr,     axi4_dcache_araddr    }),
    .u_arids(      {axi4_icache_arid,       axi4_dcache_arid      }),
    .u_arlens(     {axi4_icache_arlen,      axi4_dcache_arlen     }),
    .u_arsizes(    {axi4_icache_arsize,     axi4_dcache_arsize    }),
    .u_arbursts(   {axi4_icache_arburst,    axi4_dcache_arburst   }),
    .u_rreadys(    {axi4_icache_rready,     axi4_dcache_rready    }),
    .u_rvalids(    {axi4_icache_rvalid,     axi4_dcache_rvalid    }),
    .u_rresps(     {axi4_icache_rresp,      axi4_dcache_rresp     }),
    .u_rdatas(     {axi4_icache_rdata,      axi4_dcache_rdata     }),
    .u_rlasts(     {axi4_icache_rlast,      axi4_dcache_rlast     }),
    .u_rids(       {axi4_icache_rid,        axi4_dcache_rid       }),

    .awready(axi4_arbiter_awready),
    .awvalid(axi4_arbiter_awvalid),
    .awaddr(axi4_arbiter_awaddr),
    .awid(axi4_arbiter_awid),
    .awlen(axi4_arbiter_awlen),
    .awsize(axi4_arbiter_awsize),
    .awburst(axi4_arbiter_awburst),
    .wready(axi4_arbiter_wready),
    .wvalid(axi4_arbiter_wvalid),
    .wdata(axi4_arbiter_wdata),
    .wstrb(axi4_arbiter_wstrb),
    .wlast(axi4_arbiter_wlast),
    .bready(axi4_arbiter_bready),
    .bvalid(axi4_arbiter_bvalid),
    .bresp(axi4_arbiter_bresp),
    .bid(axi4_arbiter_bid),
    .arready(axi4_arbiter_arready),
    .arvalid(axi4_arbiter_arvalid),
    .araddr(axi4_arbiter_araddr),
    .arid(axi4_arbiter_arid),
    .arlen(axi4_arbiter_arlen),
    .arsize(axi4_arbiter_arsize),
    .arburst(axi4_arbiter_arburst),
    .rready(axi4_arbiter_rready),
    .rvalid(axi4_arbiter_rvalid),
    .rresp(axi4_arbiter_rresp),
    .rdata(axi4_arbiter_rdata),
    .rlast(axi4_arbiter_rlast),
    .rid(axi4_arbiter_rid),

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
    .awready(axi4_arbiter_awready),
    .awvalid(axi4_arbiter_awvalid),
    .awaddr(axi4_arbiter_awaddr),
    .awid(axi4_arbiter_awid),
    .awlen(axi4_arbiter_awlen),
    .awsize(axi4_arbiter_awsize),
    .awburst(axi4_arbiter_awburst),
    .wready(axi4_arbiter_wready),
    .wvalid(axi4_arbiter_wvalid),
    .wdata(axi4_arbiter_wdata),
    .wstrb(axi4_arbiter_wstrb),
    .wlast(axi4_arbiter_wlast),
    .bready(axi4_arbiter_bready),
    .bvalid(axi4_arbiter_bvalid),
    .bresp(axi4_arbiter_bresp),
    .bid(axi4_arbiter_bid),
    .arready(axi4_arbiter_arready),
    .arvalid(axi4_arbiter_arvalid),
    .araddr(axi4_arbiter_araddr),
    .arid(axi4_arbiter_arid),
    .arlen(axi4_arbiter_arlen),
    .arsize(axi4_arbiter_arsize),
    .arburst(axi4_arbiter_arburst),
    .rready(axi4_arbiter_rready),
    .rvalid(axi4_arbiter_rvalid),
    .rresp(axi4_arbiter_rresp),
    .rdata(axi4_arbiter_rdata),
    .rlast(axi4_arbiter_rlast),
    .rid(axi4_arbiter_rid),

    .u_awreadys(   {   axi4_s_awready[0],   axi4_s_awready[1],  axi4_s_awready[AXI4_SLAVE_COUNT-1]       } ),
    .u_awvalids(   {   axi4_s_awvalid[0],   axi4_s_awvalid[1],  axi4_s_awvalid[AXI4_SLAVE_COUNT-1]       } ),
    .u_awaddrs(    {   axi4_s_awaddr[0],    axi4_s_awaddr[1],   axi4_s_awaddr[AXI4_SLAVE_COUNT-1]        } ),
    .u_awids(      {   axi4_s_awid[0],      axi4_s_awid[1],     axi4_s_awid[AXI4_SLAVE_COUNT-1]          } ),
    .u_awlens(     {   axi4_s_awlen[0],     axi4_s_awlen[1],    axi4_s_awlen[AXI4_SLAVE_COUNT-1]         } ),
    .u_awsizes(    {   axi4_s_awsize[0],    axi4_s_awsize[1],   axi4_s_awsize[AXI4_SLAVE_COUNT-1]        } ),
    .u_awbursts(   {   axi4_s_awburst[0],   axi4_s_awburst[1],  axi4_s_awburst[AXI4_SLAVE_COUNT-1]       } ),
    .u_wreadys(    {   axi4_s_wready[0],    axi4_s_wready[1],   axi4_s_wready[AXI4_SLAVE_COUNT-1]        } ),
    .u_wvalids(    {   axi4_s_wvalid[0],    axi4_s_wvalid[1],   axi4_s_wvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_wdatas(     {   axi4_s_wdata[0],     axi4_s_wdata[1],    axi4_s_wdata[AXI4_SLAVE_COUNT-1]         } ),
    .u_wstrbs(     {   axi4_s_wstrb[0],     axi4_s_wstrb[1],    axi4_s_wstrb[AXI4_SLAVE_COUNT-1]         } ),
    .u_wlasts(     {   axi4_s_wlast[0],     axi4_s_wlast[1],    axi4_s_wlast[AXI4_SLAVE_COUNT-1]         } ),
    .u_breadys(    {   axi4_s_bready[0],    axi4_s_bready[1],   axi4_s_bready[AXI4_SLAVE_COUNT-1]        } ),
    .u_bvalids(    {   axi4_s_bvalid[0],    axi4_s_bvalid[1],   axi4_s_bvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_bresps(     {   axi4_s_bresp[0],     axi4_s_bresp[1],    axi4_s_bresp[AXI4_SLAVE_COUNT-1]         } ),
    .u_bids(       {   axi4_s_bid[0],       axi4_s_bid[1],      axi4_s_bid[AXI4_SLAVE_COUNT-1]           } ),
    .u_arreadys(   {   axi4_s_arready[0],   axi4_s_arready[1],  axi4_s_arready[AXI4_SLAVE_COUNT-1]       } ),
    .u_arvalids(   {   axi4_s_arvalid[0],   axi4_s_arvalid[1],  axi4_s_arvalid[AXI4_SLAVE_COUNT-1]       } ),
    .u_araddrs(    {   axi4_s_araddr[0],    axi4_s_araddr[1],   axi4_s_araddr[AXI4_SLAVE_COUNT-1]        } ),
    .u_arids(      {   axi4_s_arid[0],      axi4_s_arid[1],     axi4_s_arid[AXI4_SLAVE_COUNT-1]          } ),
    .u_arlens(     {   axi4_s_arlen[0],     axi4_s_arlen[1],    axi4_s_arlen[AXI4_SLAVE_COUNT-1]         } ),
    .u_arsizes(    {   axi4_s_arsize[0],    axi4_s_arsize[1],   axi4_s_arsize[AXI4_SLAVE_COUNT-1]        } ),
    .u_arbursts(   {   axi4_s_arburst[0],   axi4_s_arburst[1],  axi4_s_arburst[AXI4_SLAVE_COUNT-1]       } ),
    .u_rreadys(    {   axi4_s_rready[0],    axi4_s_rready[1],   axi4_s_rready[AXI4_SLAVE_COUNT-1]        } ),
    .u_rvalids(    {   axi4_s_rvalid[0],    axi4_s_rvalid[1],   axi4_s_rvalid[AXI4_SLAVE_COUNT-1]        } ),
    .u_rresps(     {   axi4_s_rresp[0],     axi4_s_rresp[1],    axi4_s_rresp[AXI4_SLAVE_COUNT-1]         } ),
    .u_rdatas(     {   axi4_s_rdata[0],     axi4_s_rdata[1],    axi4_s_rdata[AXI4_SLAVE_COUNT-1]         } ),
    .u_rlasts(     {   axi4_s_rlast[0],     axi4_s_rlast[1],    axi4_s_rlast[AXI4_SLAVE_COUNT-1]         } ),
    .u_rids(       {   axi4_s_rid[0],       axi4_s_rid[1],      axi4_s_rid[AXI4_SLAVE_COUNT-1]           } ),
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
    .awready(axi4_s_awready[0]),
    .awvalid(axi4_s_awvalid[0]),
    .awaddr(axi4_s_awaddr[0]),
    .awid(axi4_s_awid[0]),
    .awlen(axi4_s_awlen[0]),
    .awsize(axi4_s_awsize[0]),
    .awburst(axi4_s_awburst[0]),
    .wready(axi4_s_wready[0]),
    .wvalid(axi4_s_wvalid[0]),
    .wdata(axi4_s_wdata[0]),
    .wstrb(axi4_s_wstrb[0]),
    .wlast(axi4_s_wlast[0]),
    .bready(axi4_s_bready[0]),
    .bvalid(axi4_s_bvalid[0]),
    .bresp(axi4_s_bresp[0]),
    .bid(axi4_s_bid[0]),
    .arready(axi4_s_arready[0]),
    .arvalid(axi4_s_arvalid[0]),
    .araddr(axi4_s_araddr[0]),
    .arid(axi4_s_arid[0]),
    .arlen(axi4_s_arlen[0]),
    .arsize(axi4_s_arsize[0]),
    .arburst(axi4_s_arburst[0]),
    .rready(axi4_s_rready[0]),
    .rvalid(axi4_s_rvalid[0]),
    .rresp(axi4_s_rresp[0]),
    .rdata(axi4_s_rdata[0]),
    .rlast(axi4_s_rlast[0]),
    .rid(axi4_s_rid[0])
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
    .awready(axi4_s_awready[1]),
    .awvalid(axi4_s_awvalid[1]),
    .awaddr(axi4_s_awaddr[1]),
    .awid(axi4_s_awid[1]),
    .awlen(axi4_s_awlen[1]),
    .awsize(axi4_s_awsize[1]),
    .awburst(axi4_s_awburst[1]),
    .wready(axi4_s_wready[1]),
    .wvalid(axi4_s_wvalid[1]),
    .wdata(axi4_s_wdata[1]),
    .wstrb(axi4_s_wstrb[1]),
    .wlast(axi4_s_wlast[1]),
    .bready(axi4_s_bready[1]),
    .bvalid(axi4_s_bvalid[1]),
    .bresp(axi4_s_bresp[1]),
    .bid(axi4_s_bid[1]),
    .arready(axi4_s_arready[1]),
    .arvalid(axi4_s_arvalid[1]),
    .araddr(axi4_s_araddr[1]),
    .arid(axi4_s_arid[1]),
    .arlen(axi4_s_arlen[1]),
    .arsize(axi4_s_arsize[1]),
    .arburst(axi4_s_arburst[1]),
    .rready(axi4_s_rready[1]),
    .rvalid(axi4_s_rvalid[1]),
    .rresp(axi4_s_rresp[1]),
    .rdata(axi4_s_rdata[1]),
    .rlast(axi4_s_rlast[1]),
    .rid(axi4_s_rid[1])
);

/* 取指if */
inst_fetch #(
    .SRAM_TYPE(`SRAM_TYPE_AXI4),
    .INST_WIDTH(INST_WIDTH)
) ifu(
    .clk(clk),
    .rst(rst),

    .awready(axi4_if_awready),
    .awvalid(axi4_if_awvalid),
    .awaddr(axi4_if_awaddr),
    .awid(axi4_if_awid),
    .awlen(axi4_if_awlen),
    .awsize(axi4_if_awsize),
    .awburst(axi4_if_awburst),
    .wready(axi4_if_wready),
    .wvalid(axi4_if_wvalid),
    .wdata(axi4_if_wdata),
    .wstrb(axi4_if_wstrb),
    .wlast(axi4_if_wlast),
    .bready(axi4_if_bready),
    .bvalid(axi4_if_bvalid),
    .bresp(axi4_if_bresp),
    .bid(axi4_if_bid),
    .arready(axi4_if_arready),
    .arvalid(axi4_if_arvalid),
    .araddr(axi4_if_araddr),
    .arid(axi4_if_arid),
    .arlen(axi4_if_arlen),
    .arsize(axi4_if_arsize),
    .arburst(axi4_if_arburst),
    .rready(axi4_if_rready),
    .rvalid(axi4_if_rvalid),
    .rresp(axi4_if_rresp),
    .rdata(axi4_if_rdata),
    .rlast(axi4_if_rlast),
    .rid(axi4_if_rid),

    .in_ready(con_if_ready),
    .in_valid(!rst && (execute_time==0 || valid)),
    .pc(pc),

    .out_ready(con_id_ready),
    .out_valid(con_if_valid),
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

    .in_ready(con_id_ready),
    .in_valid(con_if_valid),
    .inst(inst),

    .out_ready(con_ex_ls_ready),
    .out_valid(con_id_valid),
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
assign con_ls_enable = 
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
assign con_ex_enable = !con_ls_enable;
assign con_ex_ls_ready = ({1{con_ex_enable}} & con_ex_ready) | ({1{con_ls_enable}} & con_ls_ready);

/* 执行ex */
wire [INST_WIDTH-1:0] ex_dnpc, ex_result;
wire [7:0] ex_mem_result_width;
wire ex_result_update_gpr;
execute #(
    .INST_WIDTH(INST_WIDTH)
) exu(
    .clk(clk),
    .rst(rst),

    .in_ready(con_ex_ready),
    .in_valid(con_id_valid && con_ex_enable),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .src1(src1),
    .src2(src2),
    .a0(a0),

    .out_ready(con_wb_ready),
    .out_valid(con_ex_valid),
    .dnpc(ex_dnpc),
    .result(ex_result),
    .mem_result_width(ex_mem_result_width),
    .result_update_gpr(ex_result_update_gpr)
);

/* 读存储ls */
wire [INST_WIDTH-1:0] ls_dnpc, ls_result;
wire [7:0] ls_mem_result_width;
wire ls_result_update_gpr;
load_store #(
    .INST_WIDTH(INST_WIDTH)
) lsu(
    .clk(clk),
    .rst(rst),

    .awready(axi4_ls_awready),
    .awvalid(axi4_ls_awvalid),
    .awaddr(axi4_ls_awaddr),
    .awid(axi4_ls_awid),
    .awlen(axi4_ls_awlen),
    .awsize(axi4_ls_awsize),
    .awburst(axi4_ls_awburst),
    .wready(axi4_ls_wready),
    .wvalid(axi4_ls_wvalid),
    .wdata(axi4_ls_wdata),
    .wstrb(axi4_ls_wstrb),
    .wlast(axi4_ls_wlast),
    .bready(axi4_ls_bready),
    .bvalid(axi4_ls_bvalid),
    .bresp(axi4_ls_bresp),
    .bid(axi4_ls_bid),
    .arready(axi4_ls_arready),
    .arvalid(axi4_ls_arvalid),
    .araddr(axi4_ls_araddr),
    .arid(axi4_ls_arid),
    .arlen(axi4_ls_arlen),
    .arsize(axi4_ls_arsize),
    .arburst(axi4_ls_arburst),
    .rready(axi4_ls_rready),
    .rvalid(axi4_ls_rvalid),
    .rresp(axi4_ls_rresp),
    .rdata(axi4_ls_rdata),
    .rlast(axi4_ls_rlast),
    .rid(axi4_ls_rid),

    .in_ready(con_ls_ready),
    .in_valid(con_id_valid && con_ls_enable),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .src1(src1),
    .src2(src2),

    .out_ready(con_wb_ready),
    .out_valid(con_ls_valid),
    .dnpc(ls_dnpc),
    .result(ls_result),
    .mem_result_width(ls_mem_result_width),
    .result_update_gpr(ls_result_update_gpr)
);

/* 回写wb */
wire [INST_WIDTH-1:0] dnpc, result;
wire [7:0] mem_result_width;
wire result_update_gpr;
assign dnpc = ({INST_WIDTH{con_ex_enable}} & ex_dnpc) | ({INST_WIDTH{con_ls_enable}} & ls_dnpc);
assign result = ({INST_WIDTH{con_ex_enable}} & ex_result) | ({INST_WIDTH{con_ls_enable}} & ls_result);
assign mem_result_width = ({8{con_ex_enable}} & ex_mem_result_width) | ({8{con_ls_enable}} & ls_mem_result_width);
assign result_update_gpr = ({1{con_ex_enable}} & ex_result_update_gpr) | ({1{con_ls_enable}} & ls_result_update_gpr);
assign con_ex_ls_valid = ({1{con_ex_enable}} & con_ex_valid) | ({1{con_ls_enable}} & con_ls_valid);
write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .gpr_wen(wb_gpr_wen),
    .gpr_windex(wb_gpr_windex),
    .gpr_wdata(wb_gpr_wdata),

    .in_ready(con_wb_ready),
    .in_valid(con_ex_ls_valid),
    .rd(rd),
    .imm(imm),
    .inst_code(inst_code),
    .result(result),
    .mem_result_width(mem_result_width),
    .result_update_gpr(result_update_gpr),
    .dnpc(dnpc),
    .src1(src1),
    .src2(src2),

    .out_ready(),
    .out_valid(con_wb_valid),
    .w_pc(pc)
);

endmodule
