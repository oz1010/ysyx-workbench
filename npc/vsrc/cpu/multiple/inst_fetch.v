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

wire [INST_WIDTH-1:0] w_inst;
wire [1:0] w_if_state;
reg r_sram_valid;
wire w_scom_valid;

assign inst = w_inst;

assign next_valid = w_scom_valid & r_sram_valid;

scom_send m_scom_if(
    .clk(clk),
    .rst(rst),
    .enable(1),
    .next_ready(next_ready),
    .next_valid(w_scom_valid),
    .state(w_if_state)
);

sram_delay #(
    .INST_WIDTH(INST_WIDTH),
    .SRAM_READ_DELAY(2)
) m_sram_delay (
    .clk(clk),
    .rst(rst),
    .enable(w_if_state == `SCOM_FOUND),
    .addr(pc),
    .data(w_inst),
    .valid(r_sram_valid)
);

endmodule