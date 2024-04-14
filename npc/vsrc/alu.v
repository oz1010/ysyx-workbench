module alu(
    input [2:0] f,
    input [3:0] a,b,
    output reg [3:0] out,
    output zero,overflow,carry
);

wire [3:0] add_out;
wire add_carry;
adder_4bit add(0 , a, b, add_carry, add_out);

wire [3:0] sub_out;
wire sub_carry;
wire [3:0] nocarryb = ({4{1'b1}}^b) + 1;
adder_4bit sub(0 , a, nocarryb, sub_carry, sub_out);

/* verilator lint_off LATCH */
always @(*) begin
    {zero,overflow,carry} = 0;
    case (f)
        3'b000: // A + B
        begin
            out = add_out;
            zero = ~(| out);
            overflow = add_carry;
            carry = add_carry;
        end
        3'b001:  // A - B
        begin
            // $display("b %x 1^b %x nocarryb %x\n", b, ({4{1'b1}}^b) + 4'b0001, nocarryb);
            out = sub_out;
            zero = ~(| out);
            overflow = (a[3]==nocarryb[3]) && (a[3]!=out[3]);
            carry = sub_carry;
        end
        3'b010: out = ~a; // Not A
        3'b011: out = a&b; // A and B
        3'b100: out = a|b; // A or B
        3'b101: out = a^b; // A xor B
        3'b110: out = {3'b0,a<b}; // if A<B then out=1; else out=0;
        3'b111: out = {3'b0,a==b}; // if A=B then out=1; else out=0;
        default: out = 4'b0;
    endcase
end
    
endmodule //alu
