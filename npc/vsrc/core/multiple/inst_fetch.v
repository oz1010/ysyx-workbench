module inst_fetch #(
    parameter INST_WIDTH = 32,
    parameter SRAM_TYPE = `SRAM_TYPE_AXI4,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input   wire                        clk,
    input   wire                        rst,

    input   wire [INST_WIDTH-1:0]       pc,
    output  wire [INST_WIDTH-1:0]       inst,

    input   wire                        aw_ready,
    output  wire                        aw_valid,
    output  wire [ADDR_WIDTH-1:0]       aw_addr,
    output  wire [3:0]                  aw_id,
    output  wire [7:0]                  aw_len,
    output  wire [2:0]                  aw_size,
    output  wire [1:0]                  aw_burst,
    input   wire                        w_ready,
    output  wire                        w_valid,
    output  wire [DATA_WIDTH-1:0]       w_data,
    output  wire [DATA_WIDTH/8-1:0]     w_strb,
    output  wire                        w_last,
    output  wire                        b_ready,
    input   wire                        b_valid,
    input   wire [BRESP_WIDTH-1:0]      b_resp,
    input   wire [3:0]                  b_id,

    input   wire                        ar_ready,
    output  wire                        ar_valid,
    output  wire [ADDR_WIDTH-1:0]       ar_addr,
    output  wire [3:0]                  ar_id,
    output  wire [7:0]                  ar_len,
    output  wire [2:0]                  ar_size,
    output  wire [1:0]                  ar_burst,
    output  wire                        r_ready,
    input   wire                        r_valid,
    input   wire [RRESP_WIDTH-1:0]      r_resp,
    input   wire [DATA_WIDTH-1:0]       r_data,
    input   wire                        r_last,
    input   wire [3:0]                  r_id,

    input   wire                        enable,
    input   wire                        next_ready,
    output  wire                        next_valid
);

    assign aw_valid = 0;
    assign aw_addr = 0;
    assign aw_id = 0;
    assign aw_len = 0;
    assign aw_size = 0;
    assign aw_burst = 0;
    assign w_valid = 0;
    assign w_data = 0;
    assign w_strb = 0;
    assign w_last = 0;
    assign b_ready = 0;

    /* 触发式记录使能 */
    reg in_read_en;
    always @(posedge clk) begin
        if (rst) begin
            in_read_en <= 0;
        end else begin
            if (in_read_en) begin
                if (next_valid) begin
                    in_read_en <= 0;
                end
            end

            if (enable) begin
                in_read_en <= 1;
            end
        end
    end

    generate
        if (SRAM_TYPE == `SRAM_TYPE_AXI4) begin : sram_axi4
            reg [INST_WIDTH-1:0] r_inst = 0;

            wire read_en = enable || in_read_en;
            wire [1:0] read_state;
            wire [INST_WIDTH-1:0] read_data;
            
            assign next_valid = r_valid && r_ready;
            assign inst = r_inst;

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
                .ar_ready(ar_ready),
                .ar_valid(ar_valid),
                .ar_addr(ar_addr),
                .ar_id(ar_id),
                .ar_len(ar_len),
                .ar_size(ar_size),
                .ar_burst(ar_burst),
                .r_ready(r_ready),
                .r_valid(r_valid),
                .r_resp(r_resp),
                .r_data(r_data),
                .r_last(r_last),
                .r_id(r_id),
                .enable(read_en),
                .read_sign(0),
                .read_addr(pc),
                .read_data(read_data),
                .read_size(2), // 单个burst读取大小，2^n字节
                .read_state(read_state)
            );

            always @(posedge clk) begin
                if (rst) begin
                end else begin
                    // read request
                    if (read_en) begin
                        if (ar_valid) begin
                            check_dev_addr(pc, `DEV_ATTR_READ|`DEV_ATTR_EXEC);
                        end
                        
                        if (r_valid) begin
                            r_inst <= read_data;
                        end
                    end
                end
            end

        end else begin : sram_unknown
            assign next_valid = 1;
            assign inst = 0;

            `ifndef IN_YOSYS_STA
            $error("IFU only support axi4 interface");
            `endif
        end
    endgenerate

endmodule
