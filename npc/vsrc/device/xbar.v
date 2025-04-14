module xbar #(
    parameter MASTER_COUNT = 1,
    parameter SLAVE_COUNT = 2,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SRAM_READ_DELAY = 0
) (
    input wire clk,
    input wire rst,

    input wire m_aw_valids[0:MASTER_COUNT-1],
    output wire m_aw_readys[0:MASTER_COUNT-1],
    input wire [ADDR_WIDTH-1:0] m_aw_addrs[0:MASTER_COUNT-1],
    input wire m_w_valids[0:MASTER_COUNT-1],
    output wire m_w_readys[0:MASTER_COUNT-1],
    input wire [DATA_WIDTH-1:0] m_w_datas[0:MASTER_COUNT-1],
    input wire [DATA_WIDTH/8-1:0] m_w_strbs[0:MASTER_COUNT-1],
    output wire m_b_valids[0:MASTER_COUNT-1],
    input wire m_b_readys[0:MASTER_COUNT-1],
    output wire [BRESP_WIDTH-1:0] m_b_resps[0:MASTER_COUNT-1],
    input wire m_ar_valids[0:MASTER_COUNT-1],
    output wire m_ar_readys[0:MASTER_COUNT-1],
    input wire [ADDR_WIDTH-1:0] m_ar_addrs[0:MASTER_COUNT-1],
    output wire m_r_valids[0:MASTER_COUNT-1],
    input wire m_r_readys[0:MASTER_COUNT-1],
    output wire [DATA_WIDTH-1:0] m_r_datas[0:MASTER_COUNT-1],
    output wire [RRESP_WIDTH-1:0] m_r_resps[0:MASTER_COUNT-1]
);

reg [MASTER_COUNT-1:0] m_signal_en;
reg [MASTER_COUNT-1:0] m_grant;
reg [log2(MASTER_COUNT):0] m_grant_idx;
reg aw_valid;
reg aw_ready;
reg [ADDR_WIDTH-1:0] aw_addr;
reg w_valid;
reg w_ready;
reg [DATA_WIDTH-1:0] w_data;
reg [DATA_WIDTH/8-1:0] w_strb;
reg b_valid;
reg b_ready;
reg [BRESP_WIDTH-1:0] b_resp;
reg ar_valid;
reg ar_ready;
reg [ADDR_WIDTH-1:0] ar_addr;
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

parameter logic [ADDR_WIDTH-1:0] dev_addr_bases[SLAVE_COUNT] = '{`DEV_SRAM_ADDR_BASE, `DEV_UART_ADDR_BASE};
parameter logic [ADDR_WIDTH-1:0] dev_addr_ends[SLAVE_COUNT] = '{`DEV_SRAM_ADDR_END, `DEV_UART_ADDR_END};

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

// arbiter
// m_grant记录授权为相应的位置
// m_grant_idx记录上次授权编号，便于实现轮询遍历
always @(posedge clk or posedge rst) begin
    if (rst) begin
        m_grant <= 0;
        m_grant_idx <= 0;
    end else begin
        m_grant <= 0; // default is not granted

        for (integer midx=0; midx<MASTER_COUNT; ++midx) begin
            if (m_signal_en[(m_grant_idx + midx[MASTER_COUNT-1:0]) % MASTER_COUNT]) begin
                m_grant[(m_grant_idx + midx[MASTER_COUNT-1:0]) % MASTER_COUNT] <= 1;
                m_grant_idx <= (m_grant_idx + midx[$bits(m_grant_idx)-1:0]) % MASTER_COUNT;
                break;
            end
        end
    end    
end

// manager输入引脚处理
wire aw_valid_test0 = m_aw_valids[0];
wire aw_valid_test1 = m_aw_valids[1];
assign aw_valid = m_aw_valids[m_grant_idx%MASTER_COUNT];
assign aw_addr = m_aw_addrs[m_grant_idx%MASTER_COUNT];
assign w_valid = m_w_valids[m_grant_idx%MASTER_COUNT];
assign w_data = m_w_datas[m_grant_idx%MASTER_COUNT];
assign w_strb = m_w_strbs[m_grant_idx%MASTER_COUNT];
assign b_ready = m_b_readys[m_grant_idx%MASTER_COUNT];
assign ar_valid = m_ar_valids[m_grant_idx%MASTER_COUNT];
assign ar_addr = m_ar_addrs[m_grant_idx%MASTER_COUNT];
assign r_ready = m_r_readys[m_grant_idx%MASTER_COUNT];
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
        assign s_aw_valids[i] = (aw_valid & {$bits(aw_valid){s_grant[i]}});
        assign s_aw_addrs[i] = (aw_addr & {$bits(aw_addr){s_grant[i]}});
        assign s_w_valids[i] = (w_valid & {$bits(w_valid){s_grant[i]}});
        assign s_w_datas[i] = (w_data & {$bits(w_data){s_grant[i]}});
        assign s_w_strbs[i] = (w_strb & {$bits(w_strb){s_grant[i]}});
        assign s_b_readys[i] = (b_ready & {$bits(b_ready){s_grant[i]}});
        assign s_ar_valids[i] = (ar_valid & {$bits(ar_valid){s_grant[i]}});
        assign s_ar_addrs[i] = (ar_addr & {$bits(ar_addr){s_grant[i]}});
        assign s_r_readys[i] = (r_ready & {$bits(r_ready){s_grant[i]}});
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

// slave选择逻辑
always @(posedge clk or posedge rst) begin
    if (rst) begin
        s_grant <= 0;
        s_grant_idx <= 0;
    end else begin
        s_grant <= s_grant;
        s_grant_idx <= s_grant_idx;

        if (aw_valid || ar_valid) begin
            s_grant <= 0;
            for (int sidx=0; sidx<SLAVE_COUNT; ++sidx) begin
                if ((aw_valid && aw_addr >= dev_addr_bases[sidx] && aw_addr <= dev_addr_ends[sidx]) ||
                    (ar_valid && ar_addr >= dev_addr_bases[sidx] && ar_addr <= dev_addr_ends[sidx])) begin
                    // TODO 临时强制指定为0
                    // s_grant[(sidx[$bits(s_grant_idx)-1:0])%SLAVE_COUNT] <= 1;
                    // s_grant_idx <= (sidx[$bits(s_grant_idx)-1:0])%SLAVE_COUNT;
                    s_grant[0] <= 1;
                    s_grant_idx <= 0;
                    break;
                end
            end
        end
    end
end

endmodule