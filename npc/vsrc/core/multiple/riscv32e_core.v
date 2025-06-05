// 单流水线多周期处理器
module riscv32e_core #(
    parameter INST_WIDTH = 32,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
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
wire                        ar_ready1;
wire                        ar_valid1;
wire [ADDR_WIDTH-1:0]       ar_addr1;
wire [3:0]                  ar_id1;
wire [7:0]                  ar_len1;
wire [2:0]                  ar_size1;
wire [1:0]                  ar_burst1;
wire                        r_ready1;
wire                        r_valid1;
wire [RRESP_WIDTH-1:0]      r_resp1;
wire [DATA_WIDTH-1:0]       r_data1;
wire                        r_last1;
wire [3:0]                  r_id1;
/* lsu axi4 信号 */
wire                        aw_ready2;
wire                        aw_valid2;
wire [ADDR_WIDTH-1:0]       aw_addr2;
wire [3:0]                  aw_id2;
wire [7:0]                  aw_len2;
wire [2:0]                  aw_size2;
wire [1:0]                  aw_burst2;
wire                        w_ready2;
wire                        w_valid2;
wire [DATA_WIDTH-1:0]       w_data2;
wire [DATA_WIDTH/8-1:0]     w_strb2;
wire                        w_last2;
wire                        b_ready2;
wire                        b_valid2;
wire [BRESP_WIDTH-1:0]      b_resp2;
wire [3:0]                  b_id2;
wire                        ar_ready2;
wire                        ar_valid2;
wire [ADDR_WIDTH-1:0]       ar_addr2;
wire [3:0]                  ar_id2;
wire [7:0]                  ar_len2;
wire [2:0]                  ar_size2;
wire [1:0]                  ar_burst2;
wire                        r_ready2;
wire                        r_valid2;
wire [RRESP_WIDTH-1:0]      r_resp2;
wire [DATA_WIDTH-1:0]       r_data2;
wire                        r_last2;
wire [3:0]                  r_id2;
/* 仲裁后的 axi4信号 */
wire                        m_awready;
wire                        m_awvalid;
wire [31:0]                 m_awaddr;
wire [3:0]                  m_awid;
wire [7:0]                  m_awlen;
wire [2:0]                  m_awsize;
wire [1:0]                  m_awburst;
wire                        m_wready;
wire                        m_wvalid;
wire [31:0]                 m_wdata;
wire [3:0]                  m_wstrb;
wire                        m_wlast;
wire                        m_bready;
wire                        m_bvalid;
wire [1:0]                  m_bresp;
wire [3:0]                  m_bid;
wire                        m_arready;
wire                        m_arvalid;
wire [31:0]                 m_araddr;
wire [3:0]                  m_arid;
wire [7:0]                  m_arlen;
wire [2:0]                  m_arsize;
wire [1:0]                  m_arburst;
wire                        m_rready;
wire                        m_rvalid;
wire [1:0]                  m_rresp;
wire [31:0]                 m_rdata;
wire                        m_rlast;
wire [3:0]                  m_rid;
/* clint axi4信号 */
wire                        s_awready[0:0];
wire                        s_awvalid[0:0];
wire [31:0]                 s_awaddr[0:0];
wire [3:0]                  s_awid[0:0];
wire [7:0]                  s_awlen[0:0];
wire [2:0]                  s_awsize[0:0];
wire [1:0]                  s_awburst[0:0];
wire                        s_wready[0:0];
wire                        s_wvalid[0:0];
wire [31:0]                 s_wdata[0:0];
wire [3:0]                  s_wstrb[0:0];
wire                        s_wlast[0:0];
wire                        s_bready[0:0];
wire                        s_bvalid[0:0];
wire [1:0]                  s_bresp[0:0];
wire [3:0]                  s_bid[0:0];
wire                        s_arready[0:0];
wire                        s_arvalid[0:0];
wire [31:0]                 s_araddr[0:0];
wire [3:0]                  s_arid[0:0];
wire [7:0]                  s_arlen[0:0];
wire [2:0]                  s_arsize[0:0];
wire [1:0]                  s_arburst[0:0];
wire                        s_rready[0:0];
wire                        s_rvalid[0:0];
wire [1:0]                  s_rresp[0:0];
wire [31:0]                 s_rdata[0:0];
wire                        s_rlast[0:0];
wire [3:0]                  s_rid[0:0];

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

/* arbiter模块 */
arbiter_axi4 #(
    .USER_M_COUNT(2),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_arbiter_axi4(
    .clk(clk),
    .rst(rst),
    .u_aw_readys(   {0,             aw_ready2   }),
    .u_aw_valids(   {0,             aw_valid2   }),
    .u_aw_addrs(    {0,             aw_addr2    }),
    .u_aw_ids(      {0,             aw_id2      }),
    .u_aw_lens(     {0,             aw_len2     }),
    .u_aw_sizes(    {0,             aw_size2    }),
    .u_aw_bursts(   {0,             aw_burst2   }),
    .u_w_readys(    {0,             w_ready2    }),
    .u_w_valids(    {0,             w_valid2    }),
    .u_w_datas(     {0,             w_data2     }),
    .u_w_strbs(     {0,             w_strb2     }),
    .u_w_lasts(     {0,             w_last2     }),
    .u_b_readys(    {0,             b_ready2    }),
    .u_b_valids(    {0,             b_valid2    }),
    .u_b_resps(     {0,             b_resp2     }),
    .u_b_ids(       {0,             b_id2       }),
    .u_ar_readys(   {ar_ready1,     ar_ready2   }),
    .u_ar_valids(   {ar_valid1,     ar_valid2   }),
    .u_ar_addrs(    {ar_addr1,      ar_addr2    }),
    .u_ar_ids(      {ar_id1,        ar_id2      }),
    .u_ar_lens(     {ar_len1,       ar_len2     }),
    .u_ar_sizes(    {ar_size1,      ar_size2    }),
    .u_ar_bursts(   {ar_burst1,     ar_burst2   }),
    .u_r_readys(    {r_ready1,      r_ready2    }),
    .u_r_valids(    {r_valid1,      r_valid2    }),
    .u_r_resps(     {r_resp1,       r_resp2     }),
    .u_r_datas(     {r_data1,       r_data2     }),
    .u_r_lasts(     {r_last1,       r_last2     }),
    .u_r_ids(       {r_id1,         r_id2       }),

    .aw_ready(m_awready),
    .aw_valid(m_awvalid),
    .aw_addr(m_awaddr),
    .aw_id(m_awid),
    .aw_len(m_awlen),
    .aw_size(m_awsize),
    .aw_burst(m_awburst),
    .w_ready(m_wready),
    .w_valid(m_wvalid),
    .w_data(m_wdata),
    .w_strb(m_wstrb),
    .w_last(m_wlast),
    .b_ready(m_bready),
    .b_valid(m_bvalid),
    .b_resp(m_bresp),
    .b_id(m_bid),
    .ar_ready(m_arready),
    .ar_valid(m_arvalid),
    .ar_addr(m_araddr),
    .ar_id(m_arid),
    .ar_len(m_arlen),
    .ar_size(m_arsize),
    .ar_burst(m_arburst),
    .r_ready(m_rready),
    .r_valid(m_rvalid),
    .r_resp(m_rresp),
    .r_data(m_rdata),
    .r_last(m_rlast),
    .r_id(m_rid),

    .grant_idx()
);

/* xbar模块 */
xbar_axi4 #(
    .USER_S_COUNT(2),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_xbar_axi4 (
    .clk(clk),
    .rst(rst),
    .aw_ready(m_awready),
    .aw_valid(m_awvalid),
    .aw_addr(m_awaddr),
    .aw_id(m_awid),
    .aw_len(m_awlen),
    .aw_size(m_awsize),
    .aw_burst(m_awburst),
    .w_ready(m_wready),
    .w_valid(m_wvalid),
    .w_data(m_wdata),
    .w_strb(m_wstrb),
    .w_last(m_wlast),
    .b_ready(m_bready),
    .b_valid(m_bvalid),
    .b_resp(m_bresp),
    .b_id(m_bid),
    .ar_ready(m_arready),
    .ar_valid(m_arvalid),
    .ar_addr(m_araddr),
    .ar_id(m_arid),
    .ar_len(m_arlen),
    .ar_size(m_arsize),
    .ar_burst(m_arburst),
    .r_ready(m_rready),
    .r_valid(m_rvalid),
    .r_resp(m_rresp),
    .r_data(m_rdata),
    .r_last(m_rlast),
    .r_id(m_rid),

    .u_aw_readys(   {   s_awready[0],       io_master_awready   } ),
    .u_aw_valids(   {   s_awvalid[0],       io_master_awvalid   } ),
    .u_aw_addrs(    {   s_awaddr[0],        io_master_awaddr    } ),
    .u_aw_ids(      {   s_awid[0],          io_master_awid      } ),
    .u_aw_lens(     {   s_awlen[0],         io_master_awlen     } ),
    .u_aw_sizes(    {   s_awsize[0],        io_master_awsize    } ),
    .u_aw_bursts(   {   s_awburst[0],       io_master_awburst   } ),
    .u_w_readys(    {   s_wready[0],        io_master_wready    } ),
    .u_w_valids(    {   s_wvalid[0],        io_master_wvalid    } ),
    .u_w_datas(     {   s_wdata[0],         io_master_wdata     } ),
    .u_w_strbs(     {   s_wstrb[0],         io_master_wstrb     } ),
    .u_w_lasts(     {   s_wlast[0],         io_master_wlast     } ),
    .u_b_readys(    {   s_bready[0],        io_master_bready    } ),
    .u_b_valids(    {   s_bvalid[0],        io_master_bvalid    } ),
    .u_b_resps(     {   s_bresp[0],         io_master_bresp     } ),
    .u_b_ids(       {   s_bid[0],           io_master_bid       } ),
    .u_ar_readys(   {   s_arready[0],       io_master_arready   } ),
    .u_ar_valids(   {   s_arvalid[0],       io_master_arvalid   } ),
    .u_ar_addrs(    {   s_araddr[0],        io_master_araddr    } ),
    .u_ar_ids(      {   s_arid[0],          io_master_arid      } ),
    .u_ar_lens(     {   s_arlen[0],         io_master_arlen     } ),
    .u_ar_sizes(    {   s_arsize[0],        io_master_arsize    } ),
    .u_ar_bursts(   {   s_arburst[0],       io_master_arburst   } ),
    .u_r_readys(    {   s_rready[0],        io_master_rready    } ),
    .u_r_valids(    {   s_rvalid[0],        io_master_rvalid    } ),
    .u_r_resps(     {   s_rresp[0],         io_master_rresp     } ),
    .u_r_datas(     {   s_rdata[0],         io_master_rdata     } ),
    .u_r_lasts(     {   s_rlast[0],         io_master_rlast     } ),
    .u_r_ids(       {   s_rid[0],           io_master_rid       } ),
    .u_slave_infos('{
        '{name:"CLIN",          startaddr:32'h0200_0000,    endaddr:32'h0200_ffff},
        /* 优先匹配其他项，若其他项匹配不上，则发送给master */
        '{name:"MASTER",        startaddr:32'h0000_0000,    endaddr:32'hffff_ffff}
    }),

    .grant_idx()
);

/* clint 模块 */
clint #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_clint(
    .clk(clk),
    .rst(rst),
    .aw_ready(s_awready[0]),
    .aw_valid(s_awvalid[0]),
    .aw_addr(s_awaddr[0]),
    .aw_id(s_awid[0]),
    .aw_len(s_awlen[0]),
    .aw_size(s_awsize[0]),
    .aw_burst(s_awburst[0]),
    .w_ready(s_wready[0]),
    .w_valid(s_wvalid[0]),
    .w_data(s_wdata[0]),
    .w_strb(s_wstrb[0]),
    .w_last(s_wlast[0]),
    .b_ready(s_bready[0]),
    .b_valid(s_bvalid[0]),
    .b_resp(s_bresp[0]),
    .b_id(s_bid[0]),
    .ar_ready(s_arready[0]),
    .ar_valid(s_arvalid[0]),
    .ar_addr(s_araddr[0]),
    .ar_id(s_arid[0]),
    .ar_len(s_arlen[0]),
    .ar_size(s_arsize[0]),
    .ar_burst(s_arburst[0]),
    .r_ready(s_rready[0]),
    .r_valid(s_rvalid[0]),
    .r_resp(s_rresp[0]),
    .r_data(s_rdata[0]),
    .r_last(s_rlast[0]),
    .r_id(s_rid[0])
);

/* 取指if */
inst_fetch #(
    .SRAM_TYPE(`SRAM_TYPE_AXI4),
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
    .ar_ready(ar_ready1),
    .ar_valid(ar_valid1),
    .ar_addr(ar_addr1),
    .ar_id(ar_id1),
    .ar_len(ar_len1),
    .ar_size(ar_size1),
    .ar_burst(ar_burst1),
    .r_ready(r_ready1),
    .r_valid(r_valid1),
    .r_resp(r_resp1),
    .r_data(r_data1),
    .r_last(r_last1),
    .r_id(r_id1),

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

    .aw_ready(aw_ready2),
    .aw_valid(aw_valid2),
    .aw_addr(aw_addr2),
    .aw_id(aw_id2),
    .aw_len(aw_len2),
    .aw_size(aw_size2),
    .aw_burst(aw_burst2),
    .w_ready(w_ready2),
    .w_valid(w_valid2),
    .w_data(w_data2),
    .w_strb(w_strb2),
    .w_last(w_last2),
    .b_ready(b_ready2),
    .b_valid(b_valid2),
    .b_resp(b_resp2),
    .b_id(b_id2),
    .ar_ready(ar_ready2),
    .ar_valid(ar_valid2),
    .ar_addr(ar_addr2),
    .ar_id(ar_id2),
    .ar_len(ar_len2),
    .ar_size(ar_size2),
    .ar_burst(ar_burst2),
    .r_ready(r_ready2),
    .r_valid(r_valid2),
    .r_resp(r_resp2),
    .r_data(r_data2),
    .r_last(r_last2),
    .r_id(r_id2),

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