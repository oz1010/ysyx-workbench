// `include "riscv32e_defines.v"

module top (
    input  wire         clock,
    input  wire         reset,

    output wire         out
);

    assign out = count[0];

    reg [31:0] count;

    always @(posedge clock) begin
        if (reset) begin
            count <= 0;
        end else begin
            count <= count + 1;
        end
    end

endmodule
