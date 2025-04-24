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

assign aw_len = 0; // 写入数据总burst数量，2^n
assign aw_burst = 1; // burst类型，0--FIXED 1--INCR 2--WRAP

reg r_prev_ready, r_next_valid;
assign prev_ready = r_prev_ready;
assign next_valid = r_next_valid;

reg r_aw_valid;
reg [ADDR_WIDTH-1:0] r_aw_addr;
reg [3:0] r_aw_id; // 写入数据标识，响应中可以比对是否一致
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

task get_unalign_parameter(
    input logic [15:0] inst_code,
    input logic [ADDR_WIDTH-1:0] addr,
    output logic [7:0] len,
    output logic [2:0] size,
    output logic [3:0] strb[0:1],
    output logic [1:0] shift_val
);
    static logic [ADDR_WIDTH-1:0] s_addr;
    s_addr = addr & (~32'h03); // 4字节对齐
    len = 0; // 数据总burst数量，2^n
    size = 0; // 单个burst数据大小，2^n字节
    strb = 0;
    shift_val = addr[1:0]; // 4字节对齐
    case (inst_code)
        `INST_SB:           begin size=0; strb[0]=4'h1; end
        `INST_SH:           begin size=1; strb[0]=4'h3; end
        `INST_SW:           begin size=2; strb[0]=4'hF; end
        default: ;
    endcase

    if ((4-shift_val)<(1<<size)) begin
        len = 1;
        strb[1] = strb[0] >> ((1<<size)-(4-shift_val));
        strb[0] = strb[0] << shift_val;
    end else begin
        strb[0] = strb[0] << shift_val;
    end
endtask

always @(posedge clk or posedge rst) begin
    if (rst) begin
        r_dnpc <= get_reset_pc();
        r_result <= 0;
        r_result_mem_width <= 0;
        r_result_update_csr <= 0;

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
                // write request
                if (write_status==0 && !aw_valid) begin
                    r_aw_valid <= 1;
                    r_aw_addr <= src1+imm; // sram会4字节对齐
                    r_aw_id <= `AXI4_ID_LSU;
                    r_aw_size <= (inst_code==`INST_SB) ? 0 :
                                (inst_code==`INST_SH) ? 1 : 2;
                    check_dev_addr(src1+imm, `DEV_ATTR_WRITE);
                end
                if (aw_valid && aw_ready) begin
                    r_record_aw_size <= r_aw_size;
                    r_aw_valid <= 0;
                    r_aw_addr <= 0;
                    r_aw_id <= 0;
                    r_aw_size <= 0;
                end

                // write data
                if (aw_valid && aw_ready) begin
                    r_w_valid <= 1;
                    case (inst_code)
                        `INST_SB:           begin r_w_strb <= 4'h1<<signed_data_shift_val; r_w_data <= shifted_w_data; r_w_last <= 1; end
                        `INST_SH:           begin r_w_strb <= 4'h3<<signed_data_shift_val; r_w_data <= shifted_w_data; r_w_last <= 1; end
                        `INST_SW:           begin r_w_strb <= 4'hF<<signed_data_shift_val; r_w_data <= shifted_w_data; r_w_last <= 1; end
                        default: ;
                    endcase
                end
                if (w_valid && w_ready) begin
                    dpi_dev_skip(1, src1 + imm, {25'h0, r_record_aw_size, r_w_strb}, r_w_data);
                    r_w_valid <= 0;
                    r_w_strb <= 0;
                    r_w_data <= 0;
                    r_w_last <= 0;
                end

                // write response
                if (w_valid && w_ready) begin
                    r_b_ready <= 1;
                end
                if (b_valid && b_ready) begin
                    r_b_ready <= 0;
                    // check error response
                    if (b_resp!=0 || b_id!=`AXI4_ID_LSU) begin
                        $error("LSU Write data error, addr:%x data:%x resp:%x id:%x\n", src1 + imm, src2, b_resp, b_id);
                    end
                end
                
                // notify prev module
                if (b_valid && b_ready) begin
                    // pc <= dnpc;
                    r_dnpc <= pc + 4;
                    r_result <= 0;
                    r_result_mem_width <= 0;
                    r_result_update_csr <= 0;
                    r_prev_ready <= 1;
                end

            end else begin
                if (inst_code==`INST_LB || 
                    inst_code==`INST_LH || 
                    inst_code==`INST_LW || 
                    inst_code==`INST_LBU || 
                    inst_code==`INST_LHU) begin
                end
                // read request
                if (!ar_valid && !r_valid) begin
                    r_ar_valid <= 1;
                    r_ar_addr <= src1+imm; // sram会4字节对齐
                    r_ar_id <= `AXI4_ID_LSU;
                    r_ar_len <= 0; // 读取数据总burst数量，2^n
                    r_ar_size <= (inst_code==`INST_LB || inst_code==`INST_LBU) ? 0 :
                                (inst_code==`INST_LH || inst_code==`INST_LHU) ? 1 :
                                2; // 单个burst读取大小，2^n字节
                    r_ar_burst <= 1; // burst类型，0--FIXED 1--INCR 2--WRAP
                    check_dev_addr(src1+imm, `DEV_ATTR_READ);
                end
                if (ar_valid && ar_ready) begin
                    r_ar_valid <= 0;
                    r_ar_addr <= 0;
                    r_ar_id <= 0;
                    r_ar_len <= 0;
                    r_ar_size <= 0;
                    r_ar_burst <= 0;
                    r_record_ar_len <= r_ar_len;
                    r_record_ar_size <= r_ar_size;
                end

                // read data
                if (ar_valid && ar_ready) begin
                    r_r_ready <= 1;
                end
                if (r_valid) begin
                    // 读取时需要按照4字节对齐计算偏移
                    case (inst_code)
                        `INST_LB:           r_result <= sext((shifted_r_data) & 32'h000000FF, 8);
                        `INST_LH:           r_result <= sext((shifted_r_data) & 32'h0000FFFF, 16);
                        `INST_LW:           r_result <= sext((shifted_r_data) & 32'hFFFFFFFF, 32);
                        `INST_LBU:          r_result <= (shifted_r_data) & 32'hFF;
                        `INST_LHU:          r_result <= (shifted_r_data) & 32'hFFFF;
                        default: ;
                    endcase
                end
                if (r_valid && r_ready) begin
                    r_r_ready <= 0;
                    case (inst_code)
                        `INST_LB:           dpi_dev_skip(0, src1 + imm, {21'h0, r_record_ar_size, r_record_ar_len}, sext((shifted_r_data) & 32'h000000FF, 8));
                        `INST_LH:           dpi_dev_skip(0, src1 + imm, {21'h0, r_record_ar_size, r_record_ar_len}, sext((shifted_r_data) & 32'h0000FFFF, 16));
                        `INST_LW:           dpi_dev_skip(0, src1 + imm, {21'h0, r_record_ar_size, r_record_ar_len}, sext((shifted_r_data) & 32'hFFFFFFFF, 32));
                        `INST_LBU:          dpi_dev_skip(0, src1 + imm, {21'h0, r_record_ar_size, r_record_ar_len}, (shifted_r_data) & 32'hFF);
                        `INST_LHU:          dpi_dev_skip(0, src1 + imm, {21'h0, r_record_ar_size, r_record_ar_len}, (shifted_r_data) & 32'hFFFF);
                        default: ;
                    endcase
                    // check error response
                    if (r_resp!=0 || r_last!=1 || r_id!=`AXI4_ID_LSU) begin
                        $error("LSU Read data error, addr:%x resp:%x last:%x id:%x\n", pc, r_resp, r_last, r_id);
                    end
                end

                // notify prev module
                if (r_valid && r_ready) begin
                    r_dnpc <= pc + 4;
                    r_result_mem_width <= 0;
                    r_result_update_csr <= 1;
                    r_prev_ready <= 1;
                end
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