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

`ifdef IN_YOSYS_STA
localparam [2:0] select_t       = 0;
localparam [2:0] read_t         = 1;
localparam [2:0] write_t        = 2;
localparam [2:0] err_t          = 3;
`else
typedef enum [2:0] { select_t, read_t, write_t, err_t } state_t;
`endif
reg [2:0]  state;

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

reg [MASTER_COUNT-1:0] m_signal_en;
reg [MASTER_COUNT-1:0] m_write_en;
reg [MASTER_COUNT-1:0] m_read_en;
reg [log2(MASTER_COUNT):0] r_grant_idx;

assign grant_idx = r_grant_idx;

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

function void match_master_valid;
    output [31:0] awid0;
    output [31:0] arid1;
    integer mid;
    reg found;
    begin
        awid0 = -1;
        arid1 = -1;
        found = 0;
        for (mid=0; mid<MASTER_COUNT; ++mid) begin
            if (!found && m_awvalids[mid]) begin
                awid0 = mid;
                found = 1;
            end else if (!found && m_arvalids[mid]) begin
                arid1 = mid;
                found = 1;
            end
        end
    end
endfunction

// arbiter
// 每次按照顺序循环遍历，master中最后一个为默认节点
integer aw_match_id;
integer ar_match_id;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= select_t;
        r_grant_idx <= 0;
    end else begin
        case (state)
            select_t: begin
                match_master_valid(aw_match_id, ar_match_id);
                if (aw_match_id>=0) begin
                    state <= write_t;
                    r_grant_idx <= (aw_match_id[$bits(r_grant_idx)-1:0]) % MASTER_COUNT;
                end else if (ar_match_id>=0) begin
                    state <= read_t;
                    r_grant_idx <= (ar_match_id[$bits(r_grant_idx)-1:0]) % MASTER_COUNT;
                end
            end

            write_t: begin
                if (m_bvalids[r_grant_idx] && m_breadys[r_grant_idx]) begin
                    state <= select_t;
                    r_grant_idx <= 0;
                end
            end
            
            read_t: begin
                if (m_rlasts[r_grant_idx]) begin
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
// manager输入引脚处理，没有选择的需要赋值为0
generate
    for (genvar i = 0; i < MASTER_COUNT; ++i) begin : m_sig_in_gen
        assign m_signal_en[i] = m_awvalids[i] | m_wvalids[i] | m_bvalids[i] | m_arvalids[i] | m_rvalids[i];
        assign m_write_en[i] = ((m_awvalids[i] | m_wvalids[i] | m_bvalids[i]));
        assign m_read_en[i] = ((m_arvalids[i] | m_rvalids[i]));

        assign m_awreadys[i] = (awready & {$bits(awready){i==grant_idx}});
        assign m_wreadys[i] = (wready & {$bits(wready){i==grant_idx}});
        assign m_bvalids[i] = (bvalid & {$bits(bvalid){i==grant_idx}});
        assign m_bresps[i] = (bresp & {$bits(bresp){i==grant_idx}});
        assign m_bids[i] = (bid & {$bits(bid){i==grant_idx}});
        assign m_arreadys[i] = (arready & {$bits(arready){i==grant_idx}});
        assign m_rvalids[i] = (rvalid & {$bits(rvalid){i==grant_idx}});
        assign m_rresps[i] = (rresp & {$bits(rresp){i==grant_idx}});
        assign m_rdatas[i] = (rdata & {$bits(rdata){i==grant_idx}});
        assign m_rlasts[i] = (rlast & {$bits(rlast){i==grant_idx}});
        assign m_rids[i] = (rid & {$bits(rid){i==grant_idx}});
    end
endgenerate

// manager输出引脚处理
assign awvalid = m_awvalids[r_grant_idx];
assign awaddr = m_awaddrs[r_grant_idx];
assign awid = m_awids[r_grant_idx];
assign awlen = m_awlens[r_grant_idx];
assign awsize = m_awsizes[r_grant_idx];
assign awburst = m_awbursts[r_grant_idx];
assign wvalid = m_wvalids[r_grant_idx];
assign wdata = m_wdatas[r_grant_idx];
assign wstrb = m_wstrbs[r_grant_idx];
assign wlast = m_wlasts[r_grant_idx];
assign bready = m_breadys[r_grant_idx];
assign arvalid = m_arvalids[r_grant_idx];
assign araddr = m_araddrs[r_grant_idx];
assign arid = m_arids[r_grant_idx];
assign arlen = m_arlens[r_grant_idx];
assign arsize = m_arsizes[r_grant_idx];
assign arburst = m_arbursts[r_grant_idx];
assign rready = m_rreadys[r_grant_idx];

endmodule
