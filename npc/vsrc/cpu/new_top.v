`include "riscv32e_defines.v"

module new_top (
    input wire clk,
    input wire rst
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

/* 模块通信消息 */
wire if_valid;
wire id_ready;
wire id_valid;
wire ex_ready;
wire ex_valid;
wire wb_ready;

/* 取指if */
wire [`RISCV_INST_WIDTH-1:0] if_inst;
inst_fetch #(
    .INST_WIDTH(`RISCV_INST_WIDTH)
) ifu(
    .clk(clk),
    .rst(rst),
    .pc(pc),
    .inst(if_inst),
    .next_ready(id_ready),
    .valid(if_valid)
);

/* 译码id */
wire [4:0] id_rd;
wire [4:0] id_rs1;
wire [4:0] id_rs2;
wire [`RISCV_INST_WIDTH-1:0] id_imm;
wire [15:0] id_inst_code;
inst_decode #(
    .INST_WIDTH(`RISCV_INST_WIDTH)
) idu(
    .clk(clk),
    .rst(rst),

    .inst(if_inst),
    .rd(id_rd),
    .rs1(id_rs1),
    .rs2(id_rs2),
    .imm(id_imm),
    .icode(id_inst_code),

    .next_ready(ex_ready),
    .prev_valid(if_valid),
    .ready(id_ready),
    .valid(id_valid)
);

/* 执行ex */

/* 回写wb */
assign ex_valid = id_valid;
always @(posedge clk or posedge rst)begin
    if (rst) begin
        pc <= get_reset_pc();
    end else begin
        if (ex_valid) begin
            // 默认更新程序寄存器
            pc <= snpc;
            
            // 确保 x0 始终为零
            x[0] <= 0;
        end else begin
            pc <= pc;
        end
    end
end

endmodule