// 单周期处理器
module riscv32e_cpu #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    output wire [INST_WIDTH-1:0] w_pc,
    output wire [INST_WIDTH-1:0] w_x[`RISCV_CSR_COUNT-1:0],
    output wire valid
);

/* 寄存器组 */
reg [INST_WIDTH-1:0] r_inst;

/* 常用处理器信号 */
wire [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0];
wire [INST_WIDTH-1:0] pc;

assign valid = 1;
assign w_pc = pc;
assign w_x = x;

/* 取指 */
always @(*) begin
    if (rst) begin
        r_inst = 32'b0;
    end else begin
        r_inst = fetch_inst(pc);
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
decoder risc32e_decoder(r_inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

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

write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .inst(r_inst),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .w_x(x),
    .w_pc(pc)
);

endmodule