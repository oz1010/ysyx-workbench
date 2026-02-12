// static branch predictor
module static_predictor #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        fetch_en,
    input   wire [`FLUSH_TYPE_W-1:0]    flush_type,
    input   wire [INST_WIDTH-1:0]       core_pc,
    input   wire [INST_WIDTH-1:0]       dnpc,

    output  reg [INST_WIDTH-1:0]        fetch_pc
);
    always @(posedge clk) begin
        if (rst) begin
            fetch_pc <= core_pc;
        end else begin
            fetch_pc <= 
                flush_type[`FLUSH_JUMP_BIT] ? dnpc :
                fetch_en ? fetch_pc + 4 : 
                fetch_pc;
        end
    end

endmodule