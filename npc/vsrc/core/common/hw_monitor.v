module hw_monitor #(
    parameter INST_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32,
    parameter BRESP_WIDTH = 2,
    parameter RRESP_WIDTH = 2
) (
    input  wire                         clk,
    input  wire                         rst,

    input  wire                         hw_monitor_icache_en,
    input  wire                         hw_monitor_icache_hit,
    input  wire                         hw_monitor_dcache_en,
    input  wire                         hw_monitor_dcache_hit,

    input  wire                         hw_monitor_ls_en,
    input  wire                         hw_monitor_ls_iswrite,
    input  wire [DATA_WIDTH-1:0]        hw_monitor_ls_data,

    output wire                         done
);

// CORE TICK
always @(posedge clk) begin
    if (rst) begin
        func_cpu_stat_ctrl(`HW_CPU_STAT_TICK, 0);
    end else begin
        func_cpu_stat_ctrl(`HW_CPU_STAT_TICK, 1);
    end
end

always @(posedge clk) begin
    if (rst) begin
    end else begin
        // LSU
        if (hw_monitor_ls_en) begin
            if (hw_monitor_ls_iswrite) begin
                func_cpu_stat_ctrl(`HW_CPU_STAT_DATA, hw_monitor_ls_data);
            end else begin 
                func_cpu_stat_ctrl(`HW_CPU_STAT_DATA, hw_monitor_ls_data);
            end
        end
        // ICACHE
        if (hw_monitor_icache_en) begin
            if (hw_monitor_icache_hit) begin
                func_cpu_stat_ctrl(`HW_CPU_STAT_ICACHE_HIT, 1);
            end else begin
                func_cpu_stat_ctrl(`HW_CPU_STAT_ICACHE_MISS, 1);
            end
        end
        // DCACHE
        if (hw_monitor_dcache_en) begin
            if (hw_monitor_dcache_hit) begin
                func_cpu_stat_ctrl(`HW_CPU_STAT_DCACHE_HIT, 1);
            end else begin
                func_cpu_stat_ctrl(`HW_CPU_STAT_DCACHE_MISS, 1);
            end
        end
    end
end

endmodule
