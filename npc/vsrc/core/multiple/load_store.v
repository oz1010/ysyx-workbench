module load_store #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input wire clk,
    input wire rst,

    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [15:0] inst_code,

    input wire [INST_WIDTH-1:0] inst,
    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] dnpc,

    input wire [INST_WIDTH*`RISCV_CSR_COUNT-1:0] x,
    output wire [INST_WIDTH-1:0] result,
    output wire [7:0] mem_result_width,
    output wire result_update_csr,

    input   wire                        awready,
    output  wire                        awvalid,
    output  wire [ADDR_WIDTH-1:0]       awaddr,
    output  wire [3:0]                  awid,
    output  wire [7:0]                  awlen,
    output  wire [2:0]                  awsize,
    output  wire [1:0]                  awburst,
    input   wire                        wready,
    output  wire                        wvalid,
    output  wire [DATA_WIDTH-1:0]       wdata,
    output  wire [DATA_WIDTH/8-1:0]     wstrb,
    output  wire                        wlast,
    output  wire                        bready,
    input   wire                        bvalid,
    input   wire [BRESP_WIDTH-1:0]      bresp,
    input   wire [3:0]                  bid,

    input   wire                        arready,
    output  wire                        arvalid,
    output  wire [ADDR_WIDTH-1:0]       araddr,
    output  wire [3:0]                  arid,
    output  wire [7:0]                  arlen,
    output  wire [2:0]                  arsize,
    output  wire [1:0]                  arburst,
    output  wire                        rready,
    input   wire                        rvalid,
    input   wire [RRESP_WIDTH-1:0]      rresp,
    input   wire [DATA_WIDTH-1:0]       rdata,
    input   wire                        rlast,
    input   wire [3:0]                  rid,

    output wire prev_ready,
    input wire prev_valid,
    input wire next_ready,
    output wire next_valid
);

reg r_prev_ready, r_next_valid;
assign prev_ready = r_prev_ready;
assign next_valid = r_next_valid;

reg [INST_WIDTH-1:0] r_dnpc;
reg [INST_WIDTH-1:0] r_result;
reg [7:0] r_result_mem_width;
reg r_result_update_csr;

assign dnpc = r_dnpc;
assign result = r_result;
assign mem_result_width = r_result_mem_width;
assign result_update_csr = r_result_update_csr;

wire [INST_WIDTH-1:0] xs[0:`RISCV_CSR_COUNT-1];
generate
    for (genvar i = 0; i<`RISCV_CSR_COUNT; ++i) begin
        assign xs[i] = x[i*INST_WIDTH +: INST_WIDTH];
    end
endgenerate

wire [31:0] src1 = xs[rs1];
wire [31:0] src2 = xs[rs2];

wire in_wait_prev_ready = (prev_valid && !prev_ready);
wire in_test_mode = in_wait_prev_ready && ((src1+imm)>=32'h0f00_2000 && (src1+imm)<=32'h0fff_ffff);

wire [2:0] inst_opn_size = 
      inst_code == `INST_SB ? 0
    : inst_code == `INST_LB ? 0
    : inst_code == `INST_LBU ? 0
    : inst_code == `INST_SH ? 1
    : inst_code == `INST_LH ? 1
    : inst_code == `INST_LHU ? 1
    : 2;

wire write_enable = in_wait_prev_ready && (inst_code==`INST_SB || inst_code==`INST_SH || inst_code==`INST_SW);
wire [ADDR_WIDTH-1:0] write_addr = src1+imm;
wire [DATA_WIDTH-1:0] write_data = src2;
wire [2:0] write_size = inst_opn_size;
wire [1:0] write_state;

wire read_enable = in_wait_prev_ready && (inst_code==`INST_LB || inst_code==`INST_LH || inst_code==`INST_LW || inst_code==`INST_LBU || inst_code==`INST_LHU);
wire read_sign = (inst_code==`INST_LB || inst_code==`INST_LH || inst_code==`INST_LW);
wire [ADDR_WIDTH-1:0] read_addr = src1+imm;
wire [DATA_WIDTH-1:0] read_data;
wire [2:0] read_size = inst_opn_size;
wire [1:0] read_state;

wire fence_enable = in_wait_prev_ready && (inst_code==`INST_FENCE || inst_code==`INST_FENCE_I);

axi_master_writer #(
`ifndef IN_YOSYS_STA
    .NAME("LSU"),
`endif
    .ID(`AXI4_ID_LSU),
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .INST_WIDTH(INST_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi_master_writer (
    .clk(clk),
    .rst(rst),
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
    .write_enable(write_enable),
    .write_addr(write_addr),
    .write_data(write_data),
    .write_size(write_size),
    .write_state(write_state)
);

axi_master_reader #(
`ifndef IN_YOSYS_STA
    .NAME("LSU"),
`endif
    .ID(`AXI4_ID_LSU),
    .BURST(1), // burst类型，0--FIXED 1--INCR 2--WRAP
    .INST_WIDTH(INST_WIDTH),
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .BRESP_WIDTH(BRESP_WIDTH),
    .RRESP_WIDTH(RRESP_WIDTH)
) m_axi_master_reader (
    .clk(clk),
    .rst(rst),
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
    .read_sign(read_sign),
    .read_addr(read_addr),
    .read_len(0),
    .read_data(read_data),
    .read_size(read_size),
    .read_state(read_state)
);

always @(posedge clk) begin
    if (rst) begin
        r_dnpc <= 0;
        r_result <= 0;
        r_result_mem_width <= 0;
        r_result_update_csr <= 0;

        r_prev_ready <= 0;
        r_next_valid <= 0;
    end else begin
        r_dnpc <= r_dnpc;
        r_result <= r_result;
        r_result_mem_width <= r_result_mem_width;
        r_result_update_csr <= r_result_update_csr;

        if (in_wait_prev_ready) begin
            if (in_test_mode || fence_enable) begin
                // 用于调试的地址段，向这里写数据会触发内置的调试函数
                // notify next
                r_dnpc <= pc + 4;
                if (in_test_mode) begin r_result <= func_test_intf({31'h0,(inst_code==`INST_SB || inst_code==`INST_SH || inst_code==`INST_SW)}, src1+imm, 4, src2); end
                else begin r_result <= 0; end
                r_result_mem_width <= 0;
                r_result_update_csr <= 0;
                r_prev_ready <= 1;
            end else if (write_enable) begin
                if (write_state==`AXI4_STATE_RESPONSE && bvalid && bready) begin
                    r_dnpc <= pc + 4;
                    r_result <= 0;
                    r_result_mem_width <= 0;
                    r_result_update_csr <= 0;
                    r_prev_ready <= 1;
                end

            end else if (read_enable) begin
                case (read_state)
                    `AXI4_STATE_DATA: begin
                        if (rvalid) begin
                            r_result <= read_data;
                        end

                        if (rlast) begin
                            // notify prev module
                            r_dnpc <= pc + 4;
                            r_result_mem_width <= 0;
                            r_result_update_csr <= 1;
                            r_prev_ready <= 1;
                        end
                    end
                endcase
            end else begin
                `ifndef IN_YOSYS_STA
                $error("Found unsopport inst_code(%x) in LSU", inst_code);
                `endif
            end

        end
        if (prev_valid && prev_ready) begin
            r_prev_ready <= 0;
        end
        
        if (prev_valid && prev_ready) begin
            r_next_valid <= 1;
        end
        if (next_valid && next_ready) begin
            r_next_valid <= 0;
        end

    end
end
endmodule
