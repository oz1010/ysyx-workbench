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

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [IN_DATA_W-1:0]        in_bits,

    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid
);
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

    wire [INST_WIDTH-1:0]       core_pc;
    wire [4:0]                  rd;
    wire [INST_WIDTH-1:0]       result;
    wire                        result_update_gpr;

    assign {core_pc, rd, result, result_update_gpr} = in_bits;

    /*
    * 组合逻辑，同步触发寄存器组更新
    * 更新寄存器需要与wb同步进行
    * 避免wb_valid后，寄存器任然未更新成功
    */
    assign gpr_wen = stage_in_done&result_update_gpr;
    assign gpr_windex = rd;
    assign gpr_wdata = result;

    always @(posedge clk) begin
        if (rst) begin
            r_stage_out_valid <= 0;
        end else begin
            r_stage_out_valid <= stage_in_done ? 1 : 0;
        end
    end

endmodule
