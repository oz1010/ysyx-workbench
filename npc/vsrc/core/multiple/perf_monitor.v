module perf_monitor (
    input  wire         clk,
    input  wire         rst,
    input  wire [31:0]  pc,
    input  wire [31:0]  inst,
    input  wire         if_valid,
    input  wire         id_ready,
    input  wire         id_valid,
    input  wire         ex_ready,
    input  wire         ex_valid,
    input  wire         ls_ready,
    input  wire         ls_valid,
    input  wire         wb_ready,
    input  wire [`INST_CODE_W-1:0]  inst_code,
    output wire         done
);

initial begin
    // $display("Enable perf monitor");
end

reg last_if_valid;
reg last_id_valid;
reg last_ls_valid;
reg last_ex_valid;

always @(posedge clk) begin
    if (rst) begin
        func_monitor_item(0, 0, 0);
        last_if_valid <= 0;
        last_id_valid <= 0;
        last_ls_valid <= 0;
        last_ex_valid <= 0;
    end else begin
        last_if_valid <= if_valid;
        last_id_valid <= id_valid;
        last_ls_valid <= ls_valid;
        last_ex_valid <= ex_valid;

        // IFU取到指令
        if (!last_if_valid && if_valid) begin
            func_monitor_item(1, {28'h0,`AXI4_ID_IFU}, 1);
            func_cpu_stat_ctrl(`HW_CPU_STAT_INST, pc);
        end
        // 译码出各种类别的指令, 如计算类指令, 访存指令, CSR指令等
        if (!last_id_valid && id_valid) begin
            func_monitor_item(1, {28'h0,`AXI4_ID_IDU}, 1);
        end
        // LSU取到数据
        if (!last_ls_valid && ls_valid) begin
            func_monitor_item(1, {28'h0,`AXI4_ID_LSU}, 1);
        end
        // EXU完成计算
        if (!last_ex_valid && ex_valid) begin
            func_monitor_item(1, {28'h0,`AXI4_ID_EXU}, 1);
        end
        // WBU完成回写，移到仿真中去统计

        if (!last_id_valid && id_valid) begin
            func_monitor_item(2, {16'h0, inst_code}, 1);
        end
    end
end

endmodule
