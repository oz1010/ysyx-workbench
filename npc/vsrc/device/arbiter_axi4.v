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

    output  wire                        u_aw_readys[0:USER_M_COUNT-1],
    input   wire                        u_aw_valids[0:USER_M_COUNT-1],
    input   wire [ADDR_WIDTH-1:0]       u_aw_addrs[0:USER_M_COUNT-1],
    input   wire [3:0]                  u_aw_ids[0:USER_M_COUNT-1],
    input   wire [7:0]                  u_aw_lens[0:USER_M_COUNT-1],
    input   wire [2:0]                  u_aw_sizes[0:USER_M_COUNT-1],
    input   wire [1:0]                  u_aw_bursts[0:USER_M_COUNT-1],
    output  wire                        u_w_readys[0:USER_M_COUNT-1],
    input   wire                        u_w_valids[0:USER_M_COUNT-1],
    input   wire [DATA_WIDTH-1:0]       u_w_datas[0:USER_M_COUNT-1],
    input   wire [DATA_WIDTH/8-1:0]     u_w_strbs[0:USER_M_COUNT-1],
    input   wire                        u_w_lasts[0:USER_M_COUNT-1],
    input   wire                        u_b_readys[0:USER_M_COUNT-1],
    output  wire                        u_b_valids[0:USER_M_COUNT-1],
    output  wire [BRESP_WIDTH-1:0]      u_b_resps[0:USER_M_COUNT-1],
    output  wire [3:0]                  u_b_ids[0:USER_M_COUNT-1],
    output  wire                        u_ar_readys[0:USER_M_COUNT-1],
    input   wire                        u_ar_valids[0:USER_M_COUNT-1],
    input   wire [ADDR_WIDTH-1:0]       u_ar_addrs[0:USER_M_COUNT-1],
    input   wire [3:0]                  u_ar_ids[0:USER_M_COUNT-1],
    input   wire [7:0]                  u_ar_lens[0:USER_M_COUNT-1],
    input   wire [2:0]                  u_ar_sizes[0:USER_M_COUNT-1],
    input   wire [1:0]                  u_ar_bursts[0:USER_M_COUNT-1],
    input   wire                        u_r_readys[0:USER_M_COUNT-1],
    output  wire                        u_r_valids[0:USER_M_COUNT-1],
    output  wire [RRESP_WIDTH-1:0]      u_r_resps[0:USER_M_COUNT-1],
    output  wire [DATA_WIDTH-1:0]       u_r_datas[0:USER_M_COUNT-1],
    output  wire                        u_r_lasts[0:USER_M_COUNT-1],
    output  wire [3:0]                  u_r_ids[0:USER_M_COUNT-1],

    input   wire                        aw_ready,
    output  wire                        aw_valid,
    output  wire [ADDR_WIDTH-1:0]       aw_addr,
    output  wire [3:0]                  aw_id,
    output  wire [7:0]                  aw_len,
    output  wire [2:0]                  aw_size,
    output  wire [1:0]                  aw_burst,
    input   wire                        w_ready,
    output  wire                        w_valid,
    output  wire [DATA_WIDTH-1:0]       w_data,
    output  wire [DATA_WIDTH/8-1:0]     w_strb,
    output  wire                        w_last,
    output  wire                        b_ready,
    input   wire                        b_valid,
    input   wire [BRESP_WIDTH-1:0]      b_resp,
    input   wire [3:0]                  b_id,
    input   wire                        ar_ready,
    output  wire                        ar_valid,
    output  wire [ADDR_WIDTH-1:0]       ar_addr,
    output  wire [3:0]                  ar_id,
    output  wire [7:0]                  ar_len,
    output  wire [2:0]                  ar_size,
    output  wire [1:0]                  ar_burst,
    output  wire                        r_ready,
    input   wire                        r_valid,
    input   wire [RRESP_WIDTH-1:0]      r_resp,
    input   wire [DATA_WIDTH-1:0]       r_data,
    input   wire                        r_last,
    input   wire [3:0]                  r_id,

    output  wire [log2(MASTER_COUNT):0] grant_idx
);

typedef enum [2:0] { select_t, read_t, write_t, err_t } state_t;
reg [2:0]  state;

// 默认master，避免切主时造成从设备响应错误
wire                        m_aw_readys[0:MASTER_COUNT-1];
wire                        m_aw_valids[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0]       m_aw_addrs[0:MASTER_COUNT-1];
wire [3:0]                  m_aw_ids[0:MASTER_COUNT-1];
wire [7:0]                  m_aw_lens[0:MASTER_COUNT-1];
wire [2:0]                  m_aw_sizes[0:MASTER_COUNT-1];
wire [1:0]                  m_aw_bursts[0:MASTER_COUNT-1];
wire                        m_w_readys[0:MASTER_COUNT-1];
wire                        m_w_valids[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0]       m_w_datas[0:MASTER_COUNT-1];
wire [DATA_WIDTH/8-1:0]     m_w_strbs[0:MASTER_COUNT-1];
wire                        m_w_lasts[0:MASTER_COUNT-1];
wire                        m_b_readys[0:MASTER_COUNT-1];
reg                         m_b_valids[0:MASTER_COUNT-1];
wire [BRESP_WIDTH-1:0]      m_b_resps[0:MASTER_COUNT-1];
wire [3:0]                  m_b_ids[0:MASTER_COUNT-1];
wire                        m_ar_readys[0:MASTER_COUNT-1];
wire                        m_ar_valids[0:MASTER_COUNT-1];
wire [ADDR_WIDTH-1:0]       m_ar_addrs[0:MASTER_COUNT-1];
wire [3:0]                  m_ar_ids[0:MASTER_COUNT-1];
wire [7:0]                  m_ar_lens[0:MASTER_COUNT-1];
wire [2:0]                  m_ar_sizes[0:MASTER_COUNT-1];
wire [1:0]                  m_ar_bursts[0:MASTER_COUNT-1];
wire                        m_r_readys[0:MASTER_COUNT-1];
reg                         m_r_valids[0:MASTER_COUNT-1];
wire [RRESP_WIDTH-1:0]      m_r_resps[0:MASTER_COUNT-1];
wire [DATA_WIDTH-1:0]       m_r_datas[0:MASTER_COUNT-1];
wire                        m_r_lasts[0:MASTER_COUNT-1];
wire [3:0]                  m_r_ids[0:MASTER_COUNT-1];
assign m_aw_valids = {0, u_aw_valids};
assign m_aw_addrs = {0, u_aw_addrs};
assign m_aw_ids = {0, u_aw_ids};
assign m_aw_lens = {0, u_aw_lens};
assign m_aw_sizes = {0, u_aw_sizes};
assign m_aw_bursts = {0, u_aw_bursts};
assign m_w_valids = {0, u_w_valids};
assign m_w_datas = {0, u_w_datas};
assign m_w_strbs = {0, u_w_strbs};
assign m_w_lasts = {0, u_w_lasts};
assign m_b_readys = {0, u_b_readys};
assign m_ar_valids = {0, u_ar_valids};
assign m_ar_addrs = {0, u_ar_addrs};
assign m_ar_ids = {0, u_ar_ids};
assign m_ar_lens = {0, u_ar_lens};
assign m_ar_sizes = {0, u_ar_sizes};
assign m_ar_bursts = {0, u_ar_bursts};
assign m_r_readys = {0, u_r_readys};
assign u_aw_readys = m_aw_readys[1:MASTER_COUNT-1];
assign u_w_readys = m_w_readys[1:MASTER_COUNT-1];
assign u_b_valids = m_b_valids[1:MASTER_COUNT-1];
assign u_b_resps = m_b_resps[1:MASTER_COUNT-1];
assign u_b_ids = m_b_ids[1:MASTER_COUNT-1];
assign u_ar_readys = m_ar_readys[1:MASTER_COUNT-1];
assign u_r_valids = m_r_valids[1:MASTER_COUNT-1];
assign u_r_resps = m_r_resps[1:MASTER_COUNT-1];
assign u_r_datas = m_r_datas[1:MASTER_COUNT-1];
assign u_r_lasts = m_r_lasts[1:MASTER_COUNT-1];
assign u_r_ids = m_r_ids[1:MASTER_COUNT-1];

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

// arbiter
// 每次按照顺序循环遍历，master中最后一个为默认节点
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state <= select_t;
        r_grant_idx <= 0;
    end else begin
        case (state)
            select_t: begin
                for (integer midx=0; midx<MASTER_COUNT; ++midx) begin
                    if (m_aw_valids[(midx[$bits(r_grant_idx)-1:0]) % MASTER_COUNT]) begin
                        state <= write_t;
                        r_grant_idx <= (midx[$bits(r_grant_idx)-1:0]) % MASTER_COUNT;
                        break;
                    end
                    if (m_ar_valids[(midx[$bits(r_grant_idx)-1:0]) % MASTER_COUNT]) begin
                        state <= read_t;
                        r_grant_idx <= (midx[$bits(r_grant_idx)-1:0]) % MASTER_COUNT;
                        break;
                    end
                end
            end

            write_t: begin
                if (m_b_valids[r_grant_idx] && m_b_readys[r_grant_idx]) begin
                    state <= select_t;
                    r_grant_idx <= 0;
                end
            end
            
            read_t: begin
                if (m_r_valids[r_grant_idx] && m_r_readys[r_grant_idx]) begin
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
// manager输入引脚处理，没有选择的需要赋值为0
generate
    for (genvar i = 0; i < MASTER_COUNT; ++i) begin : m_sig_in_gen
        assign m_signal_en[i] = m_aw_valids[i] | m_w_valids[i] | m_b_valids[i] | m_ar_valids[i] | m_r_valids[i];
        assign m_write_en[i] = ((m_aw_valids[i] | m_w_valids[i] | m_b_valids[i]));
        assign m_read_en[i] = ((m_ar_valids[i] | m_r_valids[i]));

        assign m_aw_readys[i] = (aw_ready & {$bits(aw_ready){i==grant_idx}});
        assign m_w_readys[i] = (w_ready & {$bits(w_ready){i==grant_idx}});
        assign m_b_valids[i] = (b_valid & {$bits(b_valid){i==grant_idx}});
        assign m_b_resps[i] = (b_resp & {$bits(b_resp){i==grant_idx}});
        assign m_b_ids[i] = (b_id & {$bits(b_id){i==grant_idx}});
        assign m_ar_readys[i] = (ar_ready & {$bits(ar_ready){i==grant_idx}});
        assign m_r_valids[i] = (r_valid & {$bits(r_valid){i==grant_idx}});
        assign m_r_resps[i] = (r_resp & {$bits(r_resp){i==grant_idx}});
        assign m_r_datas[i] = (r_data & {$bits(r_data){i==grant_idx}});
        assign m_r_lasts[i] = (r_last & {$bits(r_last){i==grant_idx}});
        assign m_r_ids[i] = (r_id & {$bits(r_id){i==grant_idx}});
    end
endgenerate

// manager输出引脚处理
assign aw_valid = m_aw_valids[r_grant_idx];
assign aw_addr = m_aw_addrs[r_grant_idx];
assign aw_id = m_aw_ids[r_grant_idx];
assign aw_len = m_aw_lens[r_grant_idx];
assign aw_size = m_aw_sizes[r_grant_idx];
assign aw_burst = m_aw_bursts[r_grant_idx];
assign w_valid = m_w_valids[r_grant_idx];
assign w_data = m_w_datas[r_grant_idx];
assign w_strb = m_w_strbs[r_grant_idx];
assign w_last = m_w_lasts[r_grant_idx];
assign b_ready = m_b_readys[r_grant_idx];
assign ar_valid = m_ar_valids[r_grant_idx];
assign ar_addr = m_ar_addrs[r_grant_idx];
assign ar_id = m_ar_ids[r_grant_idx];
assign ar_len = m_ar_lens[r_grant_idx];
assign ar_size = m_ar_sizes[r_grant_idx];
assign ar_burst = m_ar_bursts[r_grant_idx];
assign r_ready = m_r_readys[r_grant_idx];

endmodule