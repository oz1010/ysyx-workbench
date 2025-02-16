import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function int fetch_inst(input int addr);
import "DPI-C" function void write_raw_mem(input int addr, input int len, input int inst);
import "DPI-C" function int read_raw_mem(input int addr, input int len);
import "DPI-C" function int get_reset_pc();
import "DPI-C" function int sext(input int x, input int len);
import "DPI-C" function void write_raw_csr(input int idx, input int data);
import "DPI-C" function int read_raw_csr(input int idx);
import "DPI-C" function int dpi_raise_intr(input int NO, input int epc);
import "DPI-C" function int dpi_query_intr();

`include "common/riscv32e_defines.v"

module top (
    input wire clk,
    input wire rst,
    output wire [`RISCV_INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0],
    output wire [`RISCV_INST_WIDTH-1:0] pc,
    output wire valid
);

riscv32e_cpu #(
    .INST_WIDTH(`RISCV_INST_WIDTH)
) m_cpu(
    .clk(clk),
    .rst(rst),
    .w_pc(pc),
    .w_x(x),
    .valid(valid)
);

endmodule
