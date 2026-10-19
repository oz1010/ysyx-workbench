module write_back #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter IN_DATA_W,
    parameter OUT_DATA_W
) (
    input   wire                        clk,
    input   wire                        rst,

    // gpr写入
    output  wire                        gpr_wen,
    output  wire [4:0]                  gpr_windex,
    output  wire [INST_WIDTH-1:0]       gpr_wdata,
    // 普通csr写入
    output  reg                         csr_wen,
    output  reg  [`CSR_ADDR_W-1:0]      csr_waddr,
    output  reg  [DATA_WIDTH-1:0]       csr_wdata,
    // 异常csr写入
    output  reg                         expt_en,
    output  reg  [INST_WIDTH-1:0]       expt_epc,
    output  reg  [DATA_WIDTH-1:0]       expt_cause,
    output  reg  [DATA_WIDTH-1:0]       expt_tval,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [IN_DATA_W-1:0]        in_bits,

    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [OUT_DATA_W-1:0]       out_bits
);
`ifdef FORMAL_VERIFY
    /* 形式化验证：将指令本身、写回结果及load原始数据透传到WBU输出 */
    assign {
        pc, dnpc, inst, rd, rs1, rs2, inst_code, result, result_update_gpr, csr_wch,
        expt, expt_cause, expt_tval, fv_ld_data
    } = in_bits;
    assign out_bits = {
        pc, dnpc, rd, inst, result, result_update_gpr, fv_ld_data
    };
`else
    assign {
        pc, dnpc, rd, rs1, rs2, inst_code, result, result_update_gpr, csr_wch,
        in_expt, in_expt_cause, in_expt_tval
    } = in_bits;
    assign out_bits = {
        pc, dnpc, rd, result, result_update_gpr
    };
`endif

    wire [INST_WIDTH-1:0]           pc;
    wire [INST_WIDTH-1:0]           dnpc;
    wire [4:0]                      rd;
    wire [4:0]                      rs1;
    wire [4:0]                      rs2;
    wire [`INST_CODE_W-1:0]         inst_code;
    wire [INST_WIDTH-1:0]           result;
    wire                            result_update_gpr;
    wire [`CSR_WCH_W-1:0]           csr_wch;
    wire [`STAGE_COUNT-1:0]         in_expt;
    wire [DATA_WIDTH-1:0]           in_expt_cause;
    wire [DATA_WIDTH-1:0]           in_expt_tval;
`ifdef FORMAL_VERIFY
    wire [INST_WIDTH-1:0]           inst;
    wire [DATA_WIDTH-1:0]           fv_ld_data;
`endif

    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    inner_con wb_con(
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

    /**
    * 异常写入逻辑
    */
    assign expt_en = |in_expt && stage_in_done;
    assign expt_epc = pc;
    assign expt_cause = in_expt_cause;
    assign expt_tval = in_expt_tval;

    /*
    * gpr写入，组合逻辑，同步触发寄存器组更新
    * 更新寄存器需要与wb同步进行
    * 避免wb_valid后，寄存器任然未更新成功
    */
    assign gpr_wen = stage_in_done&result_update_gpr;
    assign gpr_windex = rd;
    assign gpr_wdata = result;

    /*
    * 普通csr写入逻辑，只使用通道0的数据，其他通道应该没有值
    */
    wire                            in_csr_wen[0:`CSR_WCH_ITEM_COUNT-1];
    wire  [`CSR_ADDR_W-1:0]         in_csr_waddr[0:`CSR_WCH_ITEM_COUNT-1];
    wire  [31:0]                    in_csr_wdata[0:`CSR_WCH_ITEM_COUNT-1];
    assign {
        in_csr_wen[2], in_csr_wen[1], in_csr_wen[0],
        in_csr_waddr[2], in_csr_waddr[1], in_csr_waddr[0],
        in_csr_wdata[2], in_csr_wdata[1], in_csr_wdata[0]
    } = csr_wch;
    assign csr_wen = stage_in_done && in_csr_wen[0];
    assign csr_waddr = in_csr_waddr[0];
    assign csr_wdata = in_csr_wdata[0];

    always @(posedge clk) begin
        if (rst) begin
            r_stage_out_valid <= 0;
        end else begin
            r_stage_out_valid <= stage_in_done ? 1 : 0;
        end
    end

endmodule
