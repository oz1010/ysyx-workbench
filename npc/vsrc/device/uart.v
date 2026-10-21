`ifndef IN_YOSYS_STA
module uart #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clock,
    input wire reset,

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

always @(posedge clock or posedge reset) begin
    if (reset) begin
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
            // $display("====== uart:%x strb:%d '%c'", r_write_addr, wstrb, wdata[7:0]);
            // print data
            // $write("%c", wdata[7:0]);
            // $fflush();
            dpi_uart_write(r_write_addr, w_write_width, wdata);
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
        // if (!r_arready && !rready) begin
        //     r_arready <= 1;
        // end
        // if (arvalid && arready) begin
        //     r_arready <= 0;
        // end

        // read data
        if (arvalid && arready) begin
            $display("uart don't support read, addr:%x", araddr);
            $finish();
            r_rvalid <= 1;
        end
        if (rvalid && rready) begin
            r_rvalid <= 0;
            r_rresp <= 0;
        end
    end
end

endmodule

`endif
