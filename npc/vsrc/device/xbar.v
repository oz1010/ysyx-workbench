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

    input wire aw_valids[0:MASTER_COUNT-1],
    output wire aw_readys[0:MASTER_COUNT-1],
    input wire [ADDR_WIDTH-1:0] aw_addrs[0:MASTER_COUNT-1],
    input wire w_valids[0:MASTER_COUNT-1],
    output wire w_readys[0:MASTER_COUNT-1],
    input wire [DATA_WIDTH-1:0] w_datas[0:MASTER_COUNT-1],
    input wire [DATA_WIDTH/8-1:0] w_strbs[0:MASTER_COUNT-1],
    output wire b_valids[0:MASTER_COUNT-1],
    input wire b_readys[0:MASTER_COUNT-1],
    output wire [BRESP_WIDTH-1:0] b_resps[0:MASTER_COUNT-1],
    input wire ar_valids[0:MASTER_COUNT-1],
    output wire ar_readys[0:MASTER_COUNT-1],
    input wire [ADDR_WIDTH-1:0] ar_addrs[0:MASTER_COUNT-1],
    output wire r_valids[0:MASTER_COUNT-1],
    input wire r_readys[0:MASTER_COUNT-1],
    output wire [DATA_WIDTH-1:0] r_datas[0:MASTER_COUNT-1],
    output wire [RRESP_WIDTH-1:0] r_resps[0:MASTER_COUNT-1]
);

reg [MASTER_COUNT-1:0] m_signal_en;
reg [MASTER_COUNT-1:0] m_grant;
reg [MASTER_COUNT-1:0] m_grant_idx;
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
reg [SLAVE_COUNT-1:0] s_grant;

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

// arbiter
// m_grant记录授权为相应的位置
// m_grant_idx记录上次授权编号，便于实现轮询遍历
integer t;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        m_grant <= 0;
        m_grant_idx <= 0;
    end else begin
        m_grant <= 0; // default is not granted

        for (t=0; t<MASTER_COUNT; ++t) begin
            if (m_signal_en[(m_grant_idx + t[MASTER_COUNT-1:0]) % MASTER_COUNT]) begin
                m_grant[(m_grant_idx + t[MASTER_COUNT-1:0]) % MASTER_COUNT] <= 1;
                m_grant_idx <= (m_grant_idx + t[MASTER_COUNT-1:0]) % MASTER_COUNT;
                break;
            end
        end
    end    
end

// manager输出引脚处理
genvar i;
generate
    for (i = 0; i < MASTER_COUNT; ++i) begin : signal_gen
        assign m_signal_en[i] = aw_valids[i] | w_valids[i] | b_valids[i] | ar_valids[i] | r_valids[i];

        assign aw_readys[i] = (aw_ready & {$bits(aw_ready){m_grant[i]}});
        assign w_readys[i] = (w_ready & {$bits(w_ready){m_grant[i]}});
        assign b_valids[i] = (b_valid & {$bits(b_valid){m_grant[i]}});
        assign b_resps[i] = b_resp;
        assign ar_readys[i] = (ar_ready & {$bits(ar_ready){m_grant[i]}});
        assign r_valids[i] = (r_valid & {$bits(r_valid){m_grant[i]}});
        assign r_datas[i] = r_data;
        assign r_resps[i] = (r_resp & {$bits(r_resp){m_grant[i]}});
    end
endgenerate

// manager输入引脚处理
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
        if (m_grant[m]) begin
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

// slave选择逻辑
// 要求读写地址在通信期间地址不改变
always @(*) begin
    s_grant = 0;
    
    if (m_grant != 0) begin
        for (int midx=0; midx<=MASTER_COUNT; ++midx) begin
            if (m_grant[midx]) begin
                for (int n=0; n<SLAVE_COUNT; ++n) begin
                    if ((aw_addr >= dev_addr_bases[n] && aw_addr <= dev_addr_ends[n]) ||
                        (ar_addr >= dev_addr_bases[n] && ar_addr <= dev_addr_ends[n])) begin
                        // if (n==1) begin
                        //     $display("Found sram %x %x", ar_addr, aw_addr);
                        // end
                        s_grant[n] = 1;
                        break;
                    end
                end
                break;
            end
        end
    end
end

endmodule