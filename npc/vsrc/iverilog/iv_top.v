`timescale 1ns/1ps
`ifdef CI_STANDALONE
`include "generated/autoconf.vh"
`else
`include "riscv32e_defines.v"
`endif

module iv_top;
    localparam ADDR_WIDTH = 32;
    localparam INST_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam GPR_ADDR_WIDTH = 4;
    localparam CSR_ADDR_WIDTH = 12;
    localparam [31:0] IV_EXPT_CAUSE_IAF = 1;
    localparam [31:0] IV_EXPT_CAUSE_BRK = 3;
    localparam [31:0] IV_EXPT_CAUSE_LAF = 5;
    localparam [31:0] IV_EXPT_CAUSE_SAF = 7;
`ifdef CI_STANDALONE
    localparam [ADDR_WIDTH-1:0] IMAGE_BASE = 32'h80000000;
`else
    localparam [ADDR_WIDTH-1:0] IMAGE_BASE = `CONFIG_IMG_LOAD;
`endif

    reg clock, reset;

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
    wire                         io_if_rsp_error;
    wire                         io_mem_req_valid;
    wire                         io_mem_req_ready;
    wire [ADDR_WIDTH-1:0]        io_mem_req_addr;
    wire [3:0]                   io_mem_req_op;
    wire [DATA_WIDTH-1:0]        io_mem_req_wdata;
    wire                         io_mem_rsp_valid;
    wire                         io_mem_rsp_ready;
    wire [DATA_WIDTH-1:0]        io_mem_rsp_data;
    wire                         io_mem_rsp_error;
    wire                         gpr_wen;
    wire [GPR_ADDR_WIDTH-1:0]    gpr_waddr;
    wire [DATA_WIDTH-1:0]        gpr_wdata;
    wire [DATA_WIDTH-1:0]        gpr_a0;
    wire [DATA_WIDTH-1:0]        gpr_a1;
    wire [DATA_WIDTH-1:0]        gpr_a2;
    wire [DATA_WIDTH-1:0]        mepc = gpr_a0;
    wire [DATA_WIDTH-1:0]        mcause = gpr_a1;
    wire [DATA_WIDTH-1:0]        mtval = gpr_a2;
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

`ifdef NETLIST
    ysyx_23060295 core (
        .clock(clock),
        .reset(reset),
        .io_interrupt(1'b0),
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
        .io_slave_awvalid(1'b0),
        .io_slave_awaddr(32'b0),
        .io_slave_awid(4'b0),
        .io_slave_awlen(8'b0),
        .io_slave_awsize(3'b0),
        .io_slave_awburst(2'b0),
        .io_slave_wvalid(1'b0),
        .io_slave_wdata(32'b0),
        .io_slave_wstrb(4'b0),
        .io_slave_wlast(1'b0),
        .io_slave_bready(1'b0),
        .io_slave_arvalid(1'b0),
        .io_slave_araddr(32'b0),
        .io_slave_arid(4'b0),
        .io_slave_arlen(8'b0),
        .io_slave_arsize(3'b0),
        .io_slave_arburst(2'b0),
        .io_slave_rready(1'b0),
        .iv_core_pc(core_pc[0]),
        .iv_core_inst_pc(core_inst_pc[0]),
        .iv_core_inst_done(core_inst_done[0]),
        .iv_gpr_wen(gpr_wen),
        .iv_gpr_waddr(gpr_waddr),
        .iv_gpr_wdata(gpr_wdata),
        .iv_gpr_a0(gpr_a0),
        .iv_gpr_a1(gpr_a1),
        .iv_gpr_a2(gpr_a2),
        .iv_csr_wen(csr_wen),
        .iv_csr_waddr(csr_waddr),
        .iv_csr_wdata(csr_wdata),
        .iv_trap_en(trap_en),
        .iv_trap_epc(trap_epc),
        .iv_trap_cause(trap_cause),
        .iv_trap_tval(trap_tval),
        .iv_trap_status(trap_status)
    );
`else
`ifdef CONFIG_ISA_RISCV_SINGLE
    riscv32e_core_sc #(
`else
    riscv32e_core #(
`endif
        .INST_WIDTH(INST_WIDTH)
    ) ysyx_23060295_CORE0 (
        .clock(clock),
        .reset(reset),
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
        .ADDR_WIDTH(ADDR_WIDTH),
        .INST_WIDTH(INST_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) ysyx_23060295_memsys0 (
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
`endif

    iv_memsys #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .IMAGE_BASE(IMAGE_BASE)
    ) memsys (
        .clock(clock),
        .reset(reset),
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
        clock = 0;
        forever #1 clock = ~clock;
    end
    // 驱动rst
    initial begin
        reset = 1;
        #20 reset = 0;
        // #20000 $finish;
    end
    // 输出是否符合预期
    always @(posedge clock) begin
        if (trap_en) begin
            case (trap_cause)
                IV_EXPT_CAUSE_IAF: begin // Instruction Access Fault 1
                    $display("\033[1;31mInstruction Access Fault\033[0m at pc = 0x%x addr: 0x%x", trap_epc, trap_tval);
                    $finish;
                end

                IV_EXPT_CAUSE_BRK: begin // Breakpoint 3
                    // 默认_trap_handle_def处理函数：a0-a2 mepc mcause mtval
                    if (mepc == 0) begin
                        $display("\033[1;32mHIT GOOD TRAP\033[0m at pc = 0x%x", core_inst_pc[0]);
                    end else begin
                        // case (mcause)
                        //     IV_EXPT_CAUSE_IAF: begin // Instruction Access Fault 1
                        //         $display("\033[1;31mInstruction Access Fault\033[0m at pc = 0x%x addr: 0x%x", mepc, mtval);
                        //         $finish;
                        //     end
                        //     IV_EXPT_CAUSE_LAF: begin // Load Access Fault 5
                        //         $display("\033[1;31mLoad Access Fault\033[0m at pc = 0x%x addr: 0x%x", mepc, mtval);
                        //         $finish;
                        //     end
                        //     IV_EXPT_CAUSE_SAF: begin // Store Access Fault 7
                        //         $display("\033[1;31mStore Access Fault\033[0m at pc = 0x%x addr: 0x%x", mepc, mtval);
                        //         $finish;
                        //     end
                        //     default: begin end
                        // endcase
                        $display("\033[1;31mHIT BAD TRAP\033[0m at pc = 0x%x ret: 0x%x", core_inst_pc[0], trap_tval);
                    end
                    $finish;
                end

                IV_EXPT_CAUSE_LAF: begin // Load Access Fault 5
                    $display("\033[1;31mLoad Access Fault\033[0m at pc = 0x%x addr: 0x%x", trap_epc, trap_tval);
                    $finish;
                end

                IV_EXPT_CAUSE_SAF: begin // Store Access Fault 7
                    $display("\033[1;31mStore Access Fault\033[0m at pc = 0x%x addr: 0x%x", trap_epc, trap_tval);
                    $finish;
                end

                default: begin

                end
            endcase
        end
    end
    // 记录仿真数据
    string output_path = ".";
    integer trace_on = 0;
    integer ret = 0;
    initial begin
        ret = $value$plusargs("TRACE=%d", trace_on);
        ret = $value$plusargs("OUTPUT=%s", output_path);
        if (trace_on) begin
            $display("Trace: \033[1;32mOn\033[0m");
            $dumpfile({output_path, "/iv_trace.vcd"});
            $dumpvars(0, iv_top);
        end else begin
            $display("Trace: \033[1;31mOff\033[0m");
        end
    end
endmodule
