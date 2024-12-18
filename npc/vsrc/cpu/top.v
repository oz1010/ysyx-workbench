import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function void write_raw_mem(input int addr, input int len, input int inst);
import "DPI-C" function int read_raw_mem(input int addr, input int len);
import "DPI-C" function int get_reset_pc();

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
        inst = read_raw_mem(pc, 4);
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
            `INST_AUIPC:        x[rd] <= pc + imm;
            `INST_JAL:          begin x[rd] <= pc + 4; pc <= pc + imm; end
            `INST_JALR:         begin x[rd] <= pc + 4; pc <= ((src1 + imm)&~1); end
            `INST_BEQ:          if (src1==src2) pc <= pc + imm;
            `INST_BNE:          if (src1!=src2) pc <= pc + imm;
            `INST_LW:           x[rd] <= read_raw_mem(src1 + imm, 4);
            `INST_SW:           write_raw_mem(src1 + imm, 4, src2);
            `INST_ADDI:         x[rd] <= src1 + imm;
            `INST_SLTIU:        x[rd] <= {{31{1'b0}}, (src1 < imm)};
            `INST_ADD:          x[rd] <= src1 + src2;
            `INST_SUB:          x[rd] <= src1 - src2;

            `INST_EBREAK:       exit_simu(a[0]);

            `INST_INVALID:      invalid_inst(pc, inst);
            default: ;
        endcase

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule
