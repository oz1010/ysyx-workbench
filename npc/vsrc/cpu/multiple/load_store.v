module load_store #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clock,
    input wire reset,

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

    output wire ar_valid,
    input wire ar_ready,
    output wire [ADDR_WIDTH-1:0] ar_addr,

    input wire r_valid,
    output wire r_ready,
    input wire [DATA_WIDTH-1:0] r_data,
    input wire [RRESP_WIDTH-1:0] r_resp,

    output wire prev_ready,
    input wire prev_valid,
    input wire next_ready,
    output wire next_valid
);

reg r_prev_ready, r_next_valid;
assign prev_ready = r_prev_ready;
assign next_valid = r_next_valid;

reg r_aw_valid;
reg [ADDR_WIDTH-1:0] r_aw_addr;
reg r_w_valid;
reg [DATA_WIDTH-1:0] r_w_data;
reg [DATA_WIDTH/8-1:0] r_w_strb;
reg r_b_ready;
reg r_ar_valid;
reg [ADDR_WIDTH-1:0] r_ar_addr;
reg r_r_ready;

assign aw_valid = r_aw_valid;
assign aw_addr = r_aw_addr;
assign w_valid = r_w_valid;
assign w_data = r_w_data;
assign w_strb = r_w_strb;
assign b_ready = r_b_ready;
wire [2:0] write_status = {b_valid, w_valid, aw_valid};
assign ar_valid = r_ar_valid;
assign ar_addr = r_ar_addr;
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

wire [ADDR_WIDTH-1:0] signed_ar_addr = (src1 + imm) & (~32'h03); // 4字节对齐
wire [DATA_WIDTH-1:0] signed_r_data_shift_bits = 8* ((src1 + imm) & (32'h03));

always @(posedge clock or posedge reset) begin
    if (reset) begin
        r_dnpc <= get_reset_pc();
        r_result <= 0;
        r_result_mem_width <= 0;
        r_result_update_csr <= 0;

        r_prev_ready <= 0;
        r_aw_valid <= 0;
        r_aw_addr <= 0;
        r_w_valid <= 0;
        r_w_data <= 0;
        r_w_strb <= 0;
        r_b_ready <= 0;
        r_ar_valid <= 0;
        r_ar_addr <= 0;
        r_r_ready <= 0;
    end else begin
        r_dnpc <= r_dnpc;
        r_result <= r_result;
        r_result_mem_width <= r_result_mem_width;
        r_result_update_csr <= r_result_update_csr;

        r_aw_valid <= r_aw_valid;
        r_aw_addr <= r_aw_addr;
        r_w_valid <= r_w_valid;
        r_w_data <= r_w_data;
        r_w_strb <= r_w_strb;
        r_b_ready <= r_b_ready;
        r_ar_valid <= r_ar_valid;
        r_ar_addr <= r_ar_addr;
        r_r_ready <= r_r_ready;

        if (prev_valid && !prev_ready) begin
            if (inst_code==`INST_SB || inst_code==`INST_SH || inst_code==`INST_SW) begin
                // write request
                if (write_status==0 && !aw_valid) begin
                    r_aw_valid <= 1;
                    r_aw_addr <= src1 + imm;
                end
                if (aw_valid && aw_ready) begin
                    r_aw_valid <= 0;
                end

                // write data
                if (aw_valid && aw_ready) begin
                    r_w_valid <= 1;
                    case (inst_code)
                        `INST_SB:           begin r_w_strb <= 1; r_w_data <= src2&32'hFF; end
                        `INST_SH:           begin r_w_strb <= 2; r_w_data <= src2&32'hFFFF; end
                        `INST_SW:           begin r_w_strb <= 4; r_w_data <= src2; end
                        default: ;
                    endcase
                end
                if (w_valid && w_ready) begin
                    r_w_valid <= 0;
                end

                // write response
                if (w_valid && w_ready) begin
                    r_b_ready <= 1;
                end
                if (b_valid && b_ready) begin
                    r_b_ready <= 0;
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
                    r_ar_addr <= signed_ar_addr; // 4字节对齐
                    r_ar_valid <= 1;
                end
                if (ar_valid && ar_ready) begin
                    r_ar_valid <= 0;
                end

                // read data
                if (ar_valid && ar_ready) begin
                    r_r_ready <= 1;
                end
                if (r_valid) begin
                    // 读取时需要按照4字节对齐计算偏移
                    case (inst_code)
                        `INST_LB:           r_result <= sext((r_data>>signed_r_data_shift_bits) & 32'h000000FF, 8);
                        `INST_LH:           r_result <= sext((r_data>>signed_r_data_shift_bits) & 32'h0000FFFF, 16);
                        `INST_LW:           r_result <= sext((r_data>>signed_r_data_shift_bits) & 32'hFFFFFFFF, 32);
                        `INST_LBU:          r_result <= (r_data>>signed_r_data_shift_bits) & 32'hFF;
                        `INST_LHU:          r_result <= (r_data>>signed_r_data_shift_bits) & 32'hFFFF;
                        default: ;
                    endcase
                end
                if (r_valid && r_ready) begin
                    r_r_ready <= 0;
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