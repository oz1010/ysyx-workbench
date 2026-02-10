module write_back #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    input wire [INST_WIDTH-1:0] pc,
    input wire [INST_WIDTH-1:0] inst,
    input wire [4:0] rd,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [`INST_CODE_W-1:0] inst_code,

    output wire [INST_WIDTH-1:0] w_x[`RISCV_GPR_COUNT-1:0],
    output wire [INST_WIDTH-1:0] dnpc
);

/* 寄存器组 */
// 通用寄存器
reg [INST_WIDTH-1:0] x[`RISCV_GPR_COUNT-1:0];
// 程序寄存器
// reg [INST_WIDTH-1:0] pc;
// wire [INST_WIDTH-1:0] dnpc;
wire [INST_WIDTH-1:0] snpc;
wire [INST_WIDTH-1:0] pc_plus_imm;
// 当前指令寄存器
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];

assign w_x = x;
// assign w_dnpc = dnpc;

/* 执行并更新结果 */
wire [INST_WIDTH-1:0] src1 = x[rs1];
wire [INST_WIDTH-1:0] src2 = x[rs2];
wire signed [INST_WIDTH-1:0] s_src1 = src1;
wire signed [INST_WIDTH-1:0] s_src2 = src2;
wire [63:0] src1_64 = {32'h0, src1};
wire [63:0] src2_64 = {32'h0, src2};
wire signed [63:0] s_src1_64 = {{32{src1[31]}}, src1};
wire signed [63:0] s_src2_64 = {{32{src2[31]}}, src2};
wire signed [63:0] mulh_ret = (s_src1_64 * s_src2_64) >> 32;
wire signed [63:0] mulhsu_ret = (s_src1 * src2) >> 32;
wire signed [63:0] mulhu_ret = (src1 * src2) >> 32;

assign snpc = pc + 4;
assign pc_plus_imm = pc + imm;
assign dnpc = 
    (inst_code==`INST_JAL) ? pc_plus_imm :
    (inst_code==`INST_JALR) ? ((src1 + imm)&~1) :
    ((inst_code==`INST_BEQ)&(src1==src2)) ? pc_plus_imm :
    ((inst_code==`INST_BNE)&(src1!=src2)) ? pc_plus_imm :
    ((inst_code==`INST_BLT)&(s_src1<s_src2)) ? pc_plus_imm :
    ((inst_code==`INST_BGE)&(s_src1>=s_src2)) ? pc_plus_imm :
    ((inst_code==`INST_BLTU)&(src1<src2)) ? pc_plus_imm :
    ((inst_code==`INST_BGEU)&(src1>=src2)) ? pc_plus_imm :
    (inst_code==`INST_ECALL) ? func_read_raw_csr({{(32-`CSR_ADDR_W){1'b0}}, `CSR_MTVEC}) :
    (inst_code==`INST_MRET) ? func_read_raw_csr({{(32-`CSR_ADDR_W){1'b0}}, `CSR_MEPC}) :
    snpc;
integer ret_pc, mem_data;
wire [31:0] mem_addr = src1 + imm;

always @(posedge clk) begin
    if (rst) begin
        // pc <= get_reset_pc();
    end else begin
        // 默认更新程序寄存器
        // pc <= dnpc;

        // 更新寄存器或回写内存
        // $display("Step - update, alu_result:%x rd:%d inst_code:%x", alu_result, rd, inst_code);
        case (inst_code)
            `INST_LUI:          x[rd] <= imm;
            `INST_AUIPC:        x[rd] <= pc_plus_imm;
            `INST_JAL:          x[rd] <= snpc;
            `INST_JALR:         x[rd] <= snpc;
            `INST_BEQ:          ;
            `INST_BNE:          ;
            `INST_BLT:          ;
            `INST_BGE:          ;
            `INST_BLTU:         ;
            `INST_BGEU:         ;
            `INST_LB:           begin mem_data = sext(read_raw_mem(mem_addr, 1), 8); x[rd] <= mem_data; func_dev_skip(0, mem_addr, { 24'h0, 4'h0, 4'h0}, mem_data); end
            `INST_LH:           begin mem_data = sext(read_raw_mem(mem_addr, 2), 16); x[rd] <= mem_data; func_dev_skip(0, mem_addr, { 24'h0, 4'h1, 4'h0}, mem_data); end
            `INST_LW:           begin mem_data = sext(read_raw_mem(mem_addr, 4), 32); x[rd] <= mem_data; func_dev_skip(0, mem_addr, { 24'h0, 4'h2, 4'h0}, mem_data); end
            `INST_LBU:          begin mem_data = read_raw_mem(mem_addr, 1) & 32'hFF; x[rd] <= mem_data; func_dev_skip(0, mem_addr, { 24'h0, 4'h0, 4'h0}, mem_data); end
            `INST_LHU:          begin mem_data = read_raw_mem(mem_addr, 2) & 32'hFFFF; x[rd] <= mem_data; func_dev_skip(0, mem_addr, { 24'h0, 4'h1, 4'h0}, mem_data); end
            `INST_SB:           begin mem_data = src2&32'hFF; write_raw_mem(mem_addr, 1, mem_data); func_dev_skip(1, mem_addr, {24'h0, 4'h0, 4'h1}, mem_data); end
            `INST_SH:           begin mem_data = src2&32'hFFFF; write_raw_mem(mem_addr, 2, mem_data); func_dev_skip(1, mem_addr, {24'h0, 4'h1, 4'h3}, mem_data); end
            `INST_SW:           begin mem_data = src2; write_raw_mem(mem_addr, 4, mem_data); func_dev_skip(1, mem_addr, {24'h0, 4'h2, 4'h7}, mem_data); end
            `INST_ADDI:         x[rd] <= src1 + imm;
            `INST_SLTI:         x[rd] <= {{31{1'b0}}, (s_src1 < imm)};
            `INST_SLTIU:        x[rd] <= {{31{1'b0}}, (src1 < imm)};
            `INST_XORI:         x[rd] <= src1 ^ imm;
            `INST_ORI:          x[rd] <= src1 | imm;
            `INST_ANDI:         x[rd] <= src1 & imm;
            `INST_SLLI:         if ((imm&32'h20)!=32'h0) func_exit_simu(`ERR_INV_OPN); else x[rd] <= src1 << (imm&32'h1F);
            `INST_SRLI:         if ((imm&32'h20)!=32'h0) func_exit_simu(`ERR_INV_OPN); else x[rd] <= src1 >> (imm&32'h1F);
            `INST_SRAI:         if ((imm&32'h20)!=32'h0) func_exit_simu(`ERR_INV_OPN); else x[rd] <= (src1 >> (imm&32'h1F)) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))) );
            `INST_ADD:          x[rd] <= src1 + src2;
            `INST_SUB:          x[rd] <= src1 - src2;
            `INST_SLL:          x[rd] <= src1 << (src2 & 32'h1F);
            `INST_SLT:          x[rd] <= {{31{1'b0}}, (s_src1 < s_src2)};
            `INST_SLTU:         x[rd] <= {{31{1'b0}}, (src1 < src2)};
            `INST_XOR:          x[rd] <= src1 ^ src2;
            `INST_SRL:          x[rd] <= src1 >> (src2 & 32'h1F);
            `INST_SRA:          x[rd] <= src1 >> (src2 & 32'h1F) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(src2 & 32'h1F))) );
            `INST_OR:           x[rd] <= src1 | src2;
            `INST_AND:          x[rd] <= src1 & src2;
            `INST_FENCE:        func_invalid_inst(pc, inst);
            `INST_FENCE_I:      ; // 更新缓存，这里暂时没有
            `INST_ECALL:        func_raise_intr((0<<31|11<<0), pc); // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0) , MTVEC 0x305
            `INST_EBREAK:       func_exit_simu(a[0]);
            `INST_CSRRW:        begin x[rd] <= func_read_raw_csr(imm); func_write_raw_csr(imm, src1); end
            `INST_CSRRS:        begin x[rd] <= func_read_raw_csr(imm); func_write_raw_csr(imm, (func_read_raw_csr(imm) | src1)); end
            `INST_CSRRC:        func_invalid_inst(pc, inst);
            `INST_CSRRWI:       func_invalid_inst(pc, inst);
            `INST_CSRRSI:       func_invalid_inst(pc, inst);
            `INST_CSRRCI:       func_invalid_inst(pc, inst);
            `INST_MUL:          x[rd] <= src1 * src2;
            `INST_MULH:         x[rd] <= mulh_ret[INST_WIDTH-1:0];
            `INST_MULHSU:       x[rd] <= mulhsu_ret[INST_WIDTH-1:0];
            `INST_MULHU:        x[rd] <= mulhu_ret[INST_WIDTH-1:0];
            `INST_DIV:          x[rd] <= s_src1 / s_src2;
            `INST_DIVU:         x[rd] <= src1 / src2;
            `INST_REM:          x[rd] <= s_src1 % s_src2;
            `INST_REMU:         x[rd] <= src1 % src2;
            `INST_MRET:         func_query_intr(); // MEPC 0x341
            `INST_INVALID:      func_invalid_inst(pc, inst);
            default: ;
        endcase

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule