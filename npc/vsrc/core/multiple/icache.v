/* 指令缓存控制器 */
module icache #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
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
localparam block_count = 1<<N;
localparam tag_width = ADDR_WIDTH - (offset_width+index_width);
localparam block_width = INST_WIDTH*block_count;
localparam offset_width = log2(INST_WIDTH/8);
localparam index_width = log2(block_count);
localparam index_max = {index_width{1'h1}};
localparam index_init = {index_width{1'h1}}>>1;

localparam check_cache_t = 0;
localparam return_cache_t = 1;
localparam update_cache_t = 2;

reg [1:0] icache_read_state = check_cache_t;

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

wire icache_wen = 0;
wire icache_ren = m_arid==`AXI4_ID_IFU &&
    ( 
           ( m_araddr>=`CONFIG_MROM_BASE && m_araddr<=(`CONFIG_MROM_BASE+`CONFIG_MROM_SIZE))
        || ( m_araddr>=`CONFIG_FLASH_BASE && m_araddr<=(`CONFIG_FLASH_BASE+`CONFIG_FLASH_SIZE) )
        || ( m_araddr>=`CONFIG_PSRAM_BASE && m_araddr<=(`CONFIG_PSRAM_BASE+`CONFIG_PSRAM_SIZE) )
        || ( m_araddr>=`CONFIG_SDRAM_BASE && m_araddr<=(`CONFIG_SDRAM_BASE+`CONFIG_SDRAM_SIZE) )
    );

wire                        read_en;
wire [INST_WIDTH-1:0]       read_inst;
reg                         r_write_en;
reg  [log2(block_count)-1:0] r_write_index = index_max;
reg  [ADDR_WIDTH-1:0]       r_write_addr; // 缓存写入地址
reg  [INST_WIDTH-1:0]       r_write_inst; // 缓存写入指令
wire                        slave_en; // 从设备使能标记
reg  [ADDR_WIDTH-1:0]       r_slave_addr; // 从设备读取地址
wire [INST_WIDTH-1:0]       slave_inst; // 从设备读取指令
reg  [31:0]                 r_slave_index; // 从设备指令计数

assign m_awready = icache_wen ? c_m_awready : s_awready;
assign m_wready = icache_wen ? c_m_wready : s_wready;
assign m_bvalid = icache_wen ? c_m_bvalid : s_bvalid;
assign m_bresp = icache_wen ? c_m_bresp : s_bresp;
assign m_bid = icache_wen ? c_m_bid : s_bid;
assign m_arready = icache_ren ? c_m_arready : s_arready;
assign m_rvalid = icache_ren ? c_m_rvalid : s_rvalid;
assign m_rresp = icache_ren ? c_m_rresp : s_rresp;
assign m_rdata = icache_ren ? c_m_rdata : s_rdata;
assign m_rlast = icache_ren ? c_m_rlast : s_rlast;
assign m_rid = icache_ren ? c_m_rid : s_rid;
assign c_m_awvalid = icache_wen ? m_awvalid : 0;
assign c_m_awaddr = icache_wen ? m_awaddr : 0;
assign c_m_awid = icache_wen ? m_awid : 0;
assign c_m_awlen = icache_wen ? m_awlen : 0;
assign c_m_awsize = icache_wen ? m_awsize : 0;
assign c_m_awburst = icache_wen ? m_awburst : 0;
assign c_m_wvalid = icache_wen ? m_wvalid : 0;
assign c_m_wdata = icache_wen ? m_wdata : 0;
assign c_m_wstrb = icache_wen ? m_wstrb : 0;
assign c_m_wlast = icache_wen ? m_wlast : 0;
assign c_m_bready = icache_wen ? m_bready : 0;
assign c_m_arvalid = icache_ren ? m_arvalid : 0;
assign c_m_araddr = m_araddr;
assign c_m_arid = icache_ren ? m_arid : 0;
assign c_m_arlen = icache_ren ? m_arlen : 0;
assign c_m_arsize = icache_ren ? m_arsize : 0;
assign c_m_arburst = icache_ren ? m_arburst : 0;
assign c_m_rready = icache_ren ? m_rready : 0;

assign c_s_awready = icache_wen ? s_awready : 0;
assign c_s_wready = icache_wen ? s_wready : 0;
assign c_s_bvalid = icache_wen ? s_bvalid : 0;
assign c_s_bresp = icache_wen ? s_bresp : 0;
assign c_s_bid = icache_wen ? s_bid : 0;
assign c_s_arready = icache_ren ? s_arready : 0;
assign c_s_rvalid = icache_ren ? s_rvalid : 0;
assign c_s_rresp = icache_ren ? s_rresp : 0;
assign c_s_rdata = icache_ren ? s_rdata : 0;
assign c_s_rlast = icache_ren ? s_rlast : 0;
assign c_s_rid = icache_ren ? s_rid : 0;
assign s_awvalid = icache_wen ? c_s_awvalid : m_awvalid;
assign s_awaddr = icache_wen ? c_s_awaddr : m_awaddr;
assign s_awid = icache_wen ? c_s_awid : m_awid;
assign s_awlen = icache_wen ? c_s_awlen : m_awlen;
assign s_awsize = icache_wen ? c_s_awsize : m_awsize;
assign s_awburst = icache_wen ? c_s_awburst : m_awburst;
assign s_wvalid = icache_wen ? c_s_wvalid : m_wvalid;
assign s_wdata = icache_wen ? c_s_wdata : m_wdata;
assign s_wstrb = icache_wen ? c_s_wstrb : m_wstrb;
assign s_wlast = icache_wen ? c_s_wlast : m_wlast;
assign s_bready = icache_wen ? c_s_bready : m_bready;
assign s_arvalid = icache_ren ? c_s_arvalid : m_arvalid;
assign s_araddr = icache_ren ? c_s_araddr : m_araddr;
assign s_arid = icache_ren ? c_s_arid : m_arid;
assign s_arlen = icache_ren ? c_s_arlen : m_arlen;
assign s_arsize = icache_ren ? c_s_arsize : m_arsize;
assign s_arburst = icache_ren ? c_s_arburst : m_arburst;
assign s_rready = icache_ren ? c_s_rready : m_rready;

initial begin
    r_write_en = 0;
    r_write_addr = 0;
    r_write_inst = 0;
    r_slave_addr = 0;
    r_slave_index = 0;
end

wire [ADDR_WIDTH-1:0]       read_addr;
wire [2:0]                  read_size;
wire [1:0]                  read_state;
axi4_salve_reader #(
    `ifndef IN_YOSYS_STA
    .NAME("icache"),
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
    .enable(icache_ren),
    .data_en(read_en),
    .read_addr(read_addr),
    .read_data(read_inst),
    .read_len(),
    .read_size(read_size),
    .read_state(read_state)
);

wire [1:0]                  slave_state;
assign slave_en = r_write_en && r_slave_index<block_count;
axi_master_reader #(
`ifndef IN_YOSYS_STA
    .NAME("icache"),
`endif
    .ID(`AXI4_ID_ICACHE),
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
    .read_data(slave_inst),
    .read_len(0),
    .read_size(2),
    .read_state(slave_state)
);

icache_block #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .INST_WIDTH(INST_WIDTH),
    .block_count(block_count)
) m_icache_block(
    .clk(clk),
    .rst(rst),
    .write_addr(r_write_addr),
    .write_en(r_write_en),
    .write_index(r_write_index),
    .write_inst(r_write_inst),
    .read_addr(read_addr),
    .read_en(read_en),
    .read_inst(read_inst)
);

always @(posedge clk) begin
    if (rst) begin
    end else begin
        if (icache_ren) begin
            case (icache_read_state)
                check_cache_t: begin
                    if (read_en) begin
                        icache_read_state <= return_cache_t;
                        func_cpu_stat_ctrl(`HW_CPU_STAT_ICACHE_HIT, 1);
                    end else begin
                        icache_read_state <= update_cache_t;
                        r_write_en <= 1;
                        r_write_index <= index_max; /* 默认都是从0开始更新，非0值即可 */
                        r_write_addr <= 0;
                        r_slave_addr <= {read_addr[ADDR_WIDTH-1:(offset_width+index_width)], {(offset_width+index_width){1'b0}}};
                        r_slave_index <= 0;
                        func_cpu_stat_ctrl(`HW_CPU_STAT_ICACHE_MISS, 1);
                    end
                end

                return_cache_t: icache_read_state <= check_cache_t;

                update_cache_t: begin
                    // 等待从设备读取完成数据
                    if (slave_state == `AXI4_STATE_DATA && c_s_rvalid) begin
                        r_write_index <= r_write_index + 1;
                        r_write_addr <= r_slave_addr;
                        r_write_inst <= slave_inst;
                        r_slave_addr <= r_slave_addr + (INST_WIDTH/8);
                        r_slave_index <= r_slave_index + 1;
                    end

                    // 等待缓存更新好
                    if (read_en) begin
                        r_write_en <= 0;
                        r_write_addr <= 0;
                        r_write_inst <= 0;
                        icache_read_state <= return_cache_t;
                    end
                end

                `ifndef IN_YOSYS_STA
                default: $error("icache found unknown read state %x", icache_read_state);
                `endif
            endcase
        end
    end
end

endmodule


/* 单个缓存块 */
module icache_block #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter INST_WIDTH = 32,
    parameter block_count = 16
) (
    input   wire                        clk,
    input   wire                        rst,
    input   wire [ADDR_WIDTH-1:0]       write_addr,
    input   wire                        write_en,
    input   wire [log2(block_count)-1:0] write_index,
    input   wire [INST_WIDTH-1:0]       write_inst,
    input   wire [ADDR_WIDTH-1:0]       read_addr,
    output  wire                        read_en,
    output  wire [INST_WIDTH-1:0]       read_inst
);

localparam check_cache_t = 0;
localparam return_cache_t = 1;
localparam update_cache_t = 2;

/*
 31    m+n m+n-1   m m-1    0
+---------+---------+--------+
|   tag   |  index  | offset |
+---------+---------+--------+
*/
localparam tag_width = ADDR_WIDTH - (offset_width+index_width);
localparam block_width = INST_WIDTH*block_count;
localparam offset_width = log2(INST_WIDTH/8);
localparam index_width = log2(block_count);
localparam index_max = {index_width{1'h1}};

reg [block_width-1:0] block = 0;
wire valid = tag==rtag;
reg [tag_width-1:0] tag = 0;
reg [log2(block_count)-1:0] current_write_index = 0;
reg [1:0] cache_state = check_cache_t;

wire [tag_width-1:0] rtag = read_addr[index_width+offset_width +: tag_width];
wire [index_width-1:0] rindex = read_addr[offset_width +: index_width];
wire [offset_width-1:0] roffset = read_addr[0 +: offset_width];

wire [tag_width-1:0] wtag = write_addr[index_width+offset_width +: tag_width];
wire [index_width-1:0] windex = write_addr[offset_width +: index_width];
wire [offset_width-1:0] woffset = write_addr[0 +: offset_width];

assign read_en = valid && rtag==tag && cache_state==check_cache_t;
generate
    for (genvar offset=0; offset<(INST_WIDTH/8); ++offset) begin
        assign read_inst[offset*8 +: 8] = read_en ? block[((offset + {rindex, roffset})*8)%block_width +: 8] : 0;
    end
endgenerate

always @(posedge clk) begin
    if (rst || valid) begin
        current_write_index <= 0;
        cache_state <= check_cache_t;
    end else begin
        case (cache_state)
        check_cache_t: begin
            if (write_en) begin
                cache_state <= update_cache_t;
                tag <= rtag^{tag_width{1'h1}};
            end
        end

        update_cache_t: begin
            if (write_en) begin
                if (current_write_index == write_index) begin
                    current_write_index <= write_index + 1;
                    for (integer offset=0; offset<(INST_WIDTH/8); ++offset) begin
                        block[((offset[0 +: offset_width+index_width] + {windex, woffset})*8)%block_width +: 8] <= write_inst[offset*8 +: 8];
                    end

                    if (write_index == index_max && !valid) begin
                        tag <= wtag;
                        current_write_index <= 0;
                        cache_state <= check_cache_t;
                    end
                end
            end
        end

        endcase
    end
end

endmodule
