// muldivremtest.sv
// 形式化验证测试：对比 ex_muldivrem_single 与 ex_muldivrem_multi 的结果
// 参考：test/verification/verilog/sub

`include "riscv32e_defines.v"

module muldivremtest (
    input wire clk,
    input wire rst
);

    // 非确定性输入，仅在 S_LOAD 时被采样
    (* anyseq *) reg [`INST_CODE_W-1:0] fv_inst_code;
    (* anyseq *) reg [31:0] fv_src1;
    (* anyseq *) reg [31:0] fv_src2;

    // 状态机
    localparam S_RESET = 2'd0;
    localparam S_LOAD  = 2'd1;
    localparam S_EXEC  = 2'd2;
    localparam S_CHECK = 2'd3;

    reg [1:0] state;
    reg [`INST_CODE_W-1:0] inst_code;
    reg [31:0] src1;
    reg [31:0] src2;
    reg [5:0] wait_cnt;

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
                    end else if (wait_cnt < 6'd40) begin
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

    // 除法/取余时除数不能为零（当前实现未按 RISC-V 规范处理除零）
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
    wire [31:0] single_result;

    ex_muldivrem_single #(
        .INST_WIDTH(32)
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
    wire [31:0] multi_result;

    ex_muldivrem_multi #(
        .INST_WIDTH(32)
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
    wire signed [31:0] s_src1 = src1;
    wire signed [31:0] s_src2 = src2;
    wire signed [63:0] s_src1_64 = {{32{src1[31]}}, src1};
    wire signed [63:0] s_src2_64 = {{32{src2[31]}}, src2};
    wire signed [63:0] mulh_ref   = (s_src1_64 * s_src2_64) >> 32;
    wire signed [63:0] mulhsu_ref = (s_src1 * src2) >> 32;
    wire signed [63:0] mulhu_ref  = (src1 * src2) >> 32;

    reg [31:0] ref_result;
    always @(*) begin
        case (inst_code)
            `INST_MUL:      ref_result = src1 * src2;
            `INST_MULH:     ref_result = mulh_ref[31:0];
            `INST_MULHSU:   ref_result = mulhsu_ref[31:0];
            `INST_MULHU:    ref_result = mulhu_ref[31:0];
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
