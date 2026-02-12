module risk_control #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input   wire                        clk,
    input   wire                        rst,

    input   wire [`STAGE_COUNT-1:0]     stage_valid,
    input   wire [`STAGE_COUNT-1:0]     stage_exception,
    input   wire [INST_WIDTH-1:0]       fetch_pc,
    input   wire [INST_WIDTH-1:0]       dnpc,
    input   wire [`INST_CODE_W-1:0]     inst_code,
    input   wire                        core_idle,

    output  reg  [`FLUSH_TYPE_W-1:0]    flush_type,
    output  reg  [`STAGE_COUNT-1:0]     stage_flush
);

    // IDU检测到跳转指令或处理器检测到异常，与IFU推测的地址进行比较，若不匹配则发生控制冒险。
    always @(posedge clk) begin
        if (rst) begin
            stage_flush <= 0;
            flush_type <= 0;
        end else begin
            /* TODO 当跳转执行到EXU时，最早发现异常正好是LSU，优先处理异常即可。
            */
            if (!(|stage_flush)) begin
                if (|stage_exception) begin
                end else if (fetch_pc!=dnpc & stage_valid[`STAGE_INDEX_EXU]) begin
                   stage_flush[`STAGE_INDEX_IFU] <= 1;
                   stage_flush[`STAGE_INDEX_IDU] <= 1;
                   stage_flush[`STAGE_INDEX_LSU] <= 1;
                   flush_type[`FLUSH_JUMP_BIT] <= 1;
                end
            end else begin
                if (core_idle) begin
                    if (flush_type[`FLUSH_EX_BIT]) begin
                    end else if (flush_type[`FLUSH_JUMP_BIT]) begin
                        stage_flush <= 0;
                        flush_type <= 0;
                    end
                end
            end
        end
    end

endmodule