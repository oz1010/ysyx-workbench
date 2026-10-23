// 单周期处理器
module riscv32e_core_sc #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clock,
    input  wire                         reset,

    // 复位与中断
    input  wire [ADDR_WIDTH-1:0]        reset_pc,
    input  wire                         io_interrupt,

    // 取指接口
    output reg                          io_if_req_valid,
    input  wire                         io_if_req_ready,
    output reg  [ADDR_WIDTH-1:0]        io_if_req_addr,
    output reg  [`MEMOP_W-1:0]          io_if_req_op,
    output reg  [DATA_WIDTH-1:0]        io_if_req_wdata,
    input  wire                         io_if_rsp_valid,
    output reg                          io_if_rsp_ready,
    input  wire [DATA_WIDTH-1:0]        io_if_rsp_data,
    
    // 访问存储接口
    output wire                         io_mem_req_valid,
    input  wire                         io_mem_req_ready,
    output wire [ADDR_WIDTH-1:0]        io_mem_req_addr,
    output wire [`MEMOP_W-1:0]          io_mem_req_op,
    output wire [DATA_WIDTH-1:0]        io_mem_req_wdata,
    input  wire                         io_mem_rsp_valid,
    output wire                         io_mem_rsp_ready,
    input  wire [DATA_WIDTH-1:0]        io_mem_rsp_data,

    // gpr写入
    output wire                         gpr_wen,
    output wire [`RISCV_GPR_ADDR_W-1:0] gpr_waddr,
    output wire [DATA_WIDTH-1:0]        gpr_wdata,

    // 普通csr写入
    output wire                         csr_wen,
    output wire [`CSR_ADDR_W-1:0]       csr_waddr,
    output wire [DATA_WIDTH-1:0]        csr_wdata,

    // 异常csr写入
    output wire                         trap_en,
    output wire [INST_WIDTH-1:0]        trap_epc,
    output wire [DATA_WIDTH-1:0]        trap_cause,
    output wire [DATA_WIDTH-1:0]        trap_tval,
    output wire [DATA_WIDTH-1:0]        trap_status,

    // 关键信息
    output wire [INST_WIDTH-1:0]        pc, // 退休指令的PC
    output wire [INST_WIDTH-1:0]        dnpc, // 退休指令的下一条指令PC
    output wire                         inst_done // 退休指令已经完成
);
    /* gpr寄存器组 */
    wire [DATA_WIDTH-1:0] gpr_src1;
    wire [DATA_WIDTH-1:0] gpr_src2;
    wire [DATA_WIDTH-1:0] gpr_a0;
    gprs #(
        .DATA_WIDTH(DATA_WIDTH),
        .REG_COUNT(`RISCV_GPR_COUNT)
    ) m_gprs (
        .clock(clock),
        .reset(reset),
        .rs1(rs1),
        .src1(gpr_src1),
        .rs2(rs2),
        .src2(gpr_src2),
        .a0(gpr_a0),
        .wen(gpr_wen),
        .waddr(gpr_waddr),
        .wdata(gpr_wdata)
    );


    /* csr寄存器组 */
    wire csr_raddr_en = 
        (inst_code==`INST_CSRRW) |
        (inst_code==`INST_CSRRS) |
        0;
    wire [`CSR_ADDR_W-1:0] csr_raddr = 
        csr_raddr_en ? imm[0 +: `CSR_ADDR_W] :
        (inst_code==`INST_ECALL) ? `CSR_MTVEC :
        (inst_code==`INST_MRET) ? `CSR_MEPC :
        0;
    wire [DATA_WIDTH-1:0] csr_rdata;
    csrs #(
        .DATA_WIDTH(DATA_WIDTH)
    ) m_csrs (
        .clock(clock),
        .reset(reset),
        
        .raddr(csr_raddr),
        .rdata(csr_rdata),
        .wen(csr_wen),
        .waddr(csr_waddr),
        .wdata(csr_wdata),

        .trap_en(trap_en),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .trap_status(trap_status)
    );

    /* 取指，单周期一直取指 */
    reg [INST_WIDTH-1:0] inst;
    assign io_if_req_valid = reset ? 0 : 1;
    assign io_if_req_addr = core_pc;
    assign io_if_req_op = `MEMOP_FLAG_4B;
    assign io_if_rsp_ready = reset ? 0 : 1;
    assign inst = io_if_rsp_data;
    // 禁用写接口
    assign io_if_req_wdata = 0;

    /* 译码 */
    wire [6:0] opcode;
    wire [`RISCV_GPR_ADDR_W-1:0] rd;
    wire [2:0] funct3;
    wire [`RISCV_GPR_ADDR_W-1:0] rs1;
    wire [`RISCV_GPR_ADDR_W-1:0] rs2;
    wire [6:0] funct7;
    wire [31:0] imm;
    wire [2:0] inst_type;
    wire [`INST_CODE_W-1:0] inst_code;
    inst_decode_sc risc32e_decoder(inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

    /* 回写wb */
    write_back_sc #(
        .INST_WIDTH(INST_WIDTH)
    ) wbu(
        .clock(clock),
        .reset(reset),

        .pc(core_pc),
        .inst(inst),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm(imm),
        .inst_code(inst_code),
        .io_mem_req_valid(io_mem_req_valid),
        .io_mem_req_ready(io_mem_req_ready),
        .io_mem_req_addr(io_mem_req_addr),
        .io_mem_req_op(io_mem_req_op),
        .io_mem_req_wdata(io_mem_req_wdata),
        .io_mem_rsp_valid(io_mem_rsp_valid),
        .io_mem_rsp_ready(io_mem_rsp_ready),
        .io_mem_rsp_data(io_mem_rsp_data),
        .gpr_src1(gpr_src1),
        .gpr_src2(gpr_src2),
        .gpr_a0(gpr_a0),
        .gpr_wen(gpr_wen),
        .gpr_waddr(gpr_waddr),
        .gpr_wdata(gpr_wdata),
        .csr_rdata(csr_rdata),
        .csr_wen(csr_wen),
        .csr_waddr(csr_waddr),
        .csr_wdata(csr_wdata),
        .trap_en(trap_en),
        .trap_epc(trap_epc),
        .trap_cause(trap_cause),
        .trap_tval(trap_tval),
        .trap_status(trap_status),
        .out_pc(pc),
        .out_dnpc(dnpc)
    );

    /** 
    * 关键信号处理
    */
    reg [INST_WIDTH-1:0] core_pc;
    reg [INST_WIDTH-1:0] core_dnpc;
    reg                  core_inst_done;
    assign core_dnpc = dnpc;
    assign inst_done = core_inst_done;
    always @(posedge clock) begin
        if (reset) begin
            core_pc <= reset_pc;
            core_inst_done <= 0;
        end else begin
            core_pc <= dnpc;
            core_inst_done <= 1;
        end
    end

endmodule
