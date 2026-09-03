/*
 * 流水线形式化验证顶层（docs/pipeline_test.md）
 * DUT: 五级流水线 riscv32e_core   (vsrc/core/pipeline/riscv32e_core.v)
 * REF: 单周期处理器 riscv32e_core_sc (vsrc/core/single/riscv32e_core.v)
 *
 * 验证策略：
 *   - 指令与load数据作为验证顶层模块的输入（AXI从机模型返回任意数据），
 *     BMC在深度界内遍历各种指令序列及各种访存延迟的组合；
 *   - DUT每完成一条指令(WBU)，才将该指令同步送入REF执行；
 *   - 对比状态转移而非状态空间：pc、dnpc(PC的新值)、写回GPR的编号rd与结果res；
 *   - store不写GPR，其结果不作专门对比；CSR写入经后续的CSR读指令归约为GPR对比。
 */
`include "riscv32e_defines.v"

module pipelinetest (
    input wire clk,
    input wire rst
);

/* 非确定性输入：AXI读数据(取指令/访存数据)与各通道握手延迟 */
(* anyseq *) reg [31:0] fv_any_rdata;
(* anyseq *) reg        fv_arready;
(* anyseq *) reg        fv_rrespond;
(* anyseq *) reg        fv_awready;
(* anyseq *) reg        fv_wready;
(* anyseq *) reg        fv_brespond;

/* 复位保持2拍：static_predictor需在复位第2拍才能锁存到有效的core_pc */
reg [1:0] f_rstcnt = 0;
always @(posedge clk) begin
    if (f_rstcnt != 2) f_rstcnt <= f_rstcnt + 1;
    if (f_rstcnt != 2) assume(rst);
    else assume(!rst);
end

/* ------------------------------------------------------------------ */
/* AXI从机模型：任意延迟的单拍读写，读数据任意（由assume约束取指合法）  */
/* ------------------------------------------------------------------ */
wire        m_awready;
wire        m_awvalid;
wire [31:0] m_awaddr;
wire [3:0]  m_awid;
wire [7:0]  m_awlen;
wire [2:0]  m_awsize;
wire [1:0]  m_awburst;
wire        m_wready;
wire        m_wvalid;
wire [31:0] m_wdata;
wire [3:0]  m_wstrb;
wire        m_wlast;
wire        m_bready;
wire        m_bvalid;
wire [1:0]  m_bresp;
wire [3:0]  m_bid;
wire        m_arready;
wire        m_arvalid;
wire [31:0] m_araddr;
wire [3:0]  m_arid;
wire [7:0]  m_arlen;
wire [2:0]  m_arsize;
wire [1:0]  m_arburst;
wire        m_rready;
wire        m_rvalid;
wire [1:0]  m_rresp;
wire [31:0] m_rdata;
wire        m_rlast;
wire [3:0]  m_rid;

/* 复用单周期核的译码器判断取指数据的合法性（assume(!isIllegal)） */
wire [6:0]  dec_opcode;
wire [4:0]  dec_rd;
wire [2:0]  dec_funct3;
wire [4:0]  dec_rs1;
wire [4:0]  dec_rs2;
wire [6:0]  dec_funct7;
wire [31:0] dec_imm;
wire [2:0]  dec_type;
wire [`INST_CODE_W-1:0] dec_code;
decoder fv_decoder(fv_any_rdata, dec_opcode, dec_rd, dec_funct3,
    dec_rs1, dec_rs2, dec_funct7, dec_imm, dec_type, dec_code);

/* CSR指令的地址限制在已实现的CSR范围内 */
wire fv_csr_addr_ok =
    (fv_any_rdata[31:20]==`CSR_MSTATUS) | (fv_any_rdata[31:20]==`CSR_MTVEC) |
    (fv_any_rdata[31:20]==`CSR_MEPC) | (fv_any_rdata[31:20]==`CSR_MCAUSE) |
    (fv_any_rdata[31:20]==`CSR_MVENDORID) | (fv_any_rdata[31:20]==`CSR_MARCHID);
wire fv_inst_legal =
    /* 排除非法指令及仿真结束的ebreak */
    (dec_code!=`INST_INVALID)
    & (dec_code!=`INST_EBREAK)
    /* DUT未处理CSR写后读冒险，默认不生成CSRRW；CSRRS仅允许rs1=x0的纯读形式 */
    & (dec_code!=`INST_CSRRW)
    & ((dec_code!=`INST_CSRRS) | (dec_rs1==0))
    & (((dec_code!=`INST_CSRRW) & (dec_code!=`INST_CSRRS)) | fv_csr_addr_ok);

/* 读通道 */
reg        r_rpending;
reg [3:0]  r_rid;
reg        r_rvalid;
reg [31:0] r_rdata;
assign m_arready = fv_arready & !r_rpending & !r_rvalid;
always @(posedge clk) begin
    if (rst) begin
        r_rpending <= 0;
        r_rvalid <= 0;
        r_rid <= 0;
        r_rdata <= 0;
    end else begin
        if (m_arvalid && m_arready) begin
            r_rpending <= 1;
            r_rid <= m_arid;
            r_rdata <= fv_any_rdata;
            /* 取指数据必须是合法指令，从而排除指令序列中的非法指令 */
            if (m_arid == `AXI4_ID_IFU) begin
                assume(fv_inst_legal);
            end
        end
        if (r_rpending && fv_rrespond) begin
            r_rpending <= 0;
            r_rvalid <= 1;
        end
        if (r_rvalid && m_rready) begin
            r_rvalid <= 0;
        end
    end
end
assign m_rvalid = r_rvalid;
assign m_rdata = r_rdata;
assign m_rresp = 0;
assign m_rlast = r_rvalid;
assign m_rid = r_rid;

/* 写通道：store结果不参与对比，从机只需保证协议正确完成 */
reg       r_wgot;
reg [3:0] r_bid;
reg       r_bwait;
reg       r_bvalid;
assign m_awready = fv_awready & !r_wgot & !r_bwait & !r_bvalid;
assign m_wready = fv_wready & r_wgot;
always @(posedge clk) begin
    if (rst) begin
        r_wgot <= 0;
        r_bwait <= 0;
        r_bvalid <= 0;
        r_bid <= 0;
    end else begin
        if (m_awvalid && m_awready) begin
            r_wgot <= 1;
            r_bid <= m_awid;
        end
        if (m_wvalid && m_wready) begin
            r_wgot <= 0;
            r_bwait <= 1;
        end
        if (r_bwait && fv_brespond) begin
            r_bwait <= 0;
            r_bvalid <= 1;
        end
        if (r_bvalid && m_bready) begin
            r_bvalid <= 0;
        end
    end
end
assign m_bvalid = r_bvalid;
assign m_bresp = 0;
assign m_bid = r_bid;

/* 访存约束：只允许对齐访问(单拍len=0)，排除不对齐访存；地址0被仲裁器视为无请求 */
always @(*) begin
    if (m_arvalid) begin
        assume(m_arlen == 0);
        assume(m_araddr != 0);
    end
    if (m_awvalid) begin
        assume(m_awlen == 0);
        assume(m_awaddr != 0);
    end
end

/* ------------------------------------------------------------------ */
/* DUT：流水线核（形式化配置下IFU/LSU经仲裁器直连io_master）            */
/* ------------------------------------------------------------------ */
wire [31:0] dut_wb_pc;
wire [31:0] dut_wb_dnpc;
wire [31:0] dut_wb_inst;
wire [4:0]  dut_wb_rd;
wire [31:0] dut_wb_result;
wire        dut_wb_result_update_gpr;
wire [31:0] dut_wb_ld_data;
wire        dut_valid;

riscv32e_core dut (
    .clk(clk),
    .rst(rst),

    .io_interrupt(1'b0),
    .io_master_awready(m_awready),
    .io_master_awvalid(m_awvalid),
    .io_master_awaddr(m_awaddr),
    .io_master_awid(m_awid),
    .io_master_awlen(m_awlen),
    .io_master_awsize(m_awsize),
    .io_master_awburst(m_awburst),
    .io_master_wready(m_wready),
    .io_master_wvalid(m_wvalid),
    .io_master_wdata(m_wdata),
    .io_master_wstrb(m_wstrb),
    .io_master_wlast(m_wlast),
    .io_master_bready(m_bready),
    .io_master_bvalid(m_bvalid),
    .io_master_bresp(m_bresp),
    .io_master_bid(m_bid),
    .io_master_arready(m_arready),
    .io_master_arvalid(m_arvalid),
    .io_master_araddr(m_araddr),
    .io_master_arid(m_arid),
    .io_master_arlen(m_arlen),
    .io_master_arsize(m_arsize),
    .io_master_arburst(m_arburst),
    .io_master_rready(m_rready),
    .io_master_rvalid(m_rvalid),
    .io_master_rresp(m_rresp),
    .io_master_rdata(m_rdata),
    .io_master_rlast(m_rlast),
    .io_master_rid(m_rid),

    .pc(),
    .valid(dut_valid),

    .fv_wb_pc(dut_wb_pc),
    .fv_wb_dnpc(dut_wb_dnpc),
    .fv_wb_inst(dut_wb_inst),
    .fv_wb_rd(dut_wb_rd),
    .fv_wb_result(dut_wb_result),
    .fv_wb_result_update_gpr(dut_wb_result_update_gpr),
    .fv_wb_ld_data(dut_wb_ld_data)
);

/* ------------------------------------------------------------------ */
/* REF：单周期核，DUT每完成一条指令才同步执行                           */
/* ------------------------------------------------------------------ */
wire [31:0] ref_pc;
wire [31:0] ref_dnpc;
wire [4:0]  ref_rd;
wire [31:0] ref_res;
wire        ref_wen;

riscv32e_core_sc ref_core (
    .clk(clk),
    .rst(rst),

    .i_valid(dut_valid),
    .i_inst(dut_wb_inst),
    .i_ld_data(dut_wb_ld_data),

    .o_pc(ref_pc),
    .o_dnpc(ref_dnpc),
    .o_rd(ref_rd),
    .o_res(ref_res),
    .o_wen(ref_wen)
);

/* ------------------------------------------------------------------ */
/* 验证条件：对比状态转移                                              */
/* ------------------------------------------------------------------ */
always @(posedge clk) begin
    if (!rst && dut_valid) begin
        /* 对比PC与PC的新值，检查控制流转移是否正确 */
        assert(dut_wb_pc == ref_pc);
        assert(dut_wb_dnpc == ref_dnpc);
        /* 写回GPR的编号与结果一致；不写GPR的指令无需对比rd/res */
        assert(dut_wb_result_update_gpr == ref_wen);
        if (dut_wb_result_update_gpr) begin
            assert(dut_wb_rd == ref_rd);
            assert(dut_wb_result == ref_res);
        end
    end
end

/* ------------------------------------------------------------------ */
/* 覆盖点：确认BMC确实遍历到了各类完成指令（防止空通过）                */
/* ------------------------------------------------------------------ */
wire [6:0]  wb_dec_opcode;
wire [4:0]  wb_dec_rd;
wire [2:0]  wb_dec_funct3;
wire [4:0]  wb_dec_rs1;
wire [4:0]  wb_dec_rs2;
wire [6:0]  wb_dec_funct7;
wire [31:0] wb_dec_imm;
wire [2:0]  wb_dec_type;
wire [`INST_CODE_W-1:0] wb_dec_code;
decoder wb_decoder(dut_wb_inst, wb_dec_opcode, wb_dec_rd, wb_dec_funct3,
    wb_dec_rs1, wb_dec_rs2, wb_dec_funct7, wb_dec_imm, wb_dec_type, wb_dec_code);

always @(posedge clk) begin
    if (!rst) begin
        cover(dut_valid);                                                   // 有指令完成
        cover(dut_valid && (wb_dec_code==`INST_ADD));                       // ALU R型
        cover(dut_valid && (wb_dec_code==`INST_ADDI));                      // ALU I型
        cover(dut_valid && (wb_dec_code==`INST_SLLI));                      // 移位
        cover(dut_valid && (wb_dec_code==`INST_BEQ || wb_dec_code==`INST_BNE || wb_dec_code==`INST_BLT
            || wb_dec_code==`INST_BGE || wb_dec_code==`INST_BLTU || wb_dec_code==`INST_BGEU)); // 条件分支
        cover(dut_valid && (wb_dec_code==`INST_JAL));                       // jal
        cover(dut_valid && (wb_dec_code==`INST_JALR));                      // jalr
        cover(dut_valid && (wb_dec_code==`INST_LW));                        // load
        cover(dut_valid && (wb_dec_code==`INST_LH));                        // load半字
        cover(dut_valid && (wb_dec_code==`INST_SW));                        // store
        cover(dut_valid && (wb_dec_code==`INST_CSRRS));                     // CSR指令
        cover(dut_valid && (wb_dec_code==`INST_ECALL));                     // ecall
        cover(dut_valid && (wb_dec_code==`INST_MRET));                      // mret
        cover(dut_valid && (wb_dec_code==`INST_FENCE_I));                   // fence.i
        cover(dut_valid && (wb_dec_code==`INST_MUL));                       // 乘除法
    end
end

endmodule
