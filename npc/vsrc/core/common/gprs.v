// integer general-purpose registers
module gprs #(
    parameter INST_WIDTH = 32,
    parameter REG_COUNT = `RISCV_GPR_COUNT
) (
    input   wire                        clk,
    input   wire                        rst,

    /* 读寄存器接口 */
    input   wire [REG_INDEX_W-1:0]      rs1,
    output  wire [INST_WIDTH-1:0]       src1,
    input   wire [REG_INDEX_W-1:0]      rs2,
    output  wire [INST_WIDTH-1:0]       src2,
    output  wire [INST_WIDTH-1:0]       a0,
    
    /* 写寄存器接口 */
    input   wire                        wen,
    input   wire [REG_INDEX_W-1:0]      windex,
    input   wire [INST_WIDTH-1:0]       wdata
);

localparam REG_INDEX_W = log2(REG_COUNT);

/* 寄存器组 */
// 通用寄存器
reg [INST_WIDTH-1:0] x[0:REG_COUNT-1];
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] t0 = x[5];
wire [INST_WIDTH-1:0] t1 = x[6];
wire [INST_WIDTH-1:0] t2 = x[7];
wire [INST_WIDTH-1:0] s0 = x[8];
wire [INST_WIDTH-1:0] fp = x[8];
wire [INST_WIDTH-1:0] s1 = x[9];
wire [INST_WIDTH-1:0] a[0:7];
wire [INST_WIDTH-1:0] s2 = x[18];
wire [INST_WIDTH-1:0] s3 = x[19];
wire [INST_WIDTH-1:0] s4 = x[20];
wire [INST_WIDTH-1:0] s5 = x[21];
wire [INST_WIDTH-1:0] s6 = x[22];
wire [INST_WIDTH-1:0] s7 = x[23];
wire [INST_WIDTH-1:0] s8 = x[24];
wire [INST_WIDTH-1:0] s9 = x[25];
wire [INST_WIDTH-1:0] s10 = x[26];
wire [INST_WIDTH-1:0] s11 = x[27];
wire [INST_WIDTH-1:0] t3 = x[28];
wire [INST_WIDTH-1:0] t4 = x[29];
wire [INST_WIDTH-1:0] t5 = x[30];
wire [INST_WIDTH-1:0] t6 = x[31];
generate
    // a0-7 = xs10-17
    for (genvar i = 0; i<8; ++i) begin
        assign a[i] = x[i+10];
    end
endgenerate

/* 访问读取 */
assign src1 = x[rs1];
assign src2 = x[rs2];
assign a0 = a[0];

/* 
 * 减低延时（提高频率）优化策略：
 *   - 使用onehot编码，避免使用多位比较器
 *   - generate循环可以用MUX代替解码器
 * x0 始终为零
 */
wire [`RISCV_GPR_COUNT-1:0] wen_onehot;
assign wen_onehot = wen ? (1 << windex) : 0;
// always @(posedge clk) x[0] <= 0;
assign x[0] = 0;
genvar i;
for (i=1 ; i<`RISCV_GPR_COUNT; ++i) begin
    always @(posedge clk) begin
        x[i] <= wen_onehot[i] ? wdata : x[i];
    end
end

endmodule
