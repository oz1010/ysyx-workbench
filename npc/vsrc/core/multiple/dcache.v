/* 数据缓存控制器 */
module dcache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2,
    parameter INST_WIDTH = 32,
    /* 
        w > 0
        n > 0
        m+n < 31
        m > 1
     */
    parameter W = 2,
    parameter N = 2,
    parameter M = 3
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
    input   wire [3:0]                  s_rid
);

/*
 31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/

localparam offset_width = M;
localparam index_width = N;
localparam cache_line_size = 1<<(M);
localparam cache_line_load_count = cache_line_size<4 ? 1 : (cache_line_size/((INST_WIDTH/8))); // 单次cache_line加载次数，数据位宽一般为32
localparam cache_line_load_len = log2(cache_line_load_count);

/* 与master端通信 */
reg                         c_m_awready = 0;
reg                         c_m_wready = 0;
reg                         c_m_bvalid = 0;
reg  [BRESP_WIDTH-1:0]      c_m_bresp = 0;
reg  [3:0]                  c_m_bid = 0;
reg                         c_m_arready;
reg                         c_m_rvalid;
reg  [RRESP_WIDTH-1:0]      c_m_rresp;
reg  [DATA_WIDTH-1:0]       c_m_rdata;
reg                         c_m_rlast;
reg  [3:0]                  c_m_rid;
wire                        c_m_awvalid;
wire [ADDR_WIDTH-1:0]       c_m_awaddr;
wire [3:0]                  c_m_awid;
wire [7:0]                  c_m_awlen;
wire [2:0]                  c_m_awsize;
wire [1:0]                  c_m_awburst;
wire                        c_m_wvalid;
wire [DATA_WIDTH-1:0]       c_m_wdata;
wire [DATA_WIDTH/8-1:0]     c_m_wstrb;
wire                        c_m_wlast;
wire                        c_m_bready;
wire                        c_m_arvalid;
wire [ADDR_WIDTH-1:0]       c_m_araddr;
wire [3:0]                  c_m_arid;
wire [7:0]                  c_m_arlen;
wire [2:0]                  c_m_arsize;
wire [1:0]                  c_m_arburst;
wire                        c_m_rready;
/* 与slave端通信 */
wire                        c_s_awready;
wire                        c_s_wready;
wire                        c_s_bvalid;
wire [BRESP_WIDTH-1:0]      c_s_bresp;
wire [3:0]                  c_s_bid;
wire                        c_s_arready;
wire                        c_s_rvalid;
wire [RRESP_WIDTH-1:0]      c_s_rresp;
wire [DATA_WIDTH-1:0]       c_s_rdata;
wire                        c_s_rlast;
wire [3:0]                  c_s_rid;
reg                         c_s_awvalid = 0;
reg  [ADDR_WIDTH-1:0]       c_s_awaddr = 0;
reg  [3:0]                  c_s_awid = 0;
reg  [7:0]                  c_s_awlen = 0;
reg  [2:0]                  c_s_awsize = 0;
reg  [1:0]                  c_s_awburst = 0;
reg                         c_s_wvalid;
reg  [DATA_WIDTH-1:0]       c_s_wdata;
reg  [DATA_WIDTH/8-1:0]     c_s_wstrb;
reg                         c_s_wlast;
reg                         c_s_bready;
reg                         c_s_arvalid;
reg  [ADDR_WIDTH-1:0]       c_s_araddr;
reg  [3:0]                  c_s_arid;
reg  [7:0]                  c_s_arlen;
reg  [2:0]                  c_s_arsize;
reg  [1:0]                  c_s_arburst;
reg                         c_s_rready;

`ifdef CONFIG_DCACHE
// wire dcache_wen = m_awid==`AXI4_ID_LSU &&
//     ( 
//            ( m_awaddr>=`CONFIG_MROM_BASE && m_awaddr<=(`CONFIG_MROM_BASE+`CONFIG_MROM_SIZE))
//         || ( m_awaddr>=`CONFIG_FLASH_BASE && m_awaddr<=(`CONFIG_FLASH_BASE+`CONFIG_FLASH_SIZE) )
//         || ( m_awaddr>=`CONFIG_PSRAM_BASE && m_awaddr<=(`CONFIG_PSRAM_BASE+`CONFIG_PSRAM_SIZE) )
//         || ( m_awaddr>=`CONFIG_SDRAM_BASE && m_awaddr<=(`CONFIG_SDRAM_BASE+`CONFIG_SDRAM_SIZE) )
//     );
wire dcache_wen = 0; // 写数据透传
wire dcache_ren = m_arid==`AXI4_ID_LSU &&
    ( 
           ( m_araddr>=`CONFIG_MROM_BASE && m_araddr<=(`CONFIG_MROM_BASE+`CONFIG_MROM_SIZE))
        || ( m_araddr>=`CONFIG_FLASH_BASE && m_araddr<=(`CONFIG_FLASH_BASE+`CONFIG_FLASH_SIZE) )
        || ( m_araddr>=`CONFIG_PSRAM_BASE && m_araddr<=(`CONFIG_PSRAM_BASE+`CONFIG_PSRAM_SIZE) )
        || ( m_araddr>=`CONFIG_SDRAM_BASE && m_araddr<=(`CONFIG_SDRAM_BASE+`CONFIG_SDRAM_SIZE) )
    );
`else
wire dcache_wen = 0;
wire dcache_ren = 0;
`endif
wire slave_len_burst_en = ( m_araddr>=`CONFIG_SDRAM_BASE && m_araddr<=(`CONFIG_SDRAM_BASE+`CONFIG_SDRAM_SIZE) );

wire                        slave_en; // 从设备使能标记
reg  [ADDR_WIDTH-1:0]       r_slave_addr; // 从设备读取地址
wire [INST_WIDTH-1:0]       slave_data; // 从设备读取指令
reg  [31:0]                 r_slave_index; // 从设备指令计数
wire [7:0]                  slave_len; // 从设备burst模式读取的长度
assign slave_len = slave_len_burst_en ? cache_line_load_len[7:0] : 0; // 其他存储器比如flash暂时不支持burst模式

assign m_awready = dcache_wen ? c_m_awready : s_awready;
assign m_wready = dcache_wen ? c_m_wready : s_wready;
assign m_bvalid = dcache_wen ? c_m_bvalid : s_bvalid;
assign m_bresp = dcache_wen ? c_m_bresp : s_bresp;
assign m_bid = dcache_wen ? c_m_bid : s_bid;
assign m_arready = dcache_ren ? c_m_arready : s_arready;
assign m_rvalid = dcache_ren ? c_m_rvalid : s_rvalid;
assign m_rresp = dcache_ren ? c_m_rresp : s_rresp;
assign m_rdata = dcache_ren ? c_m_rdata : s_rdata;
assign m_rlast = dcache_ren ? c_m_rlast : s_rlast;
assign m_rid = dcache_ren ? c_m_rid : s_rid;
assign c_m_awvalid = dcache_wen ? m_awvalid : 0;
assign c_m_awaddr = dcache_wen ? m_awaddr : 0;
assign c_m_awid = dcache_wen ? m_awid : 0;
assign c_m_awlen = dcache_wen ? m_awlen : 0;
assign c_m_awsize = dcache_wen ? m_awsize : 0;
assign c_m_awburst = dcache_wen ? m_awburst : 0;
assign c_m_wvalid = dcache_wen ? m_wvalid : 0;
assign c_m_wdata = dcache_wen ? m_wdata : 0;
assign c_m_wstrb = dcache_wen ? m_wstrb : 0;
assign c_m_wlast = dcache_wen ? m_wlast : 0;
assign c_m_bready = dcache_wen ? m_bready : 0;
assign c_m_arvalid = dcache_ren ? m_arvalid : 0;
assign c_m_araddr = m_araddr;
assign c_m_arid = dcache_ren ? m_arid : 0;
assign c_m_arlen = dcache_ren ? m_arlen : 0;
assign c_m_arsize = dcache_ren ? m_arsize : 0;
assign c_m_arburst = dcache_ren ? m_arburst : 0;
assign c_m_rready = dcache_ren ? m_rready : 0;

assign c_s_awready = dcache_wen ? s_awready : 0;
assign c_s_wready = dcache_wen ? s_wready : 0;
assign c_s_bvalid = dcache_wen ? s_bvalid : 0;
assign c_s_bresp = dcache_wen ? s_bresp : 0;
assign c_s_bid = dcache_wen ? s_bid : 0;
assign c_s_arready = dcache_ren ? s_arready : 0;
assign c_s_rvalid = dcache_ren ? s_rvalid : 0;
assign c_s_rresp = dcache_ren ? s_rresp : 0;
assign c_s_rdata = dcache_ren ? s_rdata : 0;
assign c_s_rlast = dcache_ren ? s_rlast : 0;
assign c_s_rid = dcache_ren ? s_rid : 0;
assign s_awvalid = dcache_wen ? c_s_awvalid : m_awvalid;
assign s_awaddr = dcache_wen ? c_s_awaddr : m_awaddr;
assign s_awid = dcache_wen ? c_s_awid : m_awid;
assign s_awlen = dcache_wen ? c_s_awlen : m_awlen;
assign s_awsize = dcache_wen ? c_s_awsize : m_awsize;
assign s_awburst = dcache_wen ? c_s_awburst : m_awburst;
assign s_wvalid = dcache_wen ? c_s_wvalid : m_wvalid;
assign s_wdata = dcache_wen ? c_s_wdata : m_wdata;
assign s_wstrb = dcache_wen ? c_s_wstrb : m_wstrb;
assign s_wlast = dcache_wen ? c_s_wlast : m_wlast;
assign s_bready = dcache_wen ? c_s_bready : m_bready;
assign s_arvalid = dcache_ren ? c_s_arvalid : m_arvalid;
assign s_araddr = dcache_ren ? c_s_araddr : m_araddr;
assign s_arid = dcache_ren ? c_s_arid : m_arid;
assign s_arlen = dcache_ren ? c_s_arlen : m_arlen;
assign s_arsize = dcache_ren ? c_s_arsize : m_arsize;
assign s_arburst = dcache_ren ? c_s_arburst : m_arburst;
assign s_rready = dcache_ren ? c_s_rready : m_rready;

initial begin
    r_slave_addr = 0;
    r_slave_index = 0;
end

wire [ADDR_WIDTH-1:0]       read_addr;
wire [7:0]                  read_len;
wire [2:0]                  read_size;
wire [1:0]                  read_state;
axi4_salve_reader #(
    `ifndef IN_YOSYS_STA
    .NAME("dcache"),
    `endif
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi4_salve_reader (
    .clk(clk),
    .rst(rst),
    .arready(c_m_arready),
    .arvalid(c_m_arvalid),
    .araddr(c_m_araddr),
    .arid(c_m_arid),
    .arlen(c_m_arlen),
    .arsize(c_m_arsize),
    .arburst(c_m_arburst),
    .rready(c_m_rready),
    .rvalid(c_m_rvalid),
    .rresp(c_m_rresp),
    .rdata(c_m_rdata),
    .rlast(c_m_rlast),
    .rid(c_m_rid),
    .enable(dcache_ren),
    .data_en(impl_read_en),
    .read_addr(read_addr),
    .read_data(impl_read_data),
    .read_len(read_len),
    .read_size(read_size),
    .read_state(read_state)
);

wire [1:0]                  slave_state;
assign slave_en = impl_update_en && r_slave_index<cache_line_load_count;
axi_master_reader #(
`ifndef IN_YOSYS_STA
    .NAME("dcache"),
`endif
    .ID(`AXI4_ID_DCACHE),
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .INST_WIDTH(INST_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi_master_reader (
    .clk(clk),
    .rst(rst),
    .arready(c_s_arready),
    .arvalid(c_s_arvalid),
    .araddr(c_s_araddr),
    .arid(c_s_arid),
    .arlen(c_s_arlen),
    .arsize(c_s_arsize),
    .arburst(c_s_arburst),
    .rready(c_s_rready),
    .rvalid(c_s_rvalid),
    .rresp(c_s_rresp),
    .rdata(c_s_rdata),
    .rlast(c_s_rlast),
    .rid(c_s_rid),
    .enable(slave_en),
    .read_sign(0),
    .read_addr(r_slave_addr),
    .read_data(slave_data),
    .read_len(slave_len),
    .read_size(2),
    .read_state(slave_state)
);

reg [ADDR_WIDTH-1:0]       impl_addr;
reg                        impl_update_en;
reg                        impl_reset_en;
reg                        impl_write_en;
reg [DATA_WIDTH-1:0]       impl_write_data;
wire                       impl_read_en;
wire [DATA_WIDTH-1:0]      impl_read_data;
cache #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .W(W),
    .N(N),
    .M(M)
) dcache_impl (
    .clk(clk),
    .rst(rst),
    .addr(impl_addr),
    .update_en(impl_update_en),
    .reset_en(impl_reset_en),
    .write_en(impl_write_en),
    .write_data(impl_write_data),
    .read_en(impl_read_en),
    .read_data(impl_read_data)
);
reg [31:0] impl_reset_addr;
assign impl_addr = dcache_ren ? c_m_araddr :
    m_awvalid ? m_awaddr :
    impl_reset_en ? impl_reset_addr : 
    0;
assign impl_write_en = impl_update_en && c_s_rvalid && c_s_rready;
assign impl_write_data = c_s_rdata;

always @(posedge clk) begin
    if (rst) begin
        impl_reset_en <= 0;
        impl_reset_addr <= 0;
    end else begin
        if (m_awvalid && impl_read_en) begin
            impl_reset_en <= 1;
            impl_reset_addr <= m_awaddr;
        end

        if (impl_reset_en) begin
            impl_reset_en <= 0;
            impl_reset_addr <= 0;
        end

        if (dcache_ren) begin
            if (c_m_arvalid && c_m_arready) begin
                // if (impl_read_en) begin 
                //     func_cpu_stat_ctrl(`HW_CPU_STAT_ICACHE_HIT, 1);
                // end else begin
                //     func_cpu_stat_ctrl(`HW_CPU_STAT_ICACHE_MISS, 1);
                // end
            end

            if (impl_update_en) begin
                // 等待从设备读取完成数据
                if (c_s_rvalid && c_s_rready) begin
                    r_slave_addr <= r_slave_addr + (INST_WIDTH/8);
                    r_slave_index <= r_slave_index + 1;
                end

                // 等待缓存更新好
                if (impl_read_en) begin
                    impl_update_en <= 0;
                end
            end else begin
                // 未命中缓存，准备更新
                if (!impl_read_en) begin
                    impl_update_en <= 1;
                    r_slave_addr <= {read_addr[ADDR_WIDTH-1:offset_width], {(offset_width){1'b0}}};
                    r_slave_index <= 0;
                end
            end
        end
    end
end

endmodule
