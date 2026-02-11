module execute #(
    parameter INST_WIDTH = 32,
    parameter IN_DATA_W,
    parameter OUT_DATA_W
) (
    input   wire                        clk,
    input   wire                        rst,

    output  wire                        jump_en,
    output  wire [INST_WIDTH-1:0]       jump_addr,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [IN_DATA_W-1:0]        in_bits,
    /* 模块输入数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [OUT_DATA_W-1:0]       out_bits
);
    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;

    inner_con ex_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done)
    );

    assign {pc, inst, rd, imm, inst_code, src1, src2, a0} = in_bits;
    assign out_bits = {
        pc, inst, rd, imm, inst_code, src1, src2,
        r_result, r_result_update_gpr
    };

    wire ex_enable = !(|(inst_code & `INST_CODE_MEM));

    wire [INST_WIDTH-1:0]       pc;
    wire [INST_WIDTH-1:0]       inst;
    wire [4:0]                  rd;
    wire [INST_WIDTH-1:0]       imm;
    wire [`INST_CODE_W-1:0]     inst_code;
    wire [INST_WIDTH-1:0]       src1;
    wire [INST_WIDTH-1:0]       src2;
    wire [INST_WIDTH-1:0]       a0;

    reg [INST_WIDTH-1:0] r_dnpc;
    reg [INST_WIDTH-1:0] r_result;
    reg r_result_update_gpr;
    reg r_jump_en;

    wire signed [31:0] s_src1 = src1;
    wire signed [31:0] s_src2 = src2;

    assign jump_en = r_jump_en;
    assign jump_addr = r_dnpc;

    wire mdr_inst = 
        inst_code==`INST_MUL |
        inst_code==`INST_MULH |
        inst_code==`INST_MULHSU |
        inst_code==`INST_MULHU |
        inst_code==`INST_DIV |
        inst_code==`INST_DIVU |
        inst_code==`INST_REM |
        inst_code==`INST_REMU
        ;
    reg r_mdr_enable;
    wire mdr_valid;
    wire [INST_WIDTH-1:0] mdr_result;
    ex_muldivrem #(
        .INST_WIDTH(INST_WIDTH)
    ) m_muldivrem(
        .clk(clk),
        .rst(rst),
        .enable(r_mdr_enable),
        .inst_code(inst_code),
        .src1(src1),
        .src2(src2),
        .valid(mdr_valid),
        .result(mdr_result)
    );

    wire [INST_WIDTH-1:0] snpc = pc + 4;
    wire [INST_WIDTH-1:0] pc_plus_imm = pc + imm;
    wire [INST_WIDTH-1:0] inst_dnpc = 
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
    wire inst_jump_en =
        (inst_code==`INST_JAL) |
        (inst_code==`INST_JALR) |
        ((inst_code==`INST_BEQ)&(src1==src2)) |
        ((inst_code==`INST_BNE)&(src1!=src2)) |
        ((inst_code==`INST_BLT)&(s_src1<s_src2)) |
        ((inst_code==`INST_BGE)&(s_src1>=s_src2)) |
        ((inst_code==`INST_BLTU)&(src1<src2)) |
        ((inst_code==`INST_BGEU)&(src1>=src2)) |
        (inst_code==`INST_ECALL) |
        (inst_code==`INST_MRET) |
        0;
    wire inst_keep_gpr =
        (inst_code==`INST_BEQ) |
        (inst_code==`INST_BNE) |
        (inst_code==`INST_BLT) |
        (inst_code==`INST_BGE) |
        (inst_code==`INST_BLTU) |
        (inst_code==`INST_BGEU) |
        (inst_code==`INST_ECALL) |
        (inst_code==`INST_MRET) |
        0;

    always @(posedge clk) begin
        if (rst) begin
            r_jump_en <= 0;
            r_dnpc <= 0;
            r_result <= 0;
            r_result_update_gpr <= 0;
        end else begin
            r_dnpc <= r_dnpc;
            r_result <= r_result;
            r_result_update_gpr <= r_result_update_gpr;

            if (stage_in_done) begin
                // 默认更新程序寄存器
                r_jump_en <= inst_jump_en;
                r_dnpc <= inst_dnpc;
                r_result <= 0;
                r_result_update_gpr <= inst_keep_gpr ? 0 : ex_enable;
            end

            if (mdr_inst) begin
                r_mdr_enable <= stage_in_done ? 1 : r_mdr_enable;
                if (mdr_valid) begin
                    r_stage_out_valid <= 1;
                    r_result <= mdr_result;
                    r_mdr_enable <= 0;
                end
                if (stage_out_done) begin
                    r_stage_out_valid <= 0;
                end
            end else begin
                r_stage_out_valid <= stage_in_done ? 1 : 0;
                if (stage_in_done) begin
                    // 更新寄存器或回写内存
                    // $display("Step - update, alu_result:%x rd:%d inst_code:%x", alu_result, rd, inst_code);
                    case (inst_code)
                        `INST_LUI:          r_result <= imm;
                        `INST_AUIPC:        r_result <= pc_plus_imm;
                        `INST_JAL:          r_result <= snpc;
                        `INST_JALR:         r_result <= snpc;
                        `INST_BEQ:          ;
                        `INST_BNE:          ;
                        `INST_BLT:          ;
                        `INST_BGE:          ;
                        `INST_BLTU:         ;
                        `INST_BGEU:         ;
                        // `INST_LB:           r_result <= sext(read_raw_mem(src1 + imm, 1), 8);
                        // `INST_LH:           r_result <= sext(read_raw_mem(src1 + imm, 2), 16);
                        // `INST_LW:           r_result <= sext(read_raw_mem(src1 + imm, 4), 32);
                        // `INST_LBU:          r_result <= read_raw_mem(src1 + imm, 1) & 32'hFF;
                        // `INST_LHU:          r_result <= read_raw_mem(src1 + imm, 2) & 32'hFFFF;
                        // // `INST_SB:           write_raw_mem(src1 + imm, 1, src2&32'hFF);
                        // // `INST_SH:           write_raw_mem(src1 + imm, 2, src2&32'hFFFF);
                        // // `INST_SW:           write_raw_mem(src1 + imm, 4, src2);
                        // `INST_SB:           begin r_result <= src2&32'hFF; r_result_mem_width <= 1; end
                        // `INST_SH:           begin r_result <= src2&32'hFFFF; r_result_mem_width <= 2; end
                        // `INST_SW:           begin r_result <= src2; r_result_mem_width <= 4; end
                        `INST_ADDI:         r_result <= src1 + imm;
                        `INST_SLTI:         r_result <= {{31{1'b0}}, (s_src1 < imm)};
                        `INST_SLTIU:        r_result <= {{31{1'b0}}, (src1 < imm)};
                        `INST_XORI:         r_result <= src1 ^ imm;
                        `INST_ORI:          r_result <= src1 | imm;
                        `INST_ANDI:         r_result <= src1 & imm;

                        `INST_SLLI:         if ((imm&32'h20)!=32'h0) func_exit_simu(`ERR_INV_OPN); else r_result <= src1 << (imm&32'h1F);
                        `INST_SRLI:         if ((imm&32'h20)!=32'h0) func_exit_simu(`ERR_INV_OPN); else r_result <= src1 >> (imm&32'h1F);
                        `INST_SRAI:         if ((imm&32'h20)!=32'h0) func_exit_simu(`ERR_INV_OPN); else r_result <= (src1 >> (imm&32'h1F)) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(imm&32'h1F))) );
                        `INST_ADD:          r_result <= src1 + src2;
                        `INST_SUB:          r_result <= src1 - src2;
                        `INST_SLL:          r_result <= src1 << (src2 & 32'h1F);
                        `INST_SLT:          r_result <= {{31{1'b0}}, (s_src1 < s_src2)};
                        `INST_SLTU:         r_result <= {{31{1'b0}}, (src1 < src2)};
                        `INST_XOR:          r_result <= src1 ^ src2;
                        `INST_SRL:          r_result <= src1 >> (src2 & 32'h1F);
                        `INST_SRA:          r_result <= src1 >> (src2 & 32'h1F) | ({32{src1[31]}} & (32'hFFFFFFFF<<(32-(src2 & 32'h1F))) );
                        `INST_OR:           r_result <= src1 | src2;
                        `INST_AND:          r_result <= src1 & src2;
                        // `INST_FENCE:        func_invalid_inst(pc, inst);
                        // `INST_FENCE_I:      func_invalid_inst(pc, inst);
                        `INST_ECALL:        func_raise_intr((0<<31|11<<0), pc); // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0) , MTVEC 0x305
                        `INST_EBREAK:       func_exit_simu(a0);
                        `INST_CSRRW:        begin r_result <= func_read_raw_csr(imm); func_write_raw_csr(imm, src1); end
                        `INST_CSRRS:        begin r_result <= func_read_raw_csr(imm); func_write_raw_csr(imm, (func_read_raw_csr(imm) | src1)); end
                        `INST_CSRRC:        func_invalid_inst(pc, inst);
                        `INST_CSRRWI:       func_invalid_inst(pc, inst);
                        `INST_CSRRSI:       func_invalid_inst(pc, inst);
                        `INST_CSRRCI:       func_invalid_inst(pc, inst);
                        // `INST_MUL:          r_result <= src1 * src2;
                        // `INST_MULH:         r_result <= mulh_ret[31:0];
                        // `INST_MULHSU:       r_result <= mulhsu_ret[31:0];
                        // `INST_MULHU:        r_result <= mulhu_ret[31:0];
                        // `INST_DIV:          r_result <= s_src1 / s_src2;
                        // `INST_DIVU:         r_result <= src1 / src2;
                        // `INST_REM:          r_result <= s_src1 % s_src2;
                        // `INST_REMU:         r_result <= src1 % src2;
                        `INST_MRET:         func_query_intr(); // MEPC 0x341
                        `INST_INVALID:      func_invalid_inst(pc, inst);
                        default: ;
                    endcase
                end
            end
        end
    end

endmodule
