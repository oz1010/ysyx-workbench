module load_store #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
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
    input   wire [INST_WIDTH-1:0]       in_pc,
    input   wire [INST_WIDTH-1:0]       in_inst,
    input   wire [4:0]                  in_rd,
    input   wire [INST_WIDTH-1:0]       in_imm,
    input   wire [`INST_CODE_W-1:0]     in_inst_code,
    input   wire [INST_WIDTH-1:0]       in_src1,
    input   wire [INST_WIDTH-1:0]       in_src2,
    input   wire [INST_WIDTH-1:0]       in_result,
    input   wire                        in_result_update_gpr,

    /* 模块输入数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [INST_WIDTH-1:0]       out_pc,
    output  wire [4:0]                  out_rd,
    output  wire [INST_WIDTH-1:0]       out_result,
    output  wire                        out_result_update_gpr
);

    localparam STAGE_IN_DATA_W =
        5 + 
        `INST_CODE_W + 
        INST_WIDTH*6 + 
        1;

    wire [STAGE_IN_DATA_W-1:0]      stage_in_bits;
    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    wire [`INNER_CON_STATE_W-1:0]   stage_state;

    inner_con #(
        .IN_DATA_STORAGE(1),
        .IN_DATA_W(STAGE_IN_DATA_W)
    ) ls_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_bits({in_pc, in_inst, in_rd, in_imm, in_inst_code, in_src1, in_src2, 
            in_result, in_result_update_gpr}),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_bits(stage_in_bits),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done),
        .stage_state(stage_state)
    );

    assign {
        pc, inst, rd, imm, inst_code, src1, src2,
        result, result_update_gpr
    } = stage_in_bits;
    assign {
        out_pc,
        out_rd,
        out_result,
        out_result_update_gpr
    } = {
        pc,
        rd,
        ls_enable ? r_result : result,
        ls_enable ? r_result_update_gpr : result_update_gpr
    };

    /* TODO 后面需要在解码时直接赋值 */
    wire ls_enable = 
        (inst_code == `INST_LB) ||
        (inst_code == `INST_LH) ||
        (inst_code == `INST_LW) ||
        (inst_code == `INST_LBU) ||
        (inst_code == `INST_LHU) ||
        (inst_code == `INST_SB) ||
        (inst_code == `INST_SH) ||
        (inst_code == `INST_SW) ||
        (inst_code == `INST_FENCE) || 
        (inst_code == `INST_FENCE_I)
        ;

    wire [INST_WIDTH-1:0]       pc;
    wire [INST_WIDTH-1:0]       inst;
    wire [4:0]                  rd;
    wire [INST_WIDTH-1:0]       imm;
    wire [`INST_CODE_W-1:0]     inst_code;
    wire [INST_WIDTH-1:0]       src1;
    wire [INST_WIDTH-1:0]       src2;
    wire [INST_WIDTH-1:0]       result;
    wire                        result_update_gpr;

    reg r_in_ready, r_out_valid;
    // assign in_ready = r_in_ready;
    // assign out_valid = r_out_valid;

    reg [INST_WIDTH-1:0] r_result;
    reg r_result_update_gpr;

    wire in_wait_in_ready = (in_valid && !in_ready);
    wire in_test_mode = in_wait_in_ready && ((src1+imm)>=32'h0f00_2000 && (src1+imm)<=32'h0fff_ffff);

    wire [2:0] inst_opn_size = 
        inst_code == `INST_SB ? 0
        : inst_code == `INST_LB ? 0
        : inst_code == `INST_LBU ? 0
        : inst_code == `INST_SH ? 1
        : inst_code == `INST_LH ? 1
        : inst_code == `INST_LHU ? 1
        : 2;

    wire write_enable = in_wait_in_ready && (inst_code==`INST_SB || inst_code==`INST_SH || inst_code==`INST_SW);
    wire [ADDR_WIDTH-1:0] write_addr = src1+imm;
    wire [DATA_WIDTH-1:0] write_data = src2;
    wire [2:0] write_size = inst_opn_size;
    wire [1:0] write_state;

    wire read_enable = in_wait_in_ready && (inst_code==`INST_LB || inst_code==`INST_LH || inst_code==`INST_LW || inst_code==`INST_LBU || inst_code==`INST_LHU);
    wire read_sign = (inst_code==`INST_LB || inst_code==`INST_LH || inst_code==`INST_LW);
    wire [ADDR_WIDTH-1:0] read_addr = src1+imm;
    wire [DATA_WIDTH-1:0] read_data;
    wire [2:0] read_size = inst_opn_size;
    wire [1:0] read_state;

    wire fence_enable = in_wait_in_ready && (inst_code==`INST_FENCE || inst_code==`INST_FENCE_I);

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
        .write_enable(write_enable),
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
        .enable(read_enable),
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

            r_in_ready <= 0;
            r_out_valid <= 0;
            r_stage_out_valid <= 0;
        end else begin
            r_result <= r_result;
            r_result_update_gpr <= r_result_update_gpr;

            r_stage_out_valid <= stage_in_done ? 1 : 0;

            if (in_wait_in_ready) begin
                if (in_test_mode || fence_enable) begin
                    // 用于调试的地址段，向这里写数据会触发内置的调试函数
                    // notify next
                    if (in_test_mode) begin r_result <= func_test_intf({31'h0,(inst_code==`INST_SB || inst_code==`INST_SH || inst_code==`INST_SW)}, src1+imm, 4, src2); end
                    else begin r_result <= 0; end
                    r_result_update_gpr <= 0;
                    r_in_ready <= 1;
                end else if (write_enable) begin
                    if (write_state==`AXI4_STATE_RESPONSE && bvalid && bready) begin
                        r_result <= 0;
                        r_result_update_gpr <= 0;
                        r_in_ready <= 1;
                    end

                    if (awvalid && awready) func_cpu_stat_ctrl(`HW_CPU_STAT_DATA, awaddr);

                end else if (read_enable) begin
                    case (read_state)
                        `AXI4_STATE_DATA: begin
                            if (rvalid) begin
                                r_result <= read_data;
                            end

                            if (rlast) begin
                                // notify prev module
                                r_result_update_gpr <= 1;
                                r_in_ready <= 1;
                            end
                        end
                    endcase

                    if (arvalid && arready) func_cpu_stat_ctrl(`HW_CPU_STAT_DATA, araddr);
                end else begin
                    `ifndef IN_YOSYS_STA
                    $error("Found unsopport inst_code(%x) in LSU", inst_code);
                    `endif
                end

            end
            if (in_valid && in_ready) begin
                r_in_ready <= 0;
            end
            
            if (in_valid && in_ready) begin
                r_out_valid <= 1;
            end
            if (out_valid && out_ready) begin
                r_out_valid <= 0;
            end

        end
    end

endmodule
