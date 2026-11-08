`timescale 1ns/1ps
`include "riscv32e_defines.v"

module iv_top;
    localparam ADDR_WIDTH = 32;
    localparam INST_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam GPR_ADDR_WIDTH = 4;
    localparam CSR_ADDR_WIDTH = 12;

    reg clk, rst;

    // 检测core是否陷入循环，默认但指令执行周期比较短暂
    wire [31:0] core_pc[`CONFIG_CORE_NUM-1:0];
    wire [31:0] core_inst_pc[`CONFIG_CORE_NUM-1:0];
    wire core_inst_done[`CONFIG_CORE_NUM-1:0];

    wire [ADDR_WIDTH-1:0]        reset_pc;
    wire                         io_if_flush;
    wire                         io_if_req_valid;
    wire                         io_if_req_ready;
    wire [ADDR_WIDTH-1:0]        io_if_req_addr;
    wire [3:0]                   io_if_req_op;
    wire [DATA_WIDTH-1:0]        io_if_req_wdata;
    wire                         io_if_rsp_valid;
    wire                         io_if_rsp_ready;
    wire [DATA_WIDTH-1:0]        io_if_rsp_data;
    wire                         io_mem_req_valid;
    wire                         io_mem_req_ready;
    wire [ADDR_WIDTH-1:0]        io_mem_req_addr;
    wire [3:0]                   io_mem_req_op;
    wire [DATA_WIDTH-1:0]        io_mem_req_wdata;
    wire                         io_mem_rsp_valid;
    wire                         io_mem_rsp_ready;
    wire [DATA_WIDTH-1:0]        io_mem_rsp_data;
    wire                         gpr_wen;
    wire [GPR_ADDR_WIDTH-1:0]    gpr_waddr;
    wire [DATA_WIDTH-1:0]        gpr_wdata;
    wire                         csr_wen;
    wire [CSR_ADDR_WIDTH-1:0]    csr_waddr;
    wire [DATA_WIDTH-1:0]        csr_wdata;
    wire                         trap_en;
    wire [INST_WIDTH-1:0]        trap_epc;
    wire [DATA_WIDTH-1:0]        trap_cause;
    wire [DATA_WIDTH-1:0]        trap_tval;
    wire [DATA_WIDTH-1:0]        trap_status;

    wire                         io_master_awready;
    wire                         io_master_awvalid;
    wire [ADDR_WIDTH-1:0]        io_master_awaddr;
    wire [3:0]                   io_master_awid;
    wire [7:0]                   io_master_awlen;
    wire [2:0]                   io_master_awsize;
    wire [1:0]                   io_master_awburst;
    wire                         io_master_wready;
    wire                         io_master_wvalid;
    wire [DATA_WIDTH-1:0]        io_master_wdata;
    wire [DATA_WIDTH/8-1:0]      io_master_wstrb;
    wire                         io_master_wlast;
    wire                         io_master_bready;
    wire                         io_master_bvalid;
    wire [1:0]                   io_master_bresp;
    wire [3:0]                   io_master_bid;
    wire                         io_master_arready;
    wire                         io_master_arvalid;
    wire [ADDR_WIDTH-1:0]        io_master_araddr;
    wire [3:0]                   io_master_arid;
    wire [7:0]                   io_master_arlen;
    wire [2:0]                   io_master_arsize;
    wire [1:0]                   io_master_arburst;
    wire                         io_master_rready;
    wire                         io_master_rvalid;
    wire [1:0]                   io_master_rresp;
    wire [DATA_WIDTH-1:0]        io_master_rdata;
    wire                         io_master_rlast;
    wire [3:0]                   io_master_rid;

`ifdef CONFIG_ISA_RISCV_SINGLE
    riscv32e_core_sc #(
`else
    riscv32e_core #(
`endif
        .INST_WIDTH(INST_WIDTH)
    ) ysyx_23060295_CORE0 (
        .clock(clk),
        .reset(rst),
        .reset_pc(reset_pc),
        .io_interrupt(1'b0),
        .io_if_flush(io_if_flush),
        .io_if_req_valid(io_if_req_valid),
        .io_if_req_ready(io_if_req_ready),
        .io_if_req_addr(io_if_req_addr),
        .io_if_req_op(io_if_req_op),
        .io_if_req_wdata(io_if_req_wdata),
        .io_if_rsp_valid(io_if_rsp_valid),
        .io_if_rsp_ready(io_if_rsp_ready),
        .io_if_rsp_data(io_if_rsp_data),
        .io_mem_req_valid(io_mem_req_valid),
        .io_mem_req_ready(io_mem_req_ready),
        .io_mem_req_addr(io_mem_req_addr),
        .io_mem_req_op(io_mem_req_op),
        .io_mem_req_wdata(io_mem_req_wdata),
        .io_mem_rsp_valid(io_mem_rsp_valid),
        .io_mem_rsp_ready(io_mem_rsp_ready),
        .io_mem_rsp_data(io_mem_rsp_data),
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
        .pc(core_pc[0]),
        .inst_pc(core_inst_pc[0]),
        .inst_done(core_inst_done[0])
    );

    riscv32e_memsys #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .INST_WIDTH(INST_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) ysyx_23060295_memsys0 (
        .clock(clk),
        .reset(rst),
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
        .io_mem_req_valid(io_mem_req_valid),
        .io_mem_req_ready(io_mem_req_ready),
        .io_mem_req_addr(io_mem_req_addr),
        .io_mem_req_op(io_mem_req_op),
        .io_mem_req_wdata(io_mem_req_wdata),
        .io_mem_rsp_valid(io_mem_rsp_valid),
        .io_mem_rsp_ready(io_mem_rsp_ready),
        .io_mem_rsp_data(io_mem_rsp_data),
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

    iv_memsys #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) memsys (
        .clock(clk),
        .reset(rst),
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
        .core_pc(core_pc[0]),
        .core_inst_pc(core_inst_pc[0]),
        .core_inst_done(core_inst_done[0])
    );

    // 驱动clk
    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end
    // 驱动rst
    initial begin
        rst = 1;
        #20 rst = 0;
        // #20000 $finish;
    end
    // 输出是否符合预期
    always @(posedge clk) begin
        if (trap_en && trap_cause == `EXPT_CAUSE_BRK) begin
            if (trap_tval == 0)
                $display("\033[1;32mHIT GOOD TRAP\033[0m at pc = 0x%x", core_inst_pc[0]);
            else
                $display("\033[1;31mHIT BAD TRAP\033[0m at pc = 0x%x ret: 0x%x", core_inst_pc[0], trap_tval);
            $finish;
        end
    end
    // 记录仿真数据
    string output_path = ".";
    initial begin
        $value$plusargs("OUTPUT=%s", output_path);
        $dumpfile({output_path, "/iv_trace.vcd"});
        $dumpvars(0, iv_top);
    end
endmodule
