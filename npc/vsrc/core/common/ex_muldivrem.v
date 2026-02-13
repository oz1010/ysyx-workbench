/*
 * 最简单实现乘除取余模块
 *   多位乘除取余需要多周期来处理，否则会严重拉低整体频率。
 */
module ex_muldivrem #(
    parameter INST_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        enable,
    input   wire [`INST_CODE_W-1:0]     inst_code,
    input   wire [INST_WIDTH-1:0]       src1,
    input   wire [INST_WIDTH-1:0]       src2,
    output  reg                         valid,
    output  reg  [INST_WIDTH-1:0]       result
);

    wire                         single_valid;
    wire  [INST_WIDTH-1:0]       single_result;
    wire                         multi_valid;
    wire  [INST_WIDTH-1:0]       multi_result;

    `ifndef IN_YOSYS_STA
    ex_muldivrem_single #(
        .INST_WIDTH(INST_WIDTH)
    ) m_ex_muldivrem_single (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .inst_code(inst_code),
        .src1(src1),
        .src2(src2),
        .valid(single_valid),
        .result(single_result)
    );
    `endif

    ex_muldivrem_multi #(
        .INST_WIDTH(INST_WIDTH)
    ) m_ex_muldivrem_multi (
        .clk(clk),
        .rst(rst),
        .enable(enable),
        .inst_code(inst_code),
        .src1(src1),
        .src2(src2),
        .valid(multi_valid),
        .result(multi_result)
    );

    assign valid = single_valid & multi_valid;
    assign result = multi_result;

    always @(posedge clk) begin
        if (rst | !enable) begin
        end else begin
            if (valid) begin
                `ifndef IN_YOSYS_STA
                // TODO 非综合使用比较方式，校验两种的结果是否一致
                if (single_result!=multi_result) begin
                    $error("muldivrem result dismatch, code %x src1 %x src2 %x result(%x %x)",
                        inst_code, src1, src2, single_result, multi_result);
                end
                `endif
            end
        end
    end

endmodule

// 单周期版本
module ex_muldivrem_single #(
    parameter INST_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        enable,
    input   wire [`INST_CODE_W-1:0]     inst_code,
    input   wire [INST_WIDTH-1:0]       src1,
    input   wire [INST_WIDTH-1:0]       src2,
    output  reg                         valid,
    output  reg  [INST_WIDTH-1:0]       result
);

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
        if (rst | !enable) begin
            valid <= 0;
            result <= 0;
        end else begin
            if (!valid) begin
                case (inst_code)
                    `INST_MUL:          result <= src1 * src2;
                    `INST_MULH:         result <= mulh_ret[31:0];
                    `INST_MULHSU:       result <= mulhsu_ret[31:0];
                    `INST_MULHU:        result <= mulhu_ret[31:0];
                    `INST_DIV:          result <= s_src1 / s_src2;
                    `INST_DIVU:         result <= src1 / src2;
                    `INST_REM:          result <= s_src1 % s_src2;
                    `INST_REMU:         result <= src1 % src2;
                    default:            result <= 0;
                endcase
                valid <= 1;
            end else begin
            end
        end
    end

endmodule

// AI生成的多收起版本
module ex_muldivrem_multi #(
    parameter INST_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        enable,
    input   wire [`INST_CODE_W-1:0]     inst_code,
    input   wire [INST_WIDTH-1:0]       src1,
    input   wire [INST_WIDTH-1:0]       src2,
    output  reg                         valid,
    output  reg  [INST_WIDTH-1:0]       result
);

    //--------------------------------------------------
    // FSM state
    //--------------------------------------------------
    localparam S_IDLE  = 0;
    localparam S_MUL   = 1;
    localparam S_DIV   = 2;
    localparam S_DONE  = 3;

    reg [1:0] state;

    //--------------------------------------------------
    // registers
    //--------------------------------------------------
    reg [5:0]  cnt;
    reg [63:0] mul_a, mul_b, mul_res;

    reg [63:0] div_dividend;
    reg [31:0] div_divisor;
    reg [31:0] quotient;
    reg [32:0] remainder;

    reg signed_mode;
    reg rem_mode;
    reg [2:0] op_type;

    // 临时变量（组合）
    reg [32:0] remainder_next;
    reg [31:0] quotient_next;
    reg [63:0] dividend_next;

    //--------------------------------------------------
    // decode operation
    //--------------------------------------------------
    always @(*) begin
        signed_mode = 0;
        rem_mode    = 0;
        op_type     = 0;

        case(inst_code)
            `INST_MUL:    op_type = 1;
            `INST_MULH:   begin op_type=1; signed_mode=1; end
            `INST_MULHSU: begin op_type=1; signed_mode=1; end
            `INST_MULHU:  op_type=1;

            `INST_DIV:  begin op_type=2; signed_mode=1; end
            `INST_DIVU: op_type=2;
            `INST_REM:  begin op_type=2; signed_mode=1; rem_mode=1; end
            `INST_REMU: begin op_type=2; rem_mode=1; end
            default: ;
        endcase
    end

    //--------------------------------------------------
    // main FSM
    //--------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            state  <= S_IDLE;
            valid  <= 0;
            result <= 0;
        end else begin
            case(state)

            //--------------------------------------------------
            // IDLE
            //--------------------------------------------------
            S_IDLE: begin
                valid <= 0;

                if(enable) begin
                    cnt <= 0;

                    // MUL start
                    if(op_type == 1) begin
                        mul_a   <= {32'b0, src1};
                        mul_b   <= {32'b0, src2};
                        mul_res <= 0;
                        state   <= S_MUL;
                    end

                    // DIV start
                    else if(op_type == 2) begin
                        div_dividend <= {32'b0, src1};
                        div_divisor  <= src2;
                        quotient     <= 0;
                        remainder    <= 0;
                        state        <= S_DIV;
                    end
                end
            end

            //--------------------------------------------------
            // MULTIPLY (shift-add)
            //--------------------------------------------------
            S_MUL: begin
                if(cnt < 32) begin
                    if(mul_b[0])
                        mul_res <= mul_res + mul_a;

                    mul_a <= mul_a << 1;
                    mul_b <= mul_b >> 1;
                    cnt   <= cnt + 1;
                end else begin
                    result <= mul_res[31:0];
                    state  <= S_DONE;
                end
            end

            //--------------------------------------------------
            // DIVIDE (restoring division)
            //--------------------------------------------------
            S_DIV: begin
                if (cnt < 32) begin
                    // ===== 组合计算 =====
                    remainder_next = {remainder[31:0], div_dividend[63]};
                    dividend_next  = div_dividend << 1;
                    quotient_next  = quotient << 1;

                    if (remainder_next >= {1'b0, div_divisor}) begin
                        remainder_next = remainder_next - div_divisor;
                        quotient_next[0] = 1'b1;
                    end

                    // ===== 时序回写（只用 <=）=====
                    remainder    <= remainder_next;
                    div_dividend <= dividend_next;
                    quotient     <= quotient_next;
                    cnt          <= cnt + 1;
                end else begin
                    result <= rem_mode ? remainder[31:0]
                                    : quotient;
                    state  <= S_DONE;
                end
            end

            //--------------------------------------------------
            // DONE
            //--------------------------------------------------
            S_DONE: begin
                valid <= 1;
                if(!enable)
                    state <= S_IDLE;
            end

            endcase
        end
    end

endmodule

