module inst_fetch #(
    parameter INST_WIDTH = 32
) (
    input wire clk,
    input wire rst,

    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] inst,

    input wire next_ready,
    output wire next_valid
);

reg [INST_WIDTH-1:0] r_inst;
wire [1:0] w_if_state;

assign inst = r_inst;

scom_send m_scom_if(
    .clk(clk),
    .rst(rst),
    .enable(1),
    .next_ready(next_ready),
    .next_valid(next_valid),
    .state(w_if_state)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_inst <= 0;
    end else begin
        if (w_if_state == `SCOM_FOUND) r_inst <= fetch_inst(pc);
    end
end

endmodule