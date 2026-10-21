module load_store #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter IN_DATA_W,
    parameter OUT_DATA_W
) (
    input   wire                        clock,
    input   wire                        reset,

    /* req-resp总线master（连接dcache） */
    output  wire                        req_valid,
    input   wire                        req_ready,
    output  wire [ADDR_WIDTH-1:0]       req_addr,
    output  wire                        req_is_write,
    output  wire [DATA_WIDTH-1:0]       req_wdata,
    output  wire [DATA_WIDTH/8-1:0]     req_wstrb,
    input   wire                        resp_valid,
    output  wire                        resp_ready,
    input   wire [DATA_WIDTH-1:0]       resp_data,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [IN_DATA_W-1:0]        in_bits,

    /* 模块输入数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [OUT_DATA_W-1:0]       out_bits,
    /* dcache读命中状态（2bit）：NONE/HIT/MISS，统计数据只针对读，写为NONE */
    input   wire [1:0]                  cache_stat,
    /* 访存对应的dcache命中状态，out_valid期间有效 */
    output  wire [1:0]                  out_cache_stat,
    /* 硬件监控信号 */
    output  wire                        hw_monitor_ls_en,
    output  wire                        hw_monitor_ls_iswrite,
    output  wire [DATA_WIDTH-1:0]       hw_monitor_ls_data,
    /* 访存标识及访存目标地址，out_valid期间有效（无访存时分别为0） */
    output  wire                        out_mem_access,
    output  wire [ADDR_WIDTH-1:0]       out_mem_addr
);
    assign {
        pc, dnpc, inst, rd, rs1, rs2, imm, inst_code, src1, src2,
        result, result_update_gpr, csr_wch,
        expt, expt_cause, expt_tval
    } = in_bits;

    assign out_bits = {
        pc,
        dnpc,
        rd,
        rs1,
        rs2,
        inst_code,
        ls_enable ? r_result : result,
        ls_enable ? r_result_update_gpr : result_update_gpr,
        csr_wch,
        prev_err ? expt : r_expt,
        prev_err ? expt_cause : r_expt_cause,
        prev_err ? expt_tval : r_expt_tval
    };

    wire [INST_WIDTH-1:0]           pc;
    wire [INST_WIDTH-1:0]           dnpc;
    wire [INST_WIDTH-1:0]           inst;
    wire [4:0]                      rd;
    wire [4:0]                      rs1;
    wire [4:0]                      rs2;
    wire [INST_WIDTH-1:0]           imm;
    wire [`INST_CODE_W-1:0]         inst_code;
    wire [INST_WIDTH-1:0]           src1;
    wire [INST_WIDTH-1:0]           src2;
    wire [INST_WIDTH-1:0]           result;
    wire                            result_update_gpr;
    wire [`CSR_WCH_W-1:0]           csr_wch;
    wire [`STAGE_COUNT-1:0]         expt;
    wire [DATA_WIDTH-1:0]           expt_cause;
    wire [DATA_WIDTH-1:0]           expt_tval;

    reg [INST_WIDTH-1:0]            r_result;
    reg                             r_result_update_gpr;
    reg  [`STAGE_COUNT-1:0]         r_expt = 0;
    reg  [DATA_WIDTH-1:0]           r_expt_cause = 0;
    reg  [DATA_WIDTH-1:0]           r_expt_tval = 0;
    reg  [1:0]                      r_cache_stat = `CACHE_STAT_NONE;
    reg                             r_mem_access = 0;
    reg  [ADDR_WIDTH-1:0]           r_mem_addr = 0;

    /* 请求事务状态：r_req_busy--请求已被接受等待响应；
       跨字访问拆成两个单字请求，r_req_second指示当前为第二拍 */
    reg                             r_req_busy = 0;
    reg                             r_req_second = 0;
    reg  [DATA_WIDTH-1:0]           r_req_first_data = 0;

    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    inner_con ls_con(
        .clock(clock),
        .reset(reset),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done)
    );

    wire prev_err = |expt;
    wire ls_enable = (|(inst_code & `INST_CODE_MEM)) && !prev_err; // 当存在异常时，避免多周期存取指令干扰，直接透传
    wire access_enable = !in_ready;
    assign out_cache_stat = r_cache_stat;
    assign out_mem_access = r_mem_access;
    assign out_mem_addr = r_mem_addr;
    wire [INST_WIDTH-1:0]       access_addr = src1+imm;
    wire [2:0]                  access_size =
        inst_code == `INST_SB ? 0
        : inst_code == `INST_LB ? 0
        : inst_code == `INST_LBU ? 0
        : inst_code == `INST_SH ? 1
        : inst_code == `INST_LH ? 1
        : inst_code == `INST_LHU ? 1
        : 2;

    reg r_write_enable;
    wire write_inst = (inst_code==`INST_SB | inst_code==`INST_SH | inst_code==`INST_SW);
    wire [ADDR_WIDTH-1:0] write_addr = access_addr;
    wire [DATA_WIDTH-1:0] write_data = src2;
    wire [2:0] write_size = access_size;

    reg r_read_enable;
    wire read_inst = (inst_code==`INST_LB | inst_code==`INST_LH | inst_code==`INST_LW | inst_code==`INST_LBU | inst_code==`INST_LHU);
    wire read_sign = (inst_code==`INST_LB | inst_code==`INST_LH | inst_code==`INST_LW);
    wire [ADDR_WIDTH-1:0] read_addr = access_addr;
    wire [2:0] read_size = access_size;

    wire fence_enable = (inst_code==`INST_FENCE | inst_code==`INST_FENCE_I);
    wire test_mode_enable = access_addr>=32'h0f00_2000 & access_addr<=32'h0fff_ffff;

    /* 非对齐访问参数：跨字时拆成两个单字请求，strb高4bit有效表示存在第二拍 */
    reg  [7:0]                  s_write_len;
    reg  [7:0]                  s_write_strb;
    reg  [1:0]                  s_write_shift;
    always @(*) begin
        s_write_len = 0;
        s_write_strb = 0;
        s_write_shift = 0;
        if (!reset && r_write_enable) begin
            get_unalign_addr_parameter(write_size, write_addr, s_write_len, s_write_strb, s_write_shift);
        end
    end
    wire write_span = |s_write_strb[7:4];

    reg  [7:0]                  s_read_len;
    reg  [7:0]                  s_read_strb;
    reg  [1:0]                  s_read_shift;
    always @(*) begin
        s_read_len = 0;
        s_read_strb = 0;
        s_read_shift = 0;
        if (!reset && r_read_enable) begin
            get_unalign_addr_parameter(read_size, read_addr, s_read_len, s_read_strb, s_read_shift);
        end
    end
    wire read_span = |s_read_strb[7:4];

    /* 读数据提取：按偏移截取并做符号扩展；
       提取窗口低字为单字读数据，跨字读时为第一拍数据 */
    wire [DATA_WIDTH-1:0]       read_window_low = read_span ? r_req_first_data : resp_data;
    wire [2*DATA_WIDTH-1:0]     read_window = {resp_data, read_window_low};
    /* 形式化验证：避免使用带输出参数的函数调用（yosys会产生伪组合环），直接按偏移截取并符号扩展 */
    reg  [DATA_WIDTH-1:0]       read_extract;
    always @(*) begin
        get_unalign_addr_data(read_sign, read_size, read_window, s_read_shift, read_extract);
    end

    /* 请求总线：单字读写，跨字访问的第二拍地址为addr+4 */
    wire [ADDR_WIDTH-1:0]       req_addr_base = r_write_enable ? write_addr : read_addr;
    assign req_valid = access_enable && (r_read_enable || r_write_enable) && !r_req_busy;
    assign req_addr = r_req_second ? (req_addr_base + (INST_WIDTH/8)) : req_addr_base;
    assign req_is_write = r_write_enable;
    assign req_wdata = r_write_enable ?
        (r_req_second ? write_data>>(32-8*s_write_shift) : write_data<<(8*s_write_shift)) : 0;
    assign req_wstrb = r_write_enable ?
        (r_req_second ? s_write_strb[7:4] : s_write_strb[3:0]) : 0;
    assign resp_ready = r_req_busy;

    // 处理硬件监控信号
    assign hw_monitor_ls_en = !reset && ls_enable && !fence_enable && !test_mode_enable && access_enable &&
        ((r_write_enable || r_read_enable) && req_valid && req_ready && !r_req_second);
    assign hw_monitor_ls_iswrite = r_write_enable;
    assign hw_monitor_ls_data = req_addr;

    always @(posedge clock) begin
        if (reset) begin
            r_result <= 0;
            r_result_update_gpr <= 0;

            r_stage_out_valid <= 0;
            r_read_enable <= 0;
            r_write_enable <= 0;
            r_cache_stat <= `CACHE_STAT_NONE;
            r_mem_access <= 0;
            r_mem_addr <= 0;
            r_req_busy <= 0;
            r_req_second <= 0;
            r_req_first_data <= 0;
        end else begin
            r_result <= r_result;
            r_result_update_gpr <= r_result_update_gpr;

            if (ls_enable && stage_in_done) begin
                r_read_enable <= read_inst ? 1 : 0;
                r_write_enable <= write_inst ? 1 : 0;
                // 进入时默认无缓存统计（写指令保持NONE），读完成时再更新
                r_cache_stat <= `CACHE_STAT_NONE;
                // 访存指令（读或写）锁存访存标识及访存目标地址，供perf monitor获取数据存储索引
                r_mem_access <= read_inst | write_inst;
                r_mem_addr <= access_addr;
                // 清除上一指令残留的请求事务状态
                r_req_busy <= 0;
                r_req_second <= 0;
            end

            if (!ls_enable) begin
                /* 透传结果数据 */
                r_stage_out_valid <= stage_in_done ? 1 : 0;
            end else if (fence_enable) begin
                r_stage_out_valid <= stage_in_done ? 1 : 0;
                r_result <= 0;
                r_result_update_gpr <= 0;
            `ifndef IN_YOSYS_STA
            `ifndef FORMAL_VERIFY
            end else if (test_mode_enable) begin
                r_stage_out_valid <= stage_in_done ? 1 : 0;
                r_result <= func_test_intf({31'h0,write_inst}, access_addr, 4, src2);
                r_result <= 0;
                r_result_update_gpr <= 0;
            `endif
            `endif
            end else if (access_enable) begin
                /* 处理读写逻辑 */
                if (!r_req_busy) begin
                    if (req_valid && req_ready) begin
                        r_req_busy <= 1;
                        if (!r_req_second) begin
                            if (r_write_enable) begin
                                check_dev_addr(write_addr, `DEV_ATTR_WRITE);
                            end
                            if (r_read_enable) begin
                                check_dev_addr(read_addr, `DEV_ATTR_READ);
                            end
                        end
                        if (r_write_enable && (!write_span || r_req_second)) begin
                            func_dev_skip(1, write_addr, {25'h0, write_size, s_write_strb[3:0]|s_write_strb[7:4]}, write_data);
                        end
                    end
                end else begin
                    if (resp_valid && resp_ready) begin
                        r_req_busy <= 0;
                        if (r_write_enable) begin
                            if (!write_span || r_req_second) begin
                                // notify prev module
                                r_write_enable <= 0;
                                r_result <= 0;
                                r_result_update_gpr <= 0;
                                r_stage_out_valid <= 1;
                                r_req_second <= 0;
                            end else begin
                                r_req_second <= 1;
                            end
                        end else if (r_read_enable) begin
                            if (!read_span || r_req_second) begin
                                // notify prev module
                                r_result <= read_extract;
                                r_result_update_gpr <= 1;
                                r_stage_out_valid <= 1;
                                r_read_enable <= 0;
                                r_req_second <= 0;
                                // 读数据返回时锁存dcache命中状态（读请求被接受后cache_stat已稳定）
                                r_cache_stat <= cache_stat;
                                func_dev_skip(0, read_addr, {21'h0, read_size, s_read_len}, read_extract);
                            end else begin
                                r_req_first_data <= resp_data;
                                r_req_second <= 1;
                            end
                        end
                    end
                end

                if (stage_out_done) begin
                    r_stage_out_valid <= 0;
                    /* 输出完成后清除dcache命中状态，避免下一条非访存指令
                       流出时采样到上一条load残留的HIT/MISS */
                    r_cache_stat <= `CACHE_STAT_NONE;
                end
            end else begin
                r_stage_out_valid <= 0;
            end

            /* 输出完成后清除访存标识及访存目标地址，避免下一条非访存指令
               流出时采样到上一条访存指令残留的数据 */
            if (stage_out_done) begin
                r_mem_access <= 0;
                r_mem_addr <= 0;
            end

        end
    end

endmodule
