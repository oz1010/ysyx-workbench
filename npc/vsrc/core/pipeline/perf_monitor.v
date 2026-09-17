module perf_monitor (
    input  wire         clk,
    input  wire         rst,

    input  wire         if_in_done,
    input  wire         if_out_done,
    input  wire         id_in_done,
    input  wire         id_out_done,
    input  wire         ex_in_done,
    input  wire         ex_out_done,
    input  wire         ls_in_done,
    input  wire         ls_out_done,
    input  wire         wb_in_done,
    input  wire         wb_out_done,

    input  wire [31:0]  in_if_pc, // 阶段in_done有效时需要存储下来
    input  wire [31:0]  in_id_pc, // 阶段in_done有效时需要存储下来
    input  wire [31:0]  in_ex_pc, // 阶段in_done有效时需要存储下来
    input  wire [31:0]  in_ls_pc, // 阶段in_done有效时需要存储下来
    input  wire [31:0]  in_wb_pc, // 阶段in_done有效时需要存储下来
    input  wire [`INST_CODE_W-1:0]  inst_code,
    input  wire [31:0]  dnpc,

    output wire         done
);

initial begin
    // $display("Enable perf monitor");
end

reg last_if_in_done;
reg last_if_out_done;
reg last_id_in_done;
reg last_id_out_done;
reg last_ex_in_done;
reg last_ex_out_done;
reg last_ls_in_done;
reg last_ls_out_done;
reg last_wb_in_done;
reg last_wb_out_done;

reg [31:0] in_done_if_pc;
reg [31:0] in_done_id_pc;
reg [31:0] in_done_ex_pc;
reg [31:0] in_done_ls_pc;
reg [31:0] in_done_wb_pc;

wire [31:0] if_pc = if_in_done ? in_if_pc : in_done_if_pc;
wire [31:0] id_pc = id_in_done ? in_id_pc : in_done_id_pc;
wire [31:0] ex_pc = ex_in_done ? in_ex_pc : in_done_ex_pc;
wire [31:0] ls_pc = ls_in_done ? in_ls_pc : in_done_ls_pc;
wire [31:0] wb_pc = wb_in_done ? in_wb_pc : in_done_wb_pc;

wire core_valid = !rst;
reg last_core_valid;

always @(posedge clk) begin
    if (rst) begin
        last_if_in_done <= 0;
        last_if_out_done <= 0;
        last_id_in_done <= 0;
        last_id_out_done <= 0;
        last_ex_in_done <= 0;
        last_ex_out_done <= 0;
        last_ls_in_done <= 0;
        last_ls_out_done <= 0;
        last_wb_in_done <= 0;
        last_wb_out_done <= 0;
        in_done_if_pc <= 0;
        in_done_id_pc <= 0;
        in_done_ex_pc <= 0;
        in_done_ls_pc <= 0;
        in_done_wb_pc <= 0;
        last_core_valid <= 0;
    end else begin
        last_if_in_done <= if_in_done;
        last_if_out_done <= if_out_done;
        last_id_in_done <= id_in_done;
        last_id_out_done <= id_out_done;
        last_ex_in_done <= ex_in_done;
        last_ex_out_done <= ex_out_done;
        last_ls_in_done <= ls_in_done;
        last_ls_out_done <= ls_out_done;
        last_wb_in_done <= wb_in_done;
        last_wb_out_done <= wb_out_done;
        last_core_valid <= core_valid;
        in_done_if_pc <= if_in_done ? in_if_pc : in_done_if_pc;
        in_done_id_pc <= id_in_done ? in_id_pc : in_done_id_pc;
        in_done_ex_pc <= ex_in_done ? in_ex_pc : in_done_ex_pc;
        in_done_ls_pc <= ls_in_done ? in_ls_pc : in_done_ls_pc;
        in_done_wb_pc <= wb_in_done ? in_wb_pc : in_done_wb_pc;

        if (!last_core_valid & core_valid) func_add_monitor_item(-1, 0, 0);

        // IFU
        if (!last_if_in_done & if_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_IFU}, if_pc, 0);
        if (!last_if_out_done & if_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_IFU}, if_pc, 0);
        // IDU
        if (!last_id_in_done & id_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_IDU}, id_pc, 0);
        if (!last_id_out_done & id_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_IDU}, id_pc, {16'h0, inst_code});
        // EXU
        if (!last_ex_in_done & ex_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_EXU}, ex_pc, 0);
        if (!last_ex_out_done & ex_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_EXU}, ex_pc, 0);
        // LSU
        if (!last_ls_in_done & ls_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_LSU}, ls_pc, 0);
        if (!last_ls_out_done & ls_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_LSU}, ls_pc, 0);
        // WBU
        if (!last_wb_in_done & wb_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_WBU}, wb_pc, 0);
        if (!last_wb_out_done & wb_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_WBU}, wb_pc, dnpc);

        // 硬件统计
        if (!last_wb_out_done & wb_out_done) func_cpu_stat_ctrl(`HW_CPU_STAT_INST, if_pc);
    end
end

endmodule
