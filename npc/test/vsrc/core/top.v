`ifndef IN_YOSYS_STA
import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function void dpi_cpu_stat_ctrl(input int dtype, input int delta);
import "DPI-C" function int fetch_inst(input int addr);
import "DPI-C" function void write_raw_mem(input int addr, input int len, input int inst);
import "DPI-C" function int read_raw_mem(input int addr, input int len);
import "DPI-C" function int get_reset_pc();
import "DPI-C" function int sext(input int x, input int len);
import "DPI-C" function void write_raw_csr(input int idx, input int data);
import "DPI-C" function int read_raw_csr(input int idx);
import "DPI-C" function int dpi_raise_intr(input int NO, input int epc);
import "DPI-C" function int dpi_query_intr();
import "DPI-C" function void dpi_uart_write(input int addr, input int len, input int inst);
import "DPI-C" function int dpi_rtc_read(input int addr, input int len);
import "DPI-C" function void dpi_dev_skip(input int write, input int addr, input int req_info, input int data);
import "DPI-C" function int dpi_test_intf(input int write, input int addr, input int len, input int data);
import "DPI-C" function void dpi_psram_write(input int addr, input int len, input int data);
import "DPI-C" function int dpi_psram_read(input int addr, input int len);
import "DPI-C" function int dpi_check_dev_addr(input int addr, input int attr);
import "DPI-C" function int dpi_vdev_read(input int addr, input int len);
import "DPI-C" function void dpi_vdev_write(input int addr, input int data, input int len);
import "DPI-C" function void dpi_monitor_item(input int item_idx, input int id, input int delta);
`endif

`include "riscv32e_defines.v"

module test_timeout ();
initial begin
#100;
$display("This is normal exit for timeout.");
$finish; 
end
endmodule

module top (
    input  wire         clock,
    input  wire         reset,
    output wire         valid
);

test_get_unalign_parameter case0(.case_num(0));
test_cache_line case1(.case_num(1));
test_cache_block case2(.case_num(2));
test_cache case3(.case_num(3));
test_timeout casetimeout();

endmodule
