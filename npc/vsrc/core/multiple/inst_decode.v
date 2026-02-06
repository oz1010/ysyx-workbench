module inst_decode #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32
) (
    input wire                          clk,
    input wire                          rst,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [ADDR_WIDTH-1:0]       in_pc,
    input   wire [INST_WIDTH-1:0]       in_inst,
    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [ADDR_WIDTH-1:0]       out_pc,
    output  wire [INST_WIDTH-1:0]       out_inst,
    output  wire [4:0]                  out_rd,
    output  wire [4:0]                  out_rs1,
    output  wire [4:0]                  out_rs2,
    output  wire [INST_WIDTH-1:0]       out_imm,
    output  wire [`INST_CODE_W-1:0]     out_inst_code
);

    localparam STAGE_IN_DATA_W = ADDR_WIDTH + INST_WIDTH;

    wire [STAGE_IN_DATA_W-1:0]      stage_in_bits;
    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    wire [`INNER_CON_STATE_W-1:0]   stage_state;
    wire [ADDR_WIDTH-1:0]           pc;
    wire [INST_WIDTH-1:0]           inst;

    inner_con #(
        .IN_DATA_STORAGE(1),
        .IN_DATA_W(STAGE_IN_DATA_W)
    ) id_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_bits({in_pc, in_inst}),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_bits(stage_in_bits),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done),
        .stage_state(stage_state)
    );

    assign {pc, inst} = stage_in_bits;
    assign {out_pc, out_inst, out_rd, out_rs1, out_rs2, out_imm, out_inst_code} = {pc, inst, rd, rs1, rs2, imm, inst_code};

    // 定义内部信号
    wire [6:0] opcode;
    wire [4:0] rd;
    wire [INST_WIDTH-1:0] imm;
    wire [2:0] funct3;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [6:0] funct7;
    wire [2:0] inst_type;
    reg [`INST_CODE_W-1:0] inst_code;

    // 提取字段
    assign opcode = inst[6:0];
    assign rd = inst[11:7];
    assign funct3 = inst[14:12];
    assign rs1 = inst[19:15];
    assign rs2 = inst[24:20];
    assign funct7 = inst[INST_WIDTH-1:25];

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
    wire [11:0] immI = inst[INST_WIDTH-1:20];
    wire [11:0] immS = {inst[INST_WIDTH-1:25], inst[11:7]};
    wire [12:0] immB = {inst[INST_WIDTH-1], inst[7], inst[30:25], inst[11:8], 1'b0};
    wire [INST_WIDTH-1:0] immU = {inst[INST_WIDTH-1:12], {12{1'b0}}};
    wire [20:0] immJ = {inst[INST_WIDTH-1], inst[19:12], inst[20], inst[30:21], 1'b0};
    assign imm = 
        (inst_type==`TYPE_I) ? {{20{immI[11]}}, immI} :
        (inst_type==`TYPE_S) ? {{20{immS[11]}}, immS} :
        (inst_type==`TYPE_B) ? {{19{immB[12]}}, immB} :
        (inst_type==`TYPE_U) ? immU :
        (inst_type==`TYPE_J) ? {{11{immJ[20]}}, immJ} :
        32'b0;

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
            32'b0000000_00000_00000_001_00000_00011_11: inst_code = `INST_FENCE_I;
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

    always @(posedge clk) begin
        if (rst) begin
            r_stage_out_valid <= 0;
        end else begin
            r_stage_out_valid <= stage_in_done ? 1 : 0;
        end
    end

endmodule
