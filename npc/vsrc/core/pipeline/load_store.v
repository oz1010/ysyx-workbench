module load_store #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2,
    parameter IN_DATA_W,
    parameter OUT_DATA_W
) (
    input   wire                        clk,
    input   wire                        rst,

    /* AXI4总线master */
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
    /* 访存标识及访存目标地址，out_valid期间有效（无访存时分别为0） */
    output  wire                        out_mem_access,
    output  wire [ADDR_WIDTH-1:0]       out_mem_addr
);
    assign {
        pc, dnpc, inst, rd, rs1, rs2, imm, inst_code, src1, src2,
        result, result_update_gpr, csr_wch,
        expt, expt_cause, expt_tval
    } = in_bits;
`ifdef FORMAL_VERIFY
    /* 形式化验证：透传inst与load使用的总线原始数据到WBU */
    assign out_bits = {
        pc,
        dnpc,
        inst,
        rd,
        rs1,
        rs2,
        inst_code,
        ls_enable ? r_result : result,
        ls_enable ? r_result_update_gpr : result_update_gpr,
        csr_wch,
        prev_err ? expt : r_expt,
        prev_err ? expt_cause : r_expt_cause,
        prev_err ? expt_tval : r_expt_tval,
        r_fv_ld_data
    };
`else
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
`endif

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

`ifdef FORMAL_VERIFY
    /* 形式化验证：记录load指令在总线上读到的原始数据 */
    reg  [DATA_WIDTH-1:0]           r_fv_ld_data;
    always @(posedge clk) begin
        if (rst) begin
            r_fv_ld_data <= 0;
        end else begin
            if (rvalid & rready & rlast) r_fv_ld_data <= rdata;
        end
    end
`endif

    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    inner_con ls_con(
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

    wire prev_err = |expt;
    wire ls_enable = (|(inst_code & `INST_CODE_MEM));
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
    wire [1:0] write_state;

    reg r_read_enable;
    wire read_inst = (inst_code==`INST_LB | inst_code==`INST_LH | inst_code==`INST_LW | inst_code==`INST_LBU | inst_code==`INST_LHU);
    wire read_sign = (inst_code==`INST_LB | inst_code==`INST_LH | inst_code==`INST_LW);
    wire [ADDR_WIDTH-1:0] read_addr = access_addr;
    wire [DATA_WIDTH-1:0] read_data;
    wire [2:0] read_size = access_size;
    wire [1:0] read_state;

    wire fence_enable = (inst_code==`INST_FENCE | inst_code==`INST_FENCE_I);
    wire test_mode_enable = access_addr>=32'h0f00_2000 & access_addr<=32'h0fff_ffff;

    axi_master_writer #(
    `ifndef IN_YOSYS_STA
        .NAME("LSU"),
    `endif
        .ID(`AXI4_ID_LSU),
        .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
        .INST_WIDTH(INST_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BRESP_WIDTH(BRESP_WIDTH),
        .RRESP_WIDTH(RRESP_WIDTH)
    ) m_axi_master_writer (
        .clk(clk),
        .rst(rst),
        .awready(awready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .awid(awid),
        .awlen(awlen),
        .awsize(awsize),
        .awburst(awburst),
        .wready(wready),
        .wvalid(wvalid),
        .wdata(wdata),
        .wstrb(wstrb),
        .wlast(wlast),
        .bready(bready),
        .bvalid(bvalid),
        .bresp(bresp),
        .bid(bid),
        .write_enable(r_write_enable),
        .write_addr(write_addr),
        .write_data(write_data),
        .write_size(write_size),
        .write_state(write_state)
    );

    axi_master_reader #(
    `ifndef IN_YOSYS_STA
        .NAME("LSU"),
    `endif
        .ID(`AXI4_ID_LSU),
        .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
        .INST_WIDTH(INST_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .DATA_WIDTH(DATA_WIDTH),
        .BRESP_WIDTH(BRESP_WIDTH),
        .RRESP_WIDTH(RRESP_WIDTH)
    ) m_axi_master_reader (
        .clk(clk),
        .rst(rst),
        .arready(arready),
        .arvalid(arvalid),
        .araddr(araddr),
        .arid(arid),
        .arlen(arlen),
        .arsize(arsize),
        .arburst(arburst),
        .rready(rready),
        .rvalid(rvalid),
        .rresp(rresp),
        .rdata(rdata),
        .rlast(rlast),
        .rid(rid),
        .enable(r_read_enable),
        .read_sign(read_sign),
        .read_addr(read_addr),
        .read_len(0),
        .read_data(read_data),
        .read_size(read_size),
        .read_state(read_state)
    );

    always @(posedge clk) begin
        if (rst) begin
            r_result <= 0;
            r_result_update_gpr <= 0;

            r_stage_out_valid <= 0;
            r_read_enable <= 0;
            r_write_enable <= 0;
            r_cache_stat <= `CACHE_STAT_NONE;
            r_mem_access <= 0;
            r_mem_addr <= 0;
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
                if (r_write_enable) begin
                    if (awvalid & awready) begin
                        func_cpu_stat_ctrl(`HW_CPU_STAT_DATA, awaddr);
                    end

                    if (bvalid & bready) begin
                        r_write_enable <= 0;
                        r_result <= 0;
                        r_result_update_gpr <= 0;
                        r_stage_out_valid <= 1;
                    end

                end else if (r_read_enable) begin
                    if (arvalid && arready) begin
                        func_cpu_stat_ctrl(`HW_CPU_STAT_DATA, araddr);
                    end

                    if (rvalid & rready) begin
                        r_result <= read_data;
                    end

                    if (rvalid & rready & rlast) begin
                        // notify prev module
                        r_result_update_gpr <= 1;
                        r_stage_out_valid <= 1;
                        r_read_enable <= 0;
                        // 读数据返回时锁存dcache命中状态（读请求被接受后cache_stat已稳定）
                        r_cache_stat <= cache_stat;
                    end
                end else begin
                    // `ifndef IN_YOSYS_STA
                    // $error("Found unsopport inst_code(%x) in LSU", inst_code);
                    // `endif
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
