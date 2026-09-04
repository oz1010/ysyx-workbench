module inst_fetch #(
    parameter INST_WIDTH = 32,
    parameter SRAM_TYPE = `SRAM_TYPE_AXI4,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2,
    parameter IN_DATA_W,
    parameter OUT_DATA_W
) (
    input   wire                        clk,
    input   wire                        rst,

    /* AXI4总线master */
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

    /* 模块额外的接口输入 */
    input   wire [INST_WIDTH-1:0]       fetch_pc,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [OUT_DATA_W-1:0]       out_bits
);
    assign out_bits = {
        fetch_pc, r_read_inst,
        r_expt, r_expt_cause, r_expt_tval
    };

    reg  [INST_WIDTH-1:0]           r_read_inst;
    reg  [`STAGE_COUNT-1:0]         r_expt = 0;
    reg  [DATA_WIDTH-1:0]           r_expt_cause = 0;
    reg  [DATA_WIDTH-1:0]           r_expt_tval = 0;

    wire                            stage_in_done;
    reg                             r_stage_out_valid;
    wire                            stage_out_done;
    inner_con if_con(
        .clk(clk),
        .rst(rst),
        .in_valid(in_valid),
        .in_ready(in_ready),
        .out_valid(out_valid),
        .out_ready(out_ready),
        .stage_in_done(stage_in_done),
        .stage_out_valid(r_stage_out_valid),
        .stage_out_done(stage_out_done)
    );

    wire [INST_WIDTH-1:0]           read_inst;
    wire axi4_read_done = rvalid && rready && rlast;
    wire [INST_WIDTH-1:0] snpc = fetch_pc + 4;

    assign awvalid = 0;
    assign awaddr = 0;
    assign awid = 0;
    assign awlen = 0;
    assign awsize = 0;
    assign awburst = 0;
    assign wvalid = 0;
    assign wdata = 0;
    assign wstrb = 0;
    assign wlast = 0;
    assign bready = 0;

    /* 触发式记录使能 */
    reg r_read_en;
    always @(posedge clk) begin
        if (rst) begin
            r_read_en <= 0;
        end else begin
            r_read_en <= 
                stage_in_done ? 1 :
                axi4_read_done ? 0 :
                r_read_en;
        end
    end
    wire read_en;

    generate
        if (SRAM_TYPE == `SRAM_TYPE_AXI4) begin : sram_axi4
            // TODO 在命中cache的情况下，回读数据也需要3周期，这里可以继续优化一下
            assign read_en = stage_in_done | r_read_en;

            axi_master_reader #(
                `ifndef IN_YOSYS_STA
                .NAME("IFU"),
                `endif
                .ID(`AXI4_ID_IFU),
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
                .enable(read_en),
                .read_sign(0),
                .read_addr(fetch_pc),
                .read_data(read_inst),
                .read_len(0), // 读取数据总burst数量，2^n
                .read_size(2), // 单个burst读取大小，2^n字节
                .read_state()
            );

            always @(posedge clk) begin
                if (rst) begin
                    r_stage_out_valid <= 0;
                end else begin
                    // read request
                    if (read_en) begin
                        if (arvalid) begin
                            check_dev_addr(fetch_pc, `DEV_ATTR_READ|`DEV_ATTR_EXEC);
                        end
                    end

                    r_stage_out_valid <= 
                        axi4_read_done ? 1 :
                        stage_out_done ? 0 :
                        r_stage_out_valid;
                    r_read_inst <= axi4_read_done ? read_inst : r_read_inst;
                end
            end

        end else begin : sram_unknown
            assign out_valid = 1;
            assign out_bits = 0;

            `ifndef IN_YOSYS_STA
            `ifndef FORMAL_VERIFY
            $error("IFU only support axi4 interface");
            `endif
            `endif
        end
    endgenerate

endmodule
