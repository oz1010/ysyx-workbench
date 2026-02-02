/*
 * 最简单实现乘除取余模块
 * TODO 多位乘除取余需要多周期来处理，否则会严重拉低整体频率。当前周期会小于100
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
