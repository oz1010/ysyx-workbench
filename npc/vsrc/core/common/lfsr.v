module lfsr_8bit (
    input wire clk,
    input wire rst,
    output reg [7:0] out
);

// 反馈多项式: x^8 + x^6 + x^5 + x^4 + 1
wire feedback = out[7] ^ out[5] ^ out[4] ^ out[3];

always @(posedge clk or posedge rst) begin
    if (rst) begin
        // 复位时初始化LFSR为一个非零值
        out <= 8'b11111111;
    end else begin
        // 移位并应用反馈
        out <= {out[6:0], feedback};
    end
end

endmodule

module lfsr_8bit_galois (
    input wire clk,
    input wire rst,
    output reg  [7:0] lfsr
);

wire enable = 1;

always @(posedge clk or posedge rst) begin
    if (rst)
        lfsr <= 8'h01; // 复位
    else begin
        lfsr <= lfsr;

        if (enable) begin    
            lfsr[7] <= lfsr[6];
            lfsr[6] <= lfsr[5];
            lfsr[5] <= lfsr[4];
            lfsr[4] <= lfsr[3] ^ lfsr[7]; // tap at x^8
            lfsr[3] <= lfsr[2] ^ lfsr[7]; // tap at x^6
            lfsr[2] <= lfsr[1] ^ lfsr[7]; // tap at x^5
            lfsr[1] <= lfsr[0];
            lfsr[0] <= lfsr[7]; // 最低位输入反馈
        end
    end
end
endmodule

module lfsr_delay_signal (
    input wire clk,
    input wire rst,
    input wire enable,

    output wire delay_enable,
    input wire [7:0] delay_max,
    output wire [7:0] delay_cnt,
    output wire [7:0] delay_cur_cnt
);

wire [7:0] cnt;
reg r_delay_enable;
reg [7:0] r_delay_cnt;
lfsr_8bit m_lfsr_ar_valid(
    .clk(clk),
    .rst(rst),
    .out(cnt)
);

assign delay_cur_cnt = cnt % delay_max;
// assign delay_cur_cnt = 0;
assign delay_cnt = r_delay_cnt;
assign delay_enable = r_delay_enable;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_delay_enable <= 0;
        r_delay_cnt <= 0;
    end else begin
        if (r_delay_enable && r_delay_cnt > 0) r_delay_cnt <= r_delay_cnt - 1;
        if (r_delay_enable && r_delay_cnt == 1) r_delay_enable <= 0;

        if (enable) begin
            if (delay_cur_cnt > 0) begin
                r_delay_cnt <= delay_cur_cnt;
                r_delay_enable <= 1;
            end
        end
    end
end

endmodule
