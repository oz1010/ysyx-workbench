`include "riscv32e_defines.v"

module new_top (
    input wire clk,
    input wire rst
);

wire w_cpu_valid;

riscv32e_cpu m_riscv32e_cpu(
    .clk(clk),
    .rst(rst),
    .valid(w_cpu_valid)
);

endmodule