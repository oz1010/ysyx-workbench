module riscv32e (
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
    reg [31:0] data;
    // 寄存器别名，register alias, ch2.3
    wire [31:0] zero = x[0];
    wire [31:0] ra = x[1];
    wire [31:0] sp = x[2];
    wire [31:0] gp = x[3];
    wire [31:0] tp = x[4];
    wire [31:0] a[7:0];
    assign a[7:0] = x[17:10];

    /* 取指 */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            data <= 32'b0;
        end else begin
            data <= Mr(pc, 4);
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
    decoder risc32e_decoder(data, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

    /* 执行 */

    /* 更新 */
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= get_reset_pc();
        end else begin
            pc <= pc + 4;
        end
    end
endmodule
