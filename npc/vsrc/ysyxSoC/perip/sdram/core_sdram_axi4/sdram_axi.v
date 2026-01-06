//-----------------------------------------------------------------
//                    SDRAM Controller (AXI4)
//                           V1.0
//                     Ultra-Embedded.com
//                     Copyright 2015-2019
//
//                 Email: admin@ultra-embedded.com
//
//                         License: GPL
// If you would like a version with a more permissive license for
// use in closed source commercial applications please contact me
// for details.
//-----------------------------------------------------------------
//
// This file is open source HDL; you can redistribute it and/or
// modify it under the terms of the GNU General Public License as
// published by the Free Software Foundation; either version 2 of
// the License, or (at your option) any later version.
//
// This file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public
// License along with this file; if not, write to the Free Software
// Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
// USA
//-----------------------------------------------------------------

//-----------------------------------------------------------------
//                          Generated File
//-----------------------------------------------------------------

module sdram_axi
(
    // Inputs
     input           clk_i
    ,input           rst_i
    ,input           inport_awvalid_i
    ,input  [ 31:0]  inport_awaddr_i
    ,input  [  3:0]  inport_awid_i
    ,input  [  7:0]  inport_awlen_i
    ,input  [  1:0]  inport_awburst_i
    ,input           inport_wvalid_i
    ,input  [ 31:0]  inport_wdata_i
    ,input  [  3:0]  inport_wstrb_i
    ,input           inport_wlast_i
    ,input           inport_bready_i
    ,input           inport_arvalid_i
    ,input  [ 31:0]  inport_araddr_i
    ,input  [  3:0]  inport_arid_i
    ,input  [  7:0]  inport_arlen_i
    ,input  [  2:0]  inport_arsize_i
    ,input  [  1:0]  inport_arburst_i
    ,input           inport_rready_i
    ,input  [`SDRAM_DATA_BITS-1:0]  sdram_data_input_i

    // Outputs
    ,output          inport_awready_o
    ,output          inport_wready_o
    ,output          inport_bvalid_o
    ,output [  1:0]  inport_bresp_o
    ,output [  3:0]  inport_bid_o
    ,output          inport_arready_o
    ,output          inport_rvalid_o
    ,output [ 31:0]  inport_rdata_o
    ,output [  1:0]  inport_rresp_o
    ,output [  3:0]  inport_rid_o
    ,output          inport_rlast_o
    ,output          sdram_clk_o
    ,output          sdram_cke_o
    ,output          sdram_cs_o
    ,output          sdram_ras_o
    ,output          sdram_cas_o
    ,output          sdram_we_o
    ,output [`SDRAM_DATA_MASK_BITS-1:0]  sdram_dqm_o
    ,output [`SDRAM_BLK_NUM-1:0]  sdram_bsel_o
    ,output [ 12:0]  sdram_addr_o
    ,output [  1:0]  sdram_ba_o
    ,output [`SDRAM_DATA_BITS-1:0]  sdram_data_output_o
    ,output          sdram_data_out_en_o
);

// TODO 暂时不处理sdram控制器的这些逻辑，这里直接读写取指定地址的数据
assign sdram_clk_o = 0;
assign sdram_cke_o = 0;
assign sdram_cs_o = 0;
assign sdram_ras_o = 0;
assign sdram_cas_o = 0;
assign sdram_we_o = 0;
assign sdram_dqm_o = 0;
assign sdram_bsel_o = 0;
assign sdram_addr_o = 0;
assign sdram_ba_o = 0;
assign sdram_data_output_o = 0;
assign sdram_data_out_en_o = 0;

reg          r_awready;
reg          r_wready;
reg          r_bvalid;
reg [  1:0]  r_bresp;
reg [  3:0]  r_bid;

assign inport_awready_o = r_awready;
assign inport_wready_o = r_wready;
assign inport_bvalid_o = r_bvalid;
assign inport_bresp_o = r_bresp;
assign inport_bid_o = r_bid;

localparam idle_t = 0;
localparam data_t = 1;
localparam resp_t = 2;

parameter ADDR_WIDTH = 32;
parameter DATA_WIDTH = 32;
parameter BRESP_WIDTH = 3;
parameter RRESP_WIDTH = 2;

wire [ADDR_WIDTH-1:0]       read_addr;
wire [ADDR_WIDTH-1:0]       read_addr_align;
wire [7:0]                  read_len;
wire [2:0]                  read_size;
wire [31:0]                 read_index;
wire [1:0]                  read_state;
reg                         r_read_data_en;
reg [DATA_WIDTH-1:0]        r_read_data;
assign read_addr_align = {read_addr[DATA_WIDTH-1:2], {2{1'b0}}} + read_index*(1<<read_size);
axi4_salve_burst_reader #(
    `ifndef IN_YOSYS_STA
    .NAME("sdram_reader"),
    `endif
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi4_salve_reader (
    .clk(clk_i),
    .rst(rst_i),
    .arready(inport_arready_o),
    .arvalid(inport_arvalid_i),
    .araddr(inport_araddr_i),
    .arid(inport_arid_i),
    .arlen(inport_arlen_i),
    .arsize(inport_arsize_i),
    .arburst(inport_arburst_i),
    .rready(inport_rready_i),
    .rvalid(inport_rvalid_o),
    .rresp(inport_rresp_o),
    .rdata(inport_rdata_o),
    .rlast(inport_rlast_o),
    .rid(inport_rid_o),
    .enable(1),
    .read_data_en(r_read_data_en),
    .read_data(r_read_data),
    .read_addr(read_addr),
    .read_len(read_len),
    .read_size(read_size),
    .read_index(read_index),
    .read_state(read_state)
);

reg [31:0] rindex_max;
reg [31:0] read_tick;
wire [31:0] read_tick_max = 4; /* tick经历范围为 0-5，总计6个时钟周期 */
always @(posedge clk_i) begin
    if (rst_i) begin
        r_read_data_en <= 0;
        r_read_data <= 0;
        rindex_max <= 0;
        read_tick <= 0;
    end else begin
        case (read_state)
            `AXI4_STATE_ADDR: begin
                r_read_data_en <= 0;
                r_read_data <= 0;

                if (inport_arvalid_i && inport_arready_o) begin
                    rindex_max <= (1<<inport_arlen_i)-1;
                    read_tick <= 0;
                end
            end

            `AXI4_STATE_DATA: begin
                read_tick <= read_tick + 1;

                if (read_tick == read_tick_max) begin
                    r_read_data_en <= 1;
                    r_read_data <= dpi_vdev_read(read_addr_align, (1<<read_size));
                end

                if (inport_rvalid_o && inport_rready_i) begin
                    // $display("sdram read data done, addr %x data %x size %x index %x", read_addr_align, r_read_data, ((1<<read_size)), read_index);

                    r_read_data_en <= 0;
                    r_read_data <= 0;
                    read_tick <= 0;
                end
            end

            `ifndef IN_YOSYS_STA
            default: $error("unknown read state %d", read_state);
            `endif
        endcase
    end
end

reg [1:0] wstate;
always @(posedge clk_i) begin
    if (rst_i) begin
        r_awready <= 0;
        r_wready <= 0;
        r_bvalid <= 0;
        r_bresp <= 0;
        r_bid <= 0; 
    end else begin
    end
end


//-----------------------------------------------------------------
// Key Params
//-----------------------------------------------------------------
parameter SDRAM_MHZ             = 50;
parameter SDRAM_ADDR_W          = 24;
parameter SDRAM_COL_W           = 9;
parameter SDRAM_READ_LATENCY    = 2;

// //-----------------------------------------------------------------
// // AXI Interface
// //-----------------------------------------------------------------
// wire [ 31:0]  ram_addr_w;
// wire [  3:0]  ram_wr_w;
// wire          ram_rd_w;
// wire          ram_accept_w;
// wire [ 31:0]  ram_write_data_w;
// wire [ 31:0]  ram_read_data_w;
// wire [  7:0]  ram_len_w;
// wire [  2:0]  ram_size_w;
// wire          ram_ack_w;
// wire          ram_error_w;

// sdram_axi_pmem
// u_axi
// (
//     .clk_i(clk_i),
//     .rst_i(rst_i),

//     // AXI port
//     .axi_awvalid_i(inport_awvalid_i),
//     .axi_awaddr_i(inport_awaddr_i),
//     .axi_awid_i(inport_awid_i),
//     .axi_awlen_i(inport_awlen_i),
//     .axi_awburst_i(inport_awburst_i),
//     .axi_wvalid_i(inport_wvalid_i),
//     .axi_wdata_i(inport_wdata_i),
//     .axi_wstrb_i(inport_wstrb_i),
//     .axi_wlast_i(inport_wlast_i),
//     .axi_bready_i(inport_bready_i),
//     .axi_arvalid_i(inport_arvalid_i),
//     .axi_araddr_i(inport_araddr_i),
//     .axi_arid_i(inport_arid_i),
//     .axi_arlen_i(inport_arlen_i),
//     .axi_arsize_i(inport_arsize_i),
//     .axi_arburst_i(inport_arburst_i),
//     .axi_rready_i(inport_rready_i),
//     .axi_awready_o(inport_awready_o),
//     .axi_wready_o(inport_wready_o),
//     .axi_bvalid_o(inport_bvalid_o),
//     .axi_bresp_o(inport_bresp_o),
//     .axi_bid_o(inport_bid_o),
//     .axi_arready_o(inport_arready_o),
//     .axi_rvalid_o(inport_rvalid_o),
//     .axi_rdata_o(inport_rdata_o),
//     .axi_rresp_o(inport_rresp_o),
//     .axi_rid_o(inport_rid_o),
//     .axi_rlast_o(inport_rlast_o),

//     // RAM interface
//     .ram_addr_o(ram_addr_w),
//     .ram_accept_i(ram_accept_w),
//     .ram_wr_o(ram_wr_w),
//     .ram_rd_o(ram_rd_w),
//     .ram_len_o(ram_len_w),
//     .ram_size_o(ram_size_w),
//     .ram_write_data_o(ram_write_data_w),
//     .ram_ack_i(ram_ack_w),
//     .ram_error_i(ram_error_w),
//     .ram_read_data_i(ram_read_data_w)
// );

// //-----------------------------------------------------------------
// // SDRAM Controller
// //-----------------------------------------------------------------
// sdram_axi_core
// #(
//      .SDRAM_MHZ(SDRAM_MHZ)
//     ,.SDRAM_ADDR_W(SDRAM_ADDR_W)
//     ,.SDRAM_COL_W(SDRAM_COL_W)
//     ,.SDRAM_READ_LATENCY(SDRAM_READ_LATENCY)
// )
// u_core
// (
//      .clk_i(clk_i)
//     ,.rst_i(rst_i)

//     ,.inport_wr_i(ram_wr_w)
//     ,.inport_rd_i(ram_rd_w)
//     ,.inport_len_i(ram_len_w)
//     ,.inport_size_i(ram_size_w)
//     ,.inport_addr_i(ram_addr_w)
//     ,.inport_write_data_i(ram_write_data_w)
//     ,.inport_accept_o(ram_accept_w)
//     ,.inport_ack_o(ram_ack_w)
//     ,.inport_error_o(ram_error_w)
//     ,.inport_read_data_o(ram_read_data_w)

//     ,.sdram_clk_o(sdram_clk_o)
//     ,.sdram_cke_o(sdram_cke_o)
//     ,.sdram_cs_o(sdram_cs_o)
//     ,.sdram_ras_o(sdram_ras_o)
//     ,.sdram_cas_o(sdram_cas_o)
//     ,.sdram_we_o(sdram_we_o)
//     ,.sdram_dqm_o(sdram_dqm_o)
//     ,.sdram_bsel_o(sdram_bsel_o)
//     ,.sdram_addr_o(sdram_addr_o)
//     ,.sdram_ba_o(sdram_ba_o)
//     ,.sdram_data_output_o(sdram_data_output_o)
//     ,.sdram_data_out_en_o(sdram_data_out_en_o)
//     ,.sdram_data_input_i(sdram_data_input_i)
// );



endmodule
