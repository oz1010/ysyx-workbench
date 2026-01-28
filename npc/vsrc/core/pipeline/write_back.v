module write_back #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input   wire                        clk,
    input   wire                        rst,

    output  wire                        gpr_wen,
    output  wire [4:0]                  gpr_windex,
    output  wire [INST_WIDTH-1:0]       gpr_wdata,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [INST_WIDTH-1:0]       in_pc,
    input   wire [4:0]                  in_rd,
    input   wire [INST_WIDTH-1:0]       in_result,
    input   wire                        in_result_update_gpr,

    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid
);

    localparam STAGE_IN_DATA_W = 
        INST_WIDTH + 
        5 + 
        INST_WIDTH + 
        1;

    wire [STAGE_IN_DATA_W-1:0]      stage_in_bits;
    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    wire [`INNER_CON_STATE_W-1:0]   stage_state;

    inner_con #(
        .IN_DATA_STORAGE(1),
        .IN_DATA_W(STAGE_IN_DATA_W)
    ) wb_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .in_bits({in_pc, in_rd, in_result, in_result_update_gpr}),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_bits(stage_in_bits),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done),
        .stage_state(stage_state)
    );

    wire [INST_WIDTH-1:0]       core_pc;
    wire [4:0]                  rd;
    wire [INST_WIDTH-1:0]       result;
    wire                        result_update_gpr;

    assign {core_pc, rd, result, result_update_gpr} = stage_in_bits;
    // TODO 需要去除
    reg [INST_WIDTH-1:0] pc;
    always @(posedge clk) begin
        if (rst) begin
            pc <= func_get_reset_pc();
        end else begin
            pc <= (in_valid&&in_ready) ? core_pc : pc;
        end
    end

    reg                         r_gpr_wen;

    assign gpr_wen = r_gpr_wen;
    assign gpr_windex = rd;
    assign gpr_wdata = result;

    always @(posedge clk) begin
        if (rst) begin
            r_stage_out_valid <= 0;
            r_gpr_wen <= 0;
        end else begin
            r_stage_out_valid <= stage_in_done ? 1 : 0;
            r_gpr_wen <= (result_update_gpr&stage_in_done) ? 1 : 0;
        end
    end

endmodule
