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

    output  wire                        gpr_wen,
    output  wire [4:0]                  gpr_windex,
    output  wire [INST_WIDTH-1:0]       gpr_wdata,
    output  wire [`CSR_WCH_W-1:0]       out_csr_wch,

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
        expt, expt_cause, expt_tval
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
    wire [`STAGE_COUNT-1:0]         expt;
    wire [DATA_WIDTH-1:0]           expt_cause;
    wire [DATA_WIDTH-1:0]           expt_tval;
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
    * 0 -- mepc
    * 1 -- mcause
    * 2 -- mtval
    */
    wire [`CSR_WCH_W-1:0]           expt_csr_wch;
    wire                            expt_csr_wen[0:`CSR_WCH_ITEM_COUNT-1];
    wire  [`CSR_ADDR_W-1:0]         expt_csr_waddr[0:`CSR_WCH_ITEM_COUNT-1];
    wire  [31:0]                    expt_csr_wdata[0:`CSR_WCH_ITEM_COUNT-1];
    assign                          expt_csr_wch = {
        expt_csr_wen[2], expt_csr_wen[1], expt_csr_wen[0],
        expt_csr_waddr[2], expt_csr_waddr[1], expt_csr_waddr[0],
        expt_csr_wdata[2], expt_csr_wdata[1], expt_csr_wdata[0]
    };
    wire expt_valid = |expt && stage_in_done;

    /*
    * 组合逻辑，同步触发寄存器组更新
    * 更新寄存器需要与wb同步进行
    * 避免wb_valid后，寄存器任然未更新成功
    */
    assign gpr_wen = stage_in_done&result_update_gpr;
    assign gpr_windex = rd;
    assign gpr_wdata = result;

    /*
    * 组合逻辑，同步触发csr寄存器组更新
    * `EXPT_CAUSE_ILL
    */
    assign expt_csr_wen[0] = 1;
    assign expt_csr_waddr[0] = `CSR_MEPC;
    assign expt_csr_wdata[0] = pc;
    assign expt_csr_wen[1] = 1;
    assign expt_csr_waddr[1] = `CSR_MCAUSE;
    assign expt_csr_wdata[1] = expt_cause;
    assign expt_csr_wen[2] = 1;
    assign expt_csr_waddr[2] = `CSR_MTVAL;
    assign expt_csr_wdata[2] = expt_tval;
    assign out_csr_wch = expt_valid ? expt_csr_wch :
        stage_in_done ? csr_wch : 
        0;

    always @(posedge clk) begin
        if (rst) begin
            r_stage_out_valid <= 0;
        end else begin
            r_stage_out_valid <= stage_in_done ? 1 : 0;
        end
    end

endmodule
