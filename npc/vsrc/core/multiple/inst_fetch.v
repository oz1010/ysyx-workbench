module inst_fetch #(
    parameter INST_WIDTH = 32,
    parameter SRAM_TYPE = `SRAM_TYPE_AXI4,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input wire clk,
    input wire rst,

    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] inst,

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

    input wire enable,
    input wire next_ready,
    output wire next_valid
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

    generate
        if (SRAM_TYPE == `SRAM_TYPE_AXI4) begin : sram_axi4
            reg r_ar_valid;
            reg [ADDR_WIDTH-1:0] r_ar_addr;
            reg [3:0] r_ar_id;
            reg [7:0] r_ar_len;
            reg [2:0] r_ar_size;
            reg [1:0] r_ar_burst;
            reg r_r_ready;
            reg [INST_WIDTH-1:0] r_inst;

            wire read_en = !ar_valid && !r_valid && enable;

            assign ar_valid = r_ar_valid;
            assign ar_addr = r_ar_addr;
            assign ar_id = r_ar_id;
            assign ar_len = r_ar_len;
            assign ar_size = r_ar_size;
            assign ar_burst = r_ar_burst;
            assign r_ready = r_r_ready;

            assign next_valid = r_valid && r_ready;
            assign inst = r_inst;

            always @(posedge clk) begin
                if (rst) begin
                    r_ar_valid <= 0;
                    r_ar_addr <= 0;
                    r_ar_id <= 0;
                    r_ar_len <= 0;
                    r_ar_size <= 0;
                    r_ar_burst <= 0;
                    r_r_ready <= 0;
                    r_inst <= 0;
                end else begin
                    r_ar_valid <= r_ar_valid;
                    r_ar_addr <= r_ar_addr;
                    r_ar_id <= r_ar_id;
                    r_ar_len <= r_ar_len;
                    r_ar_size <= r_ar_size;
                    r_ar_burst <= r_ar_burst;
                    r_r_ready <= r_r_ready;
                    r_inst <= r_inst;

                    // read request
                    if (read_en) begin
                        r_ar_valid <= 1;
                        r_ar_addr <= pc;
                        r_ar_id <= `AXI4_ID_IFU;
                        r_ar_len <= 0; // 读取数据总burst数量，2^n
                        r_ar_size <= 2; // 单个burst读取大小，2^n字节
                        r_ar_burst <= 1; // burst类型，0--FIXED 1--INCR 2--WRAP
                        check_dev_addr(pc, `DEV_ATTR_READ|`DEV_ATTR_EXEC);
                    end
                    if (ar_valid && ar_ready) begin
                        r_ar_valid <= 0;
                        r_ar_addr <= 0;
                        r_ar_id <= 0;
                        r_ar_len <= 0;
                        r_ar_size <= 0;
                        r_ar_burst <= 0;
                    end

                    // read data
                    if (ar_valid && ar_ready) begin
                        r_r_ready <= 1;
                    end
                    if (r_valid) begin
                        r_inst <= r_data;
                        r_r_ready <= 1;
                    end
                    if (r_valid && r_ready) begin
                        r_r_ready <= 0;
                        `ifndef IN_YOSYS_STA
                        // check error response
                        if (r_resp!=0 || r_last!=1 || r_id!=`AXI4_ID_IFU) begin
                            $error("IFU Read data error, addr:%x resp:%x last:%x id:%x\n", pc, r_resp, r_last, r_id);
                        end
                        `endif
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
