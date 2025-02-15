`include "riscv32e_defines.v"

module scom (
    input wire clk,
    input wire rst,

    output wire prev_ready,
    input wire prev_valid,
    input wire next_ready,
    output wire next_valid,

    output wire [1:0] prev_state,
    output wire [1:0] next_state
);

scom_recv m_scom_recv(
    .clk(clk),
    .rst(rst),
    .enable(prev_valid),
    .prev_ready(prev_ready),
    .prev_valid(prev_valid),
    .state(prev_state)
);

scom_send m_scom_send(
    .clk(clk),
    .rst(rst),
    .enable(prev_state == `SCOM_FOUND),
    .next_ready(next_ready),
    .next_valid(next_valid),
    .state(next_state)
);

endmodule

module scom_base (
    input wire enable,
    input wire ready,
    input wire valid,
    output wire [1:0] state
);

/*
w_data = {ready,valid}
======
current     next    action
00          01      send data
01          11      recv data
11          00      reset
10          00      invalid

enable==0 reset
*/

wire [1:0] w_data = {ready,valid};
assign state = 
    (enable==0) ? `SCOM_INVALID :
    (w_data==2'b00) ? `SCOM_OTHER :
    (w_data==2'b01) ? `SCOM_FOUND :
    (w_data==2'b10) ? `SCOM_INVALID :
    `SCOM_RESET;

endmodule

module scom_send (
    input wire clk,
    input wire rst,

    input wire enable,
    input wire next_ready,
    output wire next_valid,
    output wire [1:0] state
);

reg r_next_valid;

assign next_valid = r_next_valid;

scom_base m_scom_send(
    .enable(r_next_valid),
    .ready(next_ready),
    .valid(next_valid),
    .state(state)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_next_valid <= 0;
    end else begin
        r_next_valid <= r_next_valid;
        if (r_next_valid == 0) begin
            if (enable) r_next_valid <= 1;
        end else begin
            if (state == `SCOM_RESET) r_next_valid <= 0;
        end
    end
end

endmodule

module scom_recv (
    input wire clk,
    input wire rst,

    input wire enable,
    output wire prev_ready,
    input wire prev_valid,
    output wire [1:0] state
);

reg r_prev_ready;

assign prev_ready = r_prev_ready;

scom_base m_scom_recv(
    .enable(enable),
    .ready(r_prev_ready),
    .valid(prev_valid),
    .state(state)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_prev_ready <= 0;
    end else begin
        case (state)
            `SCOM_FOUND: r_prev_ready <= 1;
            default: r_prev_ready <= 0;
        endcase
    end

end

endmodule
