module inst_fetch #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,
    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] inst,

    input wire ready,
    output wire valid
);

reg [INST_WIDTH-1:0] r_inst;
reg r_valid;

assign inst = r_inst;
assign valid = r_valid;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_inst <= 0;
        r_valid <= 0;
    end else begin
        r_inst <= fetch_inst(pc);
        r_valid <= 1;
    end
end

endmodule