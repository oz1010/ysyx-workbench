module stage_regs #(
    parameter DATA_STORAGE = 1, // 输入数据存储模式，stage_bits可以维持多个周期，但会存在延时；若是直连模式，stage_bits只能维持一个周期；
    parameter DATA_W = 1
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire                        valid,
    input   wire                        ready,
    input   wire [DATA_W-1:0]           bits,

    output  wire [DATA_W-1:0]           stage_bits
);

    wire stage_done = valid && ready;
    
    generate
        if (DATA_STORAGE) begin : storage_mode
            reg [DATA_W-1:0] r_bits;
            assign stage_bits = valid ? bits : r_bits;
            always @(posedge clk) begin
                if (rst) begin
                    r_bits <= 0;
                end else begin
                    if (stage_done) r_bits <= bits;
                end
            end
        end else begin
            assign stage_bits = bits;
        end
    endgenerate
    
endmodule