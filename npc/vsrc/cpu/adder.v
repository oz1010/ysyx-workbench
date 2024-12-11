/* verilator lint_off DECLFILENAME */
module adder32(
    input cin,
    input [31:0] a,b,
    output carry,
    output [31:0] out
);

wire [$bits(a):0] c;

assign c[0] = cin;
assign carry = c[$bits(a)];

genvar i;
generate for(i = 0 ; i < $bits(a); i = i + 1) begin : adder_gen
    adder_1bit adder_u(
        c[i],
        a[i],
        b[i],
        c[i+1],
        out[i]
    );
end
endgenerate

endmodule



module adder_1bit(
    input cin,
    input a,b,
    output cout,out
);
    assign {cout,out} = a+b+cin;
endmodule // adder_1bit
