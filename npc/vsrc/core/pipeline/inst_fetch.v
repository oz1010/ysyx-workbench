module inst_fetch #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter IN_DATA_W,
    parameter OUT_DATA_W
) (
    input   wire                        clk,
    input   wire                        rst,

    /* req-resp总线master（连接icache） */
    output  wire                        req_valid,
    input   wire                        req_ready,
    output  wire [ADDR_WIDTH-1:0]       req_addr,
    output  wire                        req_is_write,
    output  wire [DATA_WIDTH-1:0]       req_wdata,
    output  wire [DATA_WIDTH/8-1:0]     req_wstrb,
    input   wire                        resp_valid,
    output  wire                        resp_ready,
    input   wire [DATA_WIDTH-1:0]       resp_data,

    /* 模块额外的接口输入 */
    input   wire [INST_WIDTH-1:0]       fetch_pc,

    /* icache读命中状态（2bit）：NONE/HIT/MISS，读请求被接受后保持到下一次读 */
    input   wire [1:0]                  cache_stat,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [OUT_DATA_W-1:0]       out_bits,
    /* 取指对应的icache命中状态，out_valid期间有效 */
    output  wire [1:0]                  out_cache_stat
);
    assign out_bits = {
        fetch_pc, r_read_inst,
        r_expt, r_expt_cause, r_expt_tval
    };

    reg  [INST_WIDTH-1:0]           r_read_inst;
    reg  [`STAGE_COUNT-1:0]         r_expt = 0;
    reg  [DATA_WIDTH-1:0]           r_expt_cause = 0;
    reg  [DATA_WIDTH-1:0]           r_expt_tval = 0;
    reg  [1:0]                      r_cache_stat = `CACHE_STAT_NONE;

    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    inner_con if_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done)
    );

    wire                            req_resp_done = resp_valid && resp_ready;
    assign out_cache_stat = r_cache_stat;

    /* 触发式记录使能 */
    reg r_read_en;
    always @(posedge clk) begin
        if (rst) begin
            r_read_en <= 0;
        end else begin
            r_read_en <=
                stage_in_done ? 1 :
                req_resp_done ? 0 :
                r_read_en;
        end
    end
    wire read_en;
    assign read_en = stage_in_done | r_read_en;

    /* 取指为4字节对齐的单字读请求 */
    assign req_valid = read_en;
    assign req_addr = fetch_pc;
    assign req_is_write = 0;
    assign req_wdata = 0;
    assign req_wstrb = 0;
    assign resp_ready = read_en;

    always @(posedge clk) begin
        if (rst) begin
            r_stage_out_valid <= 0;
            r_cache_stat <= `CACHE_STAT_NONE;
        end else begin
            // read request
            if (req_valid && req_ready) begin
                check_dev_addr(fetch_pc, `DEV_ATTR_READ|`DEV_ATTR_EXEC);
            end

            r_stage_out_valid <=
                req_resp_done ? 1 :
                stage_out_done ? 0 :
                r_stage_out_valid;
            r_read_inst <= req_resp_done ? resp_data : r_read_inst;
            // 读数据返回时锁存icache命中状态（读请求被接受后cache_stat已稳定）
            r_cache_stat <= req_resp_done ? cache_stat : r_cache_stat;
        end
    end

endmodule
