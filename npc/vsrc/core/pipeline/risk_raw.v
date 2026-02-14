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
    input   wire [4:0]                  id_imm_rd,
    input   wire [4:0]                  id_imm_rs1,
    input   wire [4:0]                  id_imm_rs2,
    input   wire [`INST_CODE_W-1:0]     id_imm_inst_code,
    input   wire [4:0]                  ex_rd,
    input   wire [4:0]                  ls_rd,
    input   wire [INST_WIDTH*CHECK_COUNT-1:0] stage_pc,
    input   wire [5*CHECK_COUNT-1:0]    stage_rd,
    input   wire [INST_WIDTH-1:0]       wb_pc,
    input   wire [4:0]                  wb_rd,

    output  reg                         raw_wait
);
    localparam CHECK_COUNT = 3;
    localparam CHECK_INDEX_W = log2up(CHECK_COUNT);
    
    wire is_raw = |stage_is_raw;
    wire is_raw_release = !(|stage_wait_pc);
    wire match_raw = (!raw_wait & stage_valid[`STAGE_INDEX_IFU] & stage_ready[`STAGE_INDEX_IDU] & is_raw);

    wire [CHECK_COUNT-1:0] stage_is_raw;
    reg [INST_WIDTH*CHECK_COUNT-1:0] stage_wait_pc;
    wire [CHECK_COUNT-1:0] stage_is_raw_release;

    generate
        genvar idx;
        for (idx=0; idx<CHECK_COUNT; ++idx) begin : wait_block
            assign stage_is_raw_release[idx] = stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH]==wb_pc;
            assign stage_is_raw[idx] =
                (
                    ((|id_imm_rs1) & ((id_imm_rs1==stage_rd[5*idx +: 5]))) | 
                    ((|id_imm_rs2) & ((id_imm_rs2==stage_rd[5*idx +: 5]))) |
                    0
                );
            always @(posedge clk) begin
                if (rst | flush_en) begin
                    stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH] <= 0;
                end else begin
                    stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH] <= 
                        match_raw ? stage_pc[INST_WIDTH*idx +: INST_WIDTH] :
                        (raw_wait & stage_is_raw_release[idx]) ? 0 :
                        stage_wait_pc[INST_WIDTH*idx +: INST_WIDTH];
                end
            end
        end
    endgenerate

    always @(posedge clk) begin
        if (rst | flush_en) begin
            raw_wait <= 0;
        end else begin
            raw_wait <= 
                match_raw ? 1:
                (raw_wait & is_raw_release) ? 0 :
                raw_wait;            
        end
    end

endmodule
