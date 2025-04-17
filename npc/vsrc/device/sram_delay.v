module sram_delay #(
    parameter INST_WIDTH = 32,
    parameter SRAM_READ_DELAY = 1
) (
    input wire clk,
    input wire rst,

    input wire enable,
    input wire [31:0] addr,
    output wire [INST_WIDTH-1:0] data,
    output wire valid,
    input wire ready
);

reg [7:0] r_delay_cnt;
reg r_delay_enable;

reg [INST_WIDTH-1:0] r_data;
reg r_valid;

assign data = r_data;
assign valid = r_valid;

assign r_delay_enable = enable;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_delay_cnt <= 8'h0;
    end else begin
        r_delay_cnt <= r_delay_cnt;

        if (r_delay_enable) begin
            r_delay_cnt <= r_delay_cnt + 1;
        end else begin
            r_delay_cnt <= 8'h0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_data <= 0;
        r_valid <= 0;
    end else begin
        r_valid <= r_valid;
        r_data <= r_data;
        if (r_delay_enable && r_delay_cnt===SRAM_READ_DELAY) begin
            r_data <= fetch_inst(addr);
            r_valid <= 1;
        end
        if (r_valid) r_valid <= 0;
    end
end
    
endmodule