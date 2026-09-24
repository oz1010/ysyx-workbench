/**
* IDU的指令将要读出的寄存器(rs1 rs2)与后续阶段(EXU LSU WBU)中将要写入的寄存器相同，则发生RAW冒险
* 检测到RAW冒险，需要阻塞IDU和EXU之间的流水线
* 产生RAW冒险，需要等到WBU完成写入后解除
*/
module risk_raw #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
)(
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        flush_en,
    input   wire [`STAGE_COUNT-1:0]     stage_ready,
    input   wire [`STAGE_COUNT-1:0]     stage_valid,
    input   wire [INST_WIDTH-1:0]       id_imm_pc,
    input   wire [4:0]                  id_imm_rs1,
    input   wire [4:0]                  id_imm_rs2,
    
    /* 组合逻辑需要捕获阶段输入（例如EX的输入是con_id） */
    input   wire [INST_WIDTH*`STAGE_COUNT-1:0] stage_in_pc,
    input   wire [5*`STAGE_COUNT-1:0]    stage_in_rd,
    input   wire [INST_WIDTH-1:0]       wb_pc,

    output  wire                        raw_wait
);
    localparam CHECK_INDEX_W = log2up(`STAGE_COUNT);

    assign raw_wait = r_raw_wait;
    
    wire id_in_done = stage_valid[`STAGE_INDEX_IFU] & stage_ready[`STAGE_INDEX_IDU];
    wire is_raw = (|stage_is_raw1)|(|stage_is_raw2); // 是否存在RAW冒险
    wire is_raw_end = !(|r_stage_wait_pc);
    wire is_raw_begin = (!r_raw_wait & id_in_done & is_raw); // RAW冒险开始等待标识
    reg  r_raw_wait;

    wire [`STAGE_COUNT-1:0] stage_is_raw1;
    wire [`STAGE_COUNT-1:0] stage_is_raw2;
    wire [`STAGE_COUNT-1:0] stage_is_raw_release;
    wire [`STAGE_COUNT-1:0] stage_is_match_pc; // 阶段正在处理的指令是否一致，不存在连续3条相同pc的指令
    reg [INST_WIDTH*`STAGE_COUNT-1:0]    r_stage_wait_pc;

    generate
        genvar idx;
        for (idx=0; idx<`STAGE_COUNT; ++idx) begin : raw_block
            if (
                idx==`STAGE_INDEX_IFU ||
                idx==`STAGE_INDEX_WBU ||
                0
            ) begin
                always @(posedge clk) r_stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH] <= 0;
            end else begin
                /**
                 * 阻塞流水线时，标识某阶段是否可以释放阻塞（等待WBU完成后pc与wait_pc一致）
                 */
                assign stage_is_raw_release[idx] = r_stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH]==wb_pc;
                /**
                 * TODO 增加pc匹配，会造成diff错误，需要解决
                 */
                // assign stage_is_match_pc[idx] = stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] == id_imm_pc;
                // assign stage_is_match_pc[idx] = idx==0 ? stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] == id_imm_pc : stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] == stage_in_pc[INST_WIDTH*(idx-1) +: INST_WIDTH];
                assign stage_is_match_pc[idx] = 1;
                /**
                 * stage_is_raw标识某个阶段是否发生RAW冒险
                 * 排除x0，EXU/LSU/WBU将要写入的rd与rsx相同，则存在RAW冒险
                 * 1或2用于转发时区分需要分发结果目的地rs1或rs2，可以同时存在
                 */
                assign stage_is_raw1[idx] = id_in_done & stage_is_match_pc[idx] & (
                    ((|id_imm_rs1) & ((id_imm_rs1==stage_in_rd[5*idx +: 5]))) |
                    0
                );
                assign stage_is_raw2[idx] = id_in_done & stage_is_match_pc[idx] & (
                    ((|id_imm_rs2) & ((id_imm_rs2==stage_in_rd[5*idx +: 5]))) |
                    0
                );
                /**
                 * 重置和flush时，阶段wait_pc为0
                 * 发现RAW冒险，阶段wait_pc为对应的阶段pc值
                 * 等待RAW冒险结束，阶段wait_pc重置为0
                 * 其他场景保持不变
                 */
                always @(posedge clk) begin
                    if (rst | flush_en) begin
                        r_stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH] <= 0;
                    end else begin
                        r_stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH] <= 
                            is_raw_begin ? stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] :
                            (r_raw_wait & stage_is_raw_release[idx]) ? 0 :
                            r_stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH];
                    end
                end 
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst | flush_en) begin
            r_raw_wait <= 0;
        end else begin
            r_raw_wait <= 
                is_raw_begin ? 1:
                (r_raw_wait & is_raw_end) ? 0 :
                r_raw_wait;            
        end
    end

endmodule
