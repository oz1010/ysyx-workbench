module axi_master ();
endmodule

module axi_master_writer #(
    `ifndef IN_YOSYS_STA
    parameter NAME = "anonym",
    `endif
    parameter ID,
    parameter BURST, // burst类型，0--FIXED 1--INCR 2--WRAP
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input   wire                        clk,
    input   wire                        rst,
    /* 通信信号 */
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
    /* 模块信号 */
    input   wire                        write_enable,
    input   wire [ADDR_WIDTH-1:0]       write_addr,
    input   wire [DATA_WIDTH-1:0]       write_data,
    input   wire [2:0]                  write_size, // 2^n字节
    output  wire [1:0]                  write_state
);

    reg [1:0] r_write_state;

    reg r_aw_valid;
    reg [ADDR_WIDTH-1:0] r_aw_addr;
    reg [3:0] r_aw_id; // 写入数据标识，响应中可以比对是否一致
    reg [7:0] r_aw_len; // burst写入数量，2^n字节
    reg [2:0] r_aw_size; // 单个burst写入数据大小，2^n字节
    reg [2:0] r_record_aw_size;
    reg r_w_valid;
    reg [DATA_WIDTH-1:0] r_w_data;
    reg [DATA_WIDTH/8-1:0] r_w_strb;
    reg r_w_last; // 写入最后一个数据时需要拉高
    reg r_b_ready;

    reg [7:0] s_write_idx;
    reg [7:0] s_write_len;
    reg [7:0] s_write_strb;
    wire [3:0] s_write_strbs[0:1];
    reg [1:0] s_write_shift_val;

    assign write_state = r_write_state;

    assign aw_valid = r_aw_valid;
    assign aw_addr = r_aw_addr;
    assign aw_id = r_aw_id;
    assign aw_len = r_aw_len;
    assign aw_size = r_aw_size;
    assign w_valid = r_w_valid;
    assign w_data = r_w_data;
    assign w_strb = r_w_strb;
    assign w_last = r_w_last;
    assign b_ready = r_b_ready;

    assign s_write_strbs[0] = s_write_strb[0 +: 4];
    assign s_write_strbs[1] = s_write_strb[4 +: 4];

    `define WRITE_DATA() \
        r_w_valid <= 1; \
        s_write_idx <= s_write_idx + 1; \
        r_w_strb <= s_write_strbs[s_write_idx[0:0]]; \
        case (s_write_idx) \
            0: r_w_data<=write_data<<(8*s_write_shift_val); \
            1: r_w_data<=write_data>>(32-8*s_write_shift_val); \
            `ifndef IN_YOSYS_STA \
            default: $error("%s aw data unalign is error", NAME); \
            `endif \
        endcase \
        if (s_write_idx == ((8'h1<<s_write_len)-1)) r_w_last <= 1;

    initial begin
        s_write_idx = 0;
        s_write_len = 0;
        s_write_strb = 0;
        s_write_shift_val = 0;
    end

    always @(posedge clk or posedge rst) begin
        if (rst || !write_enable) begin
            r_write_state <= `AXI4_STATE_ADDR;

            r_aw_valid <= 0;
            r_aw_valid <= 0;
            r_aw_addr <= 0;
            r_aw_id <= 0;
            r_aw_len <= 0;
            r_aw_size <= 0;
            r_w_valid <= 0;
            r_w_data <= 0;
            r_w_strb <= 0;
            r_w_last <= 0;
            r_b_ready <= 0;
        end else begin
            case (r_write_state)
                `AXI4_STATE_ADDR: begin
                    r_aw_valid <= 1;
                    r_aw_addr <= write_addr; // sram会4字节对齐
                    r_aw_id <= ID;
                    r_aw_len <= s_write_len;
                    r_aw_size <= write_size;
                    check_dev_addr(write_addr, `DEV_ATTR_WRITE);
                    get_unalign_write_parameter(write_size, write_addr, s_write_len, s_write_strb, s_write_shift_val);
                    s_write_idx <= 0;

                    if (aw_valid && aw_ready) begin
                        r_record_aw_size <= r_aw_size;
                        r_aw_valid <= 0;
                        r_aw_addr <= 0;
                        r_aw_id <= 0;
                        r_aw_len <= 0;
                        r_aw_size <= 0;

                        // switch to write data
                        r_write_state <= `AXI4_STATE_DATA;
                        /* 写下第一个字 */
                        `WRITE_DATA();
                    end
                end

                `AXI4_STATE_DATA: begin
                    if (s_write_idx <= ((8'h1<<s_write_len)-1)) begin
                        /* 写下第二个字 */
                        `WRITE_DATA();
                    end

                    if (w_last) begin
                        func_dev_skip(1, write_addr, {25'h0, r_record_aw_size, s_write_strbs[0]|s_write_strbs[1]}, write_data);

                        r_w_valid <= 0;
                        r_w_strb <= 0;
                        r_w_data <= 0;
                        r_w_last <= 0;
                        s_write_idx <= 0;

                        // switch to write response
                        r_write_state <= `AXI4_STATE_RESPONSE;
                        r_b_ready <= 1;
                    end
                end

                `AXI4_STATE_RESPONSE: begin
                    if (b_valid && b_ready) begin
                        // switch to init
                        r_write_state <= `AXI4_STATE_ADDR;
                        r_b_ready <= 0;

                        `ifndef IN_YOSYS_STA
                        // check error response
                        if (b_resp!=0 || b_id!=ID) begin
                            $error("%s Write data error, addr:%x data:%x resp:%x id:%x\n", NAME, write_addr, write_data, b_resp, b_id);
                        end
                        `endif
                    end
                end

                `ifndef IN_YOSYS_STA
                default: $error("%s found unknown write write_state(%d)", NAME, r_write_state);
                `endif
            endcase
        end
    end

endmodule

module axi4_salve_writer #(
    `ifndef IN_YOSYS_STA
    parameter NAME,
    `endif
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input   wire                        clk,
    input   wire                        rst,
    /* 通信信号 */
    output  wire                        aw_ready,
    input   wire                        aw_valid,
    input   wire [ADDR_WIDTH-1:0]       aw_addr,
    input   wire [3:0]                  aw_id,
    input   wire [7:0]                  aw_len,
    input   wire [2:0]                  aw_size,
    input   wire [1:0]                  aw_burst,
    output  wire                        w_ready,
    input   wire                        w_valid,
    input   wire [DATA_WIDTH-1:0]       w_data,
    input   wire [DATA_WIDTH/8-1:0]     w_strb,
    input   wire                        w_last,
    input   wire                        b_ready,
    output  wire                        b_valid,
    output  wire [BRESP_WIDTH-1:0]      b_resp,
    output  wire [3:0]                  b_id,
    /* 模块信号 */
    input   wire                        enable,
    output  wire [ADDR_WIDTH-1:0]       write_addr,
    output  wire [DATA_WIDTH-1:0]       write_data,
    output  wire [2:0]                  write_size,
    output  wire                        write_valid
);

    reg                                     r_aw_ready;
    reg                                     r_w_ready;
    reg                                     r_b_valid;
    reg [BRESP_WIDTH-1:0]                   r_b_resp;
    reg [3:0]                               r_b_id;

    reg [ADDR_WIDTH-1:0]                    r_write_addr;
    reg [3:0]                               r_write_id;
    reg [7:0]                               r_write_len; // 单个burst写入数据大小，2^n字节
    reg [2:0]                               r_write_size; // burst写入数量，2^n字节

    assign aw_ready = r_aw_ready;
    assign w_ready = r_w_ready;
    assign b_valid = r_b_valid;
    assign b_resp = r_b_resp;
    assign b_id = r_b_id;

    assign write_addr = r_write_addr;
    assign write_data = w_data;
    assign write_size = r_write_size;
    assign write_valid = w_valid;

    wire in_write_mode = (aw_ready || w_ready || b_valid);

    always @(posedge clk or posedge rst) begin
        if (rst || !enable) begin
            r_aw_ready <= 0;
            r_w_ready <= 0;
            r_b_valid <= 0;
            r_b_resp <= 0;
            r_b_id <= 0;

            r_write_addr <= 0;
            r_write_size <= 0;
            r_write_len <= 0;
            r_write_id <= 0;
        end else begin
            // write request
            if (!in_write_mode) r_aw_ready <= 1;
            if (aw_valid) begin
                r_write_addr <= aw_addr;
                r_write_size <= aw_size;
                r_write_len <= aw_len;
                r_write_id <= aw_id;
                
                `ifndef IN_YOSYS_STA
                if (aw_size!=2 || aw_len!=0) $error("%s only support write 1 burst - 4bytes, addr:%x size:%x len:%x", NAME, aw_addr, aw_size, aw_len);
                `endif
            end
            if (aw_valid && aw_ready) begin
                r_aw_ready <= 0;
            end

            // write data
            if (aw_valid && aw_ready) begin
                r_w_ready <= 1;
            end
            if (w_valid && w_ready) begin
                r_w_ready <= 0;
            end
            if (w_valid && w_ready) begin
                `ifndef IN_YOSYS_STA
                if (!w_last) $error("%s only support write 1-burst, addr:%x size:%x", NAME, aw_addr, write_size);
                `endif
            end

            // write response
            if (w_valid && w_ready && w_last) begin
                r_b_valid <= 1;
                r_b_resp <= 0;
                r_b_id <= r_write_id;
            end
            if (b_valid && b_ready) begin
                r_b_valid <= 0;
                r_b_id <= 0;
            end

        end
    end

endmodule
