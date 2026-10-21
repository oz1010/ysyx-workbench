module exter_dev #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clock,
    input wire reset,

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

wire in_write_mode = (awready || wready || bvalid);
wire write_enable = (awvalid || wready || bvalid);

wire read_enable = (arvalid || rready);

`ifdef IN_YOSYS_STA
reg [31:0] exter_dev_regs[0:31];
`endif

wire [ADDR_WIDTH-1:0]       write_addr;
wire [DATA_WIDTH-1:0]       write_data;
wire [2:0]                  write_size;
wire                        write_valid;

reg                         r_data_en;
wire [ADDR_WIDTH-1:0]       read_addr;
reg  [DATA_WIDTH-1:0]       r_read_data;
wire [2:0]                  read_size;
wire [1:0]                  read_state;

axi4_salve_writer #(
    `ifndef IN_YOSYS_STA
    .NAME("exter_dev"),
    `endif
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi4_salve_writer (
    .clock(clock),
    .reset(reset),
    .awready(awready),
    .awvalid(awvalid),
    .awaddr(awaddr),
    .awid(awid),
    .awlen(awlen),
    .awsize(awsize),
    .awburst(awburst),
    .wready(wready),
    .wvalid(wvalid),
    .wdata(wdata),
    .wstrb(wstrb),
    .wlast(wlast),
    .bready(bready),
    .bvalid(bvalid),
    .bresp(bresp),
    .bid(bid),
    .enable(write_enable),
    .write_addr(write_addr),
    .write_data(write_data),
    .write_size(write_size),
    .write_valid(write_valid)
);

axi4_salve_reader #(
    `ifndef IN_YOSYS_STA
    .NAME("exter_dev"),
    `endif
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi4_salve_reader (
    .clock(clock),
    .reset(reset),
    .arready(arready),
    .arvalid(arvalid),
    .araddr(araddr),
    .arid(arid),
    .arlen(arlen),
    .arsize(arsize),
    .arburst(arburst),
    .rready(rready),
    .rvalid(rvalid),
    .rresp(rresp),
    .rdata(rdata),
    .rlast(rlast),
    .rid(rid),
    .enable(read_enable),
    .data_en(r_data_en),
    .read_addr(read_addr),
    .read_data(r_read_data),
    .read_len(),
    .read_size(read_size),
    .read_state(read_state)
);

wire [31:0] w_real_read_size = 1<<read_size;
/* 使用组合逻辑读取数据，否则一个周期的ar信号可能无法满足要求 */
always @(*) begin
    r_read_data = 0;
    r_data_en = 0;
    if (read_enable) begin
        if (arvalid && arready) begin
            r_data_en = 1;
            `ifndef IN_YOSYS_STA
            if (w_real_read_size != 4) $error("extra dev only support read 4bytes, addr:%x size:%x", araddr, w_real_read_size);
            r_read_data = dpi_vdev_read(read_addr, w_real_read_size);
            `else
            r_read_data = exter_dev_regs[read_addr[4:0]];
            `endif
        end
    end
end

always @(posedge clock or posedge reset) begin
    if (reset) begin
    end else begin
        if (in_write_mode && wvalid && wready) begin
            `ifndef IN_YOSYS_STA
            dpi_vdev_write(write_addr, write_data, 1<<write_size);
            `else
            exter_dev_regs[write_addr[4:0]] <= write_data;
            `endif
        end
    end
end

endmodule
