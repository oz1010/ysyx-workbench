module write_back #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    input wire [INST_WIDTH-1:0] inst,
    input wire [4:0] rd,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [15:0] inst_code,

    output wire [INST_WIDTH-1:0] w_x[`RISCV_CSR_COUNT-1:0],
    output wire [INST_WIDTH-1:0] w_pc
);

/* 寄存器组 */
// 通用寄存器
reg [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0];
// 程序寄存器
reg [INST_WIDTH-1:0] pc;
// 当前指令寄存器
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];

assign w_x = x;
assign w_pc = pc;

/* 执行并更新结果 */
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

// alu risc32e_alu(inst_code, src1, src2, imm, alu_result);
// always @(*) begin
//     $display("exec info, pc:%x r_inst:%x type:%d src1:%x src2:%x imm:%x alu_result:%x",
//         pc, r_inst, inst_code, src1, src2, imm, alu_result);
// end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= get_reset_pc();
    end else begin
        // 默认更新程序寄存器
        pc <= pc + 4;

        // 更新寄存器或回写内存
        // $display("Step - update, alu_result:%x rd:%d inst_code:%x", alu_result, rd, inst_code);
        case (inst_code)
            `INST_LUI:          x[rd] <= imm;
            `INST_AUIPC:        x[rd] <= pc + imm;
            `INST_JAL:          begin x[rd] <= pc + 4; pc <= pc + imm; end
            `INST_JALR:         begin x[rd] <= pc + 4; pc <= ((src1 + imm)&~1); end
            `INST_BEQ:          if (src1==src2) pc <= pc + imm;
            `INST_BNE:          if (src1!=src2) pc <= pc + imm;
            `INST_BLT:          if (s_src1<s_src2) pc <= pc + imm;
            `INST_BGE:          if (s_src1>=s_src2) pc <= pc + imm;
            `INST_BLTU:         if (src1< src2) pc <= pc + imm;
            `INST_BGEU:         if (src1>=src2) pc <= pc + imm;
            `INST_LB:           x[rd] <= sext(read_raw_mem(src1 + imm, 1), 8);
            `INST_LH:           x[rd] <= sext(read_raw_mem(src1 + imm, 2), 16);
            `INST_LW:           x[rd] <= sext(read_raw_mem(src1 + imm, 4), 32);
            `INST_LBU:          x[rd] <= read_raw_mem(src1 + imm, 1) & 32'hFF;
            `INST_LHU:          x[rd] <= read_raw_mem(src1 + imm, 2) & 32'hFFFF;
            `INST_SB:           write_raw_mem(src1 + imm, 1, src2&32'hFF);
            `INST_SH:           write_raw_mem(src1 + imm, 2, src2&32'hFFFF);
            `INST_SW:           write_raw_mem(src1 + imm, 4, src2);
            `INST_ADDI:         x[rd] <= src1 + imm;
            `INST_SLTI:         x[rd] <= {{31{1'b0}}, (s_src1 < imm)};
            `INST_SLTIU:        x[rd] <= {{31{1'b0}}, (src1 < imm)};
            `INST_XORI:         x[rd] <= src1 ^ imm;
            `INST_ORI:          x[rd] <= src1 | imm;
            `INST_ANDI:         x[rd] <= src1 & imm;
            `INST_SLLI:         if ((imm&32'h20)!=32'h0) exit_simu(`ERR_INV_OPN); else x[rd] <= src1 << (imm&32'h1F);
            `INST_SRLI:         if ((imm&32'h20)!=32'h0) exit_simu(`ERR_INV_OPN); else x[rd] <= src1 >> (imm&32'h1F);
            `INST_SRAI:         if ((imm&32'h20)!=32'h0) exit_simu(`ERR_INV_OPN); else x[rd] <= (src1 >> (imm&32'h1F)) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))) );
            `INST_ADD:          x[rd] <= src1 + src2;
            `INST_SUB:          x[rd] <= src1 - src2;
            `INST_SLL:          x[rd] <= src1 << (src2 & 32'h1F);
            `INST_SLT:          x[rd] <= {{31{1'b0}}, (s_src1 < s_src2)};
            `INST_SLTU:         x[rd] <= {{31{1'b0}}, (src1 < src2)};
            `INST_XOR:          x[rd] <= src1 ^ src2;
            `INST_SRL:          x[rd] <= src1 >> (src2 & 32'h1F);
            `INST_SRA:          x[rd] <= src1 >> (src2 & 32'h1F) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(src2 & 32'h1F))) );
            `INST_OR:           x[rd] <= src1 | src2;
            `INST_AND:          x[rd] <= src1 & src2;
            `INST_FENCE:        invalid_inst(pc, inst);
            `INST_FENCE_I:      invalid_inst(pc, inst);
            `INST_ECALL:        pc <= dpi_raise_intr((0<<31|11<<0), pc); // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0)
            `INST_EBREAK:       exit_simu(a[0]);
            `INST_CSRRW:        begin x[rd] <= read_raw_csr(imm); write_raw_csr(imm, src1); end
            `INST_CSRRS:        begin x[rd] <= read_raw_csr(imm); write_raw_csr(imm, (read_raw_csr(imm) | src1)); end
            `INST_CSRRC:        invalid_inst(pc, inst);
            `INST_CSRRWI:       invalid_inst(pc, inst);
            `INST_CSRRSI:       invalid_inst(pc, inst);
            `INST_CSRRCI:       invalid_inst(pc, inst);
            `INST_MUL:          x[rd] <= src1 * src2;
            `INST_MULH:         x[rd] <= mulh_ret[INST_WIDTH-1:0];
            `INST_MULHSU:       x[rd] <= mulhsu_ret[INST_WIDTH-1:0];
            `INST_MULHU:        x[rd] <= mulhu_ret[INST_WIDTH-1:0];
            `INST_DIV:          x[rd] <= s_src1 / s_src2;
            `INST_DIVU:         x[rd] <= src1 / src2;
            `INST_REM:          x[rd] <= s_src1 % s_src2;
            `INST_REMU:         x[rd] <= src1 % src2;
            `INST_MRET:         pc <= dpi_query_intr();
            `INST_INVALID:      invalid_inst(pc, inst);
            default: ;
        endcase

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule