module icache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter INST_WIDTH = 32,
    parameter BLOCK_SIZE = 16
) (
    input wire                          clk,
    input wire                          rst,

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

localparam cache_block_width = INST_WIDTH + 1;

reg [31:0] r_hit_count;
reg [31:0] r_miss_count;
reg [cache_block_width-1:0] cache_block[0:BLOCK_SIZE];

assign hit_count = r_hit_count;
assign miss_count = r_miss_count;

assign m_awready = s_awready;
assign m_wready = s_wready;
assign m_bvalid = s_bvalid;
assign m_bresp = s_bresp;
assign m_bid = s_bid;
assign m_arready = s_arready;
assign m_rvalid = s_rvalid;
assign m_rresp = s_rresp;
assign m_rdata = s_rdata;
assign m_rlast = s_rlast;
assign m_rid = s_rid;
assign s_awvalid = m_awvalid;
assign s_awaddr = m_awaddr;
assign s_awid = m_awid;
assign s_awlen = m_awlen;
assign s_awsize = m_awsize;
assign s_awburst = m_awburst;
assign s_wvalid = m_wvalid;
assign s_wdata = m_wdata;
assign s_wstrb = m_wstrb;
assign s_wlast = m_wlast;
assign s_bready = m_bready;
assign s_arvalid = m_arvalid;
assign s_araddr = m_araddr;
assign s_arid = m_arid;
assign s_arlen = m_arlen;
assign s_arsize = m_arsize;
assign s_arburst = m_arburst;
assign s_rready = m_rready;

endmodule
