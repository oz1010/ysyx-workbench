module execute #(
    parameter INST_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [INST_WIDTH-1:0]       in_pc,
    input   wire [INST_WIDTH-1:0]       in_inst,
    input   wire [4:0]                  in_rd,
    input   wire [INST_WIDTH-1:0]       in_imm,
    input   wire [`INST_CODE_W-1:0]     in_inst_code,
    input   wire [INST_WIDTH-1:0]       in_src1,
    input   wire [INST_WIDTH-1:0]       in_src2,
    input   wire [INST_WIDTH-1:0]       in_a0,
    /* 模块输入数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [INST_WIDTH-1:0]       out_pc,
    output  wire [INST_WIDTH-1:0]       out_inst,
    output  wire [4:0]                  out_rd,
    output  wire [INST_WIDTH-1:0]       out_imm,
    output  wire [`INST_CODE_W-1:0]     out_inst_code,
    output  wire [INST_WIDTH-1:0]       out_src1,
    output  wire [INST_WIDTH-1:0]       out_src2,
    output  wire [INST_WIDTH-1:0]       out_result,
    output  wire                        out_result_update_gpr
);

    localparam STAGE_IN_DATA_W = 
        INST_WIDTH*6 + 
        `INST_CODE_W + 
        5;

    wire [STAGE_IN_DATA_W-1:0]      stage_in_bits;
    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    wire [`INNER_CON_STATE_W-1:0]   stage_state;

    inner_con #(
        .IN_DATA_STORAGE(1),
        .IN_DATA_W(STAGE_IN_DATA_W)
    ) ex_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_bits({in_pc, in_inst, in_rd, in_imm, in_inst_code, in_src1, in_src2, in_a0}),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_bits(stage_in_bits),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done),
        .stage_state(stage_state)
    );

    assign {pc, inst, rd, imm, inst_code, src1, src2, a0} = stage_in_bits;
    assign {
        out_pc, out_inst, out_rd, out_imm, out_inst_code, out_src1, out_src2, 
        out_result, out_result_update_gpr
    } = {
        pc, inst, rd, imm, inst_code, src1, src2,
        r_result, r_result_update_gpr
    };

    /* TODO 后面需要在解码时直接赋值 */
    wire ex_enable = !
        (inst_code == `INST_LB) ||
        (inst_code == `INST_LH) ||
        (inst_code == `INST_LW) ||
        (inst_code == `INST_LBU) ||
        (inst_code == `INST_LHU) ||
        (inst_code == `INST_SB) ||
        (inst_code == `INST_SH) ||
        (inst_code == `INST_SW) ||
        (inst_code == `INST_FENCE) || 
        (inst_code == `INST_FENCE_I)
        ;

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
    // reg [7:0] r_result_mem_width;
    reg r_result_update_gpr;

    wire signed [31:0] s_src1 = src1;
    wire signed [31:0] s_src2 = src2;
    wire [63:0] src1_64 = {32'h0, src1};
    wire [63:0] src2_64 = {32'h0, src2};
    wire signed [63:0] s_src1_64 = {{32{src1[31]}}, src1};
    wire signed [63:0] s_src2_64 = {{32{src2[31]}}, src2};
    wire signed [63:0] mulh_ret = (s_src1_64 * s_src2_64) >> 32;
    wire signed [63:0] mulhsu_ret = (s_src1 * src2) >> 32;
    wire signed [63:0] mulhu_ret = (src1 * src2) >> 32;

    always @(posedge clk) begin
        if (rst) begin
            r_dnpc <= 0;
            r_result <= 0;
            // r_result_mem_width <= 0;
            r_result_update_gpr <= 0;
        end else begin
            r_dnpc <= r_dnpc;
            r_result <= r_result;
            // r_result_mem_width <= r_result_mem_width;
            r_result_update_gpr <= r_result_update_gpr;

            r_stage_out_valid <= stage_in_done ? 1 : 0;

            if (stage_in_done) begin
                // 默认更新程序寄存器
                r_dnpc <= pc + 4;
                r_result <= 0;
                // r_result_mem_width <= 0;
                r_result_update_gpr <= ex_enable;

                // 更新寄存器或回写内存
                // $display("Step - update, alu_result:%x rd:%d inst_code:%x", alu_result, rd, inst_code);
                case (inst_code)
                    `INST_LUI:          r_result <= imm;
                    `INST_AUIPC:        r_result <= pc + imm;
                    `INST_JAL:          begin r_result <= pc + 4; r_dnpc <= pc + imm; end
                    `INST_JALR:         begin r_result <= pc + 4; r_dnpc <= ((src1 + imm)&~1); end
                    `INST_BEQ:          begin if (src1==src2) r_dnpc <= pc + imm; r_result_update_gpr <= 0; end
                    `INST_BNE:          begin if (src1!=src2) r_dnpc <= pc + imm; r_result_update_gpr <= 0; end
                    `INST_BLT:          begin if (s_src1<s_src2) r_dnpc <= pc + imm; r_result_update_gpr <= 0; end
                    `INST_BGE:          begin if (s_src1>=s_src2) r_dnpc <= pc + imm; r_result_update_gpr <= 0; end
                    `INST_BLTU:         begin if (src1< src2) r_dnpc <= pc + imm; r_result_update_gpr <= 0; end
                    `INST_BGEU:         begin if (src1>=src2) r_dnpc <= pc + imm; r_result_update_gpr <= 0; end
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
                    `INST_ECALL:        begin r_dnpc <= func_raise_intr((0<<31|11<<0), pc); r_result_update_gpr <= 0; end // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0)
                    `INST_EBREAK:       func_exit_simu(a0);
                    `INST_CSRRW:        begin r_result <= func_read_raw_csr(imm); func_write_raw_csr(imm, src1); end
                    `INST_CSRRS:        begin r_result <= func_read_raw_csr(imm); func_write_raw_csr(imm, (func_read_raw_csr(imm) | src1)); end
                    `INST_CSRRC:        func_invalid_inst(pc, inst);
                    `INST_CSRRWI:       func_invalid_inst(pc, inst);
                    `INST_CSRRSI:       func_invalid_inst(pc, inst);
                    `INST_CSRRCI:       func_invalid_inst(pc, inst);
                    /* TODO 多位乘除需要多周期来处理，会严重拉低整体频率 */
                    `INST_MUL:          r_result <= src1 * src2;
                    `INST_MULH:         r_result <= mulh_ret[31:0];
                    `INST_MULHSU:       r_result <= mulhsu_ret[31:0];
                    `INST_MULHU:        r_result <= mulhu_ret[31:0];
                    `INST_DIV:          r_result <= s_src1 / s_src2;
                    `INST_DIVU:         r_result <= src1 / src2;
                    `INST_REM:          r_result <= s_src1 % s_src2;
                    `INST_REMU:         r_result <= src1 % src2;
                    `INST_MRET:         begin r_dnpc <= func_query_intr(); r_result_update_gpr <= 0; end
                    `INST_INVALID:      func_invalid_inst(pc, inst);
                    default: ;
                endcase
            end
        end
    end

endmodule
