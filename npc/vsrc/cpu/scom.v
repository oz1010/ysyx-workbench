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
    .recv_ready(prev_ready),
    .send_valid(prev_valid),
    .recv_status(w_prev_state)
);

scom_send m_scom_send(
    .clk(clk),
    .rst(rst),
    .recv_ready(next_ready),
    .send_valid(next_valid),
    .send_status(state)
);

endmodule

module scom_base (
    input wire ready,
    input wire valid,
    output wire [1:0] state
);

/*
status = {ready,valid}
======
current     next    action
00          01      send data
01          11      recv data
1x          00      reset
*/

wire [1:0] status = {ready,valid};
assign state = 
    (status==2'b00) ? `SCOM_SEND :
    (status==2'b01) ? `SCOM_RECV :
    `SCOM_RESET;

endmodule

module scom_send (
    input wire clk,
    input wire rst,

    input wire recv_ready,
    output wire send_valid,
    output wire [1:0] send_status
);

reg r_send_valid;

assign send_valid = r_send_valid;

scom_base m_scom_send(
    .ready(recv_ready),
    .valid(send_valid),
    .state(send_status)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_send_valid <= 0;
    end else begin
        case (send_status)
            `SCOM_SEND: r_send_valid <= 1;
            `SCOM_RECV: r_send_valid <= 1;
            default: r_send_valid <= 0;
        endcase
    end

end

endmodule

module scom_recv (
    input wire clk,
    input wire rst,

    output wire recv_ready,
    input wire send_valid,
    output wire [1:0] recv_status
);

reg r_recv_ready;

assign recv_ready = r_recv_ready;

scom_base m_scom_recv(
    .ready(r_recv_ready),
    .valid(send_valid),
    .state(recv_status)
);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_recv_ready <= 0;
    end else begin
        case (recv_status)
            `SCOM_RECV: r_recv_ready <= 1;
            default: r_recv_ready <= 0;
        endcase
    end

end

endmodule
