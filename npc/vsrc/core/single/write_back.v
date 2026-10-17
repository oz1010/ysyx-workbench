`ifdef FORMAL_VERIFY
/*
 * 形式化验证使用的单周期写回级(REF)。
 * 指令语义与仿真版write_back一致，区别仅在于：
 *   - 不通过DPI访问内存，load数据由外部提供(与DUT在总线上读到的数据相同)
 *   - GPR/CSR在模块内实现并带复位初始化，保证与DUT初始状态一致
 *   - i_valid有效时执行一条指令（与DUT的WBU同步）
 */
module write_back_sc #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    input wire                  i_valid,
    input wire [INST_WIDTH-1:0] pc,
    input wire [INST_WIDTH-1:0] i_ld_data,
    input wire [`RISCV_GPR_ADDR_W-1:0] rd,
    input wire [`RISCV_GPR_ADDR_W-1:0] rs1,
    input wire [`RISCV_GPR_ADDR_W-1:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [`INST_CODE_W-1:0] inst_code,

    output wire [INST_WIDTH-1:0] o_res,
    output wire                  o_wen,
    output wire [INST_WIDTH-1:0] dnpc
);

/* 寄存器组 */
reg [INST_WIDTH-1:0] x[`RISCV_GPR_COUNT-1:0];

/* 已实现的CSR：mstatus mtvec mepc mcause可读写，mvendorid marchid只读常量 */
reg  [INST_WIDTH-1:0] csr_mstatus;
reg  [INST_WIDTH-1:0] csr_mtvec;
reg  [INST_WIDTH-1:0] csr_mepc;
reg  [INST_WIDTH-1:0] csr_mcause;
wire [`CSR_ADDR_W-1:0] csr_addr = imm[0 +: `CSR_ADDR_W];
wire [INST_WIDTH-1:0] csr_rdata = 
    (csr_addr==`CSR_MSTATUS)    ? csr_mstatus :
    (csr_addr==`CSR_MTVEC)      ? csr_mtvec :
    (csr_addr==`CSR_MEPC)       ? csr_mepc :
    (csr_addr==`CSR_MCAUSE)     ? csr_mcause :
    (csr_addr==`CSR_MVENDORID)  ? 32'h79737978 :
    (csr_addr==`CSR_MARCHID)    ? 32'h15FDF47 :
    0;

wire [INST_WIDTH-1:0] src1 = x[rs1];
wire [INST_WIDTH-1:0] src2 = x[rs2];
wire signed [INST_WIDTH-1:0] s_src1 = src1;
wire signed [INST_WIDTH-1:0] s_src2 = src2;
wire [63:0] src1_64 = {32'h0, src1};
wire [63:0] src2_64 = {32'h0, src2};
wire signed [63:0] s_src1_64 = {{32{src1[31]}}, src1};
wire signed [63:0] s_src2_64 = {{32{src2[31]}}, src2};
wire signed [63:0] mulh_ret = (s_src1_64 * s_src2_64) >> 32;
wire signed [63:0] mulhsu_ret = (s_src1 * src2) >> 32;
wire signed [63:0] mulhu_ret = (src1 * src2) >> 32;

wire [INST_WIDTH-1:0] snpc = pc + 4;
wire [INST_WIDTH-1:0] pc_plus_imm = pc + imm;
assign dnpc = 
    (inst_code==`INST_JAL) ? pc_plus_imm :
    (inst_code==`INST_JALR) ? ((src1 + imm)&~1) :
    ((inst_code==`INST_BEQ)&(src1==src2)) ? pc_plus_imm :
    ((inst_code==`INST_BNE)&(src1!=src2)) ? pc_plus_imm :
    ((inst_code==`INST_BLT)&(s_src1<s_src2)) ? pc_plus_imm :
    ((inst_code==`INST_BGE)&(s_src1>=s_src2)) ? pc_plus_imm :
    ((inst_code==`INST_BLTU)&(src1<src2)) ? pc_plus_imm :
    ((inst_code==`INST_BGEU)&(src1>=src2)) ? pc_plus_imm :
    (inst_code==`INST_ECALL) ? csr_mtvec :
    (inst_code==`INST_MRET) ? csr_mepc :
    snpc;

/* load结果：从总线原始数据按地址偏移截取并符号扩展，与DUT的LSU一致 */
wire [INST_WIDTH-1:0] mem_addr = src1 + imm;
wire [31:0] ld_shift = i_ld_data >> (8*mem_addr[1:0]);
wire [31:0] ld_res = 
    (inst_code==`INST_LB)  ? {{24{ld_shift[7]}}, ld_shift[7:0]} :
    (inst_code==`INST_LH)  ? {{16{ld_shift[15]}}, ld_shift[15:0]} :
    (inst_code==`INST_LW)  ? ld_shift :
    (inst_code==`INST_LBU) ? {24'h0, ld_shift[7:0]} :
    (inst_code==`INST_LHU) ? {16'h0, ld_shift[15:0]} :
    0;

/* 组合逻辑计算写回结果，与单周期版指令语义一致 */
reg [INST_WIDTH-1:0] r_res;
reg                  r_wen;
always @(*) begin
    r_res = 0;
    r_wen = 1;
    case (inst_code)
        `INST_LUI:          r_res = imm;
        `INST_AUIPC:        r_res = pc_plus_imm;
        `INST_JAL:          r_res = snpc;
        `INST_JALR:         r_res = snpc;
        `INST_BEQ:          r_wen = 0;
        `INST_BNE:          r_wen = 0;
        `INST_BLT:          r_wen = 0;
        `INST_BGE:          r_wen = 0;
        `INST_BLTU:         r_wen = 0;
        `INST_BGEU:         r_wen = 0;
        `INST_LB:           r_res = ld_res;
        `INST_LH:           r_res = ld_res;
        `INST_LW:           r_res = ld_res;
        `INST_LBU:          r_res = ld_res;
        `INST_LHU:          r_res = ld_res;
        `INST_SB:           r_wen = 0;
        `INST_SH:           r_wen = 0;
        `INST_SW:           r_wen = 0;
        `INST_ADDI:         r_res = src1 + imm;
        `INST_SLTI:         r_res = {{31{1'b0}}, (s_src1 < imm)};
        `INST_SLTIU:        r_res = {{31{1'b0}}, (src1 < imm)};
        `INST_XORI:         r_res = src1 ^ imm;
        `INST_ORI:          r_res = src1 | imm;
        `INST_ANDI:         r_res = src1 & imm;
        `INST_SLLI:         r_res = src1 << (imm&32'h1F);
        `INST_SRLI:         r_res = src1 >> (imm&32'h1F);
        `INST_SRAI:         r_res = (src1 >> (imm&32'h1F)) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))) );
        `INST_ADD:          r_res = src1 + src2;
        `INST_SUB:          r_res = src1 - src2;
        `INST_SLL:          r_res = src1 << (src2 & 32'h1F);
        `INST_SLT:          r_res = {{31{1'b0}}, (s_src1 < s_src2)};
        `INST_SLTU:         r_res = {{31{1'b0}}, (src1 < src2)};
        `INST_XOR:          r_res = src1 ^ src2;
        `INST_SRL:          r_res = src1 >> (src2 & 32'h1F);
        `INST_SRA:          r_res = src1 >> (src2 & 32'h1F) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(src2 & 32'h1F))) );
        `INST_OR:           r_res = src1 | src2;
        `INST_AND:          r_res = src1 & src2;
        `INST_FENCE_I:      r_wen = 0;
        `INST_ECALL:        r_wen = 0;
        `INST_MRET:         r_wen = 0;
        `INST_CSRRW:        r_res = csr_rdata;
        `INST_CSRRS:        r_res = csr_rdata;
        `INST_MUL:          r_res = src1 * src2;
        `INST_MULH:         r_res = mulh_ret[INST_WIDTH-1:0];
        `INST_MULHSU:       r_res = mulhsu_ret[INST_WIDTH-1:0];
        `INST_MULHU:        r_res = mulhu_ret[INST_WIDTH-1:0];
        `INST_DIV:          r_res = s_src1 / s_src2;
        `INST_DIVU:         r_res = src1 / src2;
        `INST_REM:          r_res = s_src1 % s_src2;
        `INST_REMU:         r_res = src1 % src2;
        default:            begin r_res = 0; r_wen = 0; end
    endcase
end
assign o_res = r_res;
assign o_wen = r_wen;

/* 状态更新：i_valid有效时执行一条指令 */
integer k;
always @(posedge clk) begin
    if (rst) begin
        for (k=0; k<`RISCV_GPR_COUNT; k=k+1) begin
            x[k] <= 0;
        end
        csr_mstatus <= 32'h0000_1800;
        csr_mtvec   <= 32'h0000_1000;
        csr_mepc    <= 32'h0000_1000;
        csr_mcause  <= 0;
    end else if (i_valid) begin
        if (o_wen) begin
            x[rd] <= o_res;
        end

        case (inst_code)
            `INST_CSRRW: begin
                case (csr_addr)
                    `CSR_MSTATUS: csr_mstatus <= src1;
                    `CSR_MTVEC:   csr_mtvec <= src1;
                    `CSR_MEPC:    csr_mepc <= src1;
                    `CSR_MCAUSE:  csr_mcause <= src1;
                    default: ;
                endcase
            end
            `INST_CSRRS: begin
                case (csr_addr)
                    `CSR_MSTATUS: csr_mstatus <= csr_mstatus | src1;
                    `CSR_MTVEC:   csr_mtvec <= csr_mtvec | src1;
                    `CSR_MEPC:    csr_mepc <= csr_mepc | src1;
                    `CSR_MCAUSE:  csr_mcause <= csr_mcause | src1;
                    default: ;
                endcase
            end
            `INST_ECALL: begin
                csr_mepc <= pc;
                csr_mcause <= 11;
            end
            default: ;
        endcase

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule
`else
module write_back #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input   wire                            clk,
    input   wire                            rst,

    input   wire [INST_WIDTH-1:0]           pc,
    input   wire [INST_WIDTH-1:0]           inst,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rd,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rs1,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rs2,
    input   wire [INST_WIDTH-1:0]           imm,
    input   wire [`INST_CODE_W-1:0]         inst_code,

    // gpr读入
    input   wire [DATA_WIDTH-1:0]           gpr_src1,
    input   wire [DATA_WIDTH-1:0]           gpr_src2,
    input   wire [DATA_WIDTH-1:0]           gpr_a0,
    // gpr写入
    output  reg                             gpr_wen,
    output  reg  [`RISCV_GPR_ADDR_W-1:0]    gpr_waddr,
    output  reg  [DATA_WIDTH-1:0]           gpr_wdata,

    // 普通csr读入
    input   wire [DATA_WIDTH-1:0]           csr_rdata,
    // 普通csr写入
    output  wire                            csr_wen,
    output  wire [`CSR_ADDR_W-1:0]          csr_waddr,
    output  wire [DATA_WIDTH-1:0]           csr_wdata,
    // 异常csr写入
    output  reg                             expt_en,
    output  reg  [INST_WIDTH-1:0]           expt_epc,
    output  reg  [DATA_WIDTH-1:0]           expt_cause,
    output  reg  [DATA_WIDTH-1:0]           expt_tval,

    output wire [INST_WIDTH-1:0]            dnpc
);
    wire [INST_WIDTH-1:0] src1 = gpr_src1;
    wire [INST_WIDTH-1:0] src2 = gpr_src2;
    wire signed [INST_WIDTH-1:0] s_src1 = src1;
    wire signed [INST_WIDTH-1:0] s_src2 = src2;
    wire [INST_WIDTH-1:0] snpc = pc + 4;
    wire [INST_WIDTH-1:0] pc_plus_imm = pc + imm;
    assign dnpc = 
        (inst_code==`INST_JAL) ? pc_plus_imm :
        (inst_code==`INST_JALR) ? ((src1 + imm)&~1) :
        ((inst_code==`INST_BEQ)&(src1==src2)) ? pc_plus_imm :
        ((inst_code==`INST_BNE)&(src1!=src2)) ? pc_plus_imm :
        ((inst_code==`INST_BLT)&(s_src1<s_src2)) ? pc_plus_imm :
        ((inst_code==`INST_BGE)&(s_src1>=s_src2)) ? pc_plus_imm :
        ((inst_code==`INST_BLTU)&(src1<src2)) ? pc_plus_imm :
        ((inst_code==`INST_BGEU)&(src1>=src2)) ? pc_plus_imm :
        (inst_code==`INST_ECALL) ? csr_rdata :
        (inst_code==`INST_MRET) ? csr_rdata :
        snpc;
    integer mem_rdata;
    integer mem_wdata;
    wire [31:0] mem_addr = src1 + imm;

    always @(posedge clk) begin
        if (rst) begin
        end else begin
            // 更新寄存器或回写内存
            case (inst_code)
`ifndef IN_YOSYS_STA
                `INST_SB:           begin mem_wdata = src2&32'hFF; write_raw_mem(mem_addr, 1, mem_wdata); func_dev_skip(1, mem_addr, {24'h0, 4'h0, 4'h1}, mem_wdata); end
                `INST_SH:           begin mem_wdata = src2&32'hFFFF; write_raw_mem(mem_addr, 2, mem_wdata); func_dev_skip(1, mem_addr, {24'h0, 4'h1, 4'h3}, mem_wdata); end
                `INST_SW:           begin mem_wdata = src2; write_raw_mem(mem_addr, 4, mem_wdata); func_dev_skip(1, mem_addr, {24'h0, 4'h2, 4'h7}, mem_wdata); end
`endif
                `INST_MRET:         func_query_intr(); // MEPC 0x341
                default: ;
            endcase
        end
    end

    /**
    * ref. https://ysyx.oscc.cc/docs/ics-pa/3.2.html#riscv32
    * riscv32触发异常后硬件的响应过程如下:
    * 
    * 将当前PC值保存到mepc寄存
    * 在mcause寄存器中设置异常号
    * 从mtvec寄存器中取出异常入口地址
    * 跳转到异常入口地址
    */
    always @(*) begin
        expt_en = 0; expt_epc = 0; expt_cause = 0; expt_tval = 0;
        case (inst_code)
            `INST_EBREAK:   begin expt_en = 1; expt_cause = `EXPT_CAUSE_BRK; expt_tval = gpr_a0; expt_epc = 0; end
            `INST_INVALID:  begin expt_en = 1; expt_cause = `EXPT_CAUSE_ILL; expt_tval = inst; expt_epc = pc; end
            `INST_ECALL:    begin expt_en = 1; expt_cause = `EXPT_CAUSE_MEC; expt_tval = (0<<31|11<<0); expt_epc = pc; end // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0) , MTVEC 0x305
            `INST_SLLI, `INST_SRLI, `INST_SRAI: if ((imm&32'h20)!=32'h0) begin expt_en = 1; expt_cause = `EXPT_CAUSE_ILL; expt_tval = inst; expt_epc = pc; end
            default: begin end
        endcase
    end

    // GPR寄存器堆处理
    always @(*) begin
        mem_rdata = 0;
        gpr_wen = 0; gpr_waddr = rd; gpr_wdata = 0;
        case (inst_code)
            `INST_LUI:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = imm; end
            `INST_AUIPC:        begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = pc_plus_imm; end
            `INST_JAL:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = snpc; end
            `INST_JALR:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = snpc; end
`ifndef IN_YOSYS_STA
            `INST_LB:           begin mem_rdata = sext(read_raw_mem(mem_addr, 1), 8); func_dev_skip(0, mem_addr, { 24'h0, 4'h0, 4'h0}, mem_rdata);    gpr_wen = 1; gpr_waddr = rd; gpr_wdata = mem_rdata; end
            `INST_LH:           begin mem_rdata = sext(read_raw_mem(mem_addr, 2), 16); func_dev_skip(0, mem_addr, { 24'h0, 4'h1, 4'h0}, mem_rdata);   gpr_wen = 1; gpr_waddr = rd; gpr_wdata = mem_rdata; end
            `INST_LW:           begin mem_rdata = sext(read_raw_mem(mem_addr, 4), 32); func_dev_skip(0, mem_addr, { 24'h0, 4'h2, 4'h0}, mem_rdata);   gpr_wen = 1; gpr_waddr = rd; gpr_wdata = mem_rdata; end
            `INST_LBU:          begin mem_rdata = read_raw_mem(mem_addr, 1) & 32'hFF; func_dev_skip(0, mem_addr, { 24'h0, 4'h0, 4'h0}, mem_rdata);    gpr_wen = 1; gpr_waddr = rd; gpr_wdata = mem_rdata; end
            `INST_LHU:          begin mem_rdata = read_raw_mem(mem_addr, 2) & 32'hFFFF; func_dev_skip(0, mem_addr, { 24'h0, 4'h1, 4'h0}, mem_rdata);  gpr_wen = 1; gpr_waddr = rd; gpr_wdata = mem_rdata; end
`endif
            `INST_ADDI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 + imm; end
            `INST_SLTI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = {{31{1'b0}}, (s_src1 < imm)}; end
            `INST_SLTIU:        begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = {{31{1'b0}}, (src1 < imm)}; end
            `INST_XORI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 ^ imm; end
            `INST_ORI:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 | imm; end
            `INST_ANDI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 & imm; end
            `INST_SLLI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 << (imm&32'h1F); end
            `INST_SRLI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 >> (imm&32'h1F); end
            `INST_SRAI:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = (src1 >> (imm&32'h1F)) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))) ); end
            `INST_ADD:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 + src2; end
            `INST_SUB:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 - src2; end
            `INST_SLL:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 << (src2 & 32'h1F); end
            `INST_SLT:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = {{31{1'b0}}, (s_src1 < s_src2)}; end
            `INST_SLTU:         begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = {{31{1'b0}}, (src1 < src2)}; end
            `INST_XOR:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 ^ src2; end
            `INST_SRL:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 >> (src2 & 32'h1F); end
            `INST_SRA:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 >> (src2 & 32'h1F) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(src2 & 32'h1F))) ); end
            `INST_OR:           begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 | src2; end
            `INST_AND:          begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = src1 & src2; end
            `INST_CSRRW:        begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = csr_rdata; end
            `INST_CSRRS:        begin gpr_wen = 1; gpr_waddr = rd; gpr_wdata = csr_rdata; end

            default:            begin end
        endcase
    end

    // CSR寄存器堆处理
    wire csr_inst = 
        (inst_code==`INST_CSRRW) |
        (inst_code==`INST_CSRRS) |
        0;
    assign csr_wen = csr_inst;
    assign csr_waddr = 
        csr_inst ? imm[0 +: `CSR_ADDR_W] :
        0;
    assign csr_wdata =
        (inst_code==`INST_CSRRW) ? src1 :
        (inst_code==`INST_CSRRS) ? (csr_rdata|src1) :
        0;

endmodule
`endif
