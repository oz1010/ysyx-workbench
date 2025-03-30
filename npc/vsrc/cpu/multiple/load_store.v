module load_store #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [15:0] inst_code,

    input wire [INST_WIDTH-1:0] inst,
    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] dnpc,

    input wire [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0],
    output wire [INST_WIDTH-1:0] result,
    output wire [7:0] mem_result_width,
    output wire result_update_csr,

    output wire prev_ready,
    input wire prev_valid,
    input wire next_ready,
    output wire next_valid
);

wire [1:0] w_ls_prev_state, w_ls_next_state;

scom m_scom_ex(
    .clk(clk),
    .rst(rst),
    .prev_ready(prev_ready),
    .prev_valid(prev_valid),
    .next_ready(next_ready),
    .next_valid(next_valid),
    .prev_state(w_ls_prev_state),
    .next_state(w_ls_next_state)
);

reg [INST_WIDTH-1:0] r_dnpc;
reg [INST_WIDTH-1:0] r_result;
reg [7:0] r_result_mem_width;
reg r_result_update_csr;

assign dnpc = r_dnpc;
assign result = r_result;
assign mem_result_width = r_result_mem_width;
assign result_update_csr = r_result_update_csr;

wire [31:0] src1 = x[rs1];
wire [31:0] src2 = x[rs2];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_dnpc <= get_reset_pc();
        r_result <= 0;
        r_result_mem_width <= 0;
        r_result_update_csr <= 0;
    end else begin
        r_dnpc <= r_dnpc;
        r_result <= r_result;
        r_result_mem_width <= r_result_mem_width;
        r_result_update_csr <= r_result_update_csr;

        if (w_ls_prev_state == `SCOM_FOUND) begin
            // 默认更新程序寄存器
            r_dnpc <= pc + 4;
            r_result <= 0;
            r_result_mem_width <= 0;
            r_result_update_csr <= 1;

            case (inst_code)
                `INST_LB:           r_result <= sext(read_raw_mem(src1 + imm, 1), 8);
                `INST_LH:           r_result <= sext(read_raw_mem(src1 + imm, 2), 16);
                `INST_LW:           r_result <= sext(read_raw_mem(src1 + imm, 4), 32);
                `INST_LBU:          r_result <= read_raw_mem(src1 + imm, 1) & 32'hFF;
                `INST_LHU:          r_result <= read_raw_mem(src1 + imm, 2) & 32'hFFFF;
                `INST_SB:           begin write_raw_mem(src1 + imm, 1, src2&32'hFF); r_result_update_csr <= 0; end
                `INST_SH:           begin write_raw_mem(src1 + imm, 2, src2&32'hFFFF); r_result_update_csr <= 0; end
                `INST_SW:           begin write_raw_mem(src1 + imm, 4, src2); r_result_update_csr <= 0; end
                default: ;
            endcase
        end
    end
end
endmodule