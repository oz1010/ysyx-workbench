// static branch predictor
module static_predictor #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        predict_en,
    input   wire                        fetch_en,
    input   wire [`FLUSH_TYPE_W-1:0]    flush_type,
    input   wire [INST_WIDTH-1:0]       core_pc,
    input   wire [INST_WIDTH-1:0]       dnpc,

    output  reg [INST_WIDTH-1:0]        predict_pc, // 记录预测的取指地址
    output  reg [INST_WIDTH-1:0]        fetch_pc // 记录本次取指地址
);
    always @(posedge clk) begin
        if (rst) begin
            predict_pc <= core_pc;
            fetch_pc <= predict_pc;
        end else begin
            predict_pc <=
                flush_type[`FLUSH_JUMP_BIT] ? dnpc :
                predict_en ? predict_pc + 4 :
                predict_pc;
            fetch_pc <= 
                (flush_type[`FLUSH_JUMP_BIT] | fetch_en) ? predict_pc :
                fetch_pc;
        end
    end

endmodule