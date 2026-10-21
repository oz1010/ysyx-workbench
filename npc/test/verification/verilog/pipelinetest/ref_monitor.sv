`include "pipeline_types.svh"

module ref_monitor #(
    parameter integer N = 5
) (
    input wire clk, reset, execute, inst_done,
    input wire gpr_wen,
    input wire [3:0] gpr_waddr,
    input wire [31:0] gpr_wdata,
    input wire mem_req, mem_rsp,
    input wire [31:0] mem_addr, mem_wdata, mem_raw_data,
    input wire [3:0] mem_op,
    input wire csr_wen, trap_en,
    output instruction_record_t records [0:N-1],
    output reg [31:0] executed_count, retired_count
);
    instruction_record_t pending;
    reg pending_valid;
    integer i;
    always @(posedge clk) begin
        if (reset) begin
            executed_count <= 0;
            retired_count <= 0;
            pending_valid <= 0;
            pending <= '0;
            for (i = 0; i < N; i = i + 1) records[i] <= '0;
        end else begin
            // REF inst_done is registered but write events are combinational.
            // Capture execute-edge fields, then pair that snapshot with the
            // following edge's inst_done. This includes the very first execute.
            pending_valid <= execute;
            if (execute) begin
                assert(executed_count < N);
                assert(!csr_wen && !trap_en);
                assert(mem_req == mem_rsp);
                pending <= '0;
                pending.seq_id <= executed_count;
                pending.retired <= 1;
                pending.gpr_wen <= gpr_wen && gpr_waddr != 0;
                pending.gpr_waddr <= gpr_waddr;
                pending.gpr_wdata <= gpr_wdata;
                pending.mem_req <= mem_req;
                pending.mem_rsp <= mem_rsp;
                pending.mem_addr <= mem_addr;
                pending.mem_op <= mem_op;
                pending.mem_wdata <= mem_wdata;
                pending.mem_rdata <= mem_raw_data;
                executed_count <= executed_count + 1;
            end
            if (pending_valid) begin
                assert(inst_done);
                assert(retired_count < N);
                if (retired_count < N) records[retired_count] <= pending;
                retired_count <= retired_count + 1;
            end
        end
    end
endmodule
