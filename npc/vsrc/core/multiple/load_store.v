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

    input wire [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0],
    output wire [INST_WIDTH-1:0] result,
    output wire [7:0] mem_result_width,
    output wire result_update_csr,

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

    output wire prev_ready,
    input wire prev_valid,
    input wire next_ready,
    output wire next_valid
);

// assign aw_len = 0; // 写入数据总burst数量，2^n
assign aw_burst = 1; // burst类型，0--FIXED 1--INCR 2--WRAP

reg r_prev_ready, r_next_valid;
assign prev_ready = r_prev_ready;
assign next_valid = r_next_valid;

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
reg r_ar_valid;
reg [ADDR_WIDTH-1:0] r_ar_addr;
reg [3:0] r_ar_id;
reg [7:0] r_ar_len;
reg [7:0] r_record_ar_len;
reg [2:0] r_ar_size;
reg [2:0] r_record_ar_size;
reg [1:0] r_ar_burst;
reg r_r_ready;

wire [2:0] write_status = {b_valid, w_valid, aw_valid};

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
assign ar_valid = r_ar_valid;
assign ar_addr = r_ar_addr;
assign ar_id = r_ar_id;
assign ar_len = r_ar_len;
assign ar_size = r_ar_size;
assign ar_burst = r_ar_burst;
assign r_ready = r_r_ready;

reg [INST_WIDTH-1:0] r_dnpc;
reg [INST_WIDTH-1:0] r_result;
reg [7:0] r_result_mem_width;
reg r_result_update_csr;

assign dnpc = r_dnpc;
assign result = r_result;
assign mem_result_width = r_result_mem_width;
assign result_update_csr = r_result_update_csr;

wire [31:0] src1 = x[rs1];
wire [31:0] src2 = x[rs2];

wire [ADDR_WIDTH-1:0] signed_addr = (src1 + imm) & (~32'h03); // 4字节对齐
wire [DATA_WIDTH-1:0] signed_data_shift_val = ((src1 + imm) & (32'h03));
wire [DATA_WIDTH-1:0] shifted_r_data = r_data>>(8*signed_data_shift_val);
wire [DATA_WIDTH-1:0] shifted_w_data = src2<<(8*signed_data_shift_val);
reg [7:0] s_write_idx;
reg [7:0] s_write_len;
reg [2:0] s_write_size;
reg [3:0] s_write_strb[0:1];
reg [1:0] s_write_shift_val;
reg [1:0] r_write_state;
reg [7:0] s_read_idx;
reg [7:0] s_read_len;
reg [2:0] s_read_size;
reg [3:0] s_read_strb[0:1];
reg [1:0] s_read_shift_val;
reg [1:0] r_read_state;
reg [DATA_WIDTH-1:0] s_read_data;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_dnpc <= get_reset_pc();
        r_result <= 0;
        r_result_mem_width <= 0;
        r_result_update_csr <= 0;
        r_write_state <= AXI4_COM_ADDR;
        r_read_state <= AXI4_COM_ADDR;

        r_prev_ready <= 0;
        r_aw_valid <= 0;
        r_aw_addr <= 0;
        r_aw_id <= 0;
        r_aw_size <= 0;
        r_w_valid <= 0;
        r_w_data <= 0;
        r_w_strb <= 0;
        r_w_last <= 0;
        r_b_ready <= 0;
        r_ar_valid <= 0;
        r_ar_addr <= 0;
        r_ar_id <= 0;
        r_ar_len <= 0;
        r_ar_size <= 0;
        r_ar_burst <= 0;
        r_r_ready <= 0;
    end else begin
        r_dnpc <= r_dnpc;
        r_result <= r_result;
        r_result_mem_width <= r_result_mem_width;
        r_result_update_csr <= r_result_update_csr;
        r_write_state <= r_write_state;
        r_read_state <= r_read_state;

        r_aw_valid <= r_aw_valid;
        r_aw_addr <= r_aw_addr;
        r_aw_id <= r_aw_id;
        r_aw_size <= r_aw_size;
        r_w_valid <= r_w_valid;
        r_w_data <= r_w_data;
        r_w_strb <= r_w_strb;
        r_w_last <= r_w_last;
        r_b_ready <= r_b_ready;
        r_ar_valid <= r_ar_valid;
        r_ar_addr <= r_ar_addr;
        r_ar_id <= r_ar_id;
        r_ar_len <= r_ar_len;
        r_ar_size <= r_ar_size;
        r_ar_burst <= r_ar_burst;
        r_r_ready <= r_r_ready;

        if (prev_valid && !prev_ready) begin
            if (inst_code==`INST_SB || inst_code==`INST_SH || inst_code==`INST_SW) begin
                case (r_write_state)
                    AXI4_COM_ADDR: begin
                        r_aw_valid <= 1;
                        r_aw_addr <= src1+imm; // sram会4字节对齐
                        r_aw_id <= `AXI4_ID_LSU;
                        r_aw_len <= s_write_len;
                        r_aw_size <= s_write_size;
                        check_dev_addr(src1+imm, `DEV_ATTR_WRITE);
                        get_unalign_parameter(inst_code, src1+imm, s_write_len, s_write_size, s_write_strb, s_write_shift_val);
                        s_write_idx <= 0;

                        if (aw_valid && aw_ready) begin
                            r_record_aw_size <= r_aw_size;
                            r_aw_valid <= 0;
                            r_aw_addr <= 0;
                            r_aw_id <= 0;
                            r_aw_len <= 0;
                            r_aw_size <= 0;

                            // switch to write data
                            r_write_state <= AXI4_COM_DATA;
                            /* 写下第一个字 */
                            r_w_valid <= 1;
                            s_write_idx <= s_write_idx + 1;
                            r_w_strb <= s_write_strb[s_write_idx[0:0]];
                            case (s_write_idx)
                                0: r_w_data<=src2<<(8*s_write_shift_val);
                                1: r_w_data<=src2>>(32-8*s_write_shift_val);
                                default: $error("aw data unalign is error");
                            endcase
                            if (s_write_idx == ((8'h1<<s_write_len)-1)) r_w_last <= 1;
                        end
                    end

                    AXI4_COM_DATA: begin
                        if (s_write_idx <= ((8'h1<<s_write_len)-1)) begin
                            /* 写下第二个字 */
                            r_w_valid <= 1;
                            s_write_idx <= s_write_idx + 1;
                            r_w_strb <= s_write_strb[s_write_idx[0:0]];
                            case (s_write_idx)
                                0: r_w_data<=src2<<(8*s_write_shift_val);
                                1: r_w_data<=src2>>(32-8*s_write_shift_val);
                                default: $error("aw data unalign is error");
                            endcase
                            if (s_write_idx == ((8'h1<<s_write_len)-1)) r_w_last <= 1;
                        end

                        if (w_last) begin
                            dpi_dev_skip(1, src1 + imm, {25'h0, r_record_aw_size, r_w_strb}, src2);
                            r_w_valid <= 0;
                            r_w_strb <= 0;
                            r_w_data <= 0;
                            r_w_last <= 0;
                            s_write_idx <= 0;

                            // switch to write response
                            r_write_state <= AXI4_COM_RESPONSE;
                            r_b_ready <= 1;
                        end
                    end

                    AXI4_COM_RESPONSE: begin
                        if (b_valid && b_ready) begin
                            r_b_ready <= 0;
                            // check error response
                            if (b_resp!=0 || b_id!=`AXI4_ID_LSU) begin
                                $error("LSU Write data error, addr:%x data:%x resp:%x id:%x\n", src1 + imm, src2, b_resp, b_id);
                            end

                            // switch to write addr
                            r_write_state <= AXI4_COM_ADDR;
                            
                            // notify prev module
                            // pc <= dnpc;
                            r_dnpc <= pc + 4;
                            r_result <= 0;
                            r_result_mem_width <= 0;
                            r_result_update_csr <= 0;
                            r_prev_ready <= 1;
                        end
                    end

                    default: $error("Found unknown write state(%d) in LSU", r_write_state);
                endcase

            end else if (
                inst_code==`INST_LB || 
                inst_code==`INST_LH || 
                inst_code==`INST_LW || 
                inst_code==`INST_LBU || 
                inst_code==`INST_LHU
            ) begin
                case (r_read_state)
                    AXI4_COM_ADDR: begin
                        // read request
                        r_ar_valid <= 1;
                        r_ar_addr <= src1+imm; // sram会4字节对齐
                        r_ar_id <= `AXI4_ID_LSU;
                        r_ar_len <= s_read_len; // 读取数据总burst数量，2^n
                        r_ar_size <= s_read_size;
                        r_ar_burst <= 1; // burst类型，0--FIXED 1--INCR 2--WRAP
                        check_dev_addr(src1+imm, `DEV_ATTR_READ);
                        get_unalign_parameter(inst_code, src1+imm, s_read_len, s_read_size, s_read_strb, s_read_shift_val);
                        s_read_idx <= 0;

                        if (ar_valid && ar_ready) begin
                            r_ar_valid <= 0;
                            r_ar_addr <= 0;
                            r_ar_id <= 0;
                            r_ar_len <= 0;
                            r_ar_size <= 0;
                            r_ar_burst <= 0;
                            r_record_ar_len <= r_ar_len;
                            r_record_ar_size <= r_ar_size;

                            // switch to read data
                            r_read_state <= AXI4_COM_DATA;
                            r_r_ready <= 1;
                            s_read_idx <= 0;
                            r_result <= 0;
                        end
                    end 

                    AXI4_COM_DATA: begin
                        // read data
                        if (r_valid) begin
                            s_read_idx <= s_read_idx + 1;
                            /* 依次读取非对齐数据 */
                            read_unalign_data(s_read_idx, inst_code, r_data, s_read_shift_val, s_read_data);
                            r_result <= s_read_data;
                        end
                        if (r_last) begin
                            r_r_ready <= 0;
                            s_read_idx <= 0;
                            dpi_dev_skip(0, src1 + imm, {21'h0, r_record_ar_size, r_record_ar_len}, s_read_data);
                            // check error response
                            if (r_resp!=0 || r_last!=1 || r_id!=`AXI4_ID_LSU) begin
                                $error("LSU Read data error, addr:%x resp:%x last:%x id:%x\n", pc, r_resp, r_last, r_id);
                            end

                            // switch to read addr
                            r_read_state <= AXI4_COM_ADDR;

                            // notify prev module
                            r_dnpc <= pc + 4;
                            r_result_mem_width <= 0;
                            r_result_update_csr <= 1;
                            r_prev_ready <= 1;
                        end
                    end

                    default: $error("Found unknown read state(%d) in LSU", r_read_state);
                endcase
            end else begin
                $error("Found unsopport inst_code(%x) in LSU", inst_code);
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
