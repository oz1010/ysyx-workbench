// integer general-purpose registers
module gprs #(
    parameter INST_WIDTH = 32,
    parameter REG_COUNT = `RISCV_CSR_COUNT
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
wire [INST_WIDTH-1:0] a[0:7];

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
 * 只有当写使能且索引为非零生效
 * 确保 x0 始终为零
 */
always @(posedge clk) begin
    if (rst) begin
        x[0] <= 0;
    end else begin
        if (wen && (|windex)) x[windex] <= wdata;
    end
end

endmodule
