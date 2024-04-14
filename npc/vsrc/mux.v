/* verilator lint_off DECLFILENAME */
module mux_21(
    input sel,
    input [1:0] in,
    output out
);
assign out = in[sel];
endmodule //mux_21

module mux_42(
    input [1:0] sel,
    input [3:0] in,
    output reg out
);
    assign out = in[sel];

// always @(*)begin
//     case (sel)
//         2'h0: out = in[0];
//         2'h1: out = in[1];
//         2'h2: out = in[2];
//         2'h3: out = in[3];
//         default: out = 1;
//     endcase
// end

endmodule //mux_42

