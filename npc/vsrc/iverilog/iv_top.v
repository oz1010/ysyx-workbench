`timescale 1ns/1ps
`include "riscv32e_defines.v"

module iv_top;
    localparam ADDR_WIDTH = 32;
    localparam INST_WIDTH = 32;
    localparam DATA_WIDTH = 32;
    localparam GPR_ADDR_WIDTH = 4;
    localparam CSR_ADDR_WIDTH = 12;

    reg clk, rst;

    wire [31:0] core_pc[`CONFIG_CORE_NUM-1:0];
    wire [31:0] core_inst_pc[`CONFIG_CORE_NUM-1:0];
    wire core_inst_done[`CONFIG_CORE_NUM-1:0];

    wire [ADDR_WIDTH-1:0]        reset_pc = `CONFIG_IMG_LOAD;
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

    iv_memsys #(
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH)
    ) memsys (
        .clock(clk),
        .reset(rst),
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
        .io_mem_rsp_data(io_mem_rsp_data)
    );

    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    initial begin
        rst = 1;
        #20 rst = 0;
        #200 $finish;
    end

    string output_path = ".";
    initial begin
        $value$plusargs("OUTPUT=%s", output_path);
        $dumpfile({output_path, "/wave.vcd"});
        $dumpvars(0, iv_top);
    end
endmodule
