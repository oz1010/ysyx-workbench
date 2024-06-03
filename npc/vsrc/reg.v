// 触发器模板
module Reg #(WIDTH = 1, RESET_VAL = 0) (
    input clk,
    input rst,
    input [WIDTH-1:0] din,
    output reg [WIDTH-1:0] dout,
    input wen
);
    always @(posedge clk) begin
        if (rst) dout <= RESET_VAL;
        else if (wen) dout <= din;
    end
endmodule

module Reg32 (
    input clk,
    input rst,
    input [31:0] din,
    output reg [31:0] dout,
    input wen
);
    Reg #(32, 32'b0) i0(clk, rst, din, dout, wen);
endmodule

module PC32 (
    input clk,
    input rst,
    input [31:0] din,
    output reg [31:0] dout
);
    Reg #(32, 32'h80000000) i0(clk, rst, din, dout, 1'b1);
endmodule
