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
    output [15:0] inst_code
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
assign inst_code =
    // (opcode==7'b00000_00) ? `INST_LUI : 
    (opcode==7'b00101_11) ? `INST_AUIPC : 
    (opcode==7'b11011_11) ? `INST_JAL : 
    (opcode==7'b11001_11) && (funct3==3'b000) ? `INST_JALR : 
    (opcode==7'b11000_11) && (funct3==3'b000) ? `INST_BEQ : 
    (opcode==7'b11000_11) && (funct3==3'b001) ? `INST_BNE : 
    // (opcode==7'b00000_00) ? `INST_BLT : 
    (opcode==7'b11000_11) && (funct3==3'b101) ? `INST_BGE : 
    // (opcode==7'b00000_00) ? `INST_BLTU : 
    // (opcode==7'b00000_00) ? `INST_BGEU : 
    // (opcode==7'b00000_00) ? `INST_LB : 
    // (opcode==7'b00000_00) ? `INST_LH : 
    (opcode==7'b00000_11) && (funct3==3'b010) ? `INST_LW : 
    // (opcode==7'b00000_00) ? `INST_LBU : 
    // (opcode==7'b00000_00) ? `INST_LHU : 
    // (opcode==7'b00000_00) ? `INST_SB : 
    // (opcode==7'b00000_00) ? `INST_SH : 
    (opcode==7'b01000_11) && (funct3==3'b010) ? `INST_SW : 
    (opcode==7'b00100_11) && (funct3==3'b000) ? `INST_ADDI : 
    // (opcode==7'b00000_00) ? `INST_SLTI : 
    (opcode==7'b00100_11) && (funct3==3'b011) ? `INST_SLTIU : 
    // (opcode==7'b00000_00) ? `INST_XORI : 
    // (opcode==7'b00000_00) ? `INST_ORI : 
    // (opcode==7'b00000_00) ? `INST_ANDI : 
    // (opcode==7'b00000_00) ? `INST_SLLI : 
    // (opcode==7'b00000_00) ? `INST_SRLI : 
    // (opcode==7'b00000_00) ? `INST_SRAI : 
    (opcode==7'b01100_11) && (funct3==3'b000) && (funct7==7'b0000000) ? `INST_ADD : 
    (opcode==7'b01100_11) && (funct3==3'b000) && (funct7==7'b0100000) ? `INST_SUB : 
    // (opcode==7'b00000_00) ? `INST_SLL : 
    // (opcode==7'b00000_00) ? `INST_SLT : 
    // (opcode==7'b00000_00) ? `INST_SLTU : 
    // (opcode==7'b00000_00) ? `INST_XOR : 
    // (opcode==7'b00000_00) ? `INST_SRL : 
    // (opcode==7'b00000_00) ? `INST_SRA : 
    // (opcode==7'b00000_00) ? `INST_OR : 
    // (opcode==7'b00000_00) ? `INST_AND : 
    // (opcode==7'b00000_00) ? `INST_FENCE : 
    // (opcode==7'b00000_00) ? `INST_FENCE_I : 
    // (opcode==7'b00000_00) ? `INST_ECALL : 
    (opcode==7'b11100_11) && (rd==5'b0) && (funct3==3'b0) && (rs1==5'b0) && (immI==12'b1) ? `INST_EBREAK :
    // (opcode==7'b00000_00) ? `INST_CSRRW : 
    // (opcode==7'b00000_00) ? `INST_CSRRS : 
    // (opcode==7'b00000_00) ? `INST_CSRRC : 
    // (opcode==7'b00000_00) ? `INST_CSRRWI : 
    // (opcode==7'b00000_00) ? `INST_CSRRSI : 
    // (opcode==7'b00000_00) ? `INST_CSRRCI : 
    // (opcode==7'b00000_00) ? `INST_MUL : 
    // (opcode==7'b00000_00) ? `INST_MULH : 
    // (opcode==7'b00000_00) ? `INST_MULHSU : 
    // (opcode==7'b00000_00) ? `INST_MULHU : 
    // (opcode==7'b00000_00) ? `INST_DIV : 
    // (opcode==7'b00000_00) ? `INST_DIVU : 
    // (opcode==7'b00000_00) ? `INST_REM : 
    // (opcode==7'b00000_00) ? `INST_REMU : 
    `INST_INVALID;

endmodule
