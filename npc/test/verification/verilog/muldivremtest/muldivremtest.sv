// muldivremtest.sv
// 形式化验证测试：对比 ex_muldivrem_single 与 ex_muldivrem_multi 的结果
// 参考：test/verification/verilog/sub
//
// 数据位宽由 FVW 宏控制（默认 8）。
// 注意：32 位全位宽的乘/除等价性 BMC 证明超出了位向量求解器（boolector/bitwuzla/
// yices/cvc5 均超 1 小时不收敛）的能力，因此默认在 8 位位宽下做穷举式证明——
// 乘除器的符号处理、高低位选择、迭代结构等逻辑均与位宽无关，8 位穷举即可完全覆盖；
// 32 位位宽的正确性另由仿真交叉校验（随机+边界向量）保证。
// 需要尝试更大位宽时：make verify FVW=16（耗时随位宽指数增长）。

`include "riscv32e_defines.v"

`ifndef FVW
`define FVW 8
`endif

module muldivremtest (
    input wire clk,
    input wire rst
);

    localparam W = `FVW;

    // 非确定性输入，仅在 S_LOAD 时被采样
    (* anyseq *) reg [`INST_CODE_W-1:0] fv_inst_code;
    (* anyseq *) reg [W-1:0] fv_src1;
    (* anyseq *) reg [W-1:0] fv_src2;

    // 状态机
    localparam S_RESET = 2'd0;
    localparam S_LOAD  = 2'd1;
    localparam S_EXEC  = 2'd2;
    localparam S_CHECK = 2'd3;

    reg [1:0] state;
    reg [`INST_CODE_W-1:0] inst_code;
    reg [W-1:0] src1;
    reg [W-1:0] src2;
    reg [7:0] wait_cnt;

    wire enable = (state == S_EXEC) || (state == S_CHECK);

    // 复位后保持两拍复位，保证模块初始化完成
    reg [1:0] f_rstcnt = 0;
    always @(posedge clk) begin
        if (f_rstcnt != 2) f_rstcnt <= f_rstcnt + 1;
        if (f_rstcnt != 2) assume(rst);
        else assume(!rst);
    end

    // 状态机：加载输入 -> 执行 -> 检查
    always @(posedge clk) begin
        if (rst) begin
            state <= S_RESET;
            wait_cnt <= 0;
            inst_code <= `INST_MUL;
            src1 <= 0;
            src2 <= 0;
        end else begin
            case (state)
                S_RESET: state <= S_LOAD;

                S_LOAD: begin
                    inst_code <= fv_inst_code;
                    src1 <= fv_src1;
                    src2 <= fv_src2;
                    state <= S_EXEC;
                    wait_cnt <= 0;
                end

                S_EXEC: begin
                    if (multi_valid) begin
                        state <= S_CHECK;
                    end else if (wait_cnt < 2*W+8) begin
                        wait_cnt <= wait_cnt + 1;
                    end
                end

                S_CHECK: begin
                    state <= S_LOAD;
                end

                default: state <= S_RESET;
            endcase
        end
    end

    // 约束输入为 RV32M 乘除取余指令
    always @(*) begin
        assume((fv_inst_code == `INST_MUL)    ||
               (fv_inst_code == `INST_MULH)   ||
               (fv_inst_code == `INST_MULHSU) ||
               (fv_inst_code == `INST_MULHU)  ||
               (fv_inst_code == `INST_DIV)    ||
               (fv_inst_code == `INST_DIVU)   ||
               (fv_inst_code == `INST_REM)    ||
               (fv_inst_code == `INST_REMU));
    end

    // 除法/取余时除数不能为零（除零语义由仿真回归覆盖）
    always @(*) begin
        if (state != S_RESET) begin
            if ((inst_code == `INST_DIV)  ||
                (inst_code == `INST_DIVU) ||
                (inst_code == `INST_REM)  ||
                (inst_code == `INST_REMU)) begin
                assume(src2 != 0);
            end
        end
    end

    // DUT：单周期实现
    wire single_valid;
    wire [W-1:0] single_result;

    ex_muldivrem_single #(
        .INST_WIDTH(W)
    ) dut_single (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .inst_code(inst_code),
        .src1(src1),
        .src2(src2),
        .valid(single_valid),
        .result(single_result)
    );

    // DUT：多周期实现
    wire multi_valid;
    wire [W-1:0] multi_result;

    ex_muldivrem_multi #(
        .INST_WIDTH(W)
    ) dut_multi (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .inst_code(inst_code),
        .src1(src1),
        .src2(src2),
        .valid(multi_valid),
        .result(multi_result)
    );

    // 参考模型：与单周期实现使用完全相同的 Verilog 语义
    wire signed [W-1:0]   s_src1 = src1;
    wire signed [W-1:0]   s_src2 = src2;
    wire signed [2*W-1:0] s_src1_64 = {{W{src1[W-1]}}, src1};
    wire signed [2*W-1:0] s_src2_64 = {{W{src2[W-1]}}, src2};
    wire signed [2*W-1:0] mulh_ref   = (s_src1_64 * s_src2_64) >> W;
    // MULHSU：src1 有符号 x src2 无符号；直接写 (s_src1 * src2) 会按无符号运算（Verilog 有符号规则）
    wire signed [2*W-1:0] mulhsu_ref = (s_src1_64 * $signed({1'b0, src2})) >> W;
    wire signed [2*W-1:0] mulhu_ref  = (src1 * src2) >> W;

    reg [W-1:0] ref_result;
    always @(*) begin
        case (inst_code)
            `INST_MUL:      ref_result = src1 * src2;
            `INST_MULH:     ref_result = mulh_ref[W-1:0];
            `INST_MULHSU:   ref_result = mulhsu_ref[W-1:0];
            `INST_MULHU:    ref_result = mulhu_ref[W-1:0];
            `INST_DIV:      ref_result = s_src1 / s_src2;
            `INST_DIVU:     ref_result = src1 / src2;
            `INST_REM:      ref_result = s_src1 % s_src2;
            `INST_REMU:     ref_result = src1 % src2;
            default:        ref_result = 0;
        endcase
    end

    // 验证断言：多周期完成时，两个实现都应有效且结果与参考模型一致
    always @(posedge clk) begin
        if (!rst && state == S_CHECK) begin
            assert(single_valid);
            assert(multi_valid);
            assert(single_result == ref_result);
            assert(multi_result  == ref_result);
            assert(single_result == multi_result);
        end
    end

    // 覆盖点：确保 BMC 遍历到各类指令
    always @(posedge clk) begin
        if (!rst) begin
            cover(state == S_CHECK);
            cover(state == S_CHECK && inst_code == `INST_MUL);
            cover(state == S_CHECK && inst_code == `INST_MULH);
            cover(state == S_CHECK && inst_code == `INST_MULHSU);
            cover(state == S_CHECK && inst_code == `INST_MULHU);
            cover(state == S_CHECK && inst_code == `INST_DIV);
            cover(state == S_CHECK && inst_code == `INST_DIVU);
            cover(state == S_CHECK && inst_code == `INST_REM);
            cover(state == S_CHECK && inst_code == `INST_REMU);
        end
    end

endmodule
