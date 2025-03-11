`include "common/riscv32e_defines.v"

module sram_axi4 #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SRAM_READ_DELAY = 0
) (
    input wire clk,
    input wire rst,

    input wire aw_valid,
    output wire aw_ready,
    input wire [ADDR_WIDTH-1:0] aw_addr,

    input wire w_valid,
    output wire w_ready,
    input wire [DATA_WIDTH-1:0] w_data,
    input wire [DATA_WIDTH/8-1:0] w_strb,

    output wire b_valid,
    input wire b_ready,
    output wire [BRESP_WIDTH-1:0] b_resp,

    input wire ar_valid,
    output wire ar_ready,
    input wire [ADDR_WIDTH-1:0] ar_addr,

    output wire r_valid,
    input wire r_ready,
    output wire [DATA_WIDTH-1:0] r_data,
    output wire [RRESP_WIDTH-1:0] r_resp
);

reg [7:0] r_delay_cnt;
reg r_delay_enable;

reg r_ar_ready;
reg r_r_valid;
reg [DATA_WIDTH-1:0] r_r_data;
reg [RRESP_WIDTH-1:0] r_r_resp;

assign ar_ready = r_ar_ready;
assign r_valid = r_r_valid;
assign r_data = r_r_data;
assign r_resp = r_r_resp;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_delay_cnt <= 8'h0;
        r_delay_enable <= 0;
    end else begin
        r_delay_cnt <= r_delay_cnt;
        r_delay_enable <= r_delay_enable;

        if (r_delay_enable) begin
            r_delay_cnt <= r_delay_cnt + 1;
        end else begin
            r_delay_cnt <= 8'h0;
        end

        if (!r_delay_enable && ar_valid) begin
            r_delay_enable <= 1;
            r_delay_cnt <= 1;
        end
        if (r_valid && r_ready) begin
            r_delay_enable <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_ar_ready <= 0;
        r_r_valid <= 0;
        r_r_data <= 0;
        r_r_resp <= 0;
    end else begin
        r_ar_ready <= r_ar_ready;
        r_r_valid <= r_r_valid;
        r_r_data <= r_r_data;
        r_r_resp <= r_r_resp;

        // read request
        if (!r_ar_ready && !r_ready) begin
            r_ar_ready <= 1;
        end
        if (ar_valid && ar_ready) begin
            r_ar_ready <= 0;
        end

        // read data
        if ((!r_delay_enable && ar_valid && 0 == SRAM_READ_DELAY) ||
            (r_delay_enable && r_delay_cnt == SRAM_READ_DELAY)) begin
            r_r_data <= fetch_inst(ar_addr);
            r_r_valid <= 1;
        end
        if (r_valid && r_ready) begin
            r_r_valid <= 0;
            // r_r_data <= 0;
            r_r_resp <= 0;
        end
    end
end

endmodule