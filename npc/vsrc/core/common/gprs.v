// integer general-purpose registers
module gprs #(
    parameter DATA_WIDTH = 32,
    parameter REG_COUNT = `RISCV_GPR_COUNT
) (
    input   wire                        clock,
    input   wire                        reset,

    /* 读寄存器接口 */
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rs1,
    output  wire [DATA_WIDTH-1:0]           src1,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    rs2,
    output  wire [DATA_WIDTH-1:0]           src2,
    output  wire [DATA_WIDTH-1:0]           a0,
    output  wire [DATA_WIDTH-1:0]           a1,
    output  wire [DATA_WIDTH-1:0]           a2,
    
    /* 写寄存器接口 */
    input   wire                            wen,
    input   wire [`RISCV_GPR_ADDR_W-1:0]    waddr,
    input   wire [DATA_WIDTH-1:0]           wdata
);

/* 寄存器组 */
reg [DATA_WIDTH-1:0] x[0:REG_COUNT-1];
// 寄存器别名，register alias, ch2.3
wire [DATA_WIDTH-1:0] zero = x[0];
wire [DATA_WIDTH-1:0] ra = x[1];
wire [DATA_WIDTH-1:0] sp = x[2];
wire [DATA_WIDTH-1:0] gp = x[3];
wire [DATA_WIDTH-1:0] tp = x[4];
wire [DATA_WIDTH-1:0] t0 = x[5];
wire [DATA_WIDTH-1:0] t1 = x[6];
wire [DATA_WIDTH-1:0] t2 = x[7];
wire [DATA_WIDTH-1:0] s0 = x[8];
wire [DATA_WIDTH-1:0] fp = x[8];
wire [DATA_WIDTH-1:0] s1 = x[9];
wire [DATA_WIDTH-1:0] a[0:7];
// wire [DATA_WIDTH-1:0] a[0:7];
// wire [DATA_WIDTH-1:0] s2 = x[18];
// wire [DATA_WIDTH-1:0] s3 = x[19];
// wire [DATA_WIDTH-1:0] s4 = x[20];
// wire [DATA_WIDTH-1:0] s5 = x[21];
// wire [DATA_WIDTH-1:0] s6 = x[22];
// wire [DATA_WIDTH-1:0] s7 = x[23];
// wire [DATA_WIDTH-1:0] s8 = x[24];
// wire [DATA_WIDTH-1:0] s9 = x[25];
// wire [DATA_WIDTH-1:0] s10 = x[26];
// wire [DATA_WIDTH-1:0] s11 = x[27];
// wire [DATA_WIDTH-1:0] t3 = x[28];
// wire [DATA_WIDTH-1:0] t4 = x[29];
// wire [DATA_WIDTH-1:0] t5 = x[30];
// wire [DATA_WIDTH-1:0] t6 = x[31];
generate
    // // a0-7 = xs10-17
    // for (genvar i = 0; i<8; ++i) begin
    //     assign a[i] = x[i+10];
    // end
    // a0-5 = xs10-15
    for (genvar i = 0; i<6; ++i) begin : argument_registers
        assign a[i] = x[i+10];
    end
endgenerate

// `ifndef IN_YOSYS_STA
//     generate
//         // if (`RISCV_GPR_COUNT==32) begin : gpr_32
//         //     assign a[7:0] = x[17:10];
//         // end else begin : gpr_16
//         //     assign a[4:0] = x[14:10];
//         // end
//         integer a_reg_count = (`RISCV_GPR_COUNT==32) ? 8 : 5;
//         // a0-4 = x10-14
//         for (genvar i = 0; i<a_reg_count; ++i) begin
//             assign a[i] = x[i+10];
//         end
//     endgenerate
// `endif

/* 访问读取 */
assign src1 = x[rs1];
assign src2 = x[rs2];
assign a0 = a[0];
assign a1 = a[1];
assign a2 = a[2];

/* 
 * 减低延时（提高频率）优化策略：
 *   - 使用onehot编码，避免使用多位比较器
 *   - generate循环可以用MUX代替解码器
 * x0 始终为零
 */
wire [`RISCV_GPR_COUNT-1:0] wen_onehot;
assign wen_onehot = wen ? (1 << waddr) : 0;
always @(posedge clock) begin
    x[0] <= 0;
end
genvar i;
for (i=1 ; i<`RISCV_GPR_COUNT; ++i) begin
    always @(posedge clock) begin
        x[i] <= wen_onehot[i] ? wdata : x[i];
    end
end

endmodule
