module arbiter_axi4 #(
    parameter USER_M_COUNT = 1,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2,
    parameter MASTER_COUNT = USER_M_COUNT + 1
) (
    input wire clk,
    input wire rst,

    output  wire [USER_M_COUNT-1:0]                     u_awreadys,
    input   wire [USER_M_COUNT-1:0]                     u_awvalids,
    input   wire [USER_M_COUNT*ADDR_WIDTH-1:0]          u_awaddrs,
    input   wire [USER_M_COUNT*4-1:0]                   u_awids,
    input   wire [USER_M_COUNT*8-1:0]                   u_awlens,
    input   wire [USER_M_COUNT*3-1:0]                   u_awsizes,
    input   wire [USER_M_COUNT*2-1:0]                   u_awbursts,
    output  wire [USER_M_COUNT-1:0]                     u_wreadys,
    input   wire [USER_M_COUNT-1:0]                     u_wvalids,
    input   wire [USER_M_COUNT*DATA_WIDTH-1:0]          u_wdatas,
    input   wire [USER_M_COUNT*DATA_WIDTH/8-1:0]        u_wstrbs,
    input   wire [USER_M_COUNT-1:0]                     u_wlasts,
    input   wire [USER_M_COUNT-1:0]                     u_breadys,
    output  wire [USER_M_COUNT-1:0]                     u_bvalids,
    output  wire [USER_M_COUNT*BRESP_WIDTH-1:0]         u_bresps,
    output  wire [USER_M_COUNT*4-1:0]                   u_bids,
    output  wire [USER_M_COUNT-1:0]                     u_arreadys,
    input   wire [USER_M_COUNT-1:0]                     u_arvalids,
    input   wire [USER_M_COUNT*ADDR_WIDTH-1:0]          u_araddrs,
    input   wire [USER_M_COUNT*4-1:0]                   u_arids,
    input   wire [USER_M_COUNT*8-1:0]                   u_arlens,
    input   wire [USER_M_COUNT*3-1:0]                   u_arsizes,
    input   wire [USER_M_COUNT*2-1:0]                   u_arbursts,
    input   wire [USER_M_COUNT-1:0]                     u_rreadys,
    output  wire [USER_M_COUNT-1:0]                     u_rvalids,
    output  wire [USER_M_COUNT*RRESP_WIDTH-1:0]         u_rresps,
    output  wire [USER_M_COUNT*DATA_WIDTH-1:0]          u_rdatas,
    output  wire [USER_M_COUNT-1:0]                     u_rlasts,
    output  wire [USER_M_COUNT*4-1:0]                   u_rids,

    input   wire                        awready,
    output  wire                        awvalid,
    output  wire [ADDR_WIDTH-1:0]       awaddr,
    output  wire [3:0]                  awid,
    output  wire [7:0]                  awlen,
    output  wire [2:0]                  awsize,
    output  wire [1:0]                  awburst,
    input   wire                        wready,
    output  wire                        wvalid,
    output  wire [DATA_WIDTH-1:0]       wdata,
    output  wire [DATA_WIDTH/8-1:0]     wstrb,
    output  wire                        wlast,
    output  wire                        bready,
    input   wire                        bvalid,
    input   wire [BRESP_WIDTH-1:0]      bresp,
    input   wire [3:0]                  bid,
    input   wire                        arready,
    output  wire                        arvalid,
    output  wire [ADDR_WIDTH-1:0]       araddr,
    output  wire [3:0]                  arid,
    output  wire [7:0]                  arlen,
    output  wire [2:0]                  arsize,
    output  wire [1:0]                  arburst,
    output  wire                        rready,
    input   wire                        rvalid,
    input   wire [RRESP_WIDTH-1:0]      rresp,
    input   wire [DATA_WIDTH-1:0]       rdata,
    input   wire                        rlast,
    input   wire [3:0]                  rid,

    output  wire [log2(MASTER_COUNT):0] grant_idx
);

// typedef enum [1:0] { idle_t, work_t, error_t } rwstate_t;
localparam idle_t       = 0;
localparam work_t       = 1;
localparam error_t      = 2;

reg [1:0] wstate = idle_t;
reg [1:0] rstate = idle_t;
reg [log2(MASTER_COUNT):0] widx_select = 0;
reg [log2(MASTER_COUNT):0] ridx_select = 0;
reg [log2(MASTER_COUNT):0] widx_last = 0;
reg [log2(MASTER_COUNT):0] ridx_last = 0;

// 默认master，避免切主时造成从设备响应错误
wire                        m_awreadys[0:MASTER_COUNT-1];
wire                        m_awvalids[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0]       m_awaddrs[0:MASTER_COUNT-1];
wire [3:0]                  m_awids[0:MASTER_COUNT-1];
wire [7:0]                  m_awlens[0:MASTER_COUNT-1];
wire [2:0]                  m_awsizes[0:MASTER_COUNT-1];
wire [1:0]                  m_awbursts[0:MASTER_COUNT-1];
wire                        m_wreadys[0:MASTER_COUNT-1];
wire                        m_wvalids[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0]       m_wdatas[0:MASTER_COUNT-1];
wire [DATA_WIDTH/8-1:0]     m_wstrbs[0:MASTER_COUNT-1];
wire                        m_wlasts[0:MASTER_COUNT-1];
wire                        m_breadys[0:MASTER_COUNT-1];
reg                         m_bvalids[0:MASTER_COUNT-1];
wire [BRESP_WIDTH-1:0]      m_bresps[0:MASTER_COUNT-1];
wire [3:0]                  m_bids[0:MASTER_COUNT-1];
wire                        m_arreadys[0:MASTER_COUNT-1];
wire                        m_arvalids[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0]       m_araddrs[0:MASTER_COUNT-1];
wire [3:0]                  m_arids[0:MASTER_COUNT-1];
wire [7:0]                  m_arlens[0:MASTER_COUNT-1];
wire [2:0]                  m_arsizes[0:MASTER_COUNT-1];
wire [1:0]                  m_arbursts[0:MASTER_COUNT-1];
wire                        m_rreadys[0:MASTER_COUNT-1];
reg                         m_rvalids[0:MASTER_COUNT-1];
wire [RRESP_WIDTH-1:0]      m_rresps[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0]       m_rdatas[0:MASTER_COUNT-1];
wire                        m_rlasts[0:MASTER_COUNT-1];
wire [3:0]                  m_rids[0:MASTER_COUNT-1];

/* master数组与user数组互联，idx==0为默认值 */
generate
    for (genvar i=0; i<MASTER_COUNT; ++i) begin
        // DEFAULT
        if (i==0) begin
            assign m_awvalids[i] = 0;
            assign m_awaddrs[i] = 0;
            assign m_awids[i] = 0;
            assign m_awlens[i] = 0;
            assign m_awsizes[i] = 0;
            assign m_awbursts[i] = 0;
            assign m_wvalids[i] = 0;
            assign m_wdatas[i] = 0;
            assign m_wstrbs[i] = 0;
            assign m_wlasts[i] = 0;
            assign m_breadys[i] = 0;
            assign m_arvalids[i] = 0;
            assign m_araddrs[i] = 0;
            assign m_arids[i] = 0;
            assign m_arlens[i] = 0;
            assign m_arsizes[i] = 0;
            assign m_arbursts[i] = 0;
            assign m_rreadys[i] = 0;
        end else begin
            integer master_idx = (USER_M_COUNT-i);

            assign m_awvalids[i] = u_awvalids[1*master_idx +: 1];
            assign m_awaddrs[i] = u_awaddrs[ADDR_WIDTH*master_idx +: ADDR_WIDTH];
            assign m_awids[i] = u_awids[4*master_idx +: 4];
            assign m_awlens[i] = u_awlens[8*master_idx +: 8];
            assign m_awsizes[i] = u_awsizes[3*master_idx +: 3];
            assign m_awbursts[i] = u_awbursts[2*master_idx +: 2];
            assign m_wvalids[i] = u_wvalids[1*master_idx +: 1];
            assign m_wdatas[i] = u_wdatas[DATA_WIDTH*master_idx +: DATA_WIDTH];
            assign m_wstrbs[i] = u_wstrbs[DATA_WIDTH/8*master_idx +: DATA_WIDTH/8];
            assign m_wlasts[i] = u_wlasts[1*master_idx +: 1];
            assign m_breadys[i] = u_breadys[1*master_idx +: 1];
            assign m_arvalids[i] = u_arvalids[1*master_idx +: 1];
            assign m_araddrs[i] = u_araddrs[ADDR_WIDTH*master_idx +: ADDR_WIDTH];
            assign m_arids[i] = u_arids[4*master_idx +: 4];
            assign m_arlens[i] = u_arlens[8*master_idx +: 8];
            assign m_arsizes[i] = u_arsizes[3*master_idx +: 3];
            assign m_arbursts[i] = u_arbursts[2*master_idx +: 2];
            assign m_rreadys[i] = u_rreadys[1*master_idx +: 1];

            assign u_awreadys[1*master_idx +: 1] = m_awreadys[i];
            assign u_wreadys[1*master_idx +: 1] = m_wreadys[i];
            assign u_bvalids[1*master_idx +: 1] = m_bvalids[i];
            assign u_bresps[BRESP_WIDTH*master_idx +: BRESP_WIDTH] = m_bresps[i];
            assign u_bids[4*master_idx +: 4] = m_bids[i];
            assign u_arreadys[1*master_idx +: 1] = m_arreadys[i];
            assign u_rvalids[1*master_idx +: 1] = m_rvalids[i];
            assign u_rresps[BRESP_WIDTH*master_idx +: BRESP_WIDTH] = m_rresps[i];
            assign u_rdatas[DATA_WIDTH*master_idx +: DATA_WIDTH] = m_rdatas[i];
            assign u_rlasts[1*master_idx +: 1] = m_rlasts[i];
            assign u_rids[4*master_idx +: 4] = m_rids[i];
        end
    end
endgenerate

// manager输入引脚处理，没有选择的需要赋值为0
generate
    for (genvar i = 0; i < MASTER_COUNT; ++i) begin : m_sig_in_gen
        assign m_awreadys[i] = (awready & {$bits(awready){i==widx_select}});
        assign m_wreadys[i] = (wready & {$bits(wready){i==widx_select}});
        assign m_bvalids[i] = (bvalid & {$bits(bvalid){i==widx_select}});
        assign m_bresps[i] = (bresp & {$bits(bresp){i==widx_select}});
        assign m_bids[i] = (bid & {$bits(bid){i==widx_select}});
        assign m_arreadys[i] = (arready & {$bits(arready){i==ridx_select}});
        assign m_rvalids[i] = (rvalid & {$bits(rvalid){i==ridx_select}});
        assign m_rresps[i] = (rresp & {$bits(rresp){i==ridx_select}});
        assign m_rdatas[i] = (rdata & {$bits(rdata){i==ridx_select}});
        assign m_rlasts[i] = (rlast & {$bits(rlast){i==ridx_select}});
        assign m_rids[i] = (rid & {$bits(rid){i==ridx_select}});
    end
endgenerate

// manager输出引脚处理
assign awvalid = m_awvalids[widx_select];
assign awaddr = m_awaddrs[widx_select];
assign awid = m_awids[widx_select];
assign awlen = m_awlens[widx_select];
assign awsize = m_awsizes[widx_select];
assign awburst = m_awbursts[widx_select];
assign wvalid = m_wvalids[widx_select];
assign wdata = m_wdatas[widx_select];
assign wstrb = m_wstrbs[widx_select];
assign wlast = m_wlasts[widx_select];
assign bready = m_breadys[widx_select];
assign arvalid = m_arvalids[ridx_select];
assign araddr = m_araddrs[ridx_select];
assign arid = m_arids[ridx_select];
assign arlen = m_arlens[ridx_select];
assign arsize = m_arsizes[ridx_select];
assign arburst = m_arbursts[ridx_select];
assign rready = m_rreadys[ridx_select];

// 组合式master写选择器
integer widx;
always @(*) begin
    widx_select = 0;
    for (integer mid=0; mid<MASTER_COUNT; ++mid) begin
        widx = (mid + {{32-$bits(widx_last){1'b0}}, widx_last}) % MASTER_COUNT;
        if (widx_select == 0 && m_awaddrs[widx] != 0) begin
            widx_select = widx[$bits(widx_select)-1:0];
        end
    end
end
assign wstate = widx_select == 0 ? idle_t : work_t;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        widx_last <= 0;
    end else begin
        if (widx_select != 0) begin
            widx_last <= widx_select;
        end
    end
end

// 组合式master读选择器
integer ridx;
always @(*) begin
    ridx_select = 0;
    for (integer mid=0; mid<MASTER_COUNT; ++mid) begin
        ridx = (mid + {{32-$bits(ridx_last){1'b0}}, ridx_last}) % MASTER_COUNT;
        if (ridx_select == 0 && m_araddrs[ridx] != 0) begin
            ridx_select = ridx[$bits(ridx_select)-1:0];
        end
    end
end
assign rstate = ridx_select == 0 ? idle_t : work_t;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ridx_last <= 0;
    end else begin
        if (ridx_select != 0) begin
            ridx_last <= ridx_select;
        end
    end
end

endmodule
