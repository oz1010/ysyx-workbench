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
    input   wire                        clock,
    input   wire                        reset,

    /* req-resp总线slave（连接IFU） */
    output  wire                        m_req_ready,
    input   wire                        m_req_valid,
    input   wire [ADDR_WIDTH-1:0]       m_req_addr,
    input   wire                        m_req_is_write,
    input   wire [DATA_WIDTH-1:0]       m_req_wdata,
    input   wire [DATA_WIDTH/8-1:0]     m_req_wstrb,
    input   wire                        m_resp_ready,
    output  wire                        m_resp_valid,
    output  wire [DATA_WIDTH-1:0]       m_resp_data,

    /* AXI4总线master（连接arbiter） */
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

    /* 读请求命中状态（2bit）：NONE/HIT/MISS；仅可缓存地址（flash/psram/sdram/mrom）有
     * 统计数据，不可缓存地址（片内sram）透传访问和写均为NONE */
    output  reg                         cache_en,
    output  reg  [1:0]                  cache_stat
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

`ifdef CONFIG_ICACHE
wire m_req_cacheable =
       ( m_req_addr>=`CONFIG_MROM_BASE && m_req_addr<=(`CONFIG_MROM_BASE+`CONFIG_MROM_SIZE))
    || ( m_req_addr>=`CONFIG_FLASH_BASE && m_req_addr<=(`CONFIG_FLASH_BASE+`CONFIG_FLASH_SIZE) )
    || ( m_req_addr>=`CONFIG_PSRAM_BASE && m_req_addr<=(`CONFIG_PSRAM_BASE+`CONFIG_PSRAM_SIZE) )
    || ( m_req_addr>=`CONFIG_SDRAM_BASE && m_req_addr<=(`CONFIG_SDRAM_BASE+`CONFIG_SDRAM_SIZE) );
`else
wire m_req_cacheable = 0;
`endif // CONFIG_ICACHE

/* master侧（req-resp）状态机 */
localparam M_STATE_IDLE  = 2'h0; // 等待请求
localparam M_STATE_CREAD = 2'h1; // 可缓存读，等待cache命中数据
localparam M_STATE_PTRD  = 2'h2; // 不可缓存读，透传到slave
localparam M_STATE_PTWR  = 2'h3; // 写，透传到slave
reg [1:0]                   r_m_state = M_STATE_IDLE;
reg [ADDR_WIDTH-1:0]        r_m_addr = 0;
reg [DATA_WIDTH-1:0]        r_m_wdata = 0;
reg [DATA_WIDTH/8-1:0]      r_m_wstrb = 0;
reg                         r_m_resp_valid = 0;
reg [DATA_WIDTH-1:0]        r_m_resp_data = 0;
reg                         r_s_aw_done = 0;
reg                         r_s_w_done = 0;

wire m_req_fire = m_req_valid && m_req_ready;
assign m_req_ready = (r_m_state==M_STATE_IDLE) &&
    (m_req_is_write ? 1'b1 : (m_req_cacheable ? 1'b1 : s_arready));

/* 透传写通道（aw与w通道独立握手，各自完成后等待写响应）；
   写地址需保持到写响应返回，仲裁器据此维持master选中状态 */
assign s_awvalid = (r_m_state==M_STATE_PTWR) && !r_s_aw_done;
assign s_awaddr  = (r_m_state==M_STATE_PTWR) ? r_m_addr : 0;
assign s_awid    = `AXI4_ID_IFU;
assign s_awlen   = 0;
assign s_awsize  = 2;
assign s_awburst = 1;
assign s_wvalid  = (r_m_state==M_STATE_PTWR) && !r_s_w_done;
assign s_wdata   = s_wvalid ? r_m_wdata : 0;
assign s_wstrb   = s_wvalid ? r_m_wstrb : 0;
assign s_wlast   = 1;
assign s_bready  = (r_m_state==M_STATE_PTWR) && m_resp_ready;

/* 透传读在请求被接受的同时发出（arready为请求接受条件），否则ar通道由cache填充使用 */
wire pt_ar = (r_m_state==M_STATE_IDLE) && m_req_valid && !m_req_is_write && !m_req_cacheable;

assign m_resp_valid = (r_m_state==M_STATE_CREAD) ? r_m_resp_valid :
                      (r_m_state==M_STATE_PTRD) ? (s_rvalid && s_rlast) :
                      (r_m_state==M_STATE_PTWR) ? s_bvalid : 1'b0;
assign m_resp_data = (r_m_state==M_STATE_CREAD) ? r_m_resp_data :
                     (r_m_state==M_STATE_PTRD) ? s_rdata : 0;

/* 与slave端通信（cache填充通道） */
wire                        c_s_arready;
wire                        c_s_rvalid;
wire [RRESP_WIDTH-1:0]      c_s_rresp;
wire [DATA_WIDTH-1:0]       c_s_rdata;
wire                        c_s_rlast;
wire [3:0]                  c_s_rid;
wire                        c_s_arvalid;
wire [ADDR_WIDTH-1:0]       c_s_araddr;
wire [3:0]                  c_s_arid;
wire [7:0]                  c_s_arlen;
wire [2:0]                  c_s_arsize;
wire [1:0]                  c_s_arburst;
wire                        c_s_rready;
wire [1:0]                  slave_state;

assign c_s_arready = s_arready;
assign c_s_rvalid = s_rvalid;
assign c_s_rresp = s_rresp;
assign c_s_rdata = s_rdata;
assign c_s_rlast = s_rlast;
assign c_s_rid = s_rid;

assign s_arvalid = pt_ar ? 1'b1 : c_s_arvalid;
/* 透传读期间需保持araddr非零，仲裁器据此维持master选中状态以回送响应 */
assign s_araddr  = pt_ar ? m_req_addr :
                   (r_m_state==M_STATE_PTRD) ? r_m_addr : c_s_araddr;
assign s_arid    = pt_ar ? `AXI4_ID_IFU : c_s_arid;
assign s_arlen   = pt_ar ? 8'd0 : c_s_arlen;
assign s_arsize  = pt_ar ? 3'd2 : c_s_arsize;
assign s_arburst = pt_ar ? 2'd1 : c_s_arburst;
assign s_rready  = (r_m_state==M_STATE_PTRD) ? m_resp_ready : c_s_rready;

wire slave_len_burst_en = ( r_m_addr>=`CONFIG_SDRAM_BASE && r_m_addr<=(`CONFIG_SDRAM_BASE+`CONFIG_SDRAM_SIZE) );

wire                        slave_en; // 从设备使能标记
reg  [ADDR_WIDTH-1:0]       r_slave_addr; // 从设备读取地址
wire [INST_WIDTH-1:0]       slave_inst; // 从设备读取指令
reg  [31:0]                 r_slave_index; // 从设备指令计数
wire [7:0]                  slave_len; // 从设备burst模式读取的长度
assign slave_len = slave_len_burst_en ? cache_line_load_len[7:0] : 0; // 其他存储器比如flash暂时不支持burst模式

initial begin
    r_slave_addr = 0;
    r_slave_index = 0;
end

assign slave_en = impl_update_en && r_slave_index<cache_line_load_count;

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
    .clock(clock),
    .reset(reset),
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
    .read_len(slave_len),
    .read_size(2),
    .read_state(slave_state)
);

reg [ADDR_WIDTH-1:0]       impl_addr;
reg                        impl_update_en;
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
) icache_impl (
    .clock(clock),
    .reset(reset),
    .addr(impl_addr),
    .update_en(impl_update_en),
    .reset_en(0),
    .write_en(impl_write_en),
    .write_data(impl_write_data),
    .read_en(impl_read_en),
    .read_data(impl_read_data)
);
/* 空闲时地址跟随当前请求（采样命中状态），接受请求后保持锁存地址 */
assign impl_addr = (r_m_state==M_STATE_IDLE) ? m_req_addr : r_m_addr;
assign impl_write_en = impl_update_en && c_s_rvalid && c_s_rready;
assign impl_write_data = c_s_rdata;

always @(posedge clock) begin
    if (reset) begin
        r_m_state <= M_STATE_IDLE;
        r_m_addr <= 0;
        r_m_wdata <= 0;
        r_m_wstrb <= 0;
        r_m_resp_valid <= 0;
        r_m_resp_data <= 0;
        r_s_aw_done <= 0;
        r_s_w_done <= 0;
        impl_update_en <= 0;
        cache_stat <= `CACHE_STAT_NONE;
        cache_en <= 0;
    end else begin
        cache_en <= 0;
        case (r_m_state)
            M_STATE_IDLE: begin
                if (m_req_fire) begin
                    r_m_addr <= m_req_addr;
                    r_m_wdata <= m_req_wdata;
                    r_m_wstrb <= m_req_wstrb;
                    if (m_req_is_write) begin
                        // 写请求透传给slave
                        r_m_state <= M_STATE_PTWR;
                    end else if (m_req_cacheable) begin
                        // 可缓存读：请求被接受时采样命中状态
                        r_m_state <= M_STATE_CREAD;
                        cache_en <= 1;
                        cache_stat <= impl_read_en ? `CACHE_STAT_HIT : `CACHE_STAT_MISS;
                    end else begin
                        // 不可缓存读请求透传给slave
                        r_m_state <= M_STATE_PTRD;
                        cache_stat <= `CACHE_STAT_NONE;
                    end
                end
            end

            M_STATE_CREAD: begin
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
                        r_slave_addr <= {r_m_addr[ADDR_WIDTH-1:offset_width], {(offset_width){1'b0}}};
                        r_slave_index <= 0;
                    end
                end

                // cache数据有效后返回响应
                if (impl_read_en) begin
                    r_m_resp_data <= impl_read_data;
                    r_m_resp_valid <= 1;
                end
                if (r_m_resp_valid && m_resp_ready) begin
                    r_m_resp_valid <= 0;
                    r_m_state <= M_STATE_IDLE;
                end
            end

            M_STATE_PTRD: begin
                if (s_rvalid && s_rready && s_rlast) begin
                    r_m_state <= M_STATE_IDLE;
                end
            end

            M_STATE_PTWR: begin
                if (s_awvalid && s_awready) begin
                    r_s_aw_done <= 1;
                end
                if (s_wvalid && s_wready) begin
                    r_s_w_done <= 1;
                end
                if (s_bvalid && s_bready) begin
                    `ifndef IN_YOSYS_STA
                    if (s_bresp!=0 || s_bid!=`AXI4_ID_IFU) begin
                        $error("icache pass-through write error, addr:%x resp:%x id:%x\n", r_m_addr, s_bresp, s_bid);
                    end
                    `endif
                    r_s_aw_done <= 0;
                    r_s_w_done <= 0;
                    r_m_state <= M_STATE_IDLE;
                end
            end

            `ifndef IN_YOSYS_STA
            default: $error("icache found unknown m_state(%d)", r_m_state);
            `endif
        endcase
    end
end

endmodule
