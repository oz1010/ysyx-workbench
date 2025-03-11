module inst_fetch #(
    parameter INST_WIDTH = 32,
    parameter SRAM_TYPE = `SRAM_TYPE_AXI4,
    parameter SRAM_READ_DELAY = 0,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    input wire [INST_WIDTH-1:0] pc,
    output wire [INST_WIDTH-1:0] inst,

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

    end if (SRAM_TYPE == `SRAM_TYPE_AXI4) begin : sram_axi4
        wire ar_valid;
        wire ar_ready;
        wire [ADDR_WIDTH-1:0] ar_addr;
        wire r_valid;
        wire r_ready;
        wire [DATA_WIDTH-1:0] r_data;
        wire [RRESP_WIDTH-1:0] r_resp;

        sram_axi4 #(
            .ADDR_WIDTH(ADDR_WIDTH),
            .DATA_WIDTH(DATA_WIDTH),
            .BRESP_WIDTH(BRESP_WIDTH),
            .RRESP_WIDTH(RRESP_WIDTH),
            .SRAM_READ_DELAY(SRAM_READ_DELAY)
        ) m_sram_axi4(
            .clk(clk),
            .rst(rst),
            .aw_valid(),
            .aw_ready(),
            .aw_addr(),
            .w_valid(),
            .w_ready(),
            .w_data(),
            .w_strb(),
            .b_valid(),
            .b_ready(),
            .b_resp(),
            .ar_valid(ar_valid),
            .ar_ready(ar_ready),
            .ar_addr(ar_addr),
            .r_valid(r_valid),
            .r_ready(r_ready),
            .r_data(r_data),
            .r_resp(r_resp)
        );

        reg r_ar_valid;
        reg [ADDR_WIDTH-1:0] r_ar_addr;
        reg r_r_ready;

        assign ar_valid = r_ar_valid;
        assign ar_addr = r_ar_addr;
        assign r_ready = r_r_ready;

        assign next_valid = r_valid && r_ready;
        assign inst = r_data;

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
            end else begin
                r_ar_valid <= r_ar_valid;
                r_ar_addr <= r_ar_addr;
                r_r_ready <= r_r_ready;

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
                if (r_valid && r_ready) begin
                    r_r_ready <= 0;
                end
            end
        end

    end else begin : sram_unknown
        assign next_valid = 1;
        assign inst = 0;
    end
endgenerate

endmodule