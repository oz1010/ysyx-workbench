`include "riscv32e_defines.v"

`ifndef IN_YOSYS_STA

module sram_axi4 #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SRAM_READ_DELAY = 0
) (
    input wire clk,
    input wire rst,

    input wire awvalid,
    output wire awready,
    input wire [ADDR_WIDTH-1:0] awaddr,

    input wire wvalid,
    output wire wready,
    input wire [DATA_WIDTH-1:0] wdata,
    input wire [DATA_WIDTH/8-1:0] wstrb,

    output wire bvalid,
    input wire bready,
    output wire [BRESP_WIDTH-1:0] bresp,

    input wire arvalid,
    output wire arready,
    input wire [ADDR_WIDTH-1:0] araddr,

    output wire rvalid,
    input wire rready,
    output wire [DATA_WIDTH-1:0] rdata,
    output wire [RRESP_WIDTH-1:0] rresp
);

reg [7:0] r_delay_cnt;
reg r_delay_enable;
reg [ADDR_WIDTH-1:0] r_write_addr;

reg r_awready;
reg r_wready;
reg r_bvalid;
reg [BRESP_WIDTH-1:0] r_bresp;
reg r_arready;
reg r_rvalid;
reg [DATA_WIDTH-1:0] r_rdata;
reg [RRESP_WIDTH-1:0] r_rresp;

wire [DATA_WIDTH-1:0] w_write_width = {{DATA_WIDTH-DATA_WIDTH/8{1'b0}}, wstrb};

assign awready = r_awready;
assign wready = r_wready;
assign bvalid = r_bvalid;
assign bresp = r_bresp;
assign arready = r_arready;
assign rvalid = r_rvalid;
assign rdata = r_rdata;
assign rresp = r_rresp;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_delay_cnt <= 8'h0;
        r_delay_enable <= 0;
    end else begin
        r_delay_cnt <= r_delay_cnt;
        r_delay_enable <= r_delay_enable;

        if (r_delay_enable) begin
            r_delay_cnt <= r_delay_cnt + 1;
        end else begin
            r_delay_cnt <= 8'h0;
        end

        if (!r_delay_enable && arvalid) begin
            r_delay_enable <= 1;
            r_delay_cnt <= 1;
        end
        if (rvalid && rready) begin
            r_delay_enable <= 0;
        end
    end
end

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_write_addr <= 0;
        r_awready <= 0;
        r_wready <= 0;
        r_bvalid <= 0;
        r_bresp <= 0;
        r_arready <= 0;
        r_rvalid <= 0;
        r_rdata <= 0;
        r_rresp <= 0;
    end else begin
        r_write_addr <= r_write_addr;
        r_awready <= r_awready;
        r_wready <= r_wready;
        r_bvalid <= r_bvalid;
        r_bresp <= r_bresp;
        r_arready <= r_arready;
        r_rvalid <= r_rvalid;
        r_rdata <= r_rdata;
        r_rresp <= r_rresp;

        // write request
        if (awvalid) begin
            r_awready <= 1;
        end
        if (awvalid && awready) begin
            r_write_addr <= awaddr;
            r_awready <= 0;
        end

        // write data
        if (awvalid && awready) begin
            r_wready <= 1;
        end
        if (wvalid && wready) begin
            write_raw_mem(r_write_addr, w_write_width, wdata);
            r_wready <= 0;
        end

        // write response
        if (wvalid && wready) begin
            r_bvalid <= 1;
            r_bresp <= 1;
        end
        if (bvalid && bready) begin
            r_bvalid <= 0;
            r_bresp <= 0;
        end

        // read request
        if (!r_arready && !rready && arvalid) begin
            r_arready <= 1;
        end
        if (arvalid && arready) begin
            r_arready <= 0;
        end

        // read data
        if ((!r_delay_enable && arvalid && 0 == SRAM_READ_DELAY) ||
            (r_delay_enable && r_delay_cnt == SRAM_READ_DELAY)) begin
            r_rdata <= fetch_inst(araddr);
            r_rvalid <= 1;
        end
        if (rvalid && rready) begin
            r_rvalid <= 0;
            // r_rdata <= 0;
            r_rresp <= 0;
        end
    end
end

endmodule

module sram_axi4_arbiter #(
    parameter MASTER_COUNT = 1,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3,
    parameter SRAM_READ_DELAY = 0
) (
    input wire clk,
    input wire rst,

    input wire awvalids[MASTER_COUNT-1:0],
    output wire awreadys[MASTER_COUNT-1:0],
    input wire [ADDR_WIDTH-1:0] awaddrs[MASTER_COUNT-1:0],
    input wire wvalids[MASTER_COUNT-1:0],
    output wire wreadys[MASTER_COUNT-1:0],
    input wire [DATA_WIDTH-1:0] wdatas[MASTER_COUNT-1:0],
    input wire [DATA_WIDTH/8-1:0] wstrbs[MASTER_COUNT-1:0],
    output wire bvalids[MASTER_COUNT-1:0],
    input wire breadys[MASTER_COUNT-1:0],
    output wire [BRESP_WIDTH-1:0] bresps[MASTER_COUNT-1:0],
    input wire arvalids[MASTER_COUNT-1:0],
    output wire arreadys[MASTER_COUNT-1:0],
    input wire [ADDR_WIDTH-1:0] araddrs[MASTER_COUNT-1:0],
    output wire rvalids[MASTER_COUNT-1:0],
    input wire rreadys[MASTER_COUNT-1:0],
    output wire [DATA_WIDTH-1:0] rdatas[MASTER_COUNT-1:0],
    output wire [RRESP_WIDTH-1:0] rresps[MASTER_COUNT-1:0]
);

sram_axi4 #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH),
    .SRAM_READ_DELAY(SRAM_READ_DELAY)
) m_sram_axi4(
    .clk(clk),
    .rst(rst),
    .awvalid(awvalid),
    .awready(awready),
    .awaddr(awaddr),
    .wvalid(wvalid),
    .wready(wready),
    .wdata(wdata),
    .wstrb(wstrb),
    .bvalid(bvalid),
    .bready(bready),
    .bresp(bresp),
    .arvalid(arvalid),
    .arready(arready),
    .araddr(araddr),
    .rvalid(rvalid),
    .rready(rready),
    .rdata(rdata),
    .rresp(rresp)
);

reg [MASTER_COUNT-1:0] signal_enable;
reg [MASTER_COUNT:0] grant;  // Master 授权信号
reg [MASTER_COUNT:0] last_granted;  // 记录上次被仲裁成功的 Master 编号

reg awvalid;
wire awready;
reg [ADDR_WIDTH-1:0] awaddr;
reg wvalid;
wire wready;
reg [DATA_WIDTH-1:0] wdata;
reg [DATA_WIDTH/8-1:0] wstrb;
wire bvalid;
reg bready;
wire [BRESP_WIDTH-1:0] bresp;
reg arvalid;
wire arready;
reg [ADDR_WIDTH-1:0] araddr;
wire rvalid;
reg rready;
wire [DATA_WIDTH-1:0] rdata;
wire [RRESP_WIDTH-1:0] rresp;

genvar i;
generate
    for (i = 0; i < MASTER_COUNT; ++i) begin : signal_gen
        assign signal_enable[i] = awvalids[i] | wvalids[i] | bvalids[i] | arvalids[i] | rvalids[i];

        assign awreadys[i] = (awready & {$bits(awready){grant[i]}});
        assign wreadys[i] = (wready & {$bits(wready){grant[i]}});
        assign bvalids[i] = (bvalid & {$bits(bvalid){grant[i]}});
        assign bresps[i] = bresp;
        assign arreadys[i] = (arready & {$bits(arready){grant[i]}});
        assign rvalids[i] = (rvalid & {$bits(rvalid){grant[i]}});
        assign rdatas[i] = rdata;
        assign rresps[i] = (rresp & {$bits(rresp){grant[i]}});
    end
endgenerate

always @(*) begin
    awvalid = 0;
    awaddr = 0;
    wvalid = 0;
    wdata = 0;
    wstrb = 0;
    bready = 0;
    arvalid = 0;
    araddr = 0;
    rready = 0;

    for (int m=0; m<MASTER_COUNT; ++m) begin
        if (grant[m]) begin
            awvalid = awvalids[m];
            awaddr = awaddrs[m];
            wvalid = wvalids[m];
            wdata = wdatas[m];
            wstrb = wstrbs[m];
            bready = breadys[m];
            arvalid = arvalids[m];
            araddr = araddrs[m];
            rready = rreadys[m];
            break;
        end
    end
end

integer t;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        grant <= 0;
        last_granted <= 0;
    end else begin
        grant <= 0; // default is not granted

        for (t=0; t<MASTER_COUNT; ++t) begin
            if (signal_enable[(last_granted + t[MASTER_COUNT:0]) % MASTER_COUNT]) begin
                grant[(last_granted + t[MASTER_COUNT:0]) % MASTER_COUNT] <= 1;
                last_granted <= (last_granted + t[MASTER_COUNT:0]) % MASTER_COUNT;
                break;
            end
        end
    end    
end

endmodule

`endif
