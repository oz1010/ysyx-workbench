`ifndef IN_YOSYS_STA
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

    input wire u_awvalids[0:USER_M_COUNT-1],
    output wire u_awreadys[0:USER_M_COUNT-1],
    input wire [ADDR_WIDTH-1:0] u_awaddrs[0:USER_M_COUNT-1],
    input wire u_wvalids[0:USER_M_COUNT-1],
    output wire u_wreadys[0:USER_M_COUNT-1],
    input wire [DATA_WIDTH-1:0] u_wdatas[0:USER_M_COUNT-1],
    input wire [DATA_WIDTH/8-1:0] u_wstrbs[0:USER_M_COUNT-1],
    output wire u_bvalids[0:USER_M_COUNT-1],
    input wire u_breadys[0:USER_M_COUNT-1],
    output wire [BRESP_WIDTH-1:0] u_bresps[0:USER_M_COUNT-1],
    input wire u_arvalids[0:USER_M_COUNT-1],
    output wire u_arreadys[0:USER_M_COUNT-1],
    input wire [ADDR_WIDTH-1:0] u_araddrs[0:USER_M_COUNT-1],
    output wire u_rvalids[0:USER_M_COUNT-1],
    input wire u_rreadys[0:USER_M_COUNT-1],
    output wire [DATA_WIDTH-1:0] u_rdatas[0:USER_M_COUNT-1],
    output wire [RRESP_WIDTH-1:0] u_rresps[0:USER_M_COUNT-1]
);

// 默认master，避免切主时造成从设备响应错误
wire m_awvalids[0:MASTER_COUNT-1];
wire m_awreadys[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0] m_awaddrs[0:MASTER_COUNT-1];
wire m_wvalids[0:MASTER_COUNT-1];
wire m_wreadys[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0] m_wdatas[0:MASTER_COUNT-1];
wire [DATA_WIDTH/8-1:0] m_wstrbs[0:MASTER_COUNT-1];
wire m_bvalids[0:MASTER_COUNT-1];
wire m_breadys[0:MASTER_COUNT-1];
wire [BRESP_WIDTH-1:0] m_bresps[0:MASTER_COUNT-1];
wire m_arvalids[0:MASTER_COUNT-1];
wire m_arreadys[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0] m_araddrs[0:MASTER_COUNT-1];
wire m_rvalids[0:MASTER_COUNT-1];
wire m_rreadys[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0] m_rdatas[0:MASTER_COUNT-1];
wire [RRESP_WIDTH-1:0] m_rresps[0:MASTER_COUNT-1];
assign m_awvalids = {0, u_awvalids};
assign m_awaddrs = {0, u_awaddrs};
assign m_wvalids = {0, u_wvalids};
assign m_wdatas = {0, u_wdatas};
assign m_wstrbs = {0, u_wstrbs};
assign m_breadys = {0, u_breadys};
assign m_arvalids = {0, u_arvalids};
assign m_araddrs = {0, u_araddrs};
assign m_rreadys = {0, u_rreadys};
assign u_awreadys = m_awreadys[1:USER_M_COUNT];
assign u_wreadys = m_wreadys[1:USER_M_COUNT];
assign u_bvalids = m_bvalids[1:USER_M_COUNT];
assign u_bresps = m_bresps[1:USER_M_COUNT];
assign u_arreadys = m_arreadys[1:USER_M_COUNT];
assign u_rvalids = m_rvalids[1:USER_M_COUNT];
assign u_rdatas = m_rdatas[1:USER_M_COUNT];
assign u_rresps = m_rresps[1:USER_M_COUNT];

reg [MASTER_COUNT-1:0] m_signal_en;
reg [MASTER_COUNT-1:0] m_write_en;
reg [MASTER_COUNT-1:0] m_read_en;
reg [MASTER_COUNT-1:0] m_grant;
reg [log2(MASTER_COUNT):0] r_m_grant_idx;
wire [log2(MASTER_COUNT):0] m_grant_idx;

reg awvalid;
reg awready;
reg [ADDR_WIDTH-1:0] awaddr; // 用于记录当前master写入的申请地址，需要在角色切换前完成
reg wvalid;
reg wready;
reg [DATA_WIDTH-1:0] wdata;
reg [DATA_WIDTH/8-1:0] wstrb;
reg bvalid;
reg bready;
reg [BRESP_WIDTH-1:0] bresp;
reg arvalid;
reg arready;
reg [ADDR_WIDTH-1:0] araddr; // 用于记录当前master读取的申请地址，需要在角色切换前完成
reg rvalid;
reg rready;
reg [DATA_WIDTH-1:0] rdata;
reg [RRESP_WIDTH-1:0] rresp;

wire s_awvalids[0:SLAVE_COUNT-1];
wire s_awreadys[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0] s_awaddrs[0:SLAVE_COUNT-1];
wire s_wvalids[0:SLAVE_COUNT-1];
wire s_wreadys[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0] s_wdatas[0:SLAVE_COUNT-1];
wire [DATA_WIDTH/8-1:0] s_wstrbs[0:SLAVE_COUNT-1];
wire s_bvalids[0:SLAVE_COUNT-1];
wire s_breadys[0:SLAVE_COUNT-1];
wire [BRESP_WIDTH-1:0] s_bresps[0:SLAVE_COUNT-1];
wire s_arvalids[0:SLAVE_COUNT-1];
wire s_arreadys[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0] s_araddrs[0:SLAVE_COUNT-1];
wire s_rvalids[0:SLAVE_COUNT-1];
wire s_rreadys[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0] s_rdatas[0:SLAVE_COUNT-1];
wire [RRESP_WIDTH-1:0] s_rresps[0:SLAVE_COUNT-1];
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
    .awvalid(s_awvalids[`DEV_SRAM_IDX]),
    .awready(s_awreadys[`DEV_SRAM_IDX]),
    .awaddr(s_awaddrs[`DEV_SRAM_IDX]),
    .wvalid(s_wvalids[`DEV_SRAM_IDX]),
    .wready(s_wreadys[`DEV_SRAM_IDX]),
    .wdata(s_wdatas[`DEV_SRAM_IDX]),
    .wstrb(s_wstrbs[`DEV_SRAM_IDX]),
    .bvalid(s_bvalids[`DEV_SRAM_IDX]),
    .bready(s_breadys[`DEV_SRAM_IDX]),
    .bresp(s_bresps[`DEV_SRAM_IDX]),
    .arvalid(s_arvalids[`DEV_SRAM_IDX]),
    .arready(s_arreadys[`DEV_SRAM_IDX]),
    .araddr(s_araddrs[`DEV_SRAM_IDX]),
    .rvalid(s_rvalids[`DEV_SRAM_IDX]),
    .rready(s_rreadys[`DEV_SRAM_IDX]),
    .rdata(s_rdatas[`DEV_SRAM_IDX]),
    .rresp(s_rresps[`DEV_SRAM_IDX])
);

uart #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_uart(
    .clk(clk),
    .rst(rst),
    .awvalid(s_awvalids[`DEV_UART_IDX]),
    .awready(s_awreadys[`DEV_UART_IDX]),
    .awaddr(s_awaddrs[`DEV_UART_IDX]),
    .wvalid(s_wvalids[`DEV_UART_IDX]),
    .wready(s_wreadys[`DEV_UART_IDX]),
    .wdata(s_wdatas[`DEV_UART_IDX]),
    .wstrb(s_wstrbs[`DEV_UART_IDX]),
    .bvalid(s_bvalids[`DEV_UART_IDX]),
    .bready(s_breadys[`DEV_UART_IDX]),
    .bresp(s_bresps[`DEV_UART_IDX]),
    .arvalid(s_arvalids[`DEV_UART_IDX]),
    .arready(s_arreadys[`DEV_UART_IDX]),
    .araddr(s_araddrs[`DEV_UART_IDX]),
    .rvalid(s_rvalids[`DEV_UART_IDX]),
    .rready(s_rreadys[`DEV_UART_IDX]),
    .rdata(s_rdatas[`DEV_UART_IDX]),
    .rresp(s_rresps[`DEV_UART_IDX])
);

clint #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_clint(
    .clk(clk),
    .rst(rst),
    // .awvalid(s_awvalids[`DEV_RTC_IDX]),
    // .awready(s_awreadys[`DEV_RTC_IDX]),
    // .awaddr(s_awaddrs[`DEV_RTC_IDX]),
    // .wvalid(s_wvalids[`DEV_RTC_IDX]),
    // .wready(s_wreadys[`DEV_RTC_IDX]),
    // .wdata(s_wdatas[`DEV_RTC_IDX]),
    // .wstrb(s_wstrbs[`DEV_RTC_IDX]),
    // .bvalid(s_bvalids[`DEV_RTC_IDX]),
    // .bready(s_breadys[`DEV_RTC_IDX]),
    // .bresp(s_bresps[`DEV_RTC_IDX]),
    // .arvalid(s_arvalids[`DEV_RTC_IDX]),
    // .arready(s_arreadys[`DEV_RTC_IDX]),
    // .araddr(s_araddrs[`DEV_RTC_IDX]),
    // .rvalid(s_rvalids[`DEV_RTC_IDX]),
    // .rready(s_rreadys[`DEV_RTC_IDX]),
    // .rdata(s_rdatas[`DEV_RTC_IDX]),
    // .rresp(s_rresps[`DEV_RTC_IDX])
    // TODO 临时屏蔽，搞定编译问题
    .awready(0),
    .awvalid(0),
    .awaddr(0),
    .awid(0),
    .awlen(0),
    .awsize(0),
    .awburst(0),
    .wready(0),
    .wvalid(0),
    .wdata(0),
    .wstrb(0),
    .wlast(0),
    .bready(0),
    .bvalid(0),
    .bresp(0),
    .bid(0),
    .arready(0),
    .arvalid(0),
    .araddr(0),
    .arid(0),
    .arlen(0),
    .arsize(0),
    .arburst(0),
    .rready(0),
    .rvalid(0),
    .rresp(0),
    .rdata(0),
    .rlast(0),
    .rid(0)
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
            if ((m_write_en>0 && awaddr >= dev_addr_bases[sidx] && awaddr <= dev_addr_ends[sidx]) ||
                (m_read_en>0 && araddr >= dev_addr_bases[sidx] && araddr <= dev_addr_ends[sidx])) begin
                s_grant[(sidx[$bits(s_grant_idx)-1:0])%SLAVE_COUNT] <= 1;
                s_grant_idx <= (sidx[$bits(s_grant_idx)-1:0])%SLAVE_COUNT;
                break;
            end
        end
    end    
end
assign m_grant_idx = {$bits(m_grant_idx){m_signal_en[r_m_grant_idx]}} & r_m_grant_idx;

// manager输入引脚处理
assign awvalid = m_awvalids[m_grant_idx%MASTER_COUNT];
assign wvalid = m_wvalids[m_grant_idx%MASTER_COUNT];
assign bready = m_breadys[m_grant_idx%MASTER_COUNT];
assign arvalid = m_arvalids[m_grant_idx%MASTER_COUNT];
assign rready = m_rreadys[m_grant_idx%MASTER_COUNT];
always @(*) begin
    awaddr = 0;
    araddr = 0;
    wdata = 0;
    wstrb = 0;

    for (integer midx=0; midx<MASTER_COUNT; ++midx) begin
        if (m_signal_en[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT]) begin
            awaddr = m_awaddrs[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
            araddr = m_araddrs[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
            wdata = m_wdatas[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
            wstrb = m_wstrbs[(midx[MASTER_COUNT-1:0]) % MASTER_COUNT];
        end
    end
end
// manager输出引脚处理
generate
    for (genvar i = 0; i < MASTER_COUNT; ++i) begin : m_sig_out_gen
        assign m_signal_en[i] = m_awvalids[i] | m_wvalids[i] | m_bvalids[i] | m_arvalids[i] | m_rvalids[i];
        assign m_write_en[i] = ((m_awvalids[i] | m_wvalids[i] | m_bvalids[i]));
        assign m_read_en[i] = ((m_arvalids[i] | m_rvalids[i]));

        assign m_awreadys[i] = (awready & {$bits(awready){m_grant[i]}});
        assign m_wreadys[i] = (wready & {$bits(wready){m_grant[i]}});
        assign m_bvalids[i] = (bvalid & {$bits(bvalid){m_grant[i]}});
        assign m_bresps[i] = bresp;
        assign m_arreadys[i] = (arready & {$bits(arready){m_grant[i]}});
        assign m_rvalids[i] = (rvalid & {$bits(rvalid){m_grant[i]}});
        assign m_rdatas[i] = rdata;
        assign m_rresps[i] = (rresp & {$bits(rresp){m_grant[i]}});
    end
endgenerate

// slave输入引脚处理
generate
    for (genvar i = 0; i < SLAVE_COUNT; ++i ) begin : s_sig_in_gen
        assign s_awvalids[i] = (awvalid & {$bits(awvalid){s_grant_idx==i}});
        assign s_awaddrs[i] = (awaddr & {$bits(awaddr){s_grant_idx==i}});
        assign s_wvalids[i] = (wvalid & {$bits(wvalid){s_grant_idx==i}});
        assign s_wdatas[i] = (wdata & {$bits(wdata){s_grant_idx==i}});
        assign s_wstrbs[i] = (wstrb & {$bits(wstrb){s_grant_idx==i}});
        assign s_breadys[i] = (bready & {$bits(bready){s_grant_idx==i}});
        assign s_arvalids[i] = (arvalid & {$bits(arvalid){s_grant_idx==i}});
        assign s_araddrs[i] = (araddr & {$bits(araddr){s_grant_idx==i}});
        assign s_rreadys[i] = (rready & {$bits(rready){s_grant_idx==i}});
    end
endgenerate
// slave输出引脚处理
assign rdata = s_rdatas[s_grant_idx%SLAVE_COUNT];
assign bresp = s_bresps[s_grant_idx%SLAVE_COUNT];
assign awready = s_awreadys[s_grant_idx%SLAVE_COUNT];
assign wready = s_wreadys[s_grant_idx%SLAVE_COUNT];
assign bvalid = s_bvalids[s_grant_idx%SLAVE_COUNT];
assign arready = s_arreadys[s_grant_idx%SLAVE_COUNT];
assign rvalid = s_rvalids[s_grant_idx%SLAVE_COUNT];
assign rresp = s_rresps[s_grant_idx%SLAVE_COUNT];

endmodule
`endif
