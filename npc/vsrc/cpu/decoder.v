`include "riscv32e_defines.v"

module decoder (
    input  [31:0] inst,
    output [6:0] opcode,
    output [4:0] rd,
    output [2:0] funct3,
    output [4:0] rs1,
    output [4:0] rs2,
    output [6:0] funct7,
    output [31:0] imm,
    output [2:0] inst_type,
    output reg [15:0] inst_code
);

// 提取字段
assign opcode = inst[6:0];
assign rd = inst[11:7];
assign funct3 = inst[14:12];
assign rs1 = inst[19:15];
assign rs2 = inst[24:20];
assign funct7 = inst[31:25];

// 根据操作码解析指令类型
assign inst_type =   
                (opcode==7'b01100_11) ? `TYPE_R : 
                (opcode==7'b00100_11 || opcode==7'b00000_11 || opcode==7'b11100_11 || opcode==7'b11001_11) ? `TYPE_I : 
                (opcode==7'b01000_11) ? `TYPE_S : 
                (opcode==7'b11000_11) ? `TYPE_B : 
                (opcode==7'b01101_11 || opcode==7'b00101_11) ? `TYPE_U : 
                (opcode==7'b11011_11) ? `TYPE_J : 
                `TYPE_INVALID;

// 根据指令类型返回立即数
wire [11:0] immI = inst[31:20];
wire [11:0] immS = {inst[31:25], inst[11:7]};
wire [12:0] immB = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
wire [31:0] immU = {inst[31:12], {12{1'b0}}};
wire [20:0] immJ = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
// wire [31:0] ext_immI = {{20{immI[11]}}, immI};
// wire [31:0] ext_immS = {{20{immS[11]}}, immS};
// wire [31:0] ext_immB = {{19{immB[12]}}, immB};
// wire [31:0] ext_immU = immU;
// wire [31:0] ext_immJ = {{11{immJ[20]}}, immJ};
assign imm = 
    (inst_type==`TYPE_I) ? {{20{immI[11]}}, immI} :
    (inst_type==`TYPE_S) ? {{20{immS[11]}}, immS} :
    (inst_type==`TYPE_B) ? {{19{immB[12]}}, immB} :
    (inst_type==`TYPE_U) ? immU :
    (inst_type==`TYPE_J) ? {{11{immJ[20]}}, immJ} :
    32'b0;

// 生成指令代码
always @(*) begin
    inst_code = `INST_INVALID;

    casez(inst)
        32'bzzzzzzz_zzzzz_zzzzz_zzz_zzzzz_01101_11: inst_code = `INST_LUI;
        32'bzzzzzzz_zzzzz_zzzzz_zzz_zzzzz_00101_11: inst_code = `INST_AUIPC;
        32'bzzzzzzz_zzzzz_zzzzz_zzz_zzzzz_11011_11: inst_code = `INST_JAL;
        32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_11001_11: inst_code = `INST_JALR;
        32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_11000_11: inst_code = `INST_BEQ;
        32'bzzzzzzz_zzzzz_zzzzz_001_zzzzz_11000_11: inst_code = `INST_BNE;
        32'bzzzzzzz_zzzzz_zzzzz_100_zzzzz_11000_11: inst_code = `INST_BLT;
        32'bzzzzzzz_zzzzz_zzzzz_101_zzzzz_11000_11: inst_code = `INST_BGE;
        32'bzzzzzzz_zzzzz_zzzzz_110_zzzzz_11000_11: inst_code = `INST_BLTU;
        32'bzzzzzzz_zzzzz_zzzzz_111_zzzzz_11000_11: inst_code = `INST_BGEU;
        32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00000_11: inst_code = `INST_LB;
        32'bzzzzzzz_zzzzz_zzzzz_001_zzzzz_00000_11: inst_code = `INST_LH;
        32'bzzzzzzz_zzzzz_zzzzz_010_zzzzz_00000_11: inst_code = `INST_LW;
        32'bzzzzzzz_zzzzz_zzzzz_100_zzzzz_00000_11: inst_code = `INST_LBU;
        32'bzzzzzzz_zzzzz_zzzzz_101_zzzzz_00000_11: inst_code = `INST_LHU;
        32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_01000_11: inst_code = `INST_SB;
        32'bzzzzzzz_zzzzz_zzzzz_001_zzzzz_01000_11: inst_code = `INST_SH;
        32'bzzzzzzz_zzzzz_zzzzz_010_zzzzz_01000_11: inst_code = `INST_SW;
        32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_ADDI;
        32'bzzzzzzz_zzzzz_zzzzz_010_zzzzz_00100_11: inst_code = `INST_SLTI;
        32'bzzzzzzz_zzzzz_zzzzz_011_zzzzz_00100_11: inst_code = `INST_SLTIU;
        32'bzzzzzzz_zzzzz_zzzzz_100_zzzzz_00100_11: inst_code = `INST_XORI;
        32'bzzzzzzz_zzzzz_zzzzz_110_zzzzz_00100_11: inst_code = `INST_ORI;
        32'bzzzzzzz_zzzzz_zzzzz_111_zzzzz_00100_11: inst_code = `INST_ANDI;
        32'b0000000_zzzzz_zzzzz_001_zzzzz_00100_11: inst_code = `INST_SLLI;
        32'b0000000_zzzzz_zzzzz_101_zzzzz_00100_11: inst_code = `INST_SRLI;
        32'b0100000_zzzzz_zzzzz_101_zzzzz_00100_11: inst_code = `INST_SRAI;
        32'b0000000_zzzzz_zzzzz_000_zzzzz_01100_11: inst_code = `INST_ADD;
        32'b0100000_zzzzz_zzzzz_000_zzzzz_01100_11: inst_code = `INST_SUB;
        32'b0000000_zzzzz_zzzzz_001_zzzzz_01100_11: inst_code = `INST_SLL;
        32'b0000000_zzzzz_zzzzz_010_zzzzz_01100_11: inst_code = `INST_SLT;
        32'b0000000_zzzzz_zzzzz_011_zzzzz_01100_11: inst_code = `INST_SLTU;
        32'b0000000_zzzzz_zzzzz_100_zzzzz_01100_11: inst_code = `INST_XOR;
        32'b0000000_zzzzz_zzzzz_101_zzzzz_01100_11: inst_code = `INST_SRL;
        32'b0100000_zzzzz_zzzzz_101_zzzzz_01100_11: inst_code = `INST_SRA;
        32'b0000000_zzzzz_zzzzz_110_zzzzz_01100_11: inst_code = `INST_OR;
        32'b0000000_zzzzz_zzzzz_111_zzzzz_01100_11: inst_code = `INST_AND;
        // 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_FENCE;
        // 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_FENCE;
        32'b0000000_00000_00000_000_00000_11100_11: inst_code = `INST_ECALL;
        32'b0000000_00001_00000_000_00000_11100_11: inst_code = `INST_EBREAK;
        32'bzzzzzzz_zzzzz_zzzzz_001_zzzzz_11100_11: inst_code = `INST_CSRRW;
        32'bzzzzzzz_zzzzz_zzzzz_010_zzzzz_11100_11: inst_code = `INST_CSRRS;
        // 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRC;
        // 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRWI;
        // 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRSI;
        // 32'bzzzzzzz_zzzzz_zzzzz_000_zzzzz_00100_11: inst_code = `INST_CSRRCI;
        32'b0000001_zzzzz_zzzzz_000_zzzzz_01100_11: inst_code = `INST_MUL;
        32'b0000001_zzzzz_zzzzz_001_zzzzz_01100_11: inst_code = `INST_MULH;
        32'b0000001_zzzzz_zzzzz_010_zzzzz_01100_11: inst_code = `INST_MULHSU;
        32'b0000001_zzzzz_zzzzz_011_zzzzz_01100_11: inst_code = `INST_MULHU;
        32'b0000001_zzzzz_zzzzz_100_zzzzz_01100_11: inst_code = `INST_DIV;
        32'b0000001_zzzzz_zzzzz_101_zzzzz_01100_11: inst_code = `INST_DIVU;
        32'b0000001_zzzzz_zzzzz_110_zzzzz_01100_11: inst_code = `INST_REM;
        32'b0000001_zzzzz_zzzzz_111_zzzzz_01100_11: inst_code = `INST_REMU;
        
        // Privileged Instructions ref. RISC-V开放架构设计之道-V1.0.0 p101
        32'b0011000_00010_00000_000_00000_11100_11: inst_code = `INST_MRET;

        default:  inst_code = `INST_INVALID;
    endcase
end

// // 生成指令代码
// assign inst_code =
//     (opcode==7'b01101_11) ? `INST_LUI : 
//     (opcode==7'b00101_11) ? `INST_AUIPC : 
//     (opcode==7'b11011_11) ? `INST_JAL : 
//     (opcode==7'b11001_11) && (funct3==3'b000) ? `INST_JALR : 
//     (opcode==7'b11000_11) && (funct3==3'b000) ? `INST_BEQ : 
//     (opcode==7'b11000_11) && (funct3==3'b001) ? `INST_BNE : 
//     (opcode==7'b11000_11) && (funct3==3'b100) ? `INST_BLT : 
//     (opcode==7'b11000_11) && (funct3==3'b101) ? `INST_BGE : 
//     (opcode==7'b11000_11) && (funct3==3'b110) ? `INST_BLTU : 
//     (opcode==7'b11000_11) && (funct3==3'b111) ? `INST_BGEU : 
//     // (opcode==7'b00000_00) ? `INST_LB : 
//     // (opcode==7'b00000_00) ? `INST_LH : 
//     (opcode==7'b00000_11) && (funct3==3'b010) ? `INST_LW : 
//     // (opcode==7'b00000_00) ? `INST_LBU : 
//     // (opcode==7'b00000_00) ? `INST_LHU : 
//     // (opcode==7'b00000_00) ? `INST_SB : 
//     // (opcode==7'b00000_00) ? `INST_SH : 
//     (opcode==7'b01000_11) && (funct3==3'b010) ? `INST_SW : 
//     (opcode==7'b00100_11) && (funct3==3'b000) ? `INST_ADDI : 
//     // (opcode==7'b00000_00) ? `INST_SLTI : 
//     (opcode==7'b00100_11) && (funct3==3'b011) ? `INST_SLTIU : 
//     // (opcode==7'b00000_00) ? `INST_XORI : 
//     // (opcode==7'b00000_00) ? `INST_ORI : 
//     (opcode==7'b00100_11) && (funct3==3'b111) ? `INST_ANDI : 
//     (inst==32'b0000000_zzzzz_zzzzz_001_zzzzz_00100_11) ? `INST_SLLI : 
//     // (opcode==7'b00100_11) && (funct3==3'b001) && (funct7==7'b0000000)? `INST_SLLI : 
//     // (opcode==7'b00000_00) ? `INST_SRLI : 
//     // (opcode==7'b00000_00) ? `INST_SRAI : 
//     (opcode==7'b01100_11) && (funct3==3'b000) && (funct7==7'b0000000) ? `INST_ADD : 
//     (opcode==7'b01100_11) && (funct3==3'b000) && (funct7==7'b0100000) ? `INST_SUB : 
//     // (opcode==7'b00000_00) ? `INST_SLL : 
//     // (opcode==7'b00000_00) ? `INST_SLT : 
//     // (opcode==7'b00000_00) ? `INST_SLTU : 
//     // (opcode==7'b00000_00) ? `INST_XOR : 
//     // (opcode==7'b00000_00) ? `INST_SRL : 
//     // (opcode==7'b00000_00) ? `INST_SRA : 
//     // (opcode==7'b00000_00) ? `INST_OR : 
//     // (opcode==7'b00000_00) ? `INST_AND : 
//     // (opcode==7'b00000_00) ? `INST_FENCE : 
//     // (opcode==7'b00000_00) ? `INST_FENCE_I : 
//     // (opcode==7'b00000_00) ? `INST_ECALL : 
//     (opcode==7'b11100_11) && (rd==5'b0) && (funct3==3'b0) && (rs1==5'b0) && (immI==12'b1) ? `INST_EBREAK :
//     // (opcode==7'b00000_00) ? `INST_CSRRW : 
//     // (opcode==7'b00000_00) ? `INST_CSRRS : 
//     // (opcode==7'b00000_00) ? `INST_CSRRC : 
//     // (opcode==7'b00000_00) ? `INST_CSRRWI : 
//     // (opcode==7'b00000_00) ? `INST_CSRRSI : 
//     // (opcode==7'b00000_00) ? `INST_CSRRCI : 
//     // (opcode==7'b00000_00) ? `INST_MUL : 
//     // (opcode==7'b00000_00) ? `INST_MULH : 
//     // (opcode==7'b00000_00) ? `INST_MULHSU : 
//     // (opcode==7'b00000_00) ? `INST_MULHU : 
//     // (opcode==7'b00000_00) ? `INST_DIV : 
//     // (opcode==7'b00000_00) ? `INST_DIVU : 
//     (opcode==7'b01100_11) && (funct3==3'b110) && (funct7==7'b0000001) ? `INST_REM : 
//     // (opcode==7'b00000_00) ? `INST_REMU : 
//     `INST_INVALID;

endmodule
