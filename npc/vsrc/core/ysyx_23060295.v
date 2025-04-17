import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function void dpi_execute_time_ctrl(input int delta);
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

`include "riscv32e_defines.v"

module ysyx_23060295 (
    input  wire         clock,
    input  wire         reset,

    /* 外部中断 */
    input  wire         io_interrupt,
    /* AXI4 Master总线 */
    input  wire         io_master_awready,
    output wire         io_master_awvalid,
    output wire [31:0]  io_master_awaddr,
    output wire [3:0]   io_master_awid,
    output wire [7:0]   io_master_awlen,
    output wire [2:0]   io_master_awsize,
    output wire [1:0]   io_master_awburst,
    input  wire         io_master_wready,
    output wire         io_master_wvalid,
    output wire [31:0]  io_master_wdata,
    output wire [3:0]   io_master_wstrb,
    output wire         io_master_wlast,
    output wire         io_master_bready,
    input  wire         io_master_bvalid,
    input  wire [1:0]   io_master_bresp,
    input  wire [3:0]   io_master_bid,
    input  wire         io_master_arready,
    output wire         io_master_arvalid,
    output wire [31:0]  io_master_araddr,
    output wire [3:0]   io_master_arid,
    output wire [7:0]   io_master_arlen,
    output wire [2:0]   io_master_arsize,
    output wire [1:0]   io_master_arburst,
    output wire         io_master_rready,
    input  wire         io_master_rvalid,
    input  wire [1:0]   io_master_rresp,
    input  wire [31:0]  io_master_rdata,
    input  wire         io_master_rlast,
    input  wire [3:0]   io_master_rid,
    /* AXI4 Slave总线 */
    output wire         io_slave_awready,
    input  wire         io_slave_awvalid,
    input  wire [31:0]  io_slave_awaddr,
    input  wire [3:0]   io_slave_awid,
    input  wire [7:0]   io_slave_awlen,
    input  wire [2:0]   io_slave_awsize,
    input  wire [1:0]   io_slave_awburst,
    output wire         io_slave_wready,
    input  wire         io_slave_wvalid,
    input  wire [31:0]  io_slave_wdata,
    input  wire [3:0]   io_slave_wstrb,
    input  wire         io_slave_wlast,
    input  wire         io_slave_bready,
    output wire         io_slave_bvalid,
    output wire [1:0]   io_slave_bresp,
    output wire [3:0]   io_slave_bid,
    output wire         io_slave_arready,
    input  wire         io_slave_arvalid,
    input  wire [31:0]  io_slave_araddr,
    input  wire [3:0]   io_slave_arid,
    input  wire [7:0]   io_slave_arlen,
    input  wire [2:0]   io_slave_arsize,
    input  wire [1:0]   io_slave_arburst,
    input  wire         io_slave_rready,
    output wire         io_slave_rvalid,
    output wire [1:0]   io_slave_rresp,
    output wire [31:0]  io_slave_rdata,
    output wire         io_slave_rlast,
    output wire [3:0]   io_slave_rid
);

// TODO awvalid必须拉高，避免ysyxSOC报错
assign io_master_awvalid = 1;

wire clk = clock;
wire rst = reset;

// 检测core是否陷入循环，默认但指令执行周期比较短暂
reg [31:0] core_inst_stuck_tick[`RISCV_CORE_NUM-1:0];
wire core_inst_done[`RISCV_CORE_NUM-1:0];
wire [31:0] core_pc[`RISCV_CORE_NUM-1:0];
generate
    for (genvar i=0; i<`RISCV_CORE_NUM; ++i) begin : m_core_loop_check
        always @(posedge clk or posedge rst) begin
            if (rst) begin
                core_inst_stuck_tick[i] <= 0;
            end else begin
                core_inst_stuck_tick[i] <= core_inst_done[i] ? 0 : core_inst_stuck_tick[i] + 1;
                if (core_inst_stuck_tick[i] >= 100) begin
                    $error("Maybe core%-2d is in forever-loop, pc:0x%x ticks:%-d\n", i, core_pc[i], core_inst_stuck_tick[i]);
                end
            end
        end
    end
endgenerate

riscv32e_core #(
    .INST_WIDTH(`RISCV_INST_WIDTH)
) ysyx_23060295_CORE0(
    .clk(clk),
    .rst(rst),

    .io_interrupt(0),
    .io_master_awready(0),
    .io_master_awvalid(),
    .io_master_awaddr(),
    .io_master_awid(),
    .io_master_awlen(),
    .io_master_awsize(),
    .io_master_awburst(),
    .io_master_wready(0),
    .io_master_wvalid(),
    .io_master_wdata(),
    .io_master_wstrb(),
    .io_master_wlast(),
    .io_master_bready(),
    .io_master_bvalid(0),
    .io_master_bresp(0),
    .io_master_bid(0),
    .io_master_arready(0),
    .io_master_arvalid(),
    .io_master_araddr(),
    .io_master_arid(),
    .io_master_arlen(),
    .io_master_arsize(),
    .io_master_arburst(),
    .io_master_rready(),
    .io_master_rvalid(0),
    .io_master_rresp(0),
    .io_master_rdata(0),
    .io_master_rlast(0),
    .io_master_rid(0),

    .pc(core_pc[0]),
    .valid(core_inst_done[0])
);

endmodule
