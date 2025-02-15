module riscv32e_cpu (
    input wire clk,
    input wire rst,
    output wire valid
);

/* 寄存器组 */
// 通用寄存器
reg [`RISCV_INST_WIDTH-1:0] x[`RISCV_INST_WIDTH-1:0];
// 程序寄存器
reg [`RISCV_INST_WIDTH-1:0] pc;
wire [`RISCV_INST_WIDTH-1:0] snpc = pc + 4;
// 当前指令寄存器
reg [`RISCV_INST_WIDTH-1:0] inst;
// // ALU结果
// reg [`RISCV_INST_WIDTH-1:0] alu_result;
// 寄存器别名，register alias, ch2.3
wire [`RISCV_INST_WIDTH-1:0] zero = x[0];
wire [`RISCV_INST_WIDTH-1:0] ra = x[1];
wire [`RISCV_INST_WIDTH-1:0] sp = x[2];
wire [`RISCV_INST_WIDTH-1:0] gp = x[3];
wire [`RISCV_INST_WIDTH-1:0] tp = x[4];
wire [`RISCV_INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];

/* 模块通信消息 */
wire if_valid;
wire id_ready;
wire id_valid;
wire ex_ready;
wire ex_valid;
wire wb_ready;
assign valid = wb_ready;

/* 取指if */
// wire [`RISCV_INST_WIDTH-1:0] if_inst;
inst_fetch #(
    .INST_WIDTH(`RISCV_INST_WIDTH)
) ifu(
    .clk(clk),
    .rst(rst),
    .pc(pc),
    .inst(inst),
    .next_ready(id_ready),
    .next_valid(if_valid)
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

    .inst(inst),
    .rd(id_rd),
    .rs1(id_rs1),
    .rs2(id_rs2),
    .imm(id_imm),
    .icode(id_inst_code),

    .prev_ready(id_ready),
    .prev_valid(if_valid),
    .next_ready(ex_ready),
    .next_valid(id_valid)
);

/* 执行ex */
wire [1:0] w_ex_prev_state, w_ex_next_state;
scom m_scom_ex(
    .clk(clk),
    .rst(rst),
    .prev_ready(ex_ready),
    .prev_valid(id_valid),
    .next_ready(wb_ready),
    .next_valid(ex_valid),
    .prev_state(w_ex_prev_state),
    .next_state(w_ex_next_state)
);

/* 回写wb */
wire [1:0] w_wb_prev_state;
scom_recv m_scom_wb(
    .clk(clk),
    .rst(rst),
    .enable(ex_valid),
    .prev_ready(wb_ready),
    .prev_valid(ex_valid),
    .state(w_wb_prev_state)
);
always @(posedge clk or posedge rst)begin
    if (rst) begin
        pc <= get_reset_pc();
    end else begin
        if (w_wb_prev_state == `SCOM_FOUND) begin
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