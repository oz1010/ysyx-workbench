module write_back #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clock,
    input wire reset,

    input wire [4:0] rd,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [15:0] inst_code,

    output wire [INST_WIDTH-1:0] w_x[`RISCV_CSR_COUNT-1:0],
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
reg [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0];
// 程序寄存器
reg [INST_WIDTH-1:0] pc;
// 当前指令寄存器
wire [INST_WIDTH-1:0] inst;
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];

wire [1:0] w_wb_prev_state;
wire [INST_WIDTH-1:0] w_mem_result_width = {{INST_WIDTH-8{1'b0}}, mem_result_width};
assign w_x = x;
assign w_pc = pc;
wire [INST_WIDTH-1:0] src1 = x[rs1];

reg r_prev_ready;
reg [7:0] cnt;


assign prev_ready = r_prev_ready;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        pc <= get_reset_pc();
        x[0] <= 0;
        r_prev_ready <= 0;
    end else begin

        if (prev_valid) begin
            if (w_mem_result_width > 0) begin
            end else begin
                if (result_update_csr) x[rd] <= result;

                pc <= dnpc;
                r_prev_ready <= 1;
            end
        end

        if (prev_valid && prev_ready) begin
            r_prev_ready <= 0;
        end

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule