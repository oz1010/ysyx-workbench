`include "pipeline_types.svh"

module dut_monitor #(
    parameter integer N = 5
) (
    input wire clk, reset,
    input wire is_mem [0:N-1],
    input wire [31:0] returned_count,
    input wire inst_done, gpr_wen,
    input wire [3:0] gpr_waddr,
    input wire [31:0] gpr_wdata,
    input wire mem_req, mem_rsp,
    input wire [31:0] mem_addr, mem_wdata, mem_rdata,
    input wire [3:0] mem_op,
    input wire csr_wen, trap_en,
    output instruction_record_t records [0:N-1],
    output reg [31:0] retired_count, mem_request_count, mem_response_count,
    output reg mem_pending
);
    reg [31:0] mem_cursor, pending_id;
    reg [31:0] next_mem_id;
    integer i;
    always @* begin
        next_mem_id = N;
        // In-order, single-outstanding MEM contract, independent of DUT payload.
        for (integer k = N-1; k >= 0; k = k - 1)
            if (k >= mem_cursor && is_mem[k]) next_mem_id = k;
    end
    always @(posedge clk) begin
        if (reset) begin
            retired_count <= 0;
            mem_request_count <= 0;
            mem_response_count <= 0;
            mem_cursor <= 0;
            pending_id <= 0;
            mem_pending <= 0;
            for (i = 0; i < N; i = i + 1) records[i] <= '0;
        end else begin
            // Unsupported events must fail, never disappear from the log.
            assert(!csr_wen);
            assert(!trap_en);
            if (gpr_wen && gpr_waddr != 0) assert(inst_done);
            if (mem_req) begin
                assert(!mem_pending);
                assert(next_mem_id < N);
                assert(next_mem_id >= retired_count);
                assert(next_mem_id < returned_count);
                if (next_mem_id < N) begin
                    assert(!records[next_mem_id].mem_req);
                    records[next_mem_id].mem_req <= 1;
                    records[next_mem_id].mem_addr <= mem_addr;
                    records[next_mem_id].mem_op <= mem_op;
                    records[next_mem_id].mem_wdata <= mem_wdata;
                end
                pending_id <= next_mem_id;
                mem_cursor <= next_mem_id + 1;
                mem_pending <= 1;
                mem_request_count <= mem_request_count + 1;
            end
            if (mem_rsp) begin
                assert(mem_pending);
                assert(pending_id < N);
                if (pending_id < N) begin
                    assert(!records[pending_id].mem_rsp);
                    records[pending_id].mem_rsp <= 1;
                    records[pending_id].mem_rdata <= mem_rdata;
                end
                mem_pending <= 0;
                mem_response_count <= mem_response_count + 1;
            end
            if (inst_done) begin
                assert(retired_count < N);
                assert(retired_count < returned_count);
                if (retired_count < N) begin
                    assert(!records[retired_count].retired);
                    assert(records[retired_count].mem_req == is_mem[retired_count]);
                    if (is_mem[retired_count])
                        assert(records[retired_count].mem_rsp ||
                               (mem_rsp && mem_pending && pending_id == retired_count));
                    records[retired_count].seq_id <= retired_count;
                    records[retired_count].retired <= 1;
                    records[retired_count].gpr_wen <= gpr_wen && gpr_waddr != 0;
                    records[retired_count].gpr_waddr <= gpr_waddr;
                    records[retired_count].gpr_wdata <= gpr_wdata;
                end
                retired_count <= retired_count + 1;
            end
        end
    end
endmodule
