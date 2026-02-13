module risk_control #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input   wire                        clk,
    input   wire                        rst,

    input   wire [`STAGE_COUNT-1:0]     stage_valid,
    input   wire [`STAGE_COUNT-1:0]     stage_exception,
    input   wire [INST_WIDTH-1:0]       fetch_pc,
    input   wire [INST_WIDTH-1:0]       id_pc,
    input   wire [INST_WIDTH-1:0]       ex_dnpc,
    input   wire [`INST_CODE_W-1:0]     inst_code,
    input   wire                        core_idle,

    output  reg  [`FLUSH_TYPE_W-1:0]    flush_type,
    output  reg  [`STAGE_COUNT-1:0]     stage_flush
);

    localparam FETCH_ITEM_COUNT = 4; /* 必须是2的指数，便于自动溢出回环 */
    localparam FETCH_INDEX_W = log2up(FETCH_ITEM_COUNT);

    /**
    * 处理器检测到异常
    * IDU检测跳转指令
    *   - IDU有效时，存储id_pc--fetch_pc
    *   - EXU有效时，找到有效的ex_pc--fetch_pc，并检测fetch_pc是否与ex_dnpc一致；
    *     若不一致则flush流水线；删除匹配的项；
    */
    reg [INST_WIDTH*2-1:0] fetch_infos[0:FETCH_ITEM_COUNT-1];
    reg [FETCH_INDEX_W-1:0] fetch_windex;
    reg [FETCH_INDEX_W-1:0] fetch_rindex;
    wire [INST_WIDTH-1:0] fetch_rpc;
    wire [INST_WIDTH-1:0] fetch_rdnpc;
    assign {
        fetch_rdnpc,
        fetch_rpc
    } = fetch_infos[fetch_rindex];
    always @(posedge clk) begin
        if (rst | (|stage_flush)) begin
            for (int i=0; i<FETCH_ITEM_COUNT; ++i) begin
                fetch_infos[i] <= 0;
                fetch_windex <= 0;
                fetch_rindex <= 0;
            end
        end else begin
            if (stage_valid[`STAGE_INDEX_IDU] & (|(inst_code&`INST_CODE_JUMP))) begin
                fetch_infos[fetch_windex] <= {fetch_pc, id_pc};
                fetch_windex <= fetch_windex + 1;
            end

            if (stage_valid[`STAGE_INDEX_EXU] & |fetch_infos[fetch_rindex]) begin
                fetch_infos[fetch_rindex] <= 0;
                fetch_rindex <= fetch_rindex + 1;
            end
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            stage_flush <= 0;
            flush_type <= 0;
        end else begin
            /* TODO 当跳转执行到EXU时，最早发现异常正好是LSU，优先处理异常即可。
            */
            if (!(|stage_flush)) begin
                if (|stage_exception) begin
                end else if (
                    stage_valid[`STAGE_INDEX_EXU] & 
                    |{fetch_rdnpc, fetch_rpc} & 
                    fetch_rdnpc!=ex_dnpc
                ) begin
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