module xbar #(
    parameter USER_M_COUNT = 1,
    parameter SLAVE_COUNT = 3,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SRAM_READ_DELAY = 0,
    parameter MASTER_COUNT = USER_M_COUNT + 1
) (
    input wire clk,
    input wire rst,

    input wire u_aw_valids[0:USER_M_COUNT-1],
    output wire u_aw_readys[0:USER_M_COUNT-1],
    input wire [ADDR_WIDTH-1:0] u_aw_addrs[0:USER_M_COUNT-1],
    input wire u_w_valids[0:USER_M_COUNT-1],
    output wire u_w_readys[0:USER_M_COUNT-1],
    input wire [DATA_WIDTH-1:0] u_w_datas[0:USER_M_COUNT-1],
    input wire [DATA_WIDTH/8-1:0] u_w_strbs[0:USER_M_COUNT-1],
    output wire u_b_valids[0:USER_M_COUNT-1],
    input wire u_b_readys[0:USER_M_COUNT-1],
    output wire [BRESP_WIDTH-1:0] u_b_resps[0:USER_M_COUNT-1],
    input wire u_ar_valids[0:USER_M_COUNT-1],
    output wire u_ar_readys[0:USER_M_COUNT-1],
    input wire [ADDR_WIDTH-1:0] u_ar_addrs[0:USER_M_COUNT-1],
    output wire u_r_valids[0:USER_M_COUNT-1],
    input wire u_r_readys[0:USER_M_COUNT-1],
    output wire [DATA_WIDTH-1:0] u_r_datas[0:USER_M_COUNT-1],
    output wire [RRESP_WIDTH-1:0] u_r_resps[0:USER_M_COUNT-1]
);

// 默认master，避免切主时造成从设备响应错误
wire m_aw_valids[0:MASTER_COUNT-1];
wire m_aw_readys[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0] m_aw_addrs[0:MASTER_COUNT-1];
wire m_w_valids[0:MASTER_COUNT-1];
wire m_w_readys[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0] m_w_datas[0:MASTER_COUNT-1];
wire [DATA_WIDTH/8-1:0] m_w_strbs[0:MASTER_COUNT-1];
wire m_b_valids[0:MASTER_COUNT-1];
wire m_b_readys[0:MASTER_COUNT-1];
wire [BRESP_WIDTH-1:0] m_b_resps[0:MASTER_COUNT-1];
wire m_ar_valids[0:MASTER_COUNT-1];
wire m_ar_readys[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0] m_ar_addrs[0:MASTER_COUNT-1];
wire m_r_valids[0:MASTER_COUNT-1];
wire m_r_readys[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0] m_r_datas[0:MASTER_COUNT-1];
wire [RRESP_WIDTH-1:0] m_r_resps[0:MASTER_COUNT-1];
assign m_aw_valids = {0, u_aw_valids};
assign m_aw_addrs = {0, u_aw_addrs};
assign m_w_valids = {0, u_w_valids};
assign m_w_datas = {0, u_w_datas};
assign m_w_strbs = {0, u_w_strbs};
assign m_b_readys = {0, u_b_readys};
assign m_ar_valids = {0, u_ar_valids};
assign m_ar_addrs = {0, u_ar_addrs};
assign m_r_readys = {0, u_r_readys};
assign u_aw_readys = m_aw_readys[1:USER_M_COUNT];
assign u_w_readys = m_w_readys[1:USER_M_COUNT];
assign u_b_valids = m_b_valids[1:USER_M_COUNT];
assign u_b_resps = m_b_resps[1:USER_M_COUNT];
assign u_ar_readys = m_ar_readys[1:USER_M_COUNT];
assign u_r_valids = m_r_valids[1:USER_M_COUNT];
assign u_r_datas = m_r_datas[1:USER_M_COUNT];
assign u_r_resps = m_r_resps[1:USER_M_COUNT];

reg [MASTER_COUNT-1:0] m_signal_en;
reg [MASTER_COUNT-1:0] m_grant;
reg [log2(MASTER_COUNT):0] r_m_grant_idx;
wire [log2(MASTER_COUNT):0] m_grant_idx;

reg aw_valid;
reg aw_ready;
reg [ADDR_WIDTH-1:0] aw_addr; // 用于记录当前master写入的申请地址，需要在角色切换前完成
reg w_valid;
reg w_ready;
reg [DATA_WIDTH-1:0] w_data;
reg [DATA_WIDTH/8-1:0] w_strb;
reg b_valid;
reg b_ready;
reg [BRESP_WIDTH-1:0] b_resp;
reg ar_valid;
reg ar_ready;
reg [ADDR_WIDTH-1:0] ar_addr; // 用于记录当前master读取的申请地址，需要在角色切换前完成
reg r_valid;
reg r_ready;
reg [DATA_WIDTH-1:0] r_data;
reg [RRESP_WIDTH-1:0] r_resp;

wire s_aw_valids[0:SLAVE_COUNT-1];
wire s_aw_readys[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0] s_aw_addrs[0:SLAVE_COUNT-1];
wire s_w_valids[0:SLAVE_COUNT-1];
wire s_w_readys[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0] s_w_datas[0:SLAVE_COUNT-1];
wire [DATA_WIDTH/8-1:0] s_w_strbs[0:SLAVE_COUNT-1];
wire s_b_valids[0:SLAVE_COUNT-1];
wire s_b_readys[0:SLAVE_COUNT-1];
wire [BRESP_WIDTH-1:0] s_b_resps[0:SLAVE_COUNT-1];
wire s_ar_valids[0:SLAVE_COUNT-1];
wire s_ar_readys[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0] s_ar_addrs[0:SLAVE_COUNT-1];
wire s_r_valids[0:SLAVE_COUNT-1];
wire s_r_readys[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0] s_r_datas[0:SLAVE_COUNT-1];
wire [RRESP_WIDTH-1:0] s_r_resps[0:SLAVE_COUNT-1];
reg [SLAVE_COUNT-1:0] s_grant;
reg [log2(SLAVE_COUNT):0] s_grant_idx;

parameter logic [ADDR_WIDTH-1:0] dev_addr_bases[SLAVE_COUNT] = '{`DEV_SRAM_ADDR_BASE, `DEV_UART_ADDR_BASE, `DEV_RTC_ADDR_BASE};
parameter logic [ADDR_WIDTH-1:0] dev_addr_ends[SLAVE_COUNT] = '{`DEV_SRAM_ADDR_END, `DEV_UART_ADDR_END, `DEV_RTC_ADDR_END};

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

sram_axi4 #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
    .SRAM_READ_DELAY(SRAM_READ_DELAY)
) m_sram_axi4(
    .clk(clk),
    .rst(rst),
    .aw_valid(s_aw_valids[`DEV_SRAM_IDX]),
    .aw_ready(s_aw_readys[`DEV_SRAM_IDX]),
    .aw_addr(s_aw_addrs[`DEV_SRAM_IDX]),
    .w_valid(s_w_valids[`DEV_SRAM_IDX]),
    .w_ready(s_w_readys[`DEV_SRAM_IDX]),
    .w_data(s_w_datas[`DEV_SRAM_IDX]),
    .w_strb(s_w_strbs[`DEV_SRAM_IDX]),
    .b_valid(s_b_valids[`DEV_SRAM_IDX]),
    .b_ready(s_b_readys[`DEV_SRAM_IDX]),
    .b_resp(s_b_resps[`DEV_SRAM_IDX]),
    .ar_valid(s_ar_valids[`DEV_SRAM_IDX]),
    .ar_ready(s_ar_readys[`DEV_SRAM_IDX]),
    .ar_addr(s_ar_addrs[`DEV_SRAM_IDX]),
    .r_valid(s_r_valids[`DEV_SRAM_IDX]),
    .r_ready(s_r_readys[`DEV_SRAM_IDX]),
    .r_data(s_r_datas[`DEV_SRAM_IDX]),
    .r_resp(s_r_resps[`DEV_SRAM_IDX])
);

uart #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_uart(
    .clk(clk),
    .rst(rst),
    .aw_valid(s_aw_valids[`DEV_UART_IDX]),
    .aw_ready(s_aw_readys[`DEV_UART_IDX]),
    .aw_addr(s_aw_addrs[`DEV_UART_IDX]),
    .w_valid(s_w_valids[`DEV_UART_IDX]),
    .w_ready(s_w_readys[`DEV_UART_IDX]),
    .w_data(s_w_datas[`DEV_UART_IDX]),
    .w_strb(s_w_strbs[`DEV_UART_IDX]),
    .b_valid(s_b_valids[`DEV_UART_IDX]),
    .b_ready(s_b_readys[`DEV_UART_IDX]),
    .b_resp(s_b_resps[`DEV_UART_IDX]),
    .ar_valid(s_ar_valids[`DEV_UART_IDX]),
    .ar_ready(s_ar_readys[`DEV_UART_IDX]),
    .ar_addr(s_ar_addrs[`DEV_UART_IDX]),
    .r_valid(s_r_valids[`DEV_UART_IDX]),
    .r_ready(s_r_readys[`DEV_UART_IDX]),
    .r_data(s_r_datas[`DEV_UART_IDX]),
    .r_resp(s_r_resps[`DEV_UART_IDX])
);

clint #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_clint(
    .clk(clk),
    .rst(rst),
    .aw_valid(s_aw_valids[`DEV_RTC_IDX]),
    .aw_ready(s_aw_readys[`DEV_RTC_IDX]),
    .aw_addr(s_aw_addrs[`DEV_RTC_IDX]),
    .w_valid(s_w_valids[`DEV_RTC_IDX]),
    .w_ready(s_w_readys[`DEV_RTC_IDX]),
    .w_data(s_w_datas[`DEV_RTC_IDX]),
    .w_strb(s_w_strbs[`DEV_RTC_IDX]),
    .b_valid(s_b_valids[`DEV_RTC_IDX]),
    .b_ready(s_b_readys[`DEV_RTC_IDX]),
    .b_resp(s_b_resps[`DEV_RTC_IDX]),
    .ar_valid(s_ar_valids[`DEV_RTC_IDX]),
    .ar_ready(s_ar_readys[`DEV_RTC_IDX]),
    .ar_addr(s_ar_addrs[`DEV_RTC_IDX]),
    .r_valid(s_r_valids[`DEV_RTC_IDX]),
    .r_ready(s_r_readys[`DEV_RTC_IDX]),
    .r_data(s_r_datas[`DEV_RTC_IDX]),
    .r_resp(s_r_resps[`DEV_RTC_IDX])
);

// arbiter
// 每次按照顺序循环遍历，master中最后一个为默认节点
always @(posedge clk or posedge rst) begin
    if (rst) begin
        m_grant <= 0;
        r_m_grant_idx <= 0;
        s_grant <= 0;
        s_grant_idx <= 0;
    end else begin
        m_grant <= 0;
        r_m_grant_idx <= 0;
        for (integer midx=0; midx<MASTER_COUNT; ++midx) begin
            if (m_signal_en[(midx[$bits(r_m_grant_idx)-1:0]) % MASTER_COUNT]) begin
                m_grant[(midx[$bits(r_m_grant_idx)-1:0]) % MASTER_COUNT] <= 1;
                r_m_grant_idx <= (midx[$bits(r_m_grant_idx)-1:0]) % MASTER_COUNT;
                break;
            end
        end

        s_grant <= 0;
        s_grant_idx <= 0;
        for (int sidx=0; sidx<SLAVE_COUNT; ++sidx) begin
            if ((aw_addr >= dev_addr_bases[sidx] && aw_addr <= dev_addr_ends[sidx]) ||
                (ar_addr >= dev_addr_bases[sidx] && ar_addr <= dev_addr_ends[sidx])) begin
                s_grant[(sidx[$bits(s_grant_idx)-1:0])%SLAVE_COUNT] <= 1;
                s_grant_idx <= (sidx[$bits(s_grant_idx)-1:0])%SLAVE_COUNT;
                break;
            end
        end
    end    
end
assign m_grant_idx = {$bits(m_grant_idx){m_signal_en[r_m_grant_idx]}} & r_m_grant_idx;

// manager输入引脚处理
assign aw_valid = m_aw_valids[m_grant_idx%MASTER_COUNT];
assign w_valid = m_w_valids[m_grant_idx%MASTER_COUNT];
assign b_ready = m_b_readys[m_grant_idx%MASTER_COUNT];
assign ar_valid = m_ar_valids[m_grant_idx%MASTER_COUNT];
assign r_ready = m_r_readys[m_grant_idx%MASTER_COUNT];
always @(*) begin
    aw_addr = 0;
    ar_addr = 0;
    w_data = 0;
    w_strb = 0;

    for (integer midx=0; midx<MASTER_COUNT; ++midx) begin
        if (m_signal_en[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT]) begin
            aw_addr = m_aw_addrs[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
            ar_addr = m_ar_addrs[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
            w_data = m_w_datas[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
            w_strb = m_w_strbs[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
        end
    end
end
// manager输出引脚处理
generate
    for (genvar i = 0; i < MASTER_COUNT; ++i) begin : m_sig_out_gen
        assign m_signal_en[i] = m_aw_valids[i] | m_w_valids[i] | m_b_valids[i] | m_ar_valids[i] | m_r_valids[i];

        assign m_aw_readys[i] = (aw_ready & {$bits(aw_ready){m_grant[i]}});
        assign m_w_readys[i] = (w_ready & {$bits(w_ready){m_grant[i]}});
        assign m_b_valids[i] = (b_valid & {$bits(b_valid){m_grant[i]}});
        assign m_b_resps[i] = b_resp;
        assign m_ar_readys[i] = (ar_ready & {$bits(ar_ready){m_grant[i]}});
        assign m_r_valids[i] = (r_valid & {$bits(r_valid){m_grant[i]}});
        assign m_r_datas[i] = r_data;
        assign m_r_resps[i] = (r_resp & {$bits(r_resp){m_grant[i]}});
    end
endgenerate

// slave输入引脚处理
generate
    for (genvar i = 0; i < SLAVE_COUNT; ++i ) begin : s_sig_in_gen
        assign s_aw_valids[i] = (aw_valid & {$bits(aw_valid){s_grant_idx==i}});
        assign s_aw_addrs[i] = (aw_addr & {$bits(aw_addr){s_grant_idx==i}});
        assign s_w_valids[i] = (w_valid & {$bits(w_valid){s_grant_idx==i}});
        assign s_w_datas[i] = (w_data & {$bits(w_data){s_grant_idx==i}});
        assign s_w_strbs[i] = (w_strb & {$bits(w_strb){s_grant_idx==i}});
        assign s_b_readys[i] = (b_ready & {$bits(b_ready){s_grant_idx==i}});
        assign s_ar_valids[i] = (ar_valid & {$bits(ar_valid){s_grant_idx==i}});
        assign s_ar_addrs[i] = (ar_addr & {$bits(ar_addr){s_grant_idx==i}});
        assign s_r_readys[i] = (r_ready & {$bits(r_ready){s_grant_idx==i}});
    end
endgenerate
// slave输出引脚处理
assign r_data = s_r_datas[s_grant_idx%SLAVE_COUNT];
assign b_resp = s_b_resps[s_grant_idx%SLAVE_COUNT];
assign aw_ready = s_aw_readys[s_grant_idx%SLAVE_COUNT];
assign w_ready = s_w_readys[s_grant_idx%SLAVE_COUNT];
assign b_valid = s_b_valids[s_grant_idx%SLAVE_COUNT];
assign ar_ready = s_ar_readys[s_grant_idx%SLAVE_COUNT];
assign r_valid = s_r_valids[s_grant_idx%SLAVE_COUNT];
assign r_resp = s_r_resps[s_grant_idx%SLAVE_COUNT];

endmodule