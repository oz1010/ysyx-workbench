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

    input  wire         wb_gpr_wen,    // WBU进入时的GPR写使能
    input  wire [4:0]   wb_gpr_windex, // WBU进入时的GPR写索引
    input  wire [31:0]  wb_gpr_wdata,  // WBU进入时的GPR写数据
    input  wire [`CSR_WCH_W-1:0] wb_csr_wch, // WBU进入时的CSR写通道（2组{en,addr,data}）

    input  wire [1:0]   if_cache_stat, // IFU取指对应的icache命中状态（NONE/HIT/MISS）
    input  wire [1:0]   ls_cache_stat, // LSU访存对应的dcache命中状态（NONE/HIT/MISS，写为NONE）
    input  wire         ls_mem_access, // LSU访存标识：访存指令（读或写）out_valid期间为1
    input  wire [31:0]  ls_mem_addr,   // LSU访存目标地址，访存指令out_valid期间有效

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

/* WBU进入时的CSR写通道拆分：2组{en(1), addr(CSR_ADDR_W), data(32)} */
wire                        mon_csr_wen[0:`CSR_WCH_ITEM_COUNT-1];
wire [`CSR_ADDR_W-1:0]      mon_csr_waddr[0:`CSR_WCH_ITEM_COUNT-1];
wire [31:0]                 mon_csr_wdata[0:`CSR_WCH_ITEM_COUNT-1];
assign {
    mon_csr_wen[1], mon_csr_wen[0],
    mon_csr_waddr[1], mon_csr_waddr[0],
    mon_csr_wdata[1], mon_csr_wdata[0]
} = wb_csr_wch;

/* 寄存器写监控项的mid扩展：{保留11bit, 写地址13bit, 写使能, 数据类型2bit, is_end, 阶段4bit} */
wire [12:0] mon_gpr_waddr = {8'h0, wb_gpr_windex};
wire [12:0] mon_csr_waddr_ext[0:`CSR_WCH_ITEM_COUNT-1];
assign mon_csr_waddr_ext[0] = {1'b0, mon_csr_waddr[0]};
assign mon_csr_waddr_ext[1] = {1'b0, mon_csr_waddr[1]};

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
        if (!last_if_out_done & if_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_IFU}, if_pc, {30'h0, if_cache_stat});
        // IDU
        if (!last_id_in_done & id_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_IDU}, id_pc, 0);
        if (!last_id_out_done & id_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_IDU}, id_pc, {16'h0, inst_code});
        // EXU
        if (!last_ex_in_done & ex_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_EXU}, ex_pc, 0);
        if (!last_ex_out_done & ex_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_EXU}, ex_pc, 0);
        // LSU
        if (!last_ls_in_done & ls_in_done) func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_LSU}, ls_pc, 0);
        // LSU结束：mid.kind携带dcache访问状态（0无 1命中 2未命中，写为0），mid.wen为访存标识，
        // wen为1（有访存，含写）时arg为访存目标地址，据此获取数据存储索引
        if (!last_ls_out_done & ls_out_done) func_add_monitor_item({11'h0, 13'h0, ls_mem_access, ls_cache_stat, 1'b1, 4'h`STAGE_INDEX_LSU}, ls_pc, ls_mem_addr);
        // WBU
        if (!last_wb_in_done & wb_in_done) begin
            func_add_monitor_item({28'h0, 4'h`STAGE_INDEX_WBU}, wb_pc, 0);
            // 寄存器写数据：mid扩展数据类型/使能/地址，arg携带写数据
            // kind编码：1=CSR写（两个写通道共用），2=GPR写；寄存器记录不需要携带pc，
            // 处理时取最近进入WBU且未完成的指令记录即可
            if (wb_gpr_wen) func_add_monitor_item({11'h0, mon_gpr_waddr, wb_gpr_wen, 2'h2, 1'b0, 4'h`STAGE_INDEX_WBU}, 0, wb_gpr_wdata);
            if (mon_csr_wen[0]) func_add_monitor_item({11'h0, mon_csr_waddr_ext[0], mon_csr_wen[0], 2'h1, 1'b0, 4'h`STAGE_INDEX_WBU}, 0, mon_csr_wdata[0]);
            if (mon_csr_wen[1]) func_add_monitor_item({11'h0, mon_csr_waddr_ext[1], mon_csr_wen[1], 2'h1, 1'b0, 4'h`STAGE_INDEX_WBU}, 0, mon_csr_wdata[1]);
        end
        if (!last_wb_out_done & wb_out_done) func_add_monitor_item({28'h1, 4'h`STAGE_INDEX_WBU}, wb_pc, dnpc);

        // 硬件统计
        if (!last_wb_out_done & wb_out_done) func_cpu_stat_ctrl(`HW_CPU_STAT_INST, if_pc);
    end
end

endmodule
