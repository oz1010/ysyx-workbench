import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function int fetch_inst(input int addr);
import "DPI-C" function void write_raw_mem(input int addr, input int len, input int inst);
import "DPI-C" function int read_raw_mem(input int addr, input int len);
import "DPI-C" function int get_reset_pc();
import "DPI-C" function int sext(input int x, input int len);
import "DPI-C" function void write_raw_csr(input int idx, input int data);
import "DPI-C" function int read_raw_csr(input int idx);
import "DPI-C" function int dpi_raise_ex(input int thispc, input int inst);

`include "riscv32e_defines.v"

module top (
    input clk,
    input rst
);

/* 寄存器组 */
// 通用寄存器
reg [31:0] x[31:0];
// 程序寄存器
reg [31:0] pc;
wire [31:0] snpc = pc + 4;
// 当前指令寄存器
reg [31:0] inst;
// // ALU结果
// reg [31:0] alu_result;
// 寄存器别名，register alias, ch2.3
wire [31:0] zero = x[0];
wire [31:0] ra = x[1];
wire [31:0] sp = x[2];
wire [31:0] gp = x[3];
wire [31:0] tp = x[4];
wire [31:0] a[7:0];
assign a[7:0] = x[17:10];

/* 取指 */
always @(*) begin
    if (rst) begin
        inst = 32'b0;
    end else begin
        inst = fetch_inst(pc);
    end
end

/* 译码 */
wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [6:0] funct7;
wire [31:0] imm;
wire [2:0] inst_type;
wire [15:0] inst_code;
decoder risc32e_decoder(inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

/* 执行并更新结果 */
wire [31:0] src1 = x[rs1];
wire [31:0] src2 = x[rs2];
wire signed [31:0] s_src1 = src1;
wire signed [31:0] s_src2 = src2;
wire [63:0] src1_64 = {32'h0, src1};
wire [63:0] src2_64 = {32'h0, src2};
wire signed [63:0] s_src1_64 = {{32{src1[31]}}, src1};
wire signed [63:0] s_src2_64 = {{32{src2[31]}}, src2};
wire signed [63:0] mulh_ret = (s_src1_64 * s_src2_64) >> 32;
wire signed [63:0] mulhsu_ret = (s_src1 * src2) >> 32;
wire signed [63:0] mulhu_ret = (src1 * src2) >> 32;
// alu risc32e_alu(inst_code, src1, src2, imm, alu_result);
// always @(*) begin
//     $display("exec info, pc:%x inst:%x type:%d src1:%x src2:%x imm:%x alu_result:%x",
//         pc, inst, inst_code, src1, src2, imm, alu_result);
// end
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= get_reset_pc();
    end else begin
        // 默认更新程序寄存器
        pc <= snpc;

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
            `INST_ECALL:        pc <= dpi_raise_ex(pc, inst);
            `INST_EBREAK:       exit_simu(a[0]);
            `INST_CSRRW:        begin x[rd] <= read_raw_csr(imm); write_raw_csr(imm, src1); end
            `INST_CSRRS:        begin x[rd] <= read_raw_csr(imm); write_raw_csr(imm, (read_raw_csr(imm) | src1)); end
            `INST_CSRRC:        invalid_inst(pc, inst);
            `INST_CSRRWI:       invalid_inst(pc, inst);
            `INST_CSRRSI:       invalid_inst(pc, inst);
            `INST_CSRRCI:       invalid_inst(pc, inst);
            `INST_MUL:          x[rd] <= src1 * src2;
            `INST_MULH:         x[rd] <= mulh_ret[31:0];
            `INST_MULHSU:       x[rd] <= mulhsu_ret[31:0];
            `INST_MULHU:        x[rd] <= mulhu_ret[31:0];
            `INST_DIV:          x[rd] <= s_src1 / s_src2;
            `INST_DIVU:         x[rd] <= src1 / src2;
            `INST_REM:          x[rd] <= s_src1 % s_src2;
            `INST_REMU:         x[rd] <= src1 % src2;
            `INST_INVALID:      invalid_inst(pc, inst);
            default: ;
        endcase

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule
