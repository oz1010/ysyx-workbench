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
`ifdef FORMAL_VERIFY
    /* 形式化验证：WBU完成指令的信息输出 */
    , output wire [INST_WIDTH-1:0] fv_wb_pc
    , output wire [INST_WIDTH-1:0] fv_wb_dnpc
    , output wire [INST_WIDTH-1:0] fv_wb_inst
    , output wire [4:0]          fv_wb_rd
    , output wire [DATA_WIDTH-1:0] fv_wb_result
    , output wire                fv_wb_result_update_gpr
    , output wire [DATA_WIDTH-1:0] fv_wb_ld_data
`endif
);

/* 模块信号输出宽度 */
localparam IF_IN_DATA_W = 0;
localparam IF_OUT_DATA_W = (ADDR_WIDTH + INST_WIDTH + `STAGE_COUNT + DATA_WIDTH*2);
localparam ID_IN_DATA_W = IF_OUT_DATA_W;
localparam ID_OUT_DATA_W = (INST_WIDTH*3 + 5 + 5 + 5 + `INST_CODE_W + `STAGE_COUNT + DATA_WIDTH*2);
localparam EX_IN_DATA_W = ID_OUT_DATA_W + DATA_WIDTH*3;
localparam EX_OUT_DATA_W = (5 + `INST_CODE_W + INST_WIDTH*7 + 1 + `STAGE_COUNT + DATA_WIDTH*2 + 5*2 + `CSR_WCH_W);
localparam LS_IN_DATA_W = EX_OUT_DATA_W;
`ifdef FORMAL_VERIFY
/* 形式化验证时LSU额外透传inst与load原始数据 */
localparam LS_OUT_DATA_W = (INST_WIDTH*4 + 5 + 1 + `INST_CODE_W + `STAGE_COUNT + DATA_WIDTH*3 + 5*2 + `CSR_WCH_W);
`else
localparam LS_OUT_DATA_W = (INST_WIDTH*3 + 5 + 1 + `INST_CODE_W + `STAGE_COUNT + DATA_WIDTH*2 + 5*2 + `CSR_WCH_W);
`endif
localparam WB_IN_DATA_W = LS_OUT_DATA_W;
`ifdef FORMAL_VERIFY
/* 形式化验证时WBU额外输出inst、写回结果及load原始数据 */
localparam WB_OUT_DATA_W = INST_WIDTH*3 + 5 + 1 + DATA_WIDTH*2;
`else
localparam WB_OUT_DATA_W = INST_WIDTH*2 + 5;
`endif

/* 模块之间的连接信号或数据 */
wire                        con_core_ready;
wire                        con_core_valid;
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
/* 模块直接输出的信号 */
wire                        mod_con_if_ready;
wire                        mod_con_if_valid;
wire                        mod_con_id_ready;
wire                        mod_con_id_valid;
wire                        mod_con_ex_ready;
wire                        mod_con_ex_valid;
wire                        mod_con_ls_ready;
wire                        mod_con_ls_valid;
wire                        mod_con_wb_ready;
wire                        mod_con_wb_valid;
/* 监控各阶段握手信号 */
wire                        monitor_if_in_done;
wire                        monitor_if_out_done;
wire                        monitor_id_in_done;
wire                        monitor_id_out_done;
wire                        monitor_ex_in_done;
wire                        monitor_ex_out_done;
wire                        monitor_ls_in_done;
wire                        monitor_ls_out_done;
wire                        monitor_wb_in_done;
wire                        monitor_wb_out_done;
/* 将模块信号和控制信号关联后输出，默认直接输出 */
assign con_core_ready = !rst;
assign con_core_valid = !rst & !core_stage_flush[`STAGE_INDEX_IFU];
assign con_if_ready = mod_con_if_ready;
assign con_if_valid = mod_con_if_valid & !core_stage_flush[`STAGE_INDEX_IDU] & !core_raw_wait;
assign con_id_ready = mod_con_id_ready & !core_raw_wait;
assign con_id_valid = mod_con_id_valid & !core_stage_flush[`STAGE_INDEX_EXU] & !core_raw_wait;
assign con_ex_ready = mod_con_ex_ready & !core_raw_wait;
assign con_ex_valid = mod_con_ex_valid & !core_stage_flush[`STAGE_INDEX_LSU];
assign con_ls_ready = mod_con_ls_ready;
assign con_ls_valid = mod_con_ls_valid & !core_stage_flush[`STAGE_INDEX_WBU];
assign con_wb_ready = mod_con_wb_ready;
assign con_wb_valid = mod_con_wb_valid;

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
`ifndef FORMAL_VERIFY
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
`else
/* 形式化验证：DUT只包含流水线本身，仲裁器输出直连io_master，不含缓存和各种外设 */
assign axi4_arbiter_awready = io_master_awready;
assign io_master_awvalid    = axi4_arbiter_awvalid;
assign io_master_awaddr     = axi4_arbiter_awaddr;
assign io_master_awid       = axi4_arbiter_awid;
assign io_master_awlen      = axi4_arbiter_awlen;
assign io_master_awsize     = axi4_arbiter_awsize;
assign io_master_awburst    = axi4_arbiter_awburst;
assign axi4_arbiter_wready  = io_master_wready;
assign io_master_wvalid     = axi4_arbiter_wvalid;
assign io_master_wdata      = axi4_arbiter_wdata;
assign io_master_wstrb      = axi4_arbiter_wstrb;
assign io_master_wlast      = axi4_arbiter_wlast;
assign io_master_bready     = axi4_arbiter_bready;
assign axi4_arbiter_bvalid  = io_master_bvalid;
assign axi4_arbiter_bresp   = io_master_bresp;
assign axi4_arbiter_bid     = io_master_bid;
assign axi4_arbiter_arready = io_master_arready;
assign io_master_arvalid    = axi4_arbiter_arvalid;
assign io_master_araddr     = axi4_arbiter_araddr;
assign io_master_arid       = axi4_arbiter_arid;
assign io_master_arlen      = axi4_arbiter_arlen;
assign io_master_arsize     = axi4_arbiter_arsize;
assign io_master_arburst    = axi4_arbiter_arburst;
assign io_master_rready     = axi4_arbiter_rready;
assign axi4_arbiter_rvalid  = io_master_rvalid;
assign axi4_arbiter_rresp   = io_master_rresp;
assign axi4_arbiter_rdata   = io_master_rdata;
assign axi4_arbiter_rlast   = io_master_rlast;
assign axi4_arbiter_rid     = io_master_rid;
`endif

/* 常用处理器信号 */
wire [INST_WIDTH-1:0] inst;
reg [63:0] execute_time;
wire [INST_WIDTH-1:0] src1, src2, a0;

assign valid = con_wb_valid;

/* 当前正在处理的pc指示 */
reg [INST_WIDTH-1:0] core_pc;
reg [INST_WIDTH-1:0] core_dnpc;
assign pc = core_pc;
always @(posedge clk) begin
    if (rst) begin
        core_pc <= func_get_reset_pc();
        core_dnpc <= core_pc;
    end else begin
        core_pc <= con_wb_valid ? con_wb_dnpc :
            core_pc;
        
        core_dnpc <= con_ls_valid ? con_ls_dnpc :
            core_dnpc;
    end
end

/* 核心执行tick计数 */
always @(posedge clk) begin
    if (rst) begin
        execute_time <= 0;
        func_cpu_stat_ctrl(`HW_CPU_STAT_TICK, 0);
    end else begin
        execute_time <= execute_time + 1;
        func_cpu_stat_ctrl(`HW_CPU_STAT_TICK, 1);
    end
end

/* gpr寄存器组 */
wire [DATA_WIDTH-1:0] gpr_src1;
wire [DATA_WIDTH-1:0] gpr_src2;
wire [DATA_WIDTH-1:0] gpr_a0;
gprs #(
    .DATA_WIDTH(DATA_WIDTH),
    .REG_COUNT(`RISCV_GPR_COUNT)
) m_gprs (
    .clk(clk),
    .rst(rst),
    .rs1(con_id_rs1),
    .src1(gpr_src1),
    .rs2(con_id_rs2),
    .src2(gpr_src2),
    .a0(gpr_a0),
    .wen(wb_gpr_wen),
    .windex(wb_gpr_windex),
    .wdata(wb_gpr_wdata)
);

/* csr寄存器组 */
wire [`INST_CODE_W-1:0] csr_inst_code = con_id_inst_code;
wire csr_raddr_en = 
    (csr_inst_code==`INST_CSRRW) |
    (csr_inst_code==`INST_CSRRS) |
    (csr_inst_code==`INST_CSRRC) |
    (csr_inst_code==`INST_CSRRWI) |
    (csr_inst_code==`INST_CSRRSI) |
    (csr_inst_code==`INST_CSRRCI) |
    0;
wire [`CSR_ADDR_W-1:0] csr_raddr = 
    csr_raddr_en ? con_id_imm[0 +: `CSR_ADDR_W] :
    (csr_inst_code==`INST_ECALL) ? `CSR_MTVEC :
    (csr_inst_code==`INST_MRET) ? `CSR_MEPC :
    0;
wire [DATA_WIDTH-1:0] csr_rdata;
csrs #(
    .DATA_WIDTH(DATA_WIDTH)
) m_csrs (
    .clk(clk),
    .rst(rst),
    .raddr(csr_raddr),
    .rdata(csr_rdata),
    .csr_wch(wb_csr_wch),
    .cscode()
);

/* 性能监控 */
/* cache命中状态（2bit：NONE/HIT/MISS）传递：icache/dcache → IFU/LSU → perf monitor */
wire [1:0] icache_stat;
wire [1:0] dcache_stat;
wire [1:0] if_cache_stat;
wire [1:0] ls_cache_stat;
wire ls_mem_access;
wire [31:0] ls_mem_addr;
perf_monitor m_perf_monitor (
    .clk(clk),
    .rst(rst),
    .if_in_done(monitor_if_in_done),
    .if_out_done(monitor_if_out_done),
    .id_in_done(monitor_id_in_done),
    .id_out_done(monitor_id_out_done),
    .ex_in_done(monitor_ex_in_done),
    .ex_out_done(monitor_ex_out_done),
    .ls_in_done(monitor_ls_in_done),
    .ls_out_done(monitor_ls_out_done),
    .wb_in_done(monitor_wb_in_done),
    .wb_out_done(monitor_wb_out_done),
    .in_if_pc(core_fetch_pc),
    .in_id_pc(con_if_pc),
    .in_ex_pc(con_id_pc),
    .in_ls_pc(con_ex_pc),
    .in_wb_pc(con_ls_pc),
    .inst_code(con_id_inst_code),
    .dnpc(con_wb_dnpc),
    .wb_gpr_wen(wb_gpr_wen),
    .wb_gpr_windex(wb_gpr_windex),
    .wb_gpr_wdata(wb_gpr_wdata),
    .wb_csr_wch(wb_csr_wch),
    .if_cache_stat(if_cache_stat),
    .ls_cache_stat(ls_cache_stat),
    .ls_mem_access(ls_mem_access),
    .ls_mem_addr(ls_mem_addr),
    .done()
);

/* 指令缓存 */
`ifndef FORMAL_VERIFY
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
    .s_rid(axi4_icache_rid),
    .cache_stat(icache_stat)
);
`else
/* 形式化验证：IFU直连仲裁器（axi4_if_*桥接axi4_icache_*），不含指令缓存 */
assign icache_stat = `CACHE_STAT_NONE;
assign axi4_if_awready        = axi4_icache_awready;
assign axi4_icache_awvalid    = axi4_if_awvalid;
assign axi4_icache_awaddr     = axi4_if_awaddr;
assign axi4_icache_awid       = axi4_if_awid;
assign axi4_icache_awlen      = axi4_if_awlen;
assign axi4_icache_awsize     = axi4_if_awsize;
assign axi4_icache_awburst    = axi4_if_awburst;
assign axi4_if_wready         = axi4_icache_wready;
assign axi4_icache_wvalid     = axi4_if_wvalid;
assign axi4_icache_wdata      = axi4_if_wdata;
assign axi4_icache_wstrb      = axi4_if_wstrb;
assign axi4_icache_wlast      = axi4_if_wlast;
assign axi4_icache_bready     = axi4_if_bready;
assign axi4_if_bvalid         = axi4_icache_bvalid;
assign axi4_if_bresp          = axi4_icache_bresp;
assign axi4_if_bid            = axi4_icache_bid;
assign axi4_if_arready        = axi4_icache_arready;
assign axi4_icache_arvalid    = axi4_if_arvalid;
assign axi4_icache_araddr     = axi4_if_araddr;
assign axi4_icache_arid       = axi4_if_arid;
assign axi4_icache_arlen      = axi4_if_arlen;
assign axi4_icache_arsize     = axi4_if_arsize;
assign axi4_icache_arburst    = axi4_if_arburst;
assign axi4_icache_rready     = axi4_if_rready;
assign axi4_if_rvalid         = axi4_icache_rvalid;
assign axi4_if_rresp          = axi4_icache_rresp;
assign axi4_if_rdata          = axi4_icache_rdata;
assign axi4_if_rlast          = axi4_icache_rlast;
assign axi4_if_rid            = axi4_icache_rid;
`endif

/* 数据缓存 */
`ifndef FORMAL_VERIFY
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
    .s_rid(axi4_dcache_rid),
    .cache_stat(dcache_stat)
);
`else
/* 形式化验证：LSU直连仲裁器（axi4_ls_*桥接axi4_dcache_*），不含数据缓存 */
assign dcache_stat = `CACHE_STAT_NONE;
assign axi4_ls_awready        = axi4_dcache_awready;
assign axi4_dcache_awvalid    = axi4_ls_awvalid;
assign axi4_dcache_awaddr     = axi4_ls_awaddr;
assign axi4_dcache_awid       = axi4_ls_awid;
assign axi4_dcache_awlen      = axi4_ls_awlen;
assign axi4_dcache_awsize     = axi4_ls_awsize;
assign axi4_dcache_awburst    = axi4_ls_awburst;
assign axi4_ls_wready         = axi4_dcache_wready;
assign axi4_dcache_wvalid     = axi4_ls_wvalid;
assign axi4_dcache_wdata      = axi4_ls_wdata;
assign axi4_dcache_wstrb      = axi4_ls_wstrb;
assign axi4_dcache_wlast      = axi4_ls_wlast;
assign axi4_dcache_bready     = axi4_ls_bready;
assign axi4_ls_bvalid         = axi4_dcache_bvalid;
assign axi4_ls_bresp          = axi4_dcache_bresp;
assign axi4_ls_bid            = axi4_dcache_bid;
assign axi4_ls_arready        = axi4_dcache_arready;
assign axi4_dcache_arvalid    = axi4_ls_arvalid;
assign axi4_dcache_araddr     = axi4_ls_araddr;
assign axi4_dcache_arid       = axi4_ls_arid;
assign axi4_dcache_arlen      = axi4_ls_arlen;
assign axi4_dcache_arsize     = axi4_ls_arsize;
assign axi4_dcache_arburst    = axi4_ls_arburst;
assign axi4_dcache_rready     = axi4_ls_rready;
assign axi4_ls_rvalid         = axi4_dcache_rvalid;
assign axi4_ls_rresp          = axi4_dcache_rresp;
assign axi4_ls_rdata          = axi4_dcache_rdata;
assign axi4_ls_rlast          = axi4_dcache_rlast;
assign axi4_ls_rid            = axi4_dcache_rid;
`endif

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
`ifndef FORMAL_VERIFY
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
`endif

/* 流水线控制信号 */
wire                            core_idle = con_if_ready & con_id_ready & con_ex_ready & con_ls_ready & con_wb_ready;
wire [INST_WIDTH-1:0]           core_fetch_pc;
wire                            core_raw_wait;
wire [`FLUSH_TYPE_W-1:0]        core_flush_type;
wire [`STAGE_COUNT-1:0]         core_stage_flush;
wire                            core_flush_done = |core_flush_type & core_idle; // flush后需要清理各阶段寄存器（除了wbu.dnpc）
/* RAW冒险 */
risk_raw #(
    .INST_WIDTH(INST_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) m_risk_raw (
    .clk(clk),
    .rst(rst),
    .flush_en(|core_stage_flush),
    .stage_ready({mod_con_wb_ready, mod_con_ls_ready, mod_con_ex_ready, mod_con_id_ready, mod_con_if_ready}),
    .stage_valid({mod_con_wb_valid, mod_con_ls_valid, mod_con_ex_valid, mod_con_id_valid, mod_con_if_valid}),
    .id_imm_pc(con_if_pc),
    .id_imm_inst_code(id_imm_inst_code),
    .id_imm_rd(id_imm_rd),
    .id_imm_rs1(id_imm_rs1),
    .id_imm_rs2(id_imm_rs2),
    .ex_rd(con_ex_rd),
    .ls_rd(con_ls_rd),
    .stage_pc({con_id_pc, con_ex_pc, con_ls_pc}),
    .stage_rd({con_id_rd, con_ex_rd, con_ls_rd}),
    .wb_pc(con_wb_pc),
    .wb_rd(con_wb_rd),
    .raw_wait(core_raw_wait)
);
/* 控制冒险 */
risk_control #(
    .INST_WIDTH(INST_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) m_risk_control (
    .clk(clk),
    .rst(rst),
    .stage_valid({mod_con_wb_valid, mod_con_ls_valid, mod_con_ex_valid, mod_con_id_valid, mod_con_if_valid}),
    .stage_exception(0),
    .fetch_pc(core_fetch_pc),
    .id_pc(con_id_pc),
    .ex_dnpc(con_ex_dnpc),
    .inst_code(con_id_inst_code),
    .core_idle(core_idle),
    .flush_type(core_flush_type),
    .stage_flush(core_stage_flush)
);

/* 静态指令预测器 */
static_predictor #(
    .INST_WIDTH(INST_WIDTH),
    .DATA_WIDTH(DATA_WIDTH)
) m_static_predictor (
    .clk(clk),
    .rst(rst),
    .fetch_en(mod_con_if_valid&mod_con_id_ready),
    .flush_type(core_flush_type),
    .core_pc(core_pc),
    .dnpc(con_wb_dnpc),
    .fetch_pc(core_fetch_pc)
);

/* 取指if */
wire [IF_OUT_DATA_W-1:0]        mod_con_if_bits;
wire [IF_OUT_DATA_W-1:0]        con_if_bits;
wire [ADDR_WIDTH-1:0]           con_if_pc;
wire [INST_WIDTH-1:0]           con_if_inst;
wire [`STAGE_COUNT-1:0]         con_if_expt;
wire [DATA_WIDTH-1:0]           con_if_expt_cause;
wire [DATA_WIDTH-1:0]           con_if_expt_data;
assign {
    con_if_pc, 
    con_if_inst,
    con_if_expt,
    con_if_expt_cause,
    con_if_expt_data
} = con_if_bits;
inst_fetch #(
    .SRAM_TYPE(`SRAM_TYPE_AXI4),
    .INST_WIDTH(INST_WIDTH),
    .IN_DATA_W(IF_IN_DATA_W),
    .OUT_DATA_W(IF_OUT_DATA_W)
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

    .fetch_pc(core_fetch_pc),
    .cache_stat(icache_stat),

    .in_ready(mod_con_if_ready),
    .in_valid(con_core_valid),

    .out_ready(con_id_ready),
    .out_valid(mod_con_if_valid),
    .out_bits(mod_con_if_bits),
    .out_cache_stat(if_cache_stat)
);
assign monitor_if_in_done = mod_con_if_ready & con_core_valid;
assign monitor_if_out_done = con_id_ready & mod_con_if_valid;
stage_regs#(
    .DATA_STORAGE(1),
    .DATA_W(IF_OUT_DATA_W)
) ifu_regs (
    .clk(clk),
    .rst(rst | core_flush_done),
    .ready(con_id_ready),
    .valid(mod_con_if_valid),
    .bits(mod_con_if_bits),
    .stage_bits(con_if_bits)
);

/* 译码id */
wire [4:0]                      id_imm_rd;
wire [4:0]                      id_imm_rs1;
wire [4:0]                      id_imm_rs2;
wire [`INST_CODE_W-1:0]         id_imm_inst_code;
wire [ID_OUT_DATA_W-1:0]        mod_con_id_bits;
wire [ID_OUT_DATA_W-1:0]        con_id_bits;
wire [ADDR_WIDTH-1:0]           con_id_pc;
wire [INST_WIDTH-1:0]           con_id_inst;
wire [4:0]                      con_id_rd;
wire [4:0]                      con_id_rs1;
wire [4:0]                      con_id_rs2;
wire [INST_WIDTH-1:0]           con_id_imm;
wire [`INST_CODE_W-1:0]         con_id_inst_code;
wire [`STAGE_COUNT-1:0]         con_id_expt;
wire [DATA_WIDTH-1:0]           con_id_expt_cause;
wire [DATA_WIDTH-1:0]           con_id_expt_data;
assign {
    con_id_pc, con_id_inst, con_id_rd, con_id_rs1, con_id_rs2, con_id_imm, con_id_inst_code,
    con_id_expt, con_id_expt_cause, con_id_expt_data
} = con_id_bits;
inst_decode #(
    .INST_WIDTH(INST_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .IN_DATA_W(ID_IN_DATA_W),
    .OUT_DATA_W(ID_OUT_DATA_W)
) idu(
    .clk(clk),
    .rst(rst),

    .imm_rd(id_imm_rd),
    .imm_rs1(id_imm_rs1),
    .imm_rs2(id_imm_rs2),
    .imm_inst_code(id_imm_inst_code),

    .in_ready(mod_con_id_ready),
    .in_valid(con_if_valid),
    .in_bits(con_if_bits),

    .out_ready(con_ex_ready),
    .out_valid(mod_con_id_valid),
    .out_bits(mod_con_id_bits)
);
assign monitor_id_in_done = mod_con_id_ready & con_if_valid;
assign monitor_id_out_done = con_ex_ready & mod_con_id_valid;
stage_regs#(
    .DATA_STORAGE(1),
    .DATA_W(ID_OUT_DATA_W)
) idu_regs (
    .clk(clk),
    .rst(rst | core_flush_done),
    .ready(con_ex_ready),
    .valid(mod_con_id_valid),
    .bits(mod_con_id_bits),
    .stage_bits(con_id_bits)
);
// idu需要存储gpr寄存器的值
wire [DATA_WIDTH*3-1:0] con_id_gpr_bits;
wire [DATA_WIDTH-1:0] con_id_gpr_src1;
wire [DATA_WIDTH-1:0] con_id_gpr_src2;
wire [DATA_WIDTH-1:0] con_id_gpr_a0;
assign {
    con_id_gpr_src1,
    con_id_gpr_src2,
    con_id_gpr_a0
} = con_id_gpr_bits;
stage_regs#(
    .DATA_STORAGE(1),
    .DATA_W(DATA_WIDTH*3)
) idu_gpr_regs (
    .clk(clk),
    .rst(rst | core_flush_done),
    .ready(con_ex_ready),
    .valid(mod_con_id_valid),
    .bits({
        gpr_src1,
        gpr_src2,
        gpr_a0
    }),
    .stage_bits(con_id_gpr_bits)
);

wire fence_enable = (con_id_inst_code == `INST_FENCE) || (con_id_inst_code == `INST_FENCE_I);
reg last_fence_enable;
always @(posedge clk ) last_fence_enable <= fence_enable;
wire fence_enable_trigger = fence_enable & !last_fence_enable;

/* 执行ex */
wire [EX_OUT_DATA_W-1:0]        mod_con_ex_bits;
wire [EX_OUT_DATA_W-1:0]        con_ex_bits;
wire [ADDR_WIDTH-1:0]           con_ex_pc;
wire [ADDR_WIDTH-1:0]           con_ex_dnpc;
wire [INST_WIDTH-1:0]           con_ex_inst;
wire [4:0]                      con_ex_rd;
wire [4:0]                      con_ex_rs1;
wire [4:0]                      con_ex_rs2;
wire [INST_WIDTH-1:0]           con_ex_imm;
wire [`INST_CODE_W-1:0]         con_ex_inst_code;
wire [INST_WIDTH-1:0]           con_ex_src1;
wire [INST_WIDTH-1:0]           con_ex_src2;
wire [INST_WIDTH-1:0]           con_ex_a0;
wire [INST_WIDTH-1:0]           con_ex_result;
wire                            con_ex_result_update_gpr;
wire [`CSR_WCH_W-1:0]           con_ex_csr_wch;
wire [`STAGE_COUNT-1:0]         con_ex_expt;
wire [DATA_WIDTH-1:0]           con_ex_expt_cause;
wire [DATA_WIDTH-1:0]           con_ex_expt_data;
assign {
    con_ex_pc,
    con_ex_dnpc,
    con_ex_inst,
    con_ex_rd,
    con_ex_rs1,
    con_ex_rs2,
    con_ex_imm,
    con_ex_inst_code,
    con_ex_src1,
    con_ex_src2,
    con_ex_result,
    con_ex_result_update_gpr,
    con_ex_csr_wch,
    con_ex_expt,
    con_ex_expt_cause,
    con_ex_expt_data
} = con_ex_bits;
execute #(
    .INST_WIDTH(INST_WIDTH),
    .IN_DATA_W(EX_IN_DATA_W),
    .OUT_DATA_W(EX_OUT_DATA_W)
) exu(
    .clk(clk),
    .rst(rst),

    .csr_rdata(csr_rdata),

    .in_ready(mod_con_ex_ready),
    .in_valid(con_id_valid),
    .in_bits({
        con_id_bits,
        con_id_gpr_src1, 
        con_id_gpr_src2, 
        con_id_gpr_a0
    }),

    .out_ready(con_ls_ready),
    .out_valid(mod_con_ex_valid),
    .out_bits(mod_con_ex_bits)
);
assign monitor_ex_in_done = mod_con_ex_ready & con_id_valid;
assign monitor_ex_out_done = con_ls_ready & mod_con_ex_valid;
stage_regs#(
    .DATA_STORAGE(1),
    .DATA_W(EX_OUT_DATA_W)
) exu_regs (
    .clk(clk),
    .rst(rst | core_flush_done),
    .ready(con_ls_ready),
    .valid(mod_con_ex_valid),
    .bits(mod_con_ex_bits),
    .stage_bits(con_ex_bits)
);

/* 读存储ls */
wire [LS_OUT_DATA_W-1:0]        mod_con_ls_bits;
wire [LS_OUT_DATA_W-1:0]        con_ls_bits;
wire [ADDR_WIDTH-1:0]           con_ls_pc;
wire [ADDR_WIDTH-1:0]           con_ls_dnpc;
wire [4:0]                      con_ls_rd;
wire [4:0]                      con_ls_rs1;
wire [4:0]                      con_ls_rs2;
wire [`INST_CODE_W-1:0]         con_ls_inst_code;
wire [INST_WIDTH-1:0]           con_ls_result;
wire                            con_ls_result_update_gpr;
wire [`CSR_WCH_W-1:0]           con_ls_csr_wch;
wire [`STAGE_COUNT-1:0]         con_ls_expt;
wire [DATA_WIDTH-1:0]           con_ls_expt_cause;
wire [DATA_WIDTH-1:0]           con_ls_expt_data;
`ifdef FORMAL_VERIFY
wire [INST_WIDTH-1:0]           con_ls_inst;
wire [DATA_WIDTH-1:0]           con_ls_ld_data;
assign {
    con_ls_pc,
    con_ls_dnpc,
    con_ls_inst,
    con_ls_rd,
    con_ls_rs1,
    con_ls_rs2,
    con_ls_inst_code,
    con_ls_result,
    con_ls_result_update_gpr,
    con_ls_csr_wch,
    con_ls_expt,
    con_ls_expt_cause,
    con_ls_expt_data,
    con_ls_ld_data
} = con_ls_bits;
`else
assign {
    con_ls_pc,
    con_ls_dnpc,
    con_ls_rd,
    con_ls_rs1,
    con_ls_rs2,
    con_ls_inst_code,
    con_ls_result,
    con_ls_result_update_gpr,
    con_ls_csr_wch,
    con_ls_expt,
    con_ls_expt_cause,
    con_ls_expt_data
} = con_ls_bits;
`endif
load_store #(
    .INST_WIDTH(INST_WIDTH),
    .IN_DATA_W(LS_IN_DATA_W),
    .OUT_DATA_W(LS_OUT_DATA_W)
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

    .in_ready(mod_con_ls_ready),
    .in_valid(con_ex_valid),
    .in_bits(con_ex_bits),

    .out_ready(con_wb_ready),
    .out_valid(mod_con_ls_valid),
    .out_bits(mod_con_ls_bits),
    .cache_stat(dcache_stat),
    .out_cache_stat(ls_cache_stat),
    .out_mem_access(ls_mem_access),
    .out_mem_addr(ls_mem_addr)
);
assign monitor_ls_in_done = mod_con_ls_ready & con_ex_valid;
assign monitor_ls_out_done = con_wb_ready & mod_con_ls_valid;
stage_regs#(
    .DATA_STORAGE(1),
    .DATA_W(LS_OUT_DATA_W)
) lsu_regs (
    .clk(clk),
    .rst(rst | core_flush_done),
    .ready(con_wb_ready),
    .valid(mod_con_ls_valid),
    .bits(mod_con_ls_bits),
    .stage_bits(con_ls_bits)
);

/* 回写wb */
wire                            wb_gpr_wen;
wire [4:0]                      wb_gpr_windex;
wire [DATA_WIDTH-1:0]           wb_gpr_wdata;
wire [`CSR_WCH_W-1:0]           wb_csr_wch;
wire [WB_OUT_DATA_W-1:0]        mod_con_wb_bits;
wire [WB_OUT_DATA_W-1:0]        con_wb_bits;
wire [ADDR_WIDTH-1:0]           con_wb_pc;
wire [ADDR_WIDTH-1:0]           con_wb_dnpc;
wire [4:0]                      con_wb_rd;
`ifdef FORMAL_VERIFY
wire [INST_WIDTH-1:0]           con_wb_inst;
wire [DATA_WIDTH-1:0]           con_wb_result;
wire                            con_wb_result_update_gpr;
wire [DATA_WIDTH-1:0]           con_wb_ld_data;
assign {
    con_wb_pc,
    con_wb_dnpc,
    con_wb_rd,
    con_wb_inst,
    con_wb_result,
    con_wb_result_update_gpr,
    con_wb_ld_data
} = con_wb_bits;

assign fv_wb_pc                 = con_wb_pc;
assign fv_wb_dnpc               = con_wb_dnpc;
assign fv_wb_inst               = con_wb_inst;
assign fv_wb_rd                 = con_wb_rd;
assign fv_wb_result             = con_wb_result;
assign fv_wb_result_update_gpr  = con_wb_result_update_gpr;
assign fv_wb_ld_data            = con_wb_ld_data;
`else
assign {
    con_wb_pc,
    con_wb_dnpc,
    con_wb_rd
} = con_wb_bits;
`endif
write_back #(
    .INST_WIDTH(INST_WIDTH),
    .IN_DATA_W(WB_IN_DATA_W),
    .OUT_DATA_W(WB_OUT_DATA_W)
) wbu(
    .clk(clk),
    .rst(rst),

    .gpr_wen(wb_gpr_wen),
    .gpr_windex(wb_gpr_windex),
    .gpr_wdata(wb_gpr_wdata),
    .out_csr_wch(wb_csr_wch),

    .in_ready(mod_con_wb_ready),
    .in_valid(con_ls_valid),
    .in_bits(con_ls_bits),

    .out_ready(con_core_ready),
    .out_valid(mod_con_wb_valid),
    .out_bits(mod_con_wb_bits)
);
assign monitor_wb_in_done = mod_con_wb_ready & con_ls_valid;
assign monitor_wb_out_done = con_core_ready & mod_con_wb_valid;
stage_regs#(
    .DATA_STORAGE(1),
    .DATA_W(WB_OUT_DATA_W)
) wbu_regs (
    .clk(clk),
    .rst(rst),
    .ready(con_core_ready),
    .valid(mod_con_wb_valid),
    .bits(mod_con_wb_bits),
    .stage_bits(con_wb_bits)
);

endmodule
