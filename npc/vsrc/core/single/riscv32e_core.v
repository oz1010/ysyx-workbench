`ifdef FORMAL_VERIFY
/*
 * 形式化验证使用的单周期处理器核(REF)。
 * 指令语义与仿真版riscv32e_core一致，区别仅在于：
 *   - 不通过DPI取指，指令由外部提供（DUT的WBU完成指令后同步输入）
 *   - load数据由外部提供（与DUT在总线上读到的数据相同）
 *   - i_valid有效时执行一条指令
 */
module riscv32e_core_sc #(
    parameter INST_WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst,

    input  wire                  i_valid,
    input  wire [INST_WIDTH-1:0] i_inst,
    input  wire [INST_WIDTH-1:0] i_ld_data,

    output wire [INST_WIDTH-1:0] o_pc,
    output wire [INST_WIDTH-1:0] o_dnpc,
    output wire [`RISCV_GPR_ADDR_W-1:0]            o_rd,
    output wire [INST_WIDTH-1:0] o_res,
    output wire                  o_wen
);

/* 当前正在处理的pc指示：每执行完一条指令更新为dnpc */
reg [INST_WIDTH-1:0] core_pc;
assign o_pc = core_pc;
always @(posedge clk) begin
    if (rst) begin
        core_pc <= func_get_reset_pc();
    end else if (i_valid) begin
        core_pc <= o_dnpc;
    end
end

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
decoder risc32e_decoder(i_inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

assign o_rd = rd;

/* 执行并更新结果 */
write_back_sc #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .i_valid(i_valid),
    .pc(core_pc),
    .i_ld_data(i_ld_data),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),

    .o_res(o_res),
    .o_wen(o_wen),
    .dnpc(o_dnpc)
);

endmodule
`else
// 单周期处理器
module riscv32e_core #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst,

    // 复位与中断
    input  wire [ADDR_WIDTH-1:0]        reset_pc,
    input  wire                         io_interrupt,

    // 取指接口
    output reg                          if_req_valid,
    input  wire                         if_req_ready,
    output reg  [ADDR_WIDTH-1:0]        if_req_addr,
    output reg  [`MEMOP_W-1:0]          if_req_op,
    output reg  [DATA_WIDTH-1:0]        if_req_wdata,
    input  wire                         if_rsp_valid,
    output reg                          if_rsp_ready,
    input  wire [DATA_WIDTH-1:0]        if_rsp_data,
    
    // 访问存储接口
    output wire                         mem_req_valid,
    input  wire                         mem_req_ready,
    output wire [ADDR_WIDTH-1:0]        mem_req_addr,
    output wire [`MEMOP_W-1:0]          mem_req_op,
    output wire [DATA_WIDTH-1:0]        mem_req_wdata,
    input  wire                         mem_rsp_valid,
    output wire                         mem_rsp_ready,
    input  wire [DATA_WIDTH-1:0]        mem_rsp_data,

    output wire [INST_WIDTH-1:0]        pc,
    output wire                         valid
);

    reg                                 r_valid;
    wire                                expt_en;
    wire [INST_WIDTH-1:0]               expt_epc;
    wire [DATA_WIDTH-1:0]               expt_cause;
    wire [DATA_WIDTH-1:0]               expt_tval;

    /* gpr寄存器组 */
    wire [DATA_WIDTH-1:0] gpr_src1;
    wire [DATA_WIDTH-1:0] gpr_src2;
    wire [DATA_WIDTH-1:0] gpr_a0;
    gprs #(
        .DATA_WIDTH(DATA_WIDTH),
        .REG_COUNT(`RISCV_GPR_COUNT)
    ) m_gprs (
        .clk(clk),
        .rst(rst),
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
    wire [`INST_CODE_W-1:0] csr_inst_code = inst_code;
    wire                            csr_wen;
    wire [`CSR_ADDR_W-1:0]          csr_waddr;
    wire [DATA_WIDTH-1:0]           csr_wdata;
    wire csr_raddr_en = 
        (csr_inst_code==`INST_CSRRW) |
        (csr_inst_code==`INST_CSRRS) |
        0;
    wire [`CSR_ADDR_W-1:0] csr_raddr = 
        csr_raddr_en ? imm[0 +: `CSR_ADDR_W] :
        (csr_inst_code==`INST_ECALL) ? `CSR_MTVEC :
        (csr_inst_code==`INST_MRET) ? `CSR_MEPC :
        0;
    wire [DATA_WIDTH-1:0] csr_rdata;
    csrs #(
        .DATA_WIDTH(DATA_WIDTH)
    ) m_csrs (
        .clk(clk),
        .rst(rst),
        
        .raddr(csr_raddr),
        .rdata(csr_rdata),
        .wen(csr_wen),
        .waddr(csr_waddr),
        .wdata(csr_wdata),

        .expt_en(expt_en),
        .expt_epc(expt_epc),
        .expt_cause(expt_cause),
        .expt_tval(expt_tval)
    );

    /* 取指，单周期一直取指 */
    reg [INST_WIDTH-1:0] inst;
    assign if_req_valid = rst ? 0 : 1;
    assign if_req_addr = core_pc;
    assign if_req_op = `MEMOP_FLAG_4B;
    assign if_rsp_ready = rst ? 0 : 1;
    assign inst = if_rsp_data;
    // 禁用写接口
    assign if_req_wdata = 0;

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
    decoder risc32e_decoder(inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

    /* 回写wb */
    wire                            gpr_wen;
    wire [`RISCV_GPR_ADDR_W-1:0]    gpr_waddr;
    wire [DATA_WIDTH-1:0]           gpr_wdata;
    write_back #(
        .INST_WIDTH(INST_WIDTH)
    ) wbu(
        .clk(clk),
        .rst(rst),

        .pc(core_pc),
        .inst(inst),
        .rd(rd),
        .rs1(rs1),
        .rs2(rs2),
        .imm(imm),
        .inst_code(inst_code),

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

        .expt_en(expt_en),
        .expt_epc(expt_epc),
        .expt_cause(expt_cause),
        .expt_tval(expt_tval),

        .mem_req_valid(mem_req_valid),
        .mem_req_ready(mem_req_ready),
        .mem_req_addr(mem_req_addr),
        .mem_req_op(mem_req_op),
        .mem_req_wdata(mem_req_wdata),
        .mem_rsp_valid(mem_rsp_valid),
        .mem_rsp_ready(mem_rsp_ready),
        .mem_rsp_data(mem_rsp_data),

        .dnpc(dnpc)
    );

    /** 
    * 关键信号处理
    */
    reg [INST_WIDTH-1:0] core_pc;
    reg [INST_WIDTH-1:0] core_dnpc;
    wire [INST_WIDTH-1:0] dnpc;
    assign valid = r_valid;
    assign pc = core_pc;
    assign core_dnpc = dnpc;
    always @(posedge clk) begin
        if (rst) begin
            core_pc <= reset_pc;
            r_valid <= 0;
        end else begin
            core_pc <= dnpc;
            r_valid <= 1;
        end
    end

endmodule
`endif