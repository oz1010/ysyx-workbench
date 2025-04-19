module inst_fetch #(
    parameter INST_WIDTH = 32,
    parameter SRAM_TYPE = `SRAM_TYPE_AXI4,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 2
) (
    input wire clk,
    input wire rst,

    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] inst,

    output wire aw_valid,
    input wire aw_ready,
    output wire [ADDR_WIDTH-1:0] aw_addr,

    output wire w_valid,
    input wire w_ready,
    output wire [DATA_WIDTH-1:0] w_data,
    output wire [DATA_WIDTH/8-1:0] w_strb,

    input wire b_valid,
    output wire b_ready,
    input wire [BRESP_WIDTH-1:0] b_resp,

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

generate
    if (SRAM_TYPE == `SRAM_TYPE_SCOM) begin : sram_scom
        wire [INST_WIDTH-1:0] w_inst;
        wire [1:0] w_if_state;
        reg r_sram_valid;
        wire w_scom_valid;

        assign inst = w_inst;
        assign next_valid = w_scom_valid & r_sram_valid;

        scom_send m_scom_if(
            .clk(clk),
            .rst(rst),
            .enable(1),
            .next_ready(next_ready),
            .next_valid(w_scom_valid),
            .state(w_if_state)
        );

        sram_delay #(
            .INST_WIDTH(INST_WIDTH),
            .SRAM_READ_DELAY(SRAM_READ_DELAY)
        ) m_sram_delay (
            .clk(clk),
            .rst(rst),
            .enable(w_if_state == `SCOM_FOUND),
            .addr(pc),
            .data(w_inst),
            .valid(r_sram_valid),
            .ready(next_ready)
        );

    end if (SRAM_TYPE == `SRAM_TYPE_AXI4_LITE) begin : sram_axi4_lite
        reg r_ar_valid;
        reg [ADDR_WIDTH-1:0] r_ar_addr;
        reg r_r_ready;
        reg [INST_WIDTH-1:0] r_inst;

        assign ar_valid = r_ar_valid;
        assign ar_addr = r_ar_addr;
        assign r_ready = r_r_ready;

        assign next_valid = r_valid && r_ready;
        assign inst = r_inst;

        wire [7:0] delay_ar_valid_cur_cnt;
        wire delay_ar_valid_enable;
        wire [7:0] delay_ar_valid_cnt;
        wire ar_valid_enable = enable && !ar_valid && !delay_ar_valid_enable;
        lfsr_delay_signal m_delay_ar_valid(
            .clk(clk),
            .rst(rst),
            .enable(ar_valid_enable),
            .delay_enable(delay_ar_valid_enable),
            .delay_max(7),
            .delay_cnt(delay_ar_valid_cnt),
            .delay_cur_cnt(delay_ar_valid_cur_cnt)
        );

        wire [7:0] delay_r_ready_cur_cnt;
        wire delay_r_ready_enable;
        wire [7:0] delay_r_ready_cnt;
        wire r_ready_enable = (ar_valid && ar_ready) && !r_ready && !delay_r_ready_enable;
        lfsr_delay_signal m_delay_r_ready(
            .clk(clk),
            .rst(rst),
            .enable(r_ready_enable),
            .delay_enable(delay_r_ready_enable),
            .delay_max(17),
            .delay_cnt(delay_r_ready_cnt),
            .delay_cur_cnt(delay_r_ready_cur_cnt)
        );

        always @(posedge clk or posedge rst) begin
            if (rst) begin
                r_ar_valid <= 0;
                r_ar_addr <= 0;
                r_r_ready <= 0;
                r_inst <= 0;
            end else begin
                r_ar_valid <= r_ar_valid;
                r_ar_addr <= r_ar_addr;
                r_r_ready <= r_r_ready;
                r_inst <= r_inst;

                // read request
                if ((ar_valid_enable && delay_ar_valid_cur_cnt == 0) ||
                    (delay_ar_valid_enable && delay_ar_valid_cnt == 1)) begin
                    r_ar_valid <= 1;
                    r_ar_addr <= pc;
                end
                if (r_ar_valid && ar_ready) begin
                    r_ar_valid <= 0;
                end

                // read data
                if ((r_ready_enable && delay_r_ready_cur_cnt == 0) ||
                    (delay_r_ready_enable && delay_r_ready_cnt == 1)) begin
                    r_r_ready <= 1;
                end
                if (r_valid) begin
                    r_inst <= r_data;
                end
                if (r_valid && r_ready) begin
                    r_r_ready <= 0;
                end
            end
        end
    end if (SRAM_TYPE == `SRAM_TYPE_AXI4) begin : sram_axi4
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

        always @(posedge clk or posedge rst) begin
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
                    // check error response
                    if (r_resp!=0 || r_last!=1 || r_id!=`AXI4_ID_IFU) begin
                        $error("IFU Read data error, addr:%x resp:%x last:%x id:%x\n", pc, r_resp, r_last, r_id);
                    end
                end
            end
        end

    end else begin : sram_unknown
        assign next_valid = 1;
        assign inst = 0;
    end
endgenerate

endmodule