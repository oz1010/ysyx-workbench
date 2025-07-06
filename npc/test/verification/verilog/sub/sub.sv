// sub.sv
`define FORMAL

module sub(
    input [3:0] a,
    input [3:0] b,
    output [3:0] c
);

    // 当a==2时注入错误，即不加1
    assign c = a + ~b + (a == 4'd2 ? 1'b0 : 1'b1);

`ifdef FORMAL
    always @(*) begin
        c_assert: assert(c == a - b);
    end
`endif  // FORMAL

endmodule