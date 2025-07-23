module write_back #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    input wire [4:0] rd,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [15:0] inst_code,

    output wire [INST_WIDTH*`RISCV_CSR_COUNT-1:0] w_x,
    input wire [INST_WIDTH-1:0] result,
    input wire [7:0] mem_result_width,
    input wire result_update_csr,
    input wire [INST_WIDTH-1:0] dnpc,
    output wire [INST_WIDTH-1:0] w_pc,

    output wire prev_ready,
    input wire prev_valid
);

/* 寄存器组 */
// 通用寄存器
reg [INST_WIDTH-1:0] xs[0:`RISCV_CSR_COUNT-1];
// 程序寄存器
reg [INST_WIDTH-1:0] pc = 0;
// 当前指令寄存器
wire [INST_WIDTH-1:0] inst;
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = xs[0];
wire [INST_WIDTH-1:0] ra = xs[1];
wire [INST_WIDTH-1:0] sp = xs[2];
wire [INST_WIDTH-1:0] gp = xs[3];
wire [INST_WIDTH-1:0] tp = xs[4];
wire [INST_WIDTH-1:0] a[0:7];

generate
    for (genvar i = 0; i<`RISCV_CSR_COUNT; ++i) begin
        assign w_x[i*INST_WIDTH +: INST_WIDTH] = xs[i];
    end
    // a0-7 = xs10-17
    for (genvar i = 0; i<8; ++i) begin
        assign a[i] = xs[i+10];
    end
endgenerate

wire [1:0] w_wb_prev_state;
wire [INST_WIDTH-1:0] w_mem_result_width = {{INST_WIDTH-8{1'b0}}, mem_result_width};
assign w_pc = pc;
wire [INST_WIDTH-1:0] src1 = xs[rs1];

reg r_prev_ready;
reg [7:0] cnt;


assign prev_ready = r_prev_ready;

always @(posedge clk) begin
    if (rst) begin
        pc <= func_get_reset_pc();
        xs[0] <= 0;
        r_prev_ready <= 0;
    end else begin

        if (prev_valid) begin
            if (w_mem_result_width > 0) begin
            end else begin
                if (result_update_csr) xs[rd] <= result;

                pc <= dnpc;
                r_prev_ready <= 1;
            end
        end

        if (prev_valid && prev_ready) begin
            r_prev_ready <= 0;
        end

        // 确保 x0 始终为零
        xs[0] <= 0;
    end
end

endmodule
