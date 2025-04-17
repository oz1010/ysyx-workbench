// 触发器模板
module Reg #(WIDTH = 1, RESET_VAL = 0) (
    input clock,
    input reset,
    input [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout,
    input wen
);
    // 数据写入在下降沿
    always @(negedge clock) begin
        if (reset) dout <= RESET_VAL;
        else if (wen) dout <= din;
    end
endmodule

module Reg32 (
    input clock,
    input reset,
    input [31:0] din,
    output reg [31:0] dout,
    input wen
);
    Reg #(32, 32'b0) i0(clock, reset, din, dout, wen);
endmodule

module PC32 (
    input clock,
    input reset,
    input [31:0] din,
    output reg [31:0] dout
);
    Reg #(32, 32'h80000000) i0(clock, reset, din, dout, 1'b1);
endmodule
