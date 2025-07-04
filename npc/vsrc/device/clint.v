module clint #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    output  wire                        awready,
    input   wire                        awvalid,
    input   wire [ADDR_WIDTH-1:0]       awaddr,
    input   wire [3:0]                  awid,
    input   wire [7:0]                  awlen,
    input   wire [2:0]                  awsize,
    input   wire [1:0]                  awburst,
    output  wire                        wready,
    input   wire                        wvalid,
    input   wire [DATA_WIDTH-1:0]       wdata,
    input   wire [DATA_WIDTH/8-1:0]     wstrb,
    input   wire                        wlast,
    input   wire                        bready,
    output  wire                        bvalid,
    output  wire [BRESP_WIDTH-1:0]      bresp,
    output  wire [3:0]                  bid,
    output  wire                        arready,
    input   wire                        arvalid,
    input   wire [ADDR_WIDTH-1:0]       araddr,
    input   wire [3:0]                  arid,
    input   wire [7:0]                  arlen,
    input   wire [2:0]                  arsize,
    input   wire [1:0]                  arburst,
    input   wire                        rready,
    output  wire                        rvalid,
    output  wire [RRESP_WIDTH-1:0]      rresp,
    output  wire [DATA_WIDTH-1:0]       rdata,
    output  wire                        rlast,
    output  wire [3:0]                  rid
);

reg                                     r_awready = 0;
reg                                     r_wready = 0;
reg                                     r_bvalid = 0;
reg [BRESP_WIDTH-1:0]                   r_bresp = 0;
reg [3:0]                               r_bid = 0;
reg                                     r_arready;
reg                                     r_rvalid;
reg [RRESP_WIDTH-1:0]                   r_rresp;
reg [DATA_WIDTH-1:0]                    r_rdata;
reg                                     r_rlast;
reg [3:0]                               r_rid;

reg [ADDR_WIDTH-1:0] r_write_addr;

wire [DATA_WIDTH-1:0] w_write_width = {{DATA_WIDTH-DATA_WIDTH/8{1'b0}}, wstrb};

assign awready = r_awready;
assign wready = r_wready;
assign bvalid = r_bvalid;
assign bresp = r_bresp;
assign bid = r_bid;
assign arready = r_arready;
assign rvalid = r_rvalid;
assign rresp = r_rresp;
assign rdata = r_rdata;
assign rlast = r_rlast;
assign rid = r_rid;

wire [31:0] read_len = 1<<arlen;      // burst写入数量，2^n字节
wire [31:0] read_size = 1<<arsize;    // 单个burst写入数据大小，2^n字节

`ifdef IN_YOSYS_STA
reg [31:0] rtc_ticks;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        rtc_ticks <= 0;
    end else begin
        rtc_ticks <= rtc_ticks + 1;
    end
end
`endif


always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_awready <= 0;
        r_wready <= 0;
        r_bvalid <= 0;
        r_bresp <= 0;
        r_bid <= 0;
        r_arready <= 0;
        r_rvalid <= 0;
        r_rresp <= 0;
        r_rdata <= 0;
        r_rlast <= 0;
        r_rid <= 0;

        r_write_addr <= 0;
    end else begin
        r_awready <= r_awready;
        r_wready <= r_wready;
        r_bvalid <= r_bvalid;
        r_bresp <= r_bresp;
        r_bid <= r_bid;
        r_arready <= r_arready;
        r_rvalid <= r_rvalid;
        r_rresp <= r_rresp;
        r_rdata <= r_rdata;
        r_rlast <= r_rlast;
        r_rid <= r_rid;

        r_write_addr <= r_write_addr;

        // read request
        if (arvalid) begin
            r_arready <= 1;
        end
        if (arvalid && arready) begin
            r_arready <= 0;
        end

        // read data
        if (arvalid && arready) begin
`ifdef IN_YOSYS_STA
            r_rdata <= rtc_ticks;
`else
            if (read_size != 4) $error("clint only support read 4bytes, addr:%x size:%x", araddr, read_size);

            r_rdata <= dpi_rtc_read(araddr, read_size);
`endif

            r_rvalid <= 1;
            r_rresp <= 0;
            r_rlast <= 1;
            r_rid <= arid;
        end
        if (rvalid && rready) begin
            r_rvalid <= 0;
            r_rresp <= 0;
            r_rlast <= 0;
            r_rid <= 0;
        end
    end
end

endmodule
