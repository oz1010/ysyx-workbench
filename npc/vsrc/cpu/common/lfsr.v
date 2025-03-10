module lfsr_8bit (
    input wire clk,    // 时钟信号
    input wire rst,    // 复位信号（异步复位）
    output reg  [7:0] lfsr // 8-bit LFSR 输出
);

wire enable = 1;

wire feedback; // 反馈信号
assign feedback = lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]; // 反馈多项式

always @(posedge clk or posedge rst) begin
    if (rst)
        lfsr <= 8'h01; // 复位时设定非零初值（不能是0）
    else begin
        lfsr <= lfsr;
        if (enable) begin
            lfsr <= {lfsr[6:0], feedback}; // 移位+反馈
        end
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

module lfsr_8bit_onesign (
    input wire clk,
    input wire rst,
    input wire raw_sign,
    output wire delay_sign
);

wire [7:0] delay_cnt;

reg r_delay_enable;
reg r_output_enable;
reg [7:0] r_delay_cnt;
reg [7:0] r_delay_output_cnt;

lfsr_8bit m_lfsr(
    .clk(clk),
    .rst(rst),
    .lfsr(delay_cnt)
);

assign delay_sign = r_output_enable && raw_sign;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_delay_cnt <= 0;
        r_delay_enable <= 0;
        r_output_enable <= 0;
    end else begin
        r_delay_cnt <= r_delay_cnt;
        r_delay_enable <= r_delay_enable;
        r_output_enable <= r_output_enable;
        r_delay_output_cnt <= r_delay_output_cnt;
        r_delay_cnt <= r_delay_cnt + 1;
        
        if (!r_delay_enable && raw_sign) begin
            r_delay_enable <= 1;
            r_delay_output_cnt <= (delay_cnt%31);
            r_delay_cnt <= 0;
        end
        if (r_output_enable) begin
            r_delay_enable <= 0;
        end

        if (r_delay_enable && r_delay_cnt >= r_delay_output_cnt) begin
            r_output_enable <= 1;
        end
        if (r_output_enable && !raw_sign) begin
            r_output_enable <= 0;
        end

        if (r_output_enable) begin 
            r_delay_output_cnt <= 0;
        end
        
    end
end

endmodule
