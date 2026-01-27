module write_back #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 3,
    parameter RRESP_WIDTH = 3
) (
    input   wire                        clk,
    input   wire                        rst,

    output  wire                        gpr_wen,
    output  wire [4:0]                  gpr_windex,
    output  wire [INST_WIDTH-1:0]       gpr_wdata,

    /* 模块输入数据总线 */
    output  wire                        in_ready,
    input   wire                        in_valid,
    input   wire [4:0]                  rd,
    input   wire [INST_WIDTH-1:0]       imm,
    input   wire [`INST_CODE_W-1:0]                 inst_code,
    input   wire [INST_WIDTH-1:0]       result,
    input   wire [7:0]                  mem_result_width,
    input   wire                        result_update_gpr,
    input   wire [INST_WIDTH-1:0]       dnpc,
    input   wire [INST_WIDTH-1:0]       src1,
    input   wire [INST_WIDTH-1:0]       src2,
    /* 模块输出数据总线 */
    input   wire                        out_ready,
    output  wire                        out_valid,
    output  wire [INST_WIDTH-1:0]       w_pc
);

// 程序寄存器
reg [INST_WIDTH-1:0] pc = 0;

wire [1:0] w_wb_prev_state;
wire [INST_WIDTH-1:0] w_mem_result_width = {{INST_WIDTH-8{1'b0}}, mem_result_width};
assign w_pc = pc;

reg r_in_ready;
reg r_out_valid;
reg [7:0] cnt;
reg                         r_gpr_wen;
reg [4:0]                   r_gpr_windex;
reg [INST_WIDTH-1:0]        r_gpr_wdata;

assign gpr_wen = r_gpr_wen;
assign gpr_windex = r_gpr_windex;
assign gpr_wdata = r_gpr_wdata;


assign in_ready = r_in_ready;
assign out_valid = r_out_valid;

always @(posedge clk) begin
    if (rst) begin
        pc <= func_get_reset_pc();
        r_in_ready <= 0;
        r_out_valid <= 0;
    end else begin

        if (in_valid) begin
            if (w_mem_result_width > 0) begin
            end else begin
                if (result_update_gpr) begin
                    r_gpr_wen <= 1;
                    r_gpr_windex <= rd;
                    r_gpr_wdata <= result;
                end

                pc <= dnpc;
                r_in_ready <= 1;
                r_out_valid <= 1;
            end
        end

        if (r_gpr_wen) begin
            r_gpr_wen <= 0;
        end

        if (in_valid && in_ready) begin
            r_in_ready <= 0;
            r_out_valid <= 0;
        end
    end
end

endmodule
