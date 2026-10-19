module riscv32e_memsys #(
    parameter INST_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire         clk,
    input  wire         rst,

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

    output wire         done
);

assign io_master_awvalid = 0;
assign io_master_awaddr = 0;
assign io_master_awid = 0;
assign io_master_awlen = 0;
assign io_master_awsize = 4;
assign io_master_awburst = 0;
assign io_master_wvalid = 0;
assign io_master_wdata = 0;
assign io_master_wstrb = 0;
assign io_master_wlast = 0;
assign io_master_bready = 0;
assign io_master_arvalid = 0;
assign io_master_araddr = 0;
assign io_master_arid = 0;
assign io_master_arlen = 0;
assign io_master_arsize = 0;
assign io_master_arburst = 0;
assign io_master_rready = 0;

endmodule
