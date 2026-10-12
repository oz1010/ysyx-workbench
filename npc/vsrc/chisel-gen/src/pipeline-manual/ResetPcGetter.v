module ResetPcGetter #(
    parameter ADDR_WIDTH = 32
)(
    input   wire            clk,
    input   wire            rst,
    output [ADDR_WIDTH-1:0] reset_pc
);
    assign reset_pc = r_pc;

    reg [31:0] r_pc;
    always @(posedge clk) begin
        if (rst) begin
            r_pc <= func_get_reset_pc();
        end
    end
endmodule
