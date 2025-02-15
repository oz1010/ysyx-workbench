// module write_back #(
//     parameter INST_WIDTH = 32
// ) (
//     input wire clk,
//     input wire rst,

//     input wire [4:0] rd,
//     input wire [4:0] rs1,
//     input wire [4:0] rs2,
//     input wire [INST_WIDTH-1:0] imm,
//     input wire [15:0] inst_code,

//     input wire [INST_WIDTH-1:0] src1,
//     output wire [INST_WIDTH-1:0] x[`RISCV_CSR_COUNT-1:0],
//     input wire [INST_WIDTH-1:0] result,
//     input wire [7:0] mem_result_width,
//     input wire [INST_WIDTH-1:0] dnpc,
//     output wire [INST_WIDTH-1:0] pc,

//     output wire prev_ready,
//     input wire prev_valid
// );

// wire [1:0] w_wb_prev_state;
// wire [INST_WIDTH-1:0] w_mem_result_width = {{INST_WIDTH-8{1'b0}}, mem_result_width};

// scom_recv m_scom_wb(
//     .clk(clk),
//     .rst(rst),
//     .enable(prev_valid),
//     .prev_ready(prev_ready),
//     .prev_valid(prev_valid),
//     .state(w_wb_prev_state)
// );

// always @(posedge clk or posedge rst) begin
//     if (!rst) begin
//         if (w_wb_prev_state == `SCOM_FOUND) begin
//             pc <= dnpc;
//             if (w_mem_result_width > 0) begin
//                 write_raw_mem(src1 + imm, w_mem_result_width, result);
//             end else begin
//                 x[rd] <= result;
//             end

//             // 确保 x0 始终为零
//             x[0] <= 0;
//         end
//     end
// end

// endmodule