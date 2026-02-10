// 单周期处理器
module riscv32e_core #(
    parameter INST_WIDTH = 32
) (
    input  wire         clk,
    input  wire         rst,

    /* 外部中断 */
    input  wire         io_interrupt,
    /* AXI4 Master总线 */
    input  wire         io_master_awready,
    output wire         io_master_awvalid,
    output wire [31:0]  io_master_awaddr,
    output wire [3:0]   io_master_awid,
    output wire [7:0]   io_master_awlen,
    output wire [2:0]   io_master_awsize,
    output wire [1:0]   io_master_awburst,
    input  wire         io_master_wready,
    output wire         io_master_wvalid,
    output wire [31:0]  io_master_wdata,
    output wire [3:0]   io_master_wstrb,
    output wire         io_master_wlast,
    output wire         io_master_bready,
    input  wire         io_master_bvalid,
    input  wire [1:0]   io_master_bresp,
    input  wire [3:0]   io_master_bid,
    input  wire         io_master_arready,
    output wire         io_master_arvalid,
    output wire [31:0]  io_master_araddr,
    output wire [3:0]   io_master_arid,
    output wire [7:0]   io_master_arlen,
    output wire [2:0]   io_master_arsize,
    output wire [1:0]   io_master_arburst,
    output wire         io_master_rready,
    input  wire         io_master_rvalid,
    input  wire [1:0]   io_master_rresp,
    input  wire [31:0]  io_master_rdata,
    input  wire         io_master_rlast,
    input  wire [3:0]   io_master_rid,

    output wire [INST_WIDTH-1:0] pc,
    output wire         valid
);

/* 寄存器组 */
reg [INST_WIDTH-1:0] r_inst;
reg r_valid;

/* 常用处理器信号 */
wire [INST_WIDTH-1:0] x[`RISCV_GPR_COUNT-1:0];
// wire [INST_WIDTH-1:0] pc;

assign valid = r_valid;
// assign w_pc = pc;
// assign w_x = x;

// initial begin
//     r_valid = 0;
// end
// assign r_valid = !rst;

/** 
 * 当前正在处理的pc指示
 * 单周期处理器core_dnpc只需与core_pc一致即可
 */
reg [INST_WIDTH-1:0] core_pc;
reg [INST_WIDTH-1:0] core_dnpc;
wire [INST_WIDTH-1:0] dnpc;
assign pc = core_pc;
always @(posedge clk) begin
    if (rst) begin
        core_pc <= get_reset_pc();
        core_dnpc <= get_reset_pc();
        r_valid <= 0;
    end else begin
        core_pc <= dnpc;
        core_dnpc <= dnpc;
        r_valid <= 1;
    end
end

/* 取指 */
always @(*) begin
    if (rst) begin
        r_inst = 32'b0;
    end else begin
        r_inst = fetch_inst(core_pc);
    end
end

/* 译码 */
wire [6:0] opcode;
wire [4:0] rd;
wire [2:0] funct3;
wire [4:0] rs1;
wire [4:0] rs2;
wire [6:0] funct7;
wire [31:0] imm;
wire [2:0] inst_type;
wire [`INST_CODE_W-1:0] inst_code;
decoder risc32e_decoder(r_inst, opcode, rd, funct3, rs1, rs2, funct7, imm, inst_type, inst_code);

/* 执行并更新结果 */
wire [31:0] src1 = x[rs1];
wire [31:0] src2 = x[rs2];
wire signed [31:0] s_src1 = src1;
wire signed [31:0] s_src2 = src2;
wire [63:0] src1_64 = {32'h0, src1};
wire [63:0] src2_64 = {32'h0, src2};
wire signed [63:0] s_src1_64 = {{32{src1[31]}}, src1};
wire signed [63:0] s_src2_64 = {{32{src2[31]}}, src2};
wire signed [63:0] mulh_ret = (s_src1_64 * s_src2_64) >> 32;
wire signed [63:0] mulhsu_ret = (s_src1 * src2) >> 32;
wire signed [63:0] mulhu_ret = (src1 * src2) >> 32;

write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .pc(core_pc),
    .inst(r_inst),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .w_x(x),
    .dnpc(dnpc)
);

endmodule