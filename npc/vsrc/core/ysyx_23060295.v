`ifndef IN_YOSYS_STA
// 异常行为触发
import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
// 监控行为
import "DPI-C" function void dpi_cpu_stat_ctrl(input int dtype, input int delta);
import "DPI-C" function void dpi_add_monitor_item(input int mid, input int pc, input int arg);
// 访问设备
import "DPI-C" function int fetch_inst(input int addr);
import "DPI-C" function void write_raw_mem(input int addr, input int len, input int inst);
import "DPI-C" function int read_raw_mem(input int addr, input int len);
import "DPI-C" function void dpi_uart_write(input int addr, input int len, input int inst);
import "DPI-C" function int dpi_rtc_read(input int addr, input int len);
import "DPI-C" function void dpi_dev_skip(input int write, input int addr, input int req_info, input int data);
import "DPI-C" function int dpi_test_intf(input int write, input int addr, input int len, input int data); // 测试代码
import "DPI-C" function void dpi_psram_write(input int addr, input int len, input int data);
import "DPI-C" function int dpi_psram_read(input int addr, input int len);
import "DPI-C" function int dpi_vdev_read(input int addr, input int len);
import "DPI-C" function void dpi_vdev_write(input int addr, input int data, input int len);
// 硬件行为模拟，让硬件和软件行为保持一致
import "DPI-C" function int get_reset_pc();
// 辅助函数，让硬件和软件行为保持一致
import "DPI-C" function int sext(input int x, input int len);
import "DPI-C" function int dpi_check_dev_addr(input int addr, input int attr);
`endif

`include "riscv32e_defines.v"

module ysyx_23060295 (
    input  wire         clock,
    input  wire         reset /* verilator public_flat_rd */,

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
`ifdef NETLIST
    ,
    output wire [31:0]  iv_core_pc,
    output wire [31:0]  iv_core_inst_pc,
    output wire         iv_core_inst_done,
    output wire         iv_gpr_wen,
    output wire [3:0]   iv_gpr_waddr,
    output wire [31:0]  iv_gpr_wdata,
    output wire [31:0]  iv_gpr_a0,
    output wire [31:0]  iv_gpr_a1,
    output wire [31:0]  iv_gpr_a2,
    output wire         iv_csr_wen,
    output wire [11:0]  iv_csr_waddr,
    output wire [31:0]  iv_csr_wdata,
    output wire         iv_trap_en,
    output wire [31:0]  iv_trap_epc,
    output wire [31:0]  iv_trap_cause,
    output wire [31:0]  iv_trap_tval,
    output wire [31:0]  iv_trap_status
`endif
);

    localparam ADDR_WIDTH = 32;
    localparam INST_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    assign io_slave_awready = 0;
    assign io_slave_wready = 0;
    assign io_slave_bvalid = 0;
    assign io_slave_bresp = 0;
    assign io_slave_bid = 0;
    assign io_slave_arready = 0;
    assign io_slave_rvalid = 0;
    assign io_slave_rresp = 0;
    assign io_slave_rdata = 0;
    assign io_slave_rlast = 0;
    assign io_slave_rid = 0;

    // 检测core是否陷入循环，默认但指令执行周期比较短暂
    wire [31:0] core_pc[`RISCV_CORE_NUM-1:0] /* verilator public_flat_rd */; // 指向下一周期待执行的指令地址，在命令执行完成前为当前指令地址
    wire [31:0] core_inst_pc[`RISCV_CORE_NUM-1:0] /* verilator public_flat_rd */; // 指向执行完的指令对应的地址
    wire core_inst_done[`RISCV_CORE_NUM-1:0] /* verilator public_flat_rd */; // 指示是否完成一条指令
    `ifndef IN_YOSYS_STA
    reg [31:0] core_inst_stuck_tick[`RISCV_CORE_NUM-1:0];
    reg core_error[`RISCV_CORE_NUM-1:0] /*verilator public_flat_rw*/;
    generate
        for (genvar i=0; i<`RISCV_CORE_NUM; ++i) begin : m_core_loop_check
            always @(posedge clock) begin
                if (reset) begin
                    core_error[i] <= 0;
                    core_inst_stuck_tick[i] <= 0;
                end else begin
                    core_inst_stuck_tick[i] <= core_inst_done[i] ? 0 : core_inst_stuck_tick[i] + 1;
                    if (core_inst_stuck_tick[i] == 5000) begin
                        $display("Maybe core%-2d is in forever-loop, pc:0x%x ticks:%-d", i, core_pc[i], core_inst_stuck_tick[i]);
                        core_error[i] <= 1;
                        // $finish;
                        // $display("Maybe core%-2d is in forever-loop, pc:0x%x ticks:%-d", i, core_pc[i], core_inst_stuck_tick[i]);
                        // $finish;
                    end
                end
            end
        end
    endgenerate
    `endif

    wire [ADDR_WIDTH-1:0]           reset_pc;
    wire                            io_if_flush;
    wire                            io_if_req_valid;
    wire                            io_if_req_ready;
    wire [ADDR_WIDTH-1:0]           io_if_req_addr;
    wire [`MEMOP_W-1:0]             io_if_req_op;
    wire [DATA_WIDTH-1:0]           io_if_req_wdata;
    wire                            io_if_rsp_valid;
    wire                            io_if_rsp_ready;
    wire  [DATA_WIDTH-1:0]          io_if_rsp_data;
    wire                            io_if_rsp_error;
    wire                            io_mem_req_valid;
    wire                            io_mem_req_ready;
    wire [ADDR_WIDTH-1:0]           io_mem_req_addr;
    wire [`MEMOP_W-1:0]             io_mem_req_op;
    wire [DATA_WIDTH-1:0]           io_mem_req_wdata;
    wire                            io_mem_rsp_valid;
    wire                            io_mem_rsp_ready;
    wire [DATA_WIDTH-1:0]           io_mem_rsp_data;
    wire                            io_mem_rsp_error;
    wire                            gpr_wen /* verilator public_flat_rd */;
    wire [`RISCV_GPR_ADDR_W-1:0]    gpr_waddr /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           gpr_wdata /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           gpr_a0;
    wire [DATA_WIDTH-1:0]           gpr_a1;
    wire [DATA_WIDTH-1:0]           gpr_a2;
    wire                            csr_wen /* verilator public_flat_rd */;
    wire [`CSR_ADDR_W-1:0]          csr_waddr /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           csr_wdata /* verilator public_flat_rd */;
    wire                            trap_en /* verilator public_flat_rd */;
    wire [INST_WIDTH-1:0]           trap_epc /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           trap_cause /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           trap_tval /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           trap_status /* verilator public_flat_rd */;

    `ifdef CONFIG_ISA_RISCV_SINGLE
    // 单周期版本的核心连接逻辑
    riscv32e_core_sc #(
    `else
    riscv32e_core #(
    `endif
        .INST_WIDTH(`RISCV_INST_WIDTH)
    ) ysyx_23060295_CORE0(
        .clock(clock),
        .reset(reset),

        .reset_pc(reset_pc),
        .io_interrupt(io_interrupt),
        .io_if_flush(io_if_flush),

        .io_if_req_valid(io_if_req_valid),
        .io_if_req_ready(io_if_req_ready),
        .io_if_req_addr(io_if_req_addr),
        .io_if_req_op(io_if_req_op),
        .io_if_req_wdata(io_if_req_wdata),
        .io_if_rsp_valid(io_if_rsp_valid),
        .io_if_rsp_ready(io_if_rsp_ready),
        .io_if_rsp_data(io_if_rsp_data),
        .io_if_rsp_error(io_if_rsp_error),
        .io_mem_req_valid(io_mem_req_valid),
        .io_mem_req_ready(io_mem_req_ready),
        .io_mem_req_addr(io_mem_req_addr),
        .io_mem_req_op(io_mem_req_op),
        .io_mem_req_wdata(io_mem_req_wdata),
        .io_mem_rsp_valid(io_mem_rsp_valid),
        .io_mem_rsp_ready(io_mem_rsp_ready),
        .io_mem_rsp_data(io_mem_rsp_data),
        .io_mem_rsp_error(io_mem_rsp_error),
        .gpr_wen(gpr_wen),
        .gpr_waddr(gpr_waddr),
        .gpr_wdata(gpr_wdata),
        .gpr_a0(gpr_a0),
        .gpr_a1(gpr_a1),
        .gpr_a2(gpr_a2),
        .csr_wen(csr_wen),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata),
        .trap_en(trap_en),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .trap_status(trap_status),

        .pc(core_pc[0]),
        .inst_pc(core_inst_pc[0]),
        .inst_done(core_inst_done[0])
    );

    riscv32e_memsys #(
        .INST_WIDTH(`RISCV_INST_WIDTH)
    ) ysyx_23060295_memsys0(
        .clock(clock),
        .reset(reset),

        .reset_pc(reset_pc),
        .io_if_flush(io_if_flush),

        .io_if_req_valid(io_if_req_valid),
        .io_if_req_ready(io_if_req_ready),
        .io_if_req_addr(io_if_req_addr),
        .io_if_req_op(io_if_req_op),
        .io_if_req_wdata(io_if_req_wdata),
        .io_if_rsp_valid(io_if_rsp_valid),
        .io_if_rsp_ready(io_if_rsp_ready),
        .io_if_rsp_data(io_if_rsp_data),
        .io_if_rsp_error(io_if_rsp_error),
        .io_mem_req_valid(io_mem_req_valid),
        .io_mem_req_ready(io_mem_req_ready),
        .io_mem_req_addr(io_mem_req_addr),
        .io_mem_req_op(io_mem_req_op),
        .io_mem_req_wdata(io_mem_req_wdata),
        .io_mem_rsp_valid(io_mem_rsp_valid),
        .io_mem_rsp_ready(io_mem_rsp_ready),
        .io_mem_rsp_data(io_mem_rsp_data),
        .io_mem_rsp_error(io_mem_rsp_error),
        .gpr_wen(gpr_wen),
        .gpr_waddr(gpr_waddr),
        .gpr_wdata(gpr_wdata),
        .csr_wen(csr_wen),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata),
        .trap_en(trap_en),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .trap_status(trap_status),

        .io_master_awready(io_master_awready),
        .io_master_awvalid(io_master_awvalid),
        .io_master_awaddr(io_master_awaddr),
        .io_master_awid(io_master_awid),
        .io_master_awlen(io_master_awlen),
        .io_master_awsize(io_master_awsize),
        .io_master_awburst(io_master_awburst),
        .io_master_wready(io_master_wready),
        .io_master_wvalid(io_master_wvalid),
        .io_master_wdata(io_master_wdata),
        .io_master_wstrb(io_master_wstrb),
        .io_master_wlast(io_master_wlast),
        .io_master_bready(io_master_bready),
        .io_master_bvalid(io_master_bvalid),
        .io_master_bresp(io_master_bresp),
        .io_master_bid(io_master_bid),
        .io_master_arready(io_master_arready),
        .io_master_arvalid(io_master_arvalid),
        .io_master_araddr(io_master_araddr),
        .io_master_arid(io_master_arid),
        .io_master_arlen(io_master_arlen),
        .io_master_arsize(io_master_arsize),
        .io_master_arburst(io_master_arburst),
        .io_master_rready(io_master_rready),
        .io_master_rvalid(io_master_rvalid),
        .io_master_rresp(io_master_rresp),
        .io_master_rdata(io_master_rdata),
        .io_master_rlast(io_master_rlast),
        .io_master_rid(io_master_rid),

        .done()
    );

`ifdef NETLIST
    assign iv_core_pc = core_pc[0];
    assign iv_core_inst_pc = core_inst_pc[0];
    assign iv_core_inst_done = core_inst_done[0];
    assign iv_gpr_wen = gpr_wen;
    assign iv_gpr_waddr = gpr_waddr;
    assign iv_gpr_wdata = gpr_wdata;
    assign iv_gpr_a0 = gpr_a0;
    assign iv_gpr_a1 = gpr_a1;
    assign iv_gpr_a2 = gpr_a2;
    assign iv_csr_wen = csr_wen;
    assign iv_csr_waddr = csr_waddr;
    assign iv_csr_wdata = csr_wdata;
    assign iv_trap_en = trap_en;
    assign iv_trap_epc = trap_epc;
    assign iv_trap_cause = trap_cause;
    assign iv_trap_tval = trap_tval;
    assign iv_trap_status = trap_status;
`endif

endmodule
