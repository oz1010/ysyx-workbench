module write_back_sc #(
    parameter ADDR_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input   wire                            clk,
    input   wire                            rst,
    // 解码指令
    input   wire [INST_WIDTH-1:0]           pc,
    input   wire [INST_WIDTH-1:0]           inst,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rd,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rs1,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rs2,
    input   wire [INST_WIDTH-1:0]           imm,
    input   wire [`INST_CODE_W-1:0]         inst_code,
    // 访问存储接口
    output reg                              io_mem_req_valid,
    input  wire                             io_mem_req_ready,
    output reg  [ADDR_WIDTH-1:0]            io_mem_req_addr,
    output reg  [`MEMOP_W-1:0]              io_mem_req_op,
    output reg  [DATA_WIDTH-1:0]            io_mem_req_wdata,
    input  wire                             io_mem_rsp_valid,
    output reg                              io_mem_rsp_ready,
    input  wire [DATA_WIDTH-1:0]            io_mem_rsp_data,
    // gpr读入
    input   wire [DATA_WIDTH-1:0]           gpr_src1,
    input   wire [DATA_WIDTH-1:0]           gpr_src2,
    input   wire [DATA_WIDTH-1:0]           gpr_a0,
    // gpr写入
    output  reg                             gpr_wen,
    output  reg  [`RISCV_GPR_ADDR_W-1:0]    gpr_waddr,
    output  reg  [DATA_WIDTH-1:0]           gpr_wdata,
    // 普通csr读入
    input   wire [DATA_WIDTH-1:0]           csr_rdata,
    // 普通csr写入
    output  reg                             csr_wen,
    output  reg  [`CSR_ADDR_W-1:0]          csr_waddr,
    output  reg  [DATA_WIDTH-1:0]           csr_wdata,
    // 异常csr写入
    output  reg                             trap_en,
    output  reg  [INST_WIDTH-1:0]           trap_epc,
    output  reg  [DATA_WIDTH-1:0]           trap_cause,
    output  reg  [DATA_WIDTH-1:0]           trap_tval,
    output  reg  [DATA_WIDTH-1:0]           trap_status,

    output wire [INST_WIDTH-1:0]            dnpc
);
    wire [INST_WIDTH-1:0] src1 = gpr_src1;
    wire [INST_WIDTH-1:0] src2 = gpr_src2;
    wire signed [INST_WIDTH-1:0] s_src1 = src1;
    wire signed [INST_WIDTH-1:0] s_src2 = src2;
    wire [INST_WIDTH-1:0] snpc = pc + 4;
    wire [INST_WIDTH-1:0] pc_plus_imm = pc + imm;
    assign dnpc = 
        (inst_code==`INST_JAL) ? pc_plus_imm :
        (inst_code==`INST_JALR) ? ((src1 + imm)&~1) :
        ((inst_code==`INST_BEQ)&(src1==src2)) ? pc_plus_imm :
        ((inst_code==`INST_BNE)&(src1!=src2)) ? pc_plus_imm :
        ((inst_code==`INST_BLT)&(s_src1<s_src2)) ? pc_plus_imm :
        ((inst_code==`INST_BGE)&(s_src1>=s_src2)) ? pc_plus_imm :
        ((inst_code==`INST_BLTU)&(src1<src2)) ? pc_plus_imm :
        ((inst_code==`INST_BGEU)&(src1>=src2)) ? pc_plus_imm :
        (inst_code==`INST_ECALL) ? csr_rdata :
        (inst_code==`INST_MRET) ? csr_rdata :
        snpc;

    /**
    * ref. https://ysyx.oscc.cc/docs/ics-pa/3.2.html#riscv32
    * riscv32触发异常后硬件的响应过程如下:
    * 
    * 将当前PC值保存到mepc寄存
    * 在mcause寄存器中设置异常号
    * 从mtvec寄存器中取出异常入口地址
    * 跳转到异常入口地址
    */
    always @(*) begin
        trap_en = 0; trap_epc = 0; trap_cause = 0; trap_tval = 0; trap_status = 0;
        case (inst_code)
            `INST_EBREAK:   begin trap_en = 1; trap_cause = `EXPT_CAUSE_BRK; trap_tval = gpr_a0; trap_epc = 0; end
            `INST_INVALID:  begin trap_en = 1; trap_cause = `EXPT_CAUSE_ILL; trap_tval = inst; trap_epc = pc; end
            `INST_ECALL:    begin trap_en = 1; trap_cause = `EXPT_CAUSE_MEC; trap_tval = (0<<31|11<<0); trap_epc = pc; end // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0) , MTVEC 0x305
            `INST_SLLI, `INST_SRLI, `INST_SRAI: if ((imm&32'h20)!=32'h0) begin trap_en = 1; trap_cause = `EXPT_CAUSE_ILL; trap_tval = inst; trap_epc = pc; end
            default: begin end
        endcase
    end

    // 访存逻辑
    assign io_mem_req_valid =
        inst_code==`INST_SB ||
        inst_code==`INST_SH ||
        inst_code==`INST_SW ||
        inst_code==`INST_LB ||
        inst_code==`INST_LH ||
        inst_code==`INST_LW ||
        inst_code==`INST_LBU ||
        inst_code==`INST_LHU ||
        0;
    assign io_mem_req_addr = src1 + imm;
    assign io_mem_req_op =
        inst_code==`INST_LB ?   `MEMOP_LB : 
        inst_code==`INST_LH ?   `MEMOP_LH : 
        inst_code==`INST_LW ?   `MEMOP_LW : 
        inst_code==`INST_LBU ?  `MEMOP_LBU : 
        inst_code==`INST_LHU ?  `MEMOP_LHU : 
        inst_code==`INST_SB ?   `MEMOP_SB : 
        inst_code==`INST_SH ?   `MEMOP_SH : 
        inst_code==`INST_SW ?   `MEMOP_SW : 
        `MEMOP_NONE;
    assign io_mem_req_wdata = 
        inst_code==`INST_SB ? src2&32'hFF : 
        inst_code==`INST_SH ? src2&32'hFFFF : 
        inst_code==`INST_SW ? src2 : 
        0;
    assign io_mem_rsp_ready = 1;

    // GPR寄存器堆处理
    always @(*) begin
        gpr_wen = 0; gpr_waddr = rd; gpr_wdata = 0;
        case (inst_code)
            `INST_LUI:          begin gpr_wen = 1; gpr_wdata = imm; end
            `INST_AUIPC:        begin gpr_wen = 1; gpr_wdata = pc_plus_imm; end
            `INST_JAL:          begin gpr_wen = 1; gpr_wdata = snpc; end
            `INST_JALR:         begin gpr_wen = 1; gpr_wdata = snpc; end
            `INST_LB:           begin gpr_wen = 1; gpr_wdata = io_mem_rsp_data; end
            `INST_LH:           begin gpr_wen = 1; gpr_wdata = io_mem_rsp_data; end
            `INST_LW:           begin gpr_wen = 1; gpr_wdata = io_mem_rsp_data; end
            `INST_LBU:          begin gpr_wen = 1; gpr_wdata = io_mem_rsp_data; end
            `INST_LHU:          begin gpr_wen = 1; gpr_wdata = io_mem_rsp_data; end
            `INST_ADDI:         begin gpr_wen = 1; gpr_wdata = src1 + imm; end
            `INST_SLTI:         begin gpr_wen = 1; gpr_wdata = {{31{1'b0}}, (s_src1 < imm)}; end
            `INST_SLTIU:        begin gpr_wen = 1; gpr_wdata = {{31{1'b0}}, (src1 < imm)}; end
            `INST_XORI:         begin gpr_wen = 1; gpr_wdata = src1 ^ imm; end
            `INST_ORI:          begin gpr_wen = 1; gpr_wdata = src1 | imm; end
            `INST_ANDI:         begin gpr_wen = 1; gpr_wdata = src1 & imm; end
            `INST_SLLI:         begin gpr_wen = 1; gpr_wdata = src1 << (imm&32'h1F); end
            `INST_SRLI:         begin gpr_wen = 1; gpr_wdata = src1 >> (imm&32'h1F); end
            `INST_SRAI:         begin gpr_wen = 1; gpr_wdata = (src1 >> (imm&32'h1F)) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))) ); end
            `INST_ADD:          begin gpr_wen = 1; gpr_wdata = src1 + src2; end
            `INST_SUB:          begin gpr_wen = 1; gpr_wdata = src1 - src2; end
            `INST_SLL:          begin gpr_wen = 1; gpr_wdata = src1 << (src2 & 32'h1F); end
            `INST_SLT:          begin gpr_wen = 1; gpr_wdata = {{31{1'b0}}, (s_src1 < s_src2)}; end
            `INST_SLTU:         begin gpr_wen = 1; gpr_wdata = {{31{1'b0}}, (src1 < src2)}; end
            `INST_XOR:          begin gpr_wen = 1; gpr_wdata = src1 ^ src2; end
            `INST_SRL:          begin gpr_wen = 1; gpr_wdata = src1 >> (src2 & 32'h1F); end
            `INST_SRA:          begin gpr_wen = 1; gpr_wdata = src1 >> (src2 & 32'h1F) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(src2 & 32'h1F))) ); end
            `INST_OR:           begin gpr_wen = 1; gpr_wdata = src1 | src2; end
            `INST_AND:          begin gpr_wen = 1; gpr_wdata = src1 & src2; end
            `INST_CSRRW:        begin gpr_wen = 1; gpr_wdata = csr_rdata; end
            `INST_CSRRS:        begin gpr_wen = 1; gpr_wdata = csr_rdata; end
            default:            begin end
        endcase
    end

    // CSR寄存器堆处理
    always @(*) begin
        csr_wen = 0; csr_waddr = 0; csr_wdata = 0;
        case(inst_code)
            `INST_CSRRW:        begin csr_wen = 1; csr_waddr = imm[0 +: `CSR_ADDR_W]; csr_wdata = src1; end
            `INST_CSRRS:        begin csr_wen = 1; csr_waddr = imm[0 +: `CSR_ADDR_W]; csr_wdata = (csr_rdata|src1); end
            default: ;
        endcase
    end

endmodule
