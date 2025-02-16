// 单流水线多周期处理器
module riscv32e_cpu #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    // output wire [INST_WIDTH-1:0] w_pc,
    // output wire [INST_WIDTH-1:0] w_x[`RISCV_CSR_COUNT-1:0],
    output wire valid
);

/* 模块通信消息 */
wire if_valid;
wire id_ready;
wire id_valid;
wire ex_ready;
wire ex_valid;
wire wb_ready;

/* 常用处理器信号 */
wire [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0];
wire [INST_WIDTH-1:0] pc;
wire [INST_WIDTH-1:0] inst;
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];

assign valid = wb_ready;
// assign w_x = x;
// assign w_pc = pc;

/* 取指if */
inst_fetch #(
    .INST_WIDTH(INST_WIDTH)
) ifu(
    .clk(clk),
    .rst(rst),

    .pc(pc),
    .inst(inst),

    .next_ready(id_ready),
    .next_valid(if_valid)
);

/* 译码id */
wire [4:0] rd;
wire [4:0] rs1;
wire [4:0] rs2;
wire [INST_WIDTH-1:0] imm;
wire [15:0] inst_code;
inst_decode #(
    .INST_WIDTH(INST_WIDTH)
) idu(
    .clk(clk),
    .rst(rst),

    .inst(inst),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .icode(inst_code),

    .prev_ready(id_ready),
    .prev_valid(if_valid),
    .next_ready(ex_ready),
    .next_valid(id_valid)
);

/* 执行ex */
wire [INST_WIDTH-1:0] result, dnpc;
wire [7:0] mem_result_width;
wire result_update_csr;
execute #(
    .INST_WIDTH(INST_WIDTH)
) exu(
    .clk(clk),
    .rst(rst),

    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .dnpc(dnpc),
    .x(x),
    .result(result),
    .mem_result_width(mem_result_width),
    .result_update_csr(result_update_csr),

    .prev_ready(ex_ready),
    .prev_valid(id_valid),
    .next_ready(wb_ready),
    .next_valid(ex_valid)
);

/* 回写wb */
write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .w_x(x),
    .result(result),
    .mem_result_width(mem_result_width),
    .result_update_csr(result_update_csr),
    .dnpc(dnpc),
    .w_pc(pc),

    .prev_ready(wb_ready),
    .prev_valid(ex_valid)
);

endmodule