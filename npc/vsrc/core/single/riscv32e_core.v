`ifdef FORMAL_VERIFY
/*
 * 形式化验证使用的单周期处理器核(REF)。
 * 指令语义与仿真版riscv32e_core一致，区别仅在于：
 *   - 不通过DPI取指，指令由外部提供（DUT的WBU完成指令后同步输入）
 *   - load数据由外部提供（与DUT在总线上读到的数据相同）
 *   - i_valid有效时执行一条指令
 */
module riscv32e_core_sc #(
    parameter INST_WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst,

    input  wire                  i_valid,
    input  wire [INST_WIDTH-1:0] i_inst,
    input  wire [INST_WIDTH-1:0] i_ld_data,

    output wire [INST_WIDTH-1:0] o_pc,
    output wire [INST_WIDTH-1:0] o_dnpc,
    output wire [`RISCV_GPR_ADDR_W-1:0]            o_rd,
    output wire [INST_WIDTH-1:0] o_res,
    output wire                  o_wen
);

/* 当前正在处理的pc指示：每执行完一条指令更新为dnpc */
reg [INST_WIDTH-1:0] core_pc;
assign o_pc = core_pc;
always @(posedge clk) begin
    if (rst) begin
        core_pc <= func_get_reset_pc();
    end else if (i_valid) begin
        core_pc <= o_dnpc;
    end
end

/* 译码 */
wire [6:0] opcode;
wire [`RISCV_GPR_ADDR_W-1:0] rd;
wire [2:0] funct3;
wire [`RISCV_GPR_ADDR_W-1:0] rs1;
wire [`RISCV_GPR_ADDR_W-1:0] rs2;
wire [6:0] funct7;
wire [31:0] imm;
wire [2:0] inst_type;
wire [`INST_CODE_W-1:0] inst_code;
decoder risc32e_decoder(i_inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

assign o_rd = rd;

/* 执行并更新结果 */
write_back_sc #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .i_valid(i_valid),
    .pc(core_pc),
    .i_ld_data(i_ld_data),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),

    .o_res(o_res),
    .o_wen(o_wen),
    .dnpc(o_dnpc)
);

endmodule
`else
// 单周期处理器
module riscv32e_core #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
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

/* 寄存器组 */
reg [INST_WIDTH-1:0] r_inst;
reg r_valid;

assign valid = r_valid;

/* csr寄存器组 */
wire [`INST_CODE_W-1:0] csr_inst_code = inst_code;
wire                            csr_wen;
wire [`CSR_ADDR_W-1:0]          csr_waddr;
wire [DATA_WIDTH-1:0]           csr_wdata;
wire csr_raddr_en = 
    (csr_inst_code==`INST_CSRRW) |
    (csr_inst_code==`INST_CSRRS) |
    0;
wire [`CSR_ADDR_W-1:0] csr_raddr = 
    csr_raddr_en ? imm[0 +: `CSR_ADDR_W] :
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
    .wen(csr_wen),
    .waddr(csr_waddr),
    .wdata(csr_wdata),

    .expt_en(expt_en),
    .expt_epc(expt_epc),
    .expt_cause(expt_cause),
    .expt_tval(expt_tval)
);

/** 
 * 当前正在处理的pc指示
 * 单周期处理器core_dnpc只需与core_pc一致即可
 */
reg [INST_WIDTH-1:0] core_pc;
reg [INST_WIDTH-1:0] core_dnpc;
wire [INST_WIDTH-1:0] dnpc;
assign pc = core_pc;
always @(posedge clk) begin
    if (rst) begin
        core_pc <= func_get_reset_pc();
        core_dnpc <= func_get_reset_pc();
        r_valid <= 0;
    end else begin
        core_pc <= dnpc;
        core_dnpc <= dnpc;
        r_valid <= 1;
    end
end

/* 硬件性能监控 */
hw_monitor #(
    .INST_WIDTH(INST_WIDTH)
) m_hw_monitor (
    .clk(clk),
    .rst(rst),
    .hw_monitor_icache_en(0),
    .hw_monitor_icache_hit(0),
    .hw_monitor_dcache_en(0),
    .hw_monitor_dcache_hit(0),
    .hw_monitor_ls_en(0),
    .hw_monitor_ls_iswrite(0),
    .hw_monitor_ls_data(0),
    .done()
);

/* 取指 */
always @(*) begin
    if (rst) begin
        r_inst = 32'b0;
    end else begin
        r_inst = func_vdev_read(core_pc, 4);
    end
end

/* 译码 */
wire [6:0] opcode;
wire [`RISCV_GPR_ADDR_W-1:0] rd;
wire [2:0] funct3;
wire [`RISCV_GPR_ADDR_W-1:0] rs1;
wire [`RISCV_GPR_ADDR_W-1:0] rs2;
wire [6:0] funct7;
wire [31:0] imm;
wire [2:0] inst_type;
wire [`INST_CODE_W-1:0] inst_code;
decoder risc32e_decoder(r_inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .pc(core_pc),
    .inst(r_inst),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),

    .csr_rdata(csr_rdata),
    .csr_wen(csr_wen),
    .csr_waddr(csr_waddr),
    .csr_wdata(csr_wdata),

    .expt_en(expt_en),
    .expt_epc(expt_epc),
    .expt_cause(expt_cause),
    .expt_tval(expt_tval),

    .dnpc(dnpc)
);

/* 集中异常处理 */
wire                             expt_en;
wire [INST_WIDTH-1:0]            expt_epc;
wire [DATA_WIDTH-1:0]            expt_cause;
wire [DATA_WIDTH-1:0]            expt_tval;

endmodule
`endif