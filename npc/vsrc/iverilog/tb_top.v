`timescale 1ns/1ps
module tb_top;
    localparam ADDR_WIDTH = 32;
    localparam DATA_WIDTH = 32;

    reg clk, rst;

    wire [31:0] core_pc[`RISCV_CORE_NUM-1:0] /* verilator public_flat_rd */; // 指向下一周期待执行的指令地址，在命令执行完成前为当前指令地址
    wire [31:0] core_inst_pc[`RISCV_CORE_NUM-1:0] /* verilator public_flat_rd */; // 指向执行完的指令对应的地址
    wire core_inst_done[`RISCV_CORE_NUM-1:0] /* verilator public_flat_rd */; // 指示是否完成一条指令

    wire [ADDR_WIDTH-1:0]           reset_pc = `RISCV_RESET_PC;
    wire                            io_if_flush;
    wire                            io_if_req_valid;
    wire                            io_if_req_ready;
    wire [ADDR_WIDTH-1:0]           io_if_req_addr;
    wire [`MEMOP_W-1:0]             io_if_req_op;
    wire [DATA_WIDTH-1:0]           io_if_req_wdata;
    wire                            io_if_rsp_valid;
    wire                            io_if_rsp_ready;
    wire  [DATA_WIDTH-1:0]          io_if_rsp_data;
    wire                            io_mem_req_valid;
    wire                            io_mem_req_ready;
    wire [ADDR_WIDTH-1:0]           io_mem_req_addr;
    wire [`MEMOP_W-1:0]             io_mem_req_op;
    wire [DATA_WIDTH-1:0]           io_mem_req_wdata;
    wire                            io_mem_rsp_valid;
    wire                            io_mem_rsp_ready;
    wire [DATA_WIDTH-1:0]           io_mem_rsp_data;
    wire                            gpr_wen /* verilator public_flat_rd */;
    wire [`RISCV_GPR_ADDR_W-1:0]    gpr_waddr /* verilator public_flat_rd */;
    wire [DATA_WIDTH-1:0]           gpr_wdata /* verilator public_flat_rd */;
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
        .INST_WIDTH(32)
    ) ysyx_23060295_CORE0(
        .clock(clk),
        .reset(rst),

        .reset_pc(reset_pc),
        .io_interrupt(),
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

    initial begin
        clk = 0;
        forever #1 clk = ~clk;   // 100MHz
    end

    initial begin
        rst = 1; #20 rst = 0;
        #200 $finish;
    end

    initial begin
        $dumpfile("wave.vcd");
        $dumpvars(0, tb_top);
    end
endmodule