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
reg [ADDR_WIDTH-1:0] r_write_addr;

reg r_aw_ready;
reg r_w_ready;
reg r_b_valid;
reg [BRESP_WIDTH-1:0] r_b_resp;
reg r_ar_ready;
reg r_r_valid;
reg [DATA_WIDTH-1:0] r_r_data;
reg [RRESP_WIDTH-1:0] r_r_resp;

wire [DATA_WIDTH-1:0] w_write_width = {{DATA_WIDTH-DATA_WIDTH/8{1'b0}}, w_strb};

assign aw_ready = r_aw_ready;
assign w_ready = r_w_ready;
assign b_valid = r_b_valid;
assign b_resp = r_b_resp;
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
        r_write_addr <= 0;
        r_aw_ready <= 0;
        r_w_ready <= 0;
        r_b_valid <= 0;
        r_b_resp <= 0;
        r_ar_ready <= 0;
        r_r_valid <= 0;
        r_r_data <= 0;
        r_r_resp <= 0;
    end else begin
        r_write_addr <= r_write_addr;
        r_aw_ready <= r_aw_ready;
        r_w_ready <= r_w_ready;
        r_b_valid <= r_b_valid;
        r_b_resp <= r_b_resp;
        r_ar_ready <= r_ar_ready;
        r_r_valid <= r_r_valid;
        r_r_data <= r_r_data;
        r_r_resp <= r_r_resp;

        // write request
        if (aw_valid) begin
            r_aw_ready <= 1;
        end
        if (aw_valid && aw_ready) begin
            r_write_addr <= aw_addr;
            r_aw_ready <= 0;
        end

        // write data
        if (aw_valid && aw_ready) begin
            r_w_ready <= 1;
        end
        if (w_valid && w_ready) begin
            write_raw_mem(r_write_addr, w_write_width, w_data);
            r_w_ready <= 0;
        end

        // write response
        if (w_valid && w_ready) begin
            r_b_valid <= 1;
            r_b_resp <= 1;
        end
        if (b_valid && b_ready) begin
            r_b_valid <= 0;
            r_b_resp <= 0;
        end

        // read request
        if (!r_ar_ready && !r_ready && ar_valid) begin
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

module sram_axi4_arbiter #(
    parameter MASTER_COUNT = 1,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SRAM_READ_DELAY = 0
) (
    input wire clk,
    input wire rst,

    input wire aw_valids[MASTER_COUNT-1:0],
    output wire aw_readys[MASTER_COUNT-1:0],
    input wire [ADDR_WIDTH-1:0] aw_addrs[MASTER_COUNT-1:0],
    input wire w_valids[MASTER_COUNT-1:0],
    output wire w_readys[MASTER_COUNT-1:0],
    input wire [DATA_WIDTH-1:0] w_datas[MASTER_COUNT-1:0],
    input wire [DATA_WIDTH/8-1:0] w_strbs[MASTER_COUNT-1:0],
    output wire b_valids[MASTER_COUNT-1:0],
    input wire b_readys[MASTER_COUNT-1:0],
    output wire [BRESP_WIDTH-1:0] b_resps[MASTER_COUNT-1:0],
    input wire ar_valids[MASTER_COUNT-1:0],
    output wire ar_readys[MASTER_COUNT-1:0],
    input wire [ADDR_WIDTH-1:0] ar_addrs[MASTER_COUNT-1:0],
    output wire r_valids[MASTER_COUNT-1:0],
    input wire r_readys[MASTER_COUNT-1:0],
    output wire [DATA_WIDTH-1:0] r_datas[MASTER_COUNT-1:0],
    output wire [RRESP_WIDTH-1:0] r_resps[MASTER_COUNT-1:0]
);

sram_axi4 #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
    .SRAM_READ_DELAY(SRAM_READ_DELAY)
) m_sram_axi4(
    .clk(clk),
    .rst(rst),
    .aw_valid(aw_valid),
    .aw_ready(aw_ready),
    .aw_addr(aw_addr),
    .w_valid(w_valid),
    .w_ready(w_ready),
    .w_data(w_data),
    .w_strb(w_strb),
    .b_valid(b_valid),
    .b_ready(b_ready),
    .b_resp(b_resp),
    .ar_valid(ar_valid),
    .ar_ready(ar_ready),
    .ar_addr(ar_addr),
    .r_valid(r_valid),
    .r_ready(r_ready),
    .r_data(r_data),
    .r_resp(r_resp)
);

function integer log2;
    input integer value;
    integer result;
    begin
        result = 0;
        while (value > 1) begin
            value = value >> 1;
            result = result + 1;
        end
        log2 = result;
    end
endfunction

reg [MASTER_COUNT-1:0] signal_enable;
reg [MASTER_COUNT:0] grant;  // Master 授权信号
reg [MASTER_COUNT:0] last_granted;  // 记录上次被仲裁成功的 Master 编号

reg aw_valid;
wire aw_ready;
reg [ADDR_WIDTH-1:0] aw_addr;
reg w_valid;
wire w_ready;
reg [DATA_WIDTH-1:0] w_data;
reg [DATA_WIDTH/8-1:0] w_strb;
wire b_valid;
reg b_ready;
wire [BRESP_WIDTH-1:0] b_resp;
reg ar_valid;
wire ar_ready;
reg [ADDR_WIDTH-1:0] ar_addr;
wire r_valid;
reg r_ready;
wire [DATA_WIDTH-1:0] r_data;
wire [RRESP_WIDTH-1:0] r_resp;

genvar i;
generate
    for (i = 0; i < MASTER_COUNT; ++i) begin : signal_gen
        assign signal_enable[i] = aw_valids[i] | w_valids[i] | b_valids[i] | ar_valids[i] | r_valids[i];

        assign aw_readys[i] = (aw_ready & {$bits(aw_ready){grant[i]}});
        assign w_readys[i] = (w_ready & {$bits(w_ready){grant[i]}});
        assign b_valids[i] = (b_valid & {$bits(b_valid){grant[i]}});
        assign b_resps[i] = b_resp;
        assign ar_readys[i] = (ar_ready & {$bits(ar_ready){grant[i]}});
        assign r_valids[i] = (r_valid & {$bits(r_valid){grant[i]}});
        assign r_datas[i] = r_data;
        assign r_resps[i] = (r_resp & {$bits(r_resp){grant[i]}});
    end
endgenerate

always @(*) begin
    aw_valid = 0;
    aw_addr = 0;
    w_valid = 0;
    w_data = 0;
    w_strb = 0;
    b_ready = 0;
    ar_valid = 0;
    ar_addr = 0;
    r_ready = 0;

    for (int m=0; m<MASTER_COUNT; ++m) begin
        if (grant[m]) begin
            aw_valid = aw_valids[m];
            aw_addr = aw_addrs[m];
            w_valid = w_valids[m];
            w_data = w_datas[m];
            w_strb = w_strbs[m];
            b_ready = b_readys[m];
            ar_valid = ar_valids[m];
            ar_addr = ar_addrs[m];
            r_ready = r_readys[m];
            break;
        end
    end
end

integer t;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        grant <= 0;
        last_granted <= 0;
    end else begin
        grant <= 0; // default is not granted

        for (t=0; t<MASTER_COUNT; ++t) begin
            if (signal_enable[(last_granted + t[MASTER_COUNT:0]) % MASTER_COUNT]) begin
                grant[(last_granted + t[MASTER_COUNT:0]) % MASTER_COUNT] <= 1;
                last_granted <= (last_granted + t[MASTER_COUNT:0]) % MASTER_COUNT;
                break;
            end
        end
    end    
end

endmodule
