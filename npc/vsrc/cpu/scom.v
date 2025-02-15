`include "riscv32e_defines.v"

module scom (
    input wire clk,
    input wire rst,

    output wire prev_ready,
    input wire prev_valid,
    input wire next_ready,
    output wire next_valid,

    output wire [1:0] state
);

wire [1:0] w_prev_state;

scom_recv m_scom_recv(
    .clk(clk),
    .rst(rst),
    .recv_enable(prev_valid),
    .recv_ready(prev_ready),
    .send_valid(prev_valid),
    .recv_state(w_prev_state)
);

scom_send m_scom_send(
    .clk(clk),
    .rst(rst),
    .send_enable(prev_ready),
    .recv_ready(next_ready),
    .send_valid(next_valid),
    .send_state(state)
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
    (w_data==2'b00) ? `SCOM_SEND :
    (w_data==2'b01) ? `SCOM_RECV :
    (w_data==2'b10) ? `SCOM_INVALID :
    `SCOM_RESET;

endmodule

module scom_send (
    input wire clk,
    input wire rst,

    input wire send_enable,
    input wire recv_ready,
    output wire send_valid,
    output wire [1:0] send_state
);

reg r_send_valid;

assign send_valid = r_send_valid;

scom_base m_scom_send(
    .enable(r_send_valid),
    .ready(recv_ready),
    .valid(send_valid),
    .state(send_state)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_send_valid <= 0;
    end else begin
        r_send_valid <= r_send_valid;
        if (r_send_valid == 0) begin
            if (send_enable) r_send_valid <= 1;
        end else begin
            if (send_state == `SCOM_RESET) r_send_valid <= 0;
        end
    end
end

endmodule

module scom_recv (
    input wire clk,
    input wire rst,

    input wire recv_enable,
    output wire recv_ready,
    input wire send_valid,
    output wire [1:0] recv_state
);

reg r_recv_ready;

assign recv_ready = r_recv_ready;

scom_base m_scom_recv(
    .enable(recv_enable),
    .ready(r_recv_ready),
    .valid(send_valid),
    .state(recv_state)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_recv_ready <= 0;
    end else begin
        case (recv_state)
            `SCOM_RECV: r_recv_ready <= 1;
            default: r_recv_ready <= 0;
        endcase
    end

end

endmodule
