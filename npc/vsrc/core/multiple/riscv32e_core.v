// 单流水线多周期处理器
module riscv32e_core #(
    parameter INST_WIDTH = 32,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
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

/* 模块通信消息 */
wire if_valid;
wire id_ready;
wire id_valid;
wire ex_ready;
wire ex_valid;
wire ls_ready;
wire ls_valid;
wire wb_ready;
wire ex_enable;
wire ls_enable;
wire ex_ls_valid;
wire ex_ls_ready;

/* ifu axi4 信号 */
wire ar_valid_1;
wire ar_ready_1;
wire [ADDR_WIDTH-1:0] ar_addr_1;
wire r_valid_1;
wire r_ready_1;
wire [DATA_WIDTH-1:0] r_data_1;
wire [RRESP_WIDTH-1:0] r_resp_1;
/* lsu axi4 信号 */
wire aw_valid_2;
wire aw_ready_2;
wire [ADDR_WIDTH-1:0] aw_addr_2;
wire w_valid_2;
wire w_ready_2;
wire [DATA_WIDTH-1:0] w_data_2;
wire [DATA_WIDTH/8-1:0] w_strb_2;
wire b_valid_2;
wire b_ready_2;
wire [BRESP_WIDTH-1:0] b_resp_2;
wire ar_valid_2;
wire ar_ready_2;
wire [ADDR_WIDTH-1:0] ar_addr_2;
wire r_valid_2;
wire r_ready_2;
wire [DATA_WIDTH-1:0] r_data_2;
wire [RRESP_WIDTH-1:0] r_resp_2;

/* 常用处理器信号 */
wire [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0];
wire [INST_WIDTH-1:0] inst;
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];
reg [63:0] execute_time;

assign valid = wb_ready;
// assign w_x = x;
// assign w_pc = pc;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        execute_time <= 0;
        dpi_execute_time_ctrl(0);
    end else begin
        execute_time <= execute_time + 1;
        dpi_execute_time_ctrl(1);
    end
end

/* xbar模块 */
xbar #(
    .USER_M_COUNT(2),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
    .SRAM_READ_DELAY(SRAM_READ_DELAY)
) m_xbar(
    .clk(clk),
    .rst(rst),
    .u_aw_valids({0, aw_valid_2}),
    .u_aw_readys({0, aw_ready_2}),
    .u_aw_addrs({0, aw_addr_2}),
    .u_w_valids({0, w_valid_2}),
    .u_w_readys({0, w_ready_2}),
    .u_w_datas({0, w_data_2}),
    .u_w_strbs({0, w_strb_2}),
    .u_b_valids({0, b_valid_2}),
    .u_b_readys({0, b_ready_2}),
    .u_b_resps({0, b_resp_2}),
    .u_ar_valids({ar_valid_1, ar_valid_2}),
    .u_ar_readys({ar_ready_1, ar_ready_2}),
    .u_ar_addrs({ar_addr_1, ar_addr_2}),
    .u_r_valids({r_valid_1, r_valid_2}),
    .u_r_readys({r_ready_1, r_ready_2}),
    .u_r_datas({r_data_1, r_data_2}),
    .u_r_resps({r_resp_1,r_resp_2})
);

/* 取指if */
inst_fetch #(
    .INST_WIDTH(INST_WIDTH)
) ifu(
    .clk(clk),
    .rst(rst),

    .pc(pc),
    .inst(inst),

    .aw_valid(),
    .aw_ready(),
    .aw_addr(),
    .w_valid(),
    .w_ready(),
    .w_data(),
    .w_strb(),
    .b_valid(),
    .b_ready(),
    .b_resp(),
    .ar_valid(ar_valid_1),
    .ar_ready(ar_ready_1),
    .ar_addr(ar_addr_1),
    .r_valid(r_valid_1),
    .r_ready(r_ready_1),
    .r_data(r_data_1),
    .r_resp(r_resp_1),

    .enable(execute_time<=1 || valid),
    .next_ready(id_ready),
    .next_valid(if_valid)
);

/* 译码id */
wire [4:0] rd;
wire [4:0] rs1;
wire [4:0] rs2;
wire [INST_WIDTH-1:0] imm;
wire [15:0] inst_code;
inst_decode #(
    .INST_WIDTH(INST_WIDTH)
) idu(
    .clk(clk),
    .rst(rst),

    .inst(inst),
    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .icode(inst_code),

    .prev_ready(id_ready),
    .prev_valid(if_valid),
    .next_ready(ex_ls_ready),
    .next_valid(id_valid)
);
assign ls_enable = 
(inst_code == `INST_LB) ||
(inst_code == `INST_LH) ||
(inst_code == `INST_LW) ||
(inst_code == `INST_LBU) ||
(inst_code == `INST_LHU) ||
(inst_code == `INST_SB) ||
(inst_code == `INST_SH) ||
(inst_code == `INST_SW)
;
assign ex_enable = !ls_enable;
assign ex_ls_ready = ({1{ex_enable}} & ex_ready) | ({1{ls_enable}} & ls_ready);

/* 执行ex */
wire [INST_WIDTH-1:0] ex_dnpc, ex_result;
wire [7:0] ex_mem_result_width;
wire ex_result_update_csr;
execute #(
    .INST_WIDTH(INST_WIDTH)
) exu(
    .clk(clk),
    .rst(rst),

    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .dnpc(ex_dnpc),
    .x(x),
    .result(ex_result),
    .mem_result_width(ex_mem_result_width),
    .result_update_csr(ex_result_update_csr),

    .prev_ready(ex_ready),
    .prev_valid(id_valid && ex_enable),
    .next_ready(wb_ready),
    .next_valid(ex_valid)
);

/* 读存储ls */
wire [INST_WIDTH-1:0] ls_dnpc, ls_result;
wire [7:0] ls_mem_result_width;
wire ls_result_update_csr;
load_store #(
    .INST_WIDTH(INST_WIDTH)
) lsu(
    .clk(clk),
    .rst(rst),

    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .inst(inst),
    .pc(pc),
    .dnpc(ls_dnpc),
    .x(x),
    .result(ls_result),
    .mem_result_width(ls_mem_result_width),
    .result_update_csr(ls_result_update_csr),

    .aw_valid(aw_valid_2),
    .aw_ready(aw_ready_2),
    .aw_addr(aw_addr_2),
    .w_valid(w_valid_2),
    .w_ready(w_ready_2),
    .w_data(w_data_2),
    .w_strb(w_strb_2),
    .b_valid(b_valid_2),
    .b_ready(b_ready_2),
    .b_resp(b_resp_2),
    .ar_valid(ar_valid_2),
    .ar_ready(ar_ready_2),
    .ar_addr(ar_addr_2),
    .r_valid(r_valid_2),
    .r_ready(r_ready_2),
    .r_data(r_data_2),
    .r_resp(r_resp_2),

    .prev_ready(ls_ready),
    .prev_valid(id_valid && ls_enable),
    .next_ready(wb_ready),
    .next_valid(ls_valid)
);

/* 回写wb */
wire [INST_WIDTH-1:0] dnpc, result;
wire [7:0] mem_result_width;
wire result_update_csr;
assign dnpc = ({INST_WIDTH{ex_enable}} & ex_dnpc) | ({INST_WIDTH{ls_enable}} & ls_dnpc);
assign result = ({INST_WIDTH{ex_enable}} & ex_result) | ({INST_WIDTH{ls_enable}} & ls_result);
assign mem_result_width = ({8{ex_enable}} & ex_mem_result_width) | ({8{ls_enable}} & ls_mem_result_width);
assign result_update_csr = ({1{ex_enable}} & ex_result_update_csr) | ({1{ls_enable}} & ls_result_update_csr);
assign ex_ls_valid = ({1{ex_enable}} & ex_valid) | ({1{ls_enable}} & ls_valid);
write_back #(
    .INST_WIDTH(INST_WIDTH)
) wbu(
    .clk(clk),
    .rst(rst),

    .rd(rd),
    .rs1(rs1),
    .rs2(rs2),
    .imm(imm),
    .inst_code(inst_code),
    .w_x(x),
    .result(result),
    .mem_result_width(mem_result_width),
    .result_update_csr(result_update_csr),
    .dnpc(dnpc),
    .w_pc(pc),

    .prev_ready(wb_ready),
    .prev_valid(ex_ls_valid)
);

endmodule