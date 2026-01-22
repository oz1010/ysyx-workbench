// 单master多slave选择器
module xbar_axi4 #(
    parameter USER_S_COUNT = 1,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SLAVE_COUNT = USER_S_COUNT + 1
) (
    input wire clk,
    input wire rst,

    output  wire                                            awready,
    input   wire                                            awvalid,
    input   wire [ADDR_WIDTH-1:0]                           awaddr,
    input   wire [3:0]                                      awid,
    input   wire [7:0]                                      awlen,
    input   wire [2:0]                                      awsize,
    input   wire [1:0]                                      awburst,
    output  wire                                            wready,
    input   wire                                            wvalid,
    input   wire [DATA_WIDTH-1:0]                           wdata,
    input   wire [DATA_WIDTH/8-1:0]                         wstrb,
    input   wire                                            wlast,
    input   wire                                            bready,
    output  wire                                            bvalid,
    output  wire [BRESP_WIDTH-1:0]                          bresp,
    output  wire [3:0]                                      bid,
    output  wire                                            arready,
    input   wire                                            arvalid,
    input   wire [ADDR_WIDTH-1:0]                           araddr,
    input   wire [3:0]                                      arid,
    input   wire [7:0]                                      arlen,
    input   wire [2:0]                                      arsize,
    input   wire [1:0]                                      arburst,
    input   wire                                            rready,
    output  wire                                            rvalid,
    output  wire [RRESP_WIDTH-1:0]                          rresp,
    output  wire [DATA_WIDTH-1:0]                           rdata,
    output  wire                                            rlast,
    output  wire [3:0]                                      rid,

    input   wire [USER_S_COUNT-1:0]                         u_awreadys,
    output  wire [USER_S_COUNT-1:0]                         u_awvalids,
    output  wire [USER_S_COUNT*ADDR_WIDTH-1:0]              u_awaddrs,
    output  wire [USER_S_COUNT*4-1:0]                       u_awids,
    output  wire [USER_S_COUNT*8-1:0]                       u_awlens,
    output  wire [USER_S_COUNT*3-1:0]                       u_awsizes,
    output  wire [USER_S_COUNT*2-1:0]                       u_awbursts,
    input   wire [USER_S_COUNT-1:0]                         u_wreadys,
    output  wire [USER_S_COUNT-1:0]                         u_wvalids,
    output  wire [USER_S_COUNT*DATA_WIDTH-1:0]              u_wdatas,
    output  wire [USER_S_COUNT*DATA_WIDTH/8-1:0]            u_wstrbs,
    output  wire [USER_S_COUNT-1:0]                         u_wlasts,
    output  wire [USER_S_COUNT-1:0]                         u_breadys,
    input   wire [USER_S_COUNT-1:0]                         u_bvalids,
    input   wire [USER_S_COUNT*BRESP_WIDTH-1:0]             u_bresps,
    input   wire [USER_S_COUNT*4-1:0]                       u_bids,
    input   wire [USER_S_COUNT-1:0]                         u_arreadys,
    output  wire [USER_S_COUNT-1:0]                         u_arvalids,
    output  wire [USER_S_COUNT*ADDR_WIDTH-1:0]              u_araddrs,
    output  wire [USER_S_COUNT*4-1:0]                       u_arids,
    output  wire [USER_S_COUNT*8-1:0]                       u_arlens,
    output  wire [USER_S_COUNT*3-1:0]                       u_arsizes,
    output  wire [USER_S_COUNT*2-1:0]                       u_arbursts,
    output  wire [USER_S_COUNT-1:0]                         u_rreadys,
    input   wire [USER_S_COUNT-1:0]                         u_rvalids,
    input   wire [USER_S_COUNT*RRESP_WIDTH-1:0]             u_rresps,
    input   wire [USER_S_COUNT*DATA_WIDTH-1:0]              u_rdatas,
    input   wire [USER_S_COUNT-1:0]                         u_rlasts,
    input   wire [USER_S_COUNT*4-1:0]                       u_rids,

    input   wire [64*USER_S_COUNT-1:0]                      u_slave_addrs,

    output  wire [log2(SLAVE_COUNT):0] grant_idx
);

localparam select_t     = 0;
localparam read_t       = 1;
localparam write_t      = 2;
localparam err_t        = 3;
// typedef enum [1:0] { idle_t, work_t, error_t } rwstate_t;
localparam idle_t       = 0;
localparam work_t       = 1;
localparam error_t      = 2;

// typedef enum [2:0] { select_t, read_t, write_t, err_t } state_t;
reg [2:0]  state;

reg [1:0] wstate = idle_t;
reg [1:0] rstate = idle_t;
reg [log2(SLAVE_COUNT):0] widx_select = 0;
reg [log2(SLAVE_COUNT):0] ridx_select = 0;
reg [log2(SLAVE_COUNT):0] widx_last = 0;
reg [log2(SLAVE_COUNT):0] ridx_last = 0;

// 默认slave，避免切设备时造成响应错误
wire                        s_awreadys[0:SLAVE_COUNT-1];
wire                        s_awvalids[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0]       s_awaddrs[0:SLAVE_COUNT-1];
wire [3:0]                  s_awids[0:SLAVE_COUNT-1];
wire [7:0]                  s_awlens[0:SLAVE_COUNT-1];
wire [2:0]                  s_awsizes[0:SLAVE_COUNT-1];
wire [1:0]                  s_awbursts[0:SLAVE_COUNT-1];
wire                        s_wreadys[0:SLAVE_COUNT-1];
wire                        s_wvalids[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0]       s_wdatas[0:SLAVE_COUNT-1];
wire [DATA_WIDTH/8-1:0]     s_wstrbs[0:SLAVE_COUNT-1];
wire                        s_wlasts[0:SLAVE_COUNT-1];
wire                        s_breadys[0:SLAVE_COUNT-1];
reg                         s_bvalids[0:SLAVE_COUNT-1];
wire [BRESP_WIDTH-1:0]      s_bresps[0:SLAVE_COUNT-1];
wire [3:0]                  s_bids[0:SLAVE_COUNT-1];
wire                        s_arreadys[0:SLAVE_COUNT-1];
wire                        s_arvalids[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0]       s_araddrs[0:SLAVE_COUNT-1];
wire [3:0]                  s_arids[0:SLAVE_COUNT-1];
wire [7:0]                  s_arlens[0:SLAVE_COUNT-1];
wire [2:0]                  s_arsizes[0:SLAVE_COUNT-1];
wire [1:0]                  s_arbursts[0:SLAVE_COUNT-1];
wire                        s_rreadys[0:SLAVE_COUNT-1];
reg                         s_rvalids[0:SLAVE_COUNT-1];
wire [RRESP_WIDTH-1:0]      s_rresps[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0]       s_rdatas[0:SLAVE_COUNT-1];
wire                        s_rlasts[0:SLAVE_COUNT-1];
wire [3:0]                  s_rids[0:SLAVE_COUNT-1];

wire [31:0] s_slave_start_addrs[0:SLAVE_COUNT-1];
wire [31:0] s_slave_end_addrs[0:SLAVE_COUNT-1];
generate
    for (genvar i = 0; i<SLAVE_COUNT; ++i) begin
        // DEFAULT
        if (i==0) begin
            assign s_slave_start_addrs[i] = 32'h0000_0000;
            assign s_slave_end_addrs[i] = 32'h0000_0000;
            assign s_awreadys[i] = 0;
            assign s_wreadys[i] = 0;
            assign s_bvalids[i] = 0;
            assign s_bresps[i] = 0;
            assign s_bids[i] = 0;
            assign s_arreadys[i] = 0;
            assign s_rvalids[i] = 0;
            assign s_rresps[i] = 0;
            assign s_rdatas[i] = 0;
            assign s_rlasts[i] = 0;
            assign s_rids[i] = 0;
        end else begin
            integer slave_idx = (USER_S_COUNT-i);
            assign s_slave_start_addrs[i] = u_slave_addrs[64*slave_idx+32 +: 32];
            assign s_slave_end_addrs[i] = u_slave_addrs[64*slave_idx+0 +: 32];

            assign s_awreadys[i]   = u_awreadys[1*slave_idx +: 1];
            assign s_wreadys[i]    = u_wreadys[1*slave_idx +: 1];
            assign s_bvalids[i]    = u_bvalids[1*slave_idx +: 1];
            assign s_bresps[i]     = u_bresps[BRESP_WIDTH*slave_idx +: BRESP_WIDTH];
            assign s_bids[i]       = u_bids[4*slave_idx +: 4];
            assign s_arreadys[i]   = u_arreadys[1*slave_idx +: 1];
            assign s_rvalids[i]    = u_rvalids[1*slave_idx +: 1];
            assign s_rresps[i]     = u_rresps[BRESP_WIDTH*slave_idx +: BRESP_WIDTH];
            assign s_rdatas[i]     = u_rdatas[DATA_WIDTH*slave_idx +: DATA_WIDTH];
            assign s_rlasts[i]     = u_rlasts[1*slave_idx +: 1];
            assign s_rids[i]       = u_rids[4*slave_idx +: 4];

            assign u_awvalids[1*slave_idx +: 1]                        = s_awvalids[i];
            assign u_awaddrs[ADDR_WIDTH*slave_idx +: ADDR_WIDTH]       = s_awaddrs[i];
            assign u_awids[4*slave_idx +: 4]                           = s_awids[i];
            assign u_awlens[8*slave_idx +: 8]                          = s_awlens[i];
            assign u_awsizes[3*slave_idx +: 3]                         = s_awsizes[i];
            assign u_awbursts[2*slave_idx +: 2]                        = s_awbursts[i];
            assign u_wvalids[1*slave_idx +: 1]                         = s_wvalids[i];
            assign u_wdatas[DATA_WIDTH*slave_idx +: DATA_WIDTH]        = s_wdatas[i];
            assign u_wstrbs[DATA_WIDTH/8*slave_idx +: DATA_WIDTH/8]    = s_wstrbs[i];
            assign u_wlasts[1*slave_idx +: 1]                          = s_wlasts[i];
            assign u_breadys[1*slave_idx +: 1]                         = s_breadys[i];
            assign u_arvalids[1*slave_idx +: 1]                        = s_arvalids[i];
            assign u_araddrs[ADDR_WIDTH*slave_idx +: ADDR_WIDTH]       = s_araddrs[i];
            assign u_arids[4*slave_idx +: 4]                           = s_arids[i];
            assign u_arlens[8*slave_idx +: 8]                          = s_arlens[i];
            assign u_arsizes[3*slave_idx +: 3]                         = s_arsizes[i];
            assign u_arbursts[2*slave_idx +: 2]                        = s_arbursts[i];
            assign u_rreadys[1*slave_idx +: 1]                         = s_rreadys[i];
        end
    end
endgenerate

reg [SLAVE_COUNT-1:0] s_signal_en;
reg [SLAVE_COUNT-1:0] s_write_en;
reg [SLAVE_COUNT-1:0] s_read_en;
reg [log2(SLAVE_COUNT):0] r_grant_idx;

assign grant_idx = r_grant_idx;

function [31:0] match_slave_addr;
    input [31:0] addr;
    integer sid;
    reg found;
    begin
        match_slave_addr = -1;
        found = 0;
        for (sid=0; sid<SLAVE_COUNT; ++sid) begin
            if (!found
                && addr>=s_slave_start_addrs[sid%SLAVE_COUNT]
                && addr<=s_slave_end_addrs[sid%SLAVE_COUNT]
            ) begin
                match_slave_addr = sid;
                found = 1;
            end
        end
    end
endfunction

// arbiter
// 每次按照顺序循环遍历，slave中第一个为默认节点
integer aw_match_id;
integer ar_match_id;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= select_t;
        r_grant_idx <= 0;
    end else begin
        case (state)
            select_t: begin
                r_grant_idx <= 0;
                // write请求
                if (awvalid) begin
                    aw_match_id = match_slave_addr(awaddr);
                    if (aw_match_id > 0) begin
                        state <= write_t;
                        r_grant_idx <= (aw_match_id[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT;
                    end
                end
                // read请求
                if (arvalid) begin
                    ar_match_id = match_slave_addr(araddr);
                    if (ar_match_id > 0) begin
                        state <= read_t;
                        r_grant_idx <= (ar_match_id[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT;
                    end
                end
            end

            write_t: begin
                if (bvalid && bready) begin
                    state <= select_t;
                    r_grant_idx <= 0;
                end
            end
            
            read_t: begin
                if (rlast) begin
                    state <= select_t;
                    r_grant_idx <= 0;
                end
            end

            default: begin
`ifndef IN_YOSYS_STA
                $error("arbiter-axi4 is error, state:%x\n", state);
`endif
                state <= select_t;
            end
        endcase
    end
end

// 各信号使能处理
// slave输入引脚处理
generate
    for (genvar i = 0; i < SLAVE_COUNT; ++i ) begin : s_sig_in_gen
        assign s_awvalids[i] = (awvalid & {$bits(awvalid){widx_select==i}});
        assign s_awaddrs[i] = (awaddr & {$bits(awaddr){widx_select==i}});
        assign s_awids[i] = (awid & {$bits(awid){widx_select==i}});
        assign s_awlens[i] = (awlen & {$bits(awlen){widx_select==i}});
        assign s_awsizes[i] = (awsize & {$bits(awsize){widx_select==i}});
        assign s_awbursts[i] = (awburst & {$bits(awburst){widx_select==i}});
        assign s_wvalids[i] = (wvalid & {$bits(wvalid){widx_select==i}});
        assign s_wdatas[i] = (wdata & {$bits(wdata){widx_select==i}});
        assign s_wstrbs[i] = (wstrb & {$bits(wstrb){widx_select==i}});
        assign s_wlasts[i] = (wlast & {$bits(wlast){widx_select==i}});
        assign s_breadys[i] = (bready & {$bits(bready){widx_select==i}});
        assign s_arvalids[i] = (arvalid & {$bits(arvalid){ridx_select==i}});
        assign s_araddrs[i] = (araddr & {$bits(araddr){ridx_select==i}});
        assign s_arids[i] = (arid & {$bits(arid){ridx_select==i}});
        assign s_arlens[i] = (arlen & {$bits(arlen){ridx_select==i}});
        assign s_arsizes[i] = (arsize & {$bits(arsize){ridx_select==i}});
        assign s_arbursts[i] = (arburst & {$bits(arburst){ridx_select==i}});
        assign s_rreadys[i] = (rready & {$bits(rready){ridx_select==i}});
    end
endgenerate
// slave输出引脚处理
assign awready = s_awreadys[widx_select%SLAVE_COUNT];
assign wready = s_wreadys[widx_select%SLAVE_COUNT];
assign bvalid = s_bvalids[widx_select%SLAVE_COUNT];
assign bresp = s_bresps[widx_select%SLAVE_COUNT];
assign bid = s_bids[widx_select%SLAVE_COUNT];
assign arready = s_arreadys[ridx_select%SLAVE_COUNT];
assign rvalid = s_rvalids[ridx_select%SLAVE_COUNT];
assign rresp = s_rresps[ridx_select%SLAVE_COUNT];
assign rdata = s_rdatas[ridx_select%SLAVE_COUNT];
assign rlast = s_rlasts[ridx_select%SLAVE_COUNT];
assign rid = s_rids[ridx_select%SLAVE_COUNT];

// 组合式slave写选择器
integer widx;
always @(*) begin
    widx_select = 0;
    for (integer sid=0; sid<SLAVE_COUNT; ++sid) begin
        widx = (sid + {{32-$bits(widx_last){1'b0}}, widx_last}) % SLAVE_COUNT;
        if (widx_select == 0
            && awaddr>=s_slave_start_addrs[widx]
            && awaddr<=s_slave_end_addrs[widx]
        ) begin
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

// 组合式slave读选择器
integer ridx;
always @(*) begin
    ridx_select = 0;
    for (integer sid=0; sid<SLAVE_COUNT; ++sid) begin
        ridx = (sid + {{32-$bits(ridx_last){1'b0}}, ridx_last}) % SLAVE_COUNT;
        if (ridx_select == 0
            && araddr>=s_slave_start_addrs[ridx]
            && araddr<=s_slave_end_addrs[ridx]
        ) begin
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
