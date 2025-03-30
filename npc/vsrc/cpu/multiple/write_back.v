module write_back #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input wire clk,
    input wire rst,

    input wire [4:0] rd,
    input wire [4:0] rs1,
    input wire [4:0] rs2,
    input wire [INST_WIDTH-1:0] imm,
    input wire [15:0] inst_code,

    output wire [INST_WIDTH-1:0] w_x[`RISCV_CSR_COUNT-1:0],
    input wire [INST_WIDTH-1:0] result,
    input wire [7:0] mem_result_width,
    input wire result_update_csr,
    input wire [INST_WIDTH-1:0] dnpc,
    output wire [INST_WIDTH-1:0] w_pc,

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
    input wire prev_valid
);

/* 寄存器组 */
// 通用寄存器
reg [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0];
// 程序寄存器
reg [INST_WIDTH-1:0] pc;
// 当前指令寄存器
wire [INST_WIDTH-1:0] inst;
// 寄存器别名，register alias, ch2.3
wire [INST_WIDTH-1:0] zero = x[0];
wire [INST_WIDTH-1:0] ra = x[1];
wire [INST_WIDTH-1:0] sp = x[2];
wire [INST_WIDTH-1:0] gp = x[3];
wire [INST_WIDTH-1:0] tp = x[4];
wire [INST_WIDTH-1:0] a[7:0];
assign a[7:0] = x[17:10];

wire [1:0] w_wb_prev_state;
wire [INST_WIDTH-1:0] w_mem_result_width = {{INST_WIDTH-8{1'b0}}, mem_result_width};
assign w_x = x;
assign w_pc = pc;
wire [INST_WIDTH-1:0] src1 = x[rs1];

reg r_prev_ready;
reg [7:0] cnt;

reg r_aw_valid;
reg [ADDR_WIDTH-1:0] r_aw_addr;
reg r_w_valid;
reg [DATA_WIDTH-1:0] r_w_data;
reg [DATA_WIDTH/8-1:0] r_w_strb;
reg r_b_ready;

assign aw_valid = r_aw_valid;
assign aw_addr = r_aw_addr;
assign w_valid = r_w_valid;
assign w_data = r_w_data;
assign w_strb = r_w_strb;
assign b_ready = r_b_ready;

assign prev_ready = r_prev_ready;

wire [2:0] write_status = {b_valid, w_valid, aw_valid};

always @(posedge clk or posedge rst) begin
    if (rst) begin
        pc <= get_reset_pc();
        x[0] <= 0;
        r_prev_ready <= 0;
        r_aw_valid <= 0;
        r_aw_addr <= 0;
        r_w_valid <= 0;
        r_w_data <= 0;
        r_w_strb <= 0;
        r_b_ready <= 0;
    end else begin
        r_aw_valid <= r_aw_valid;
        r_aw_addr <= r_aw_addr;
        r_w_valid <= r_w_valid;
        r_w_data <= r_w_data;
        r_w_strb <= r_w_strb;
        r_b_ready <= r_b_ready;

        if (prev_valid) begin
            if (w_mem_result_width > 0) begin
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
                    r_w_data <= result;
                    r_w_strb <= mem_result_width[3:0];
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
                if (w_valid && w_ready) begin
                    pc <= dnpc;
                    r_prev_ready <= 1;
                end
            end else begin
                if (result_update_csr) x[rd] <= result;

                pc <= dnpc;
                r_prev_ready <= 1;
            end
        end

        if (prev_valid && prev_ready) begin
            r_prev_ready <= 0;
        end

        // 确保 x0 始终为零
        x[0] <= 0;
    end
end

endmodule