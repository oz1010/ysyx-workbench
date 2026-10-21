`include "pipeline_types.svh"

// Synthetic records test the checker, not ISA semantics or DUT correctness.
module scoreboard_selftest #(
    parameter integer FAULT = 0
) (input wire clk);
    reg [4:0] cycle = 0;
    wire reset = cycle == 0;
    instruction_record_t ref_records [0:2], dut_records [0:2];
    wire [31:0] compared_count;
    wire complete;
    always @(posedge clk) if (cycle < 20) cycle <= cycle + 1;
    always @* begin
        for (integer i = 0; i < 3; i = i + 1) begin
            ref_records[i] = '0;
            ref_records[i].seq_id = i;
            ref_records[i].retired = cycle >= i+2;
        end
        ref_records[0].gpr_wen = 1;
        ref_records[0].gpr_waddr = 3;
        ref_records[0].gpr_wdata = 32'h12345678;
        ref_records[1].mem_req = 1;
        ref_records[1].mem_rsp = 1;
        ref_records[1].mem_addr = 4;
        ref_records[1].mem_op = 8; // SB; high wdata bits are intentionally ignored.
        ref_records[1].mem_wdata = 32'hab;
        ref_records[1].mem_rdata = 32'h11223344; // store response data has no semantics.
        ref_records[2].mem_req = 1;
        ref_records[2].mem_rsp = 1;
        ref_records[2].mem_addr = 8;
        ref_records[2].mem_op = 2;
        ref_records[2].mem_rdata = 32'h87654321;
        ref_records[2].csr_wen = 1;
        ref_records[2].csr_waddr = 12'h300;
        ref_records[2].csr_wdata = 32'h1800;
        ref_records[2].trap_en = 1;
        ref_records[2].trap_epc = 32'h30000008;
        ref_records[2].trap_cause = 11;
        ref_records[2].trap_tval = 32'habcdef00;
        ref_records[2].trap_status = 32'h1880;
        for (integer i = 0; i < 3; i = i + 1) begin
            dut_records[i] = ref_records[i];
            // Deliberately different arrival times, never cycle-aligned.
            dut_records[i].retired = cycle >= i+4;
        end
        dut_records[1].mem_wdata = 32'hdeadbeab;
        dut_records[1].mem_rdata = 0;
        dut_records[2].mem_wdata = 32'hffffffff; // load write data is irrelevant.
        case (FAULT)
            1: dut_records[0].gpr_wdata[0] = ~ref_records[0].gpr_wdata[0];
            2: dut_records[0].gpr_waddr = 4;
            3: dut_records[0].gpr_wen = 0;
            4: dut_records[1].mem_addr = 5;
            5: dut_records[1].mem_op = 9;
            6: dut_records[1].mem_wdata[0] = ~ref_records[1].mem_wdata[0];
            7: dut_records[2].mem_rdata[0] = ~ref_records[2].mem_rdata[0];
            8: dut_records[2].csr_waddr = 12'h305;
            9: dut_records[2].csr_wdata = 0;
            10: dut_records[2].trap_epc = 0;
            11: dut_records[2].trap_cause = 3;
            12: dut_records[2].trap_tval = 0;
            13: dut_records[2].trap_status = 0;
            14: dut_records[0].seq_id = 1;
            15: dut_records[0].retired = 0;
            16: dut_records[1].mem_req = 0;
            17: dut_records[1].mem_rsp = 0;
            18: begin dut_records[0].mem_req = 1; dut_records[0].mem_rsp = 1; end
            19: dut_records[2].csr_wen = 0;
            20: dut_records[2].trap_en = 0;
            default: begin end
        endcase
    end
    event_scoreboard #(.N(3)) scoreboard (.*);
    always @(posedge clk) if (!reset) begin
        if (cycle == 12) assert(complete);
        cover(complete);
    end
endmodule
