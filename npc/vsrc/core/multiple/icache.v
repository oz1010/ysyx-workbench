/* 指令缓存控制器 */
module icache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter INST_WIDTH = 32,
    parameter BLOCK_SIZE = 16
) (
    input   wire                        clk,
    input   wire                        rst,

    output  wire                        m_awready,
    input   wire                        m_awvalid,
    input   wire [ADDR_WIDTH-1:0]       m_awaddr,
    input   wire [3:0]                  m_awid,
    input   wire [7:0]                  m_awlen,
    input   wire [2:0]                  m_awsize,
    input   wire [1:0]                  m_awburst,
    output  wire                        m_wready,
    input   wire                        m_wvalid,
    input   wire [DATA_WIDTH-1:0]       m_wdata,
    input   wire [DATA_WIDTH/8-1:0]     m_wstrb,
    input   wire                        m_wlast,
    input   wire                        m_bready,
    output  wire                        m_bvalid,
    output  wire [BRESP_WIDTH-1:0]      m_bresp,
    output  wire [3:0]                  m_bid,
    output  wire                        m_arready,
    input   wire                        m_arvalid,
    input   wire [ADDR_WIDTH-1:0]       m_araddr,
    input   wire [3:0]                  m_arid,
    input   wire [7:0]                  m_arlen,
    input   wire [2:0]                  m_arsize,
    input   wire [1:0]                  m_arburst,
    input   wire                        m_rready,
    output  wire                        m_rvalid,
    output  wire [RRESP_WIDTH-1:0]      m_rresp,
    output  wire [DATA_WIDTH-1:0]       m_rdata,
    output  wire                        m_rlast,
    output  wire [3:0]                  m_rid,

    input   wire                        s_awready,
    output  wire                        s_awvalid,
    output  wire [ADDR_WIDTH-1:0]       s_awaddr,
    output  wire [3:0]                  s_awid,
    output  wire [7:0]                  s_awlen,
    output  wire [2:0]                  s_awsize,
    output  wire [1:0]                  s_awburst,
    input   wire                        s_wready,
    output  wire                        s_wvalid,
    output  wire [DATA_WIDTH-1:0]       s_wdata,
    output  wire [DATA_WIDTH/8-1:0]     s_wstrb,
    output  wire                        s_wlast,
    output  wire                        s_bready,
    input   wire                        s_bvalid,
    input   wire [BRESP_WIDTH-1:0]      s_bresp,
    input   wire [3:0]                  s_bid,
    input   wire                        s_arready,
    output  wire                        s_arvalid,
    output  wire [ADDR_WIDTH-1:0]       s_araddr,
    output  wire [3:0]                  s_arid,
    output  wire [7:0]                  s_arlen,
    output  wire [2:0]                  s_arsize,
    output  wire [1:0]                  s_arburst,
    output  wire                        s_rready,
    input   wire                        s_rvalid,
    input   wire [RRESP_WIDTH-1:0]      s_rresp,
    input   wire [DATA_WIDTH-1:0]       s_rdata,
    input   wire                        s_rlast,
    input   wire [3:0]                  s_rid,

    output  wire [31:0]                 hit_count,
    output  wire [31:0]                 miss_count
);

reg [31:0] r_hit_count = 0;
reg [31:0] r_miss_count = 0;

/* 与master端通信 */
reg                         r_m_awready;
reg                         r_m_wready;
reg                         r_m_bvalid;
reg [BRESP_WIDTH-1:0]       r_m_bresp;
reg [3:0]                   r_m_bid;
reg                         r_m_arready;
reg                         r_m_rvalid;
reg [RRESP_WIDTH-1:0]       r_m_rresp;
reg [DATA_WIDTH-1:0]        r_m_rdata;
reg                         r_m_rlast;
reg [3:0]                   r_m_rid;
/* 与slave端通信 */
reg                         r_s_awvalid;
reg [ADDR_WIDTH-1:0]        r_s_awaddr;
reg [3:0]                   r_s_awid;
reg [7:0]                   r_s_awlen;
reg [2:0]                   r_s_awsize;
reg [1:0]                   r_s_awburst;
reg                         r_s_wvalid;
reg [DATA_WIDTH-1:0]        r_s_wdata;
reg [DATA_WIDTH/8-1:0]      r_s_wstrb;
reg                         r_s_wlast;
reg                         r_s_bready;
reg                         r_s_arvalid;
reg [ADDR_WIDTH-1:0]        r_s_araddr;
reg [3:0]                   r_s_arid;
reg [7:0]                   r_s_arlen;
reg [2:0]                   r_s_arsize;
reg [1:0]                   r_s_arburst;
reg                         r_s_rready;

wire in_slow_mem = 0;
wire icache_en = in_slow_mem;

assign hit_count = r_hit_count;
assign miss_count = r_miss_count;

assign m_awready = icache_en ? r_m_awready : s_awready;
assign m_wready = icache_en ? r_m_wready : s_wready;
assign m_bvalid = icache_en ? r_m_bvalid : s_bvalid;
assign m_bresp = icache_en ? r_m_bresp : s_bresp;
assign m_bid = icache_en ? r_m_bid : s_bid;
assign m_arready = icache_en ? r_m_arready : s_arready;
assign m_rvalid = icache_en ? r_m_rvalid : s_rvalid;
assign m_rresp = icache_en ? r_m_rresp : s_rresp;
assign m_rdata = icache_en ? r_m_rdata : s_rdata;
assign m_rlast = icache_en ? r_m_rlast : s_rlast;
assign m_rid = icache_en ? r_m_rid : s_rid;
assign s_awvalid = icache_en ? r_s_awvalid : m_awvalid;
assign s_awaddr = icache_en ? r_s_awaddr : m_awaddr;
assign s_awid = icache_en ? r_s_awid : m_awid;
assign s_awlen = icache_en ? r_s_awlen : m_awlen;
assign s_awsize = icache_en ? r_s_awsize : m_awsize;
assign s_awburst = icache_en ? r_s_awburst : m_awburst;
assign s_wvalid = icache_en ? r_s_wvalid : m_wvalid;
assign s_wdata = icache_en ? r_s_wdata : m_wdata;
assign s_wstrb = icache_en ? r_s_wstrb : m_wstrb;
assign s_wlast = icache_en ? r_s_wlast : m_wlast;
assign s_bready = icache_en ? r_s_bready : m_bready;
assign s_arvalid = icache_en ? r_s_arvalid : m_arvalid;
assign s_araddr = icache_en ? r_s_araddr : m_araddr;
assign s_arid = icache_en ? r_s_arid : m_arid;
assign s_arlen = icache_en ? r_s_arlen : m_arlen;
assign s_arsize = icache_en ? r_s_arsize : m_arsize;
assign s_arburst = icache_en ? r_s_arburst : m_arburst;
assign s_rready = icache_en ? r_s_rready : m_rready;

icache_block #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .INST_WIDTH(INST_WIDTH),
    .BLOCK_SIZE(BLOCK_SIZE)
) m_icache_block(
    .clk(clk),
    .rst(rst),
    .addr(m_araddr),
    .write_en(0),
    .write_inst(),
    .read_en(),
    .read_inst()
);

endmodule


/* 单个缓存块 */
module icache_block #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter BLOCK_SIZE = 16
) (
    input   wire                        clk,
    input   wire                        rst,
    input   wire [ADDR_WIDTH-1:0]       addr,
    input   wire                        write_en,
    input   wire [INST_WIDTH-1:0]       write_inst,
    output  wire                        read_en,
    output  wire [INST_WIDTH-1:0]       read_inst
);

/*
 31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/

localparam tag_width = ADDR_WIDTH - (offset_width+index_width);
localparam block_width = INST_WIDTH*BLOCK_SIZE;
localparam offset_width = log2(INST_WIDTH/8);
localparam index_width = log2(BLOCK_SIZE);

reg [block_width-1:0] block = 0;
reg valid = 0;
reg [tag_width-1:0] tag = 0;

wire [tag_width-1:0] select_tag = addr[index_width+offset_width +: tag_width];
wire [index_width-1:0] select_index = addr[offset_width +: index_width];
wire [offset_width-1:0] select_offset = addr[0 +: offset_width];

assign read_en = valid && select_tag==tag;
generate
    for (genvar i=0; i<(INST_WIDTH/8); ++i) begin
        assign read_inst[i*8 +: 8] = read_en ? block[((i + {select_index, select_offset})*8)%block_width +: 8] : 0;
    end
endgenerate

endmodule
