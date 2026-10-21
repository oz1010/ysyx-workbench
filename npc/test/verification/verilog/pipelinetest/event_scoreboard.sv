`include "pipeline_types.svh"

module event_scoreboard #(
    parameter integer N = 5
) (
    input wire clk, reset,
    input instruction_record_t ref_records [0:N-1], dut_records [0:N-1],
    output reg [31:0] compared_count,
    output wire complete
);
    instruction_record_t expected_record, actual_record;
    reg [31:0] write_mask;
    assign complete = compared_count == N;
    always @* begin
        expected_record = '0;
        actual_record = '0;
        if (compared_count < N) begin
            expected_record = ref_records[compared_count];
            actual_record = dut_records[compared_count];
        end
        case (expected_record.mem_op[1:0])
            0: write_mask = 32'h000000ff;
            1: write_mask = 32'h0000ffff;
            default: write_mask = 32'hffffffff;
        endcase
    end
    always @(posedge clk) begin
        if (reset) compared_count <= 0;
        else if (compared_count < N && expected_record.retired && actual_record.retired) begin
            assert(expected_record.seq_id == compared_count);
            assert(actual_record.seq_id == compared_count);
            assert(expected_record.mem_req == expected_record.mem_rsp);
            assert(actual_record.mem_req == actual_record.mem_rsp);
            assert(expected_record.gpr_wen == actual_record.gpr_wen);
            if (expected_record.gpr_wen) begin
                assert(expected_record.gpr_waddr == actual_record.gpr_waddr);
                assert(expected_record.gpr_wdata == actual_record.gpr_wdata);
            end
            assert(expected_record.mem_req == actual_record.mem_req);
            assert(expected_record.mem_rsp == actual_record.mem_rsp);
            if (expected_record.mem_req) begin
                assert(expected_record.mem_addr == actual_record.mem_addr);
                assert(expected_record.mem_op == actual_record.mem_op);
                if (expected_record.mem_op[3])
                    assert((expected_record.mem_wdata & write_mask) ==
                           (actual_record.mem_wdata & write_mask));
                else assert(expected_record.mem_rdata == actual_record.mem_rdata);
            end
            assert(expected_record.csr_wen == actual_record.csr_wen);
            if (expected_record.csr_wen) begin
                assert(expected_record.csr_waddr == actual_record.csr_waddr);
                assert(expected_record.csr_wdata == actual_record.csr_wdata);
            end
            assert(expected_record.trap_en == actual_record.trap_en);
            if (expected_record.trap_en) begin
                assert(expected_record.trap_epc == actual_record.trap_epc);
                assert(expected_record.trap_cause == actual_record.trap_cause);
                assert(expected_record.trap_tval == actual_record.trap_tval);
                assert(expected_record.trap_status == actual_record.trap_status);
            end
            compared_count <= compared_count + 1;
        end
    end
endmodule
