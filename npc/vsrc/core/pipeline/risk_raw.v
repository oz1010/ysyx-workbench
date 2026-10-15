/**
* IDU的指令将要读出的寄存器(rs1 rs2)与后续阶段(EXU LSU WBU)中将要写入的寄存器相同，则发生RAW冒险
* 检测到RAW冒险，需要阻塞IDU和EXU之间的流水线
* 产生RAW冒险，需要等到WBU完成写入后解除
* TODO 当前的转发只实现了前一周期的检测
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
    input   wire [`INST_CODE_W-1:0]     id_imm_inst_code,
    
    /* 组合逻辑需要捕获阶段输入（例如EX的输入是con_id） */
    input   wire [INST_WIDTH*`STAGE_COUNT-1:0] stage_in_pc,
    input   wire [5*`STAGE_COUNT-1:0]    stage_in_rd,
    input   wire [DATA_WIDTH*`STAGE_COUNT-1:0] stage_in_result,
    input   wire [INST_WIDTH-1:0]       if_last_pc,
    input   wire [INST_WIDTH-1:0]       wb_pc,

    output  wire                        raw_wait,
    output  wire                        forward_result1_en,
    output  wire                        forward_result2_en,
    output  wire [DATA_WIDTH-1:0]       forward_result
);
    localparam CHECK_INDEX_W = log2up(`STAGE_COUNT);

    assign raw_wait = r_raw_wait;
    assign forward_result1_en = r_forward_result1_en;
    assign forward_result2_en = r_forward_result2_en;
    assign forward_result = r_forward_result;
    
    wire id_in_done = stage_valid[`STAGE_INDEX_IFU] & stage_ready[`STAGE_INDEX_IDU];
    wire is_raw = (|stage_is_raw1)|(|stage_is_raw2); // 是否存在RAW冒险
    wire is_raw_end = !(|r_stage_wait_pc);
    wire is_raw_begin = (!r_raw_wait & id_in_done & is_raw); // RAW冒险开始等待标识
    // 是否可以转发数据
    wire is_forward = 
        (stage_is_forward1[`STAGE_INDEX_LSU] | stage_is_forward2[`STAGE_INDEX_LSU]);
    reg  r_raw_wait;
    reg  r_forward_result1_en;
    reg  r_forward_result2_en;
    reg [DATA_WIDTH-1:0]       r_forward_result;
    wire load_inst = 
        id_imm_inst_code==`INST_LB ||
        id_imm_inst_code==`INST_LH ||
        id_imm_inst_code==`INST_LW ||
        id_imm_inst_code==`INST_LBU ||
        id_imm_inst_code==`INST_LHU ||
        0;

    wire [`STAGE_COUNT-1:0] stage_is_raw1;
    wire [`STAGE_COUNT-1:0] stage_is_raw2;
    wire [`STAGE_COUNT-1:0] stage_is_raw_release;
    wire [`STAGE_COUNT-1:0] stage_is_match_pc; // 阶段正在处理的指令是否一致，不存在连续3条相同pc的指令
    reg [INST_WIDTH*`STAGE_COUNT-1:0]    r_stage_wait_pc;
    wire [`STAGE_COUNT-1:0] stage_is_forward1;
    wire [`STAGE_COUNT-1:0] stage_is_forward2;

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
                 * 这里只处理了上一周期的数据，理论上应该与上三个周期比对
                 */
                assign stage_is_match_pc[idx] = stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] == if_last_pc;
                // assign stage_is_match_pc[idx] = idx==`STAGE_INDEX_IDU ? stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] == id_imm_pc : stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] == stage_in_pc[INST_WIDTH*(idx-1) +: INST_WIDTH];
                // assign stage_is_match_pc[idx] = 1;
                /**
                 * stage_is_raw标识某个阶段是否发生RAW冒险
                 * 排除x0，EXU/LSU/WBU将要写入的rd与rsx相同，则存在RAW冒险
                 * 1或2用于转发时区分需要分发结果目的地rs1或rs2，可以同时存在
                 */
                assign stage_is_raw1[idx] = id_in_done & (
                    ((|id_imm_rs1) & ((id_imm_rs1==stage_in_rd[5*idx +: 5]))) |
                    0
                );
                assign stage_is_raw2[idx] = id_in_done & (
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
                            (!is_forward & is_raw_begin) ? stage_in_pc[INST_WIDTH*idx +: INST_WIDTH] :
                            (r_raw_wait & stage_is_raw_release[idx]) ? 0 :
                            r_stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH];
                    end
                end

                // 检测到RAW后，判断是可以转发
                assign stage_is_forward1[idx] = stage_is_raw1[idx] & stage_is_match_pc[idx];
                assign stage_is_forward2[idx] = stage_is_raw2[idx] & stage_is_match_pc[idx];
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst | flush_en) begin
            r_raw_wait <= 0;
        end else begin
            r_raw_wait <= 
                (!is_forward & is_raw_begin) ? 1 :
                (r_raw_wait & is_raw_end) ? 0 :
                r_raw_wait;            
        end
    end

    /**
     * 转发需要通过时序逻辑实现，组合逻辑会出现循环依赖的问题
     */
    always @(posedge clk) begin
        if (rst | flush_en) begin
            r_forward_result1_en <= 0;
            r_forward_result2_en <= 0;
        end else begin
            r_forward_result1_en <= 
                (is_forward & stage_is_forward1[`STAGE_INDEX_LSU]) ? 1 :
                (r_forward_result1_en & stage_valid[`STAGE_INDEX_IDU] & stage_ready[`STAGE_INDEX_EXU]) ? 0 :
                r_forward_result1_en;
            
            r_forward_result2_en <= 
                (is_forward & stage_is_forward2[`STAGE_INDEX_LSU]) ? 1 :
                (r_forward_result2_en & stage_valid[`STAGE_INDEX_IDU] & stage_ready[`STAGE_INDEX_EXU]) ? 0 :
                r_forward_result2_en;

            r_forward_result <= 
                (stage_is_forward1[`STAGE_INDEX_LSU] | stage_is_forward2[`STAGE_INDEX_LSU]) ? 
                stage_in_result[DATA_WIDTH*`STAGE_INDEX_LSU +: DATA_WIDTH] : 
                r_forward_result;
        end
    end
endmodule
