module top (
    input wire clk,
    input wire rst,
    output wire [31:0] w_pc,
    // output wire [31:0] w_inst,
    // output wire [(`RISCV_INST_WIDTH*`RISCV_CSR_COUNT)-1:0] w_x,
    output wire valid
);

riscv32e_cpu #(
    .INST_WIDTH(`RISCV_INST_WIDTH)
) m_cpu(
    .clk(clk),
    .rst(rst),
    .w_pc(w_pc),
    // .w_inst(w_inst),
    // .w_x(w_x),
    .valid(valid)
);

endmodule