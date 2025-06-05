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

    output  wire                        aw_ready,
    input   wire                        aw_valid,
    input   wire [ADDR_WIDTH-1:0]       aw_addr,
    input   wire [3:0]                  aw_id,
    input   wire [7:0]                  aw_len,
    input   wire [2:0]                  aw_size,
    input   wire [1:0]                  aw_burst,
    output  wire                        w_ready,
    input   wire                        w_valid,
    input   wire [DATA_WIDTH-1:0]       w_data,
    input   wire [DATA_WIDTH/8-1:0]     w_strb,
    input   wire                        w_last,
    input   wire                        b_ready,
    output  wire                        b_valid,
    output  wire [BRESP_WIDTH-1:0]      b_resp,
    output  wire [3:0]                  b_id,
    output  wire                        ar_ready,
    input   wire                        ar_valid,
    input   wire [ADDR_WIDTH-1:0]       ar_addr,
    input   wire [3:0]                  ar_id,
    input   wire [7:0]                  ar_len,
    input   wire [2:0]                  ar_size,
    input   wire [1:0]                  ar_burst,
    input   wire                        r_ready,
    output  wire                        r_valid,
    output  wire [RRESP_WIDTH-1:0]      r_resp,
    output  wire [DATA_WIDTH-1:0]       r_data,
    output  wire                        r_last,
    output  wire [3:0]                  r_id,

    input   wire                        u_aw_readys[0:USER_S_COUNT-1],
    output  wire                        u_aw_valids[0:USER_S_COUNT-1],
    output  wire [ADDR_WIDTH-1:0]       u_aw_addrs[0:USER_S_COUNT-1],
    output  wire [3:0]                  u_aw_ids[0:USER_S_COUNT-1],
    output  wire [7:0]                  u_aw_lens[0:USER_S_COUNT-1],
    output  wire [2:0]                  u_aw_sizes[0:USER_S_COUNT-1],
    output  wire [1:0]                  u_aw_bursts[0:USER_S_COUNT-1],
    input   wire                        u_w_readys[0:USER_S_COUNT-1],
    output  wire                        u_w_valids[0:USER_S_COUNT-1],
    output  wire [DATA_WIDTH-1:0]       u_w_datas[0:USER_S_COUNT-1],
    output  wire [DATA_WIDTH/8-1:0]     u_w_strbs[0:USER_S_COUNT-1],
    output  wire                        u_w_lasts[0:USER_S_COUNT-1],
    output  wire                        u_b_readys[0:USER_S_COUNT-1],
    input   wire                        u_b_valids[0:USER_S_COUNT-1],
    input   wire [BRESP_WIDTH-1:0]      u_b_resps[0:USER_S_COUNT-1],
    input   wire [3:0]                  u_b_ids[0:USER_S_COUNT-1],
    input   wire                        u_ar_readys[0:USER_S_COUNT-1],
    output  wire                        u_ar_valids[0:USER_S_COUNT-1],
    output  wire [ADDR_WIDTH-1:0]       u_ar_addrs[0:USER_S_COUNT-1],
    output  wire [3:0]                  u_ar_ids[0:USER_S_COUNT-1],
    output  wire [7:0]                  u_ar_lens[0:USER_S_COUNT-1],
    output  wire [2:0]                  u_ar_sizes[0:USER_S_COUNT-1],
    output  wire [1:0]                  u_ar_bursts[0:USER_S_COUNT-1],
    output  wire                        u_r_readys[0:USER_S_COUNT-1],
    input   wire                        u_r_valids[0:USER_S_COUNT-1],
    input   wire [RRESP_WIDTH-1:0]      u_r_resps[0:USER_S_COUNT-1],
    input   wire [DATA_WIDTH-1:0]       u_r_datas[0:USER_S_COUNT-1],
    input   wire                        u_r_lasts[0:USER_S_COUNT-1],
    input   wire [3:0]                  u_r_ids[0:USER_S_COUNT-1],

    input   slave_info_t                u_slave_infos[0:USER_S_COUNT-1],
    output  wire [log2(SLAVE_COUNT):0] grant_idx
);

typedef enum [2:0] { select_t, read_t, write_t, err_t } state_t;
reg [2:0]  state;

// 默认slave，避免切设备时造成响应错误
wire                        s_aw_readys[0:SLAVE_COUNT-1];
wire                        s_aw_valids[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0]       s_aw_addrs[0:SLAVE_COUNT-1];
wire [3:0]                  s_aw_ids[0:SLAVE_COUNT-1];
wire [7:0]                  s_aw_lens[0:SLAVE_COUNT-1];
wire [2:0]                  s_aw_sizes[0:SLAVE_COUNT-1];
wire [1:0]                  s_aw_bursts[0:SLAVE_COUNT-1];
wire                        s_w_readys[0:SLAVE_COUNT-1];
wire                        s_w_valids[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0]       s_w_datas[0:SLAVE_COUNT-1];
wire [DATA_WIDTH/8-1:0]     s_w_strbs[0:SLAVE_COUNT-1];
wire                        s_w_lasts[0:SLAVE_COUNT-1];
wire                        s_b_readys[0:SLAVE_COUNT-1];
reg                         s_b_valids[0:SLAVE_COUNT-1];
wire [BRESP_WIDTH-1:0]      s_b_resps[0:SLAVE_COUNT-1];
wire [3:0]                  s_b_ids[0:SLAVE_COUNT-1];
wire                        s_ar_readys[0:SLAVE_COUNT-1];
wire                        s_ar_valids[0:SLAVE_COUNT-1];
wire [ADDR_WIDTH-1:0]       s_ar_addrs[0:SLAVE_COUNT-1];
wire [3:0]                  s_ar_ids[0:SLAVE_COUNT-1];
wire [7:0]                  s_ar_lens[0:SLAVE_COUNT-1];
wire [2:0]                  s_ar_sizes[0:SLAVE_COUNT-1];
wire [1:0]                  s_ar_bursts[0:SLAVE_COUNT-1];
wire                        s_r_readys[0:SLAVE_COUNT-1];
reg                         s_r_valids[0:SLAVE_COUNT-1];
wire [RRESP_WIDTH-1:0]      s_r_resps[0:SLAVE_COUNT-1];
wire [DATA_WIDTH-1:0]       s_r_datas[0:SLAVE_COUNT-1];
wire                        s_r_lasts[0:SLAVE_COUNT-1];
wire [3:0]                  s_r_ids[0:SLAVE_COUNT-1];
assign s_aw_readys = {0, u_aw_readys};
assign s_w_readys = {0, u_w_readys};
assign s_b_valids = {0, u_b_valids};
assign s_b_resps = {0, u_b_resps};
assign s_b_ids = {0, u_b_ids};
assign s_ar_readys = {0, u_ar_readys};
assign s_r_valids = {0, u_r_valids};
assign s_r_resps = {0, u_r_resps};
assign s_r_datas = {0, u_r_datas};
assign s_r_lasts = {0, u_r_lasts};
assign s_r_ids = {0, u_r_ids};
assign u_aw_valids = s_aw_valids[1:SLAVE_COUNT-1];
assign u_aw_addrs = s_aw_addrs[1:SLAVE_COUNT-1];
assign u_aw_ids = s_aw_ids[1:SLAVE_COUNT-1];
assign u_aw_lens = s_aw_lens[1:SLAVE_COUNT-1];
assign u_aw_sizes = s_aw_sizes[1:SLAVE_COUNT-1];
assign u_aw_bursts = s_aw_bursts[1:SLAVE_COUNT-1];
assign u_w_valids = s_w_valids[1:SLAVE_COUNT-1];
assign u_w_datas = s_w_datas[1:SLAVE_COUNT-1];
assign u_w_strbs = s_w_strbs[1:SLAVE_COUNT-1];
assign u_w_lasts = s_w_lasts[1:SLAVE_COUNT-1];
assign u_b_readys = s_b_readys[1:SLAVE_COUNT-1];
assign u_ar_valids = s_ar_valids[1:SLAVE_COUNT-1];
assign u_ar_addrs = s_ar_addrs[1:SLAVE_COUNT-1];
assign u_ar_ids = s_ar_ids[1:SLAVE_COUNT-1];
assign u_ar_lens = s_ar_lens[1:SLAVE_COUNT-1];
assign u_ar_sizes = s_ar_sizes[1:SLAVE_COUNT-1];
assign u_ar_bursts = s_ar_bursts[1:SLAVE_COUNT-1];
assign u_r_readys = s_r_readys[1:SLAVE_COUNT-1];

slave_info_t s_slave_infos[0:SLAVE_COUNT-1];
assign s_slave_infos[0] = '{name:"DEFAULT",          startaddr:32'h0000_0000,    endaddr:32'h0000_0000};
assign s_slave_infos[1:SLAVE_COUNT-1] = u_slave_infos;

reg [SLAVE_COUNT-1:0] s_signal_en;
reg [SLAVE_COUNT-1:0] s_write_en;
reg [SLAVE_COUNT-1:0] s_read_en;
reg [log2(SLAVE_COUNT):0] r_grant_idx;

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

// arbiter
// 每次按照顺序循环遍历，slave中第一个为默认节点
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= select_t;
        r_grant_idx <= 0;
    end else begin
        case (state)
            select_t: begin
                r_grant_idx <= 0;
                // write请求
                if (aw_valid) begin
                    for (integer sid=0; sid<SLAVE_COUNT; ++sid) begin
                        if (aw_addr>=s_slave_infos[(sid[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT].startaddr && 
                            aw_addr<=s_slave_infos[(sid[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT].endaddr) begin
                            state <= write_t;
                            r_grant_idx <= (sid[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT;
                            break;
                        end
                    end
                end
                // read请求
                if (ar_valid) begin
                    for (integer sid=0; sid<SLAVE_COUNT; ++sid) begin
                        if (ar_addr>=s_slave_infos[(sid[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT].startaddr && 
                            ar_addr<=s_slave_infos[(sid[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT].endaddr) begin
                            state <= read_t;
                            r_grant_idx <= (sid[$bits(r_grant_idx)-1:0]) % SLAVE_COUNT;
                            break;
                        end
                    end
                end
            end

            write_t: begin
                if (b_valid && b_ready) begin
                    state <= select_t;
                    r_grant_idx <= 0;
                end
            end
            
            read_t: begin
                if (r_last) begin
                    state <= select_t;
                    r_grant_idx <= 0;
                end
            end

            default: begin
                $error("arbiter-axi4 is error, state:%x\n", state);
                state <= select_t;
            end
        endcase
    end
end

// 各信号使能处理
// slave输入引脚处理
generate
    for (genvar i = 0; i < SLAVE_COUNT; ++i ) begin : s_sig_in_gen
        assign s_aw_valids[i] = (aw_valid & {$bits(aw_valid){r_grant_idx==i}});
        assign s_aw_addrs[i] = (aw_addr & {$bits(aw_addr){r_grant_idx==i}});
        assign s_aw_ids[i] = (aw_id & {$bits(aw_id){r_grant_idx==i}});
        assign s_aw_lens[i] = (aw_len & {$bits(aw_len){r_grant_idx==i}});
        assign s_aw_sizes[i] = (aw_size & {$bits(aw_size){r_grant_idx==i}});
        assign s_aw_bursts[i] = (aw_burst & {$bits(aw_burst){r_grant_idx==i}});
        assign s_w_valids[i] = (w_valid & {$bits(w_valid){r_grant_idx==i}});
        assign s_w_datas[i] = (w_data & {$bits(w_data){r_grant_idx==i}});
        assign s_w_strbs[i] = (w_strb & {$bits(w_strb){r_grant_idx==i}});
        assign s_w_lasts[i] = (w_last & {$bits(w_last){r_grant_idx==i}});
        assign s_b_readys[i] = (b_ready & {$bits(b_ready){r_grant_idx==i}});
        assign s_ar_valids[i] = (ar_valid & {$bits(ar_valid){r_grant_idx==i}});
        assign s_ar_addrs[i] = (ar_addr & {$bits(ar_addr){r_grant_idx==i}});
        assign s_ar_ids[i] = (ar_id & {$bits(ar_id){r_grant_idx==i}});
        assign s_ar_lens[i] = (ar_len & {$bits(ar_len){r_grant_idx==i}});
        assign s_ar_sizes[i] = (ar_size & {$bits(ar_size){r_grant_idx==i}});
        assign s_ar_bursts[i] = (ar_burst & {$bits(ar_burst){r_grant_idx==i}});
        assign s_r_readys[i] = (r_ready & {$bits(r_ready){r_grant_idx==i}});
    end
endgenerate
// slave输出引脚处理
assign aw_ready = s_aw_readys[r_grant_idx%SLAVE_COUNT];
assign w_ready = s_w_readys[r_grant_idx%SLAVE_COUNT];
assign b_valid = s_b_valids[r_grant_idx%SLAVE_COUNT];
assign b_resp = s_b_resps[r_grant_idx%SLAVE_COUNT];
assign b_id = s_b_ids[r_grant_idx%SLAVE_COUNT];
assign ar_ready = s_ar_readys[r_grant_idx%SLAVE_COUNT];
assign r_valid = s_r_valids[r_grant_idx%SLAVE_COUNT];
assign r_resp = s_r_resps[r_grant_idx%SLAVE_COUNT];
assign r_data = s_r_datas[r_grant_idx%SLAVE_COUNT];
assign r_last = s_r_lasts[r_grant_idx%SLAVE_COUNT];
assign r_id = s_r_ids[r_grant_idx%SLAVE_COUNT];

endmodule
