module riscv32e_cpu2 (
    input wire clk,
    input wire rst,
    output wire [31:0] instr_addr,
    input wire [31:0] instr
);

    // 程序计数器
    reg [31:0] pc;

    // 寄存器文件
    reg [31:0] regfile [0:31];

    // 指令字段分解
    wire [6:0] opcode = instr[6:0];
    wire [4:0] rd     = instr[11:7];
    wire [2:0] funct3 = instr[14:12];
    wire [4:0] rs1    = instr[19:15];
    wire [4:0] rs2    = instr[24:20];
    wire [6:0] funct7 = instr[31:25];

    // 立即数生成
    wire [31:0] imm_i = {{20{instr[31]}}, instr[31:20]};         // I类型立即数
    wire [31:0] imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]}; // S类型立即数
    wire [31:0] imm_b = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}; // B类型立即数
    wire [31:0] imm_j = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}; // J类型立即数

    // 寄存器值
    wire [31:0] rs1_val = regfile[rs1];
    wire [31:0] rs2_val = regfile[rs2];

    // ALU 操作结果
    reg [31:0] alu_result;

    // 指令地址
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 0;
        end else begin
            if (opcode == 7'b1100011) begin // BEQ/BNE
                if ((funct3 == 3'b000 && rs1_val == rs2_val) || // BEQ
                    (funct3 == 3'b001 && rs1_val != rs2_val))  // BNE
                    pc <= pc + imm_b;
                else
                    pc <= pc + 4;
            end else if (opcode == 7'b1101111) begin // JAL
                pc <= pc + imm_j;
            end else begin
                pc <= pc + 4;
            end
        end
    end

    assign instr_addr = pc;

    // ALU 逻辑
    always @(*) begin
        case (opcode)
            7'b0110011: begin // R类型
                case (funct3)
                    3'b000: alu_result = (funct7[5] ? rs1_val - rs2_val : rs1_val + rs2_val); // ADD/SUB
                    3'b111: alu_result = rs1_val & rs2_val; // AND
                    3'b110: alu_result = rs1_val | rs2_val; // OR
                    3'b100: alu_result = rs1_val ^ rs2_val; // XOR
                    default: alu_result = 0;
                endcase
            end
            7'b0010011: alu_result = rs1_val + imm_i; // ADDI
            7'b0000011: alu_result = rs1_val + imm_i; // LW
            7'b0100011: alu_result = rs1_val + imm_s; // SW
            default: alu_result = 0;
        endcase
    end

    // 使用 DPI-C 实现内存访问
    import "DPI-C" function int read_mem(input int addr);
    import "DPI-C" function void write_mem(input int addr, input int data);

    always @(posedge clk) begin
        if (opcode == 7'b0000011) begin // LW
            regfile[rd] <= read_mem(alu_result);
        end else if (opcode == 7'b0100011) begin // SW
            write_mem(alu_result, rs2_val);
        end else if (opcode == 7'b0110011 || opcode == 7'b0010011 || opcode == 7'b1101111) begin
            regfile[rd] <= alu_result;
        end
    end

endmodule
