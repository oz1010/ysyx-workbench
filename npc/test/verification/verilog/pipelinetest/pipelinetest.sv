`include "pipeline_types.svh"

// All matching is by accepted sequence slot and in-order retirement, never PC.
// Tasks exclude redirects/flush, interrupts, CSR and traps.
module pipelinetest #(
    parameter integer N = 5,
    parameter bit WITH_MEM = 0,
    parameter bit STALL = 0,
    parameter integer MAX_WAIT = 2,
    parameter integer MAX_CYCLES = 96,
    parameter integer MEM_BYTES = 16,
    parameter [31:0] RESET_PC = 32'h30000000
) (
    input wire clk,
    input wire [N*32-1:0] symbolic_instructions,
    input wire [MEM_BYTES*8-1:0] initial_mem,
    input wire if_allow_request, mem_allow_request,
    input wire [31:0] if_response_delay, mem_response_delay
);
    // Top-level inputs are unconstrained formal environment sources. Freeze
    // instruction slots after reset without changing any DUT-internal state.
    reg [N*32-1:0] sequence_bits;
    always @(posedge clk) if (reset) sequence_bits <= symbolic_instructions;
    reg [2:0] reset_count = 0;
    wire reset = reset_count < 3;
    reg [31:0] cycle_count;
    always @(posedge clk) begin
        if (reset) begin
            reset_count <= reset_count + 1;
            cycle_count <= 0;
        end else if (cycle_count < MAX_CYCLES) cycle_count <= cycle_count + 1;
    end
    initial begin
        assert(N > 0);
        assert(MEM_BYTES >= 4 && MEM_BYTES % 4 == 0);
        assert(MAX_CYCLES > N + 3);
        assert(MAX_WAIT >= 0);
    end

    wire [31:0] instr_seq [0:N-1];
    wire is_mem [0:N-1];
    instruction_sequence #(.N(N), .WITH_MEM(WITH_MEM), .MEM_BYTES(MEM_BYTES)) sequence_gen (
        .sequence_bits(sequence_bits), .instr_seq(instr_seq), .is_mem(is_mem)
    );

    // Side 0 = independent single-cycle reference, side 1 = Chisel DUT.
    wire [1:0] if_req_valid, if_req_ready, if_rsp_valid, if_rsp_ready;
    wire [31:0] if_req_addr [0:1], if_req_wdata [0:1], if_rsp_data [0:1];
    wire [3:0] if_req_op [0:1];
    wire [1:0] mem_req_valid, mem_req_ready, mem_rsp_valid, mem_rsp_ready;
    wire [31:0] mem_req_addr [0:1], mem_req_wdata [0:1], mem_rsp_data [0:1];
    wire [31:0] mem_raw_data [0:1];
    wire [3:0] mem_req_op [0:1];
    wire [1:0] gpr_wen, csr_wen, trap_en, inst_done;
    wire [3:0] gpr_waddr [0:1];
    wire [11:0] csr_waddr [0:1];
    wire [31:0] gpr_wdata [0:1], csr_wdata [0:1];
    wire [31:0] trap_epc [0:1], trap_cause [0:1], trap_tval [0:1], trap_status [0:1];
    wire [31:0] pc [0:1], dnpc [0:1];

`define CORE_PORTS(S) \
    .clock(clk), .reset(reset), .reset_pc(RESET_PC), .io_interrupt(1'b0), \
    .io_if_req_valid(if_req_valid[S]), .io_if_req_ready(if_req_ready[S]), \
    .io_if_req_addr(if_req_addr[S]), .io_if_req_op(if_req_op[S]), \
    .io_if_req_wdata(if_req_wdata[S]), .io_if_rsp_valid(if_rsp_valid[S]), \
    .io_if_rsp_ready(if_rsp_ready[S]), .io_if_rsp_data(if_rsp_data[S]), \
    .io_if_rsp_error(1'b0), \
    .io_mem_req_valid(mem_req_valid[S]), .io_mem_req_ready(mem_req_ready[S]), \
    .io_mem_req_addr(mem_req_addr[S]), .io_mem_req_op(mem_req_op[S]), \
    .io_mem_req_wdata(mem_req_wdata[S]), .io_mem_rsp_valid(mem_rsp_valid[S]), \
    .io_mem_rsp_ready(mem_rsp_ready[S]), .io_mem_rsp_data(mem_rsp_data[S]), \
    .io_mem_rsp_error(1'b0), \
    .gpr_wen(gpr_wen[S]), .gpr_waddr(gpr_waddr[S]), .gpr_wdata(gpr_wdata[S]), \
    .csr_wen(csr_wen[S]), .csr_waddr(csr_waddr[S]), .csr_wdata(csr_wdata[S]), \
    .trap_en(trap_en[S]), .trap_epc(trap_epc[S]), .trap_cause(trap_cause[S]), \
    .trap_tval(trap_tval[S]), .trap_status(trap_status[S]), \
    .pc(pc[S]), .dnpc(dnpc[S]), .inst_done(inst_done[S])

    riscv32e_core_sc reference_core (`CORE_PORTS(0));
    riscv32e_core dut (`CORE_PORTS(1));
`undef CORE_PORTS

    wire [31:0] ref_executed, ref_retired, dut_retired;
    wire ref_execute = !reset && ref_executed < N;
    // The REF has no execution-enable input. After the finite sequence feed NOPs;
    // do not gate its clock or reset it before the last retirement is captured.
    assign if_req_ready[0] = !reset;
    assign if_rsp_valid[0] = !reset;
    assign if_rsp_data[0] = ref_execute ? instr_seq[ref_executed] : 32'h00000013;

    reg [31:0] if_accepted, if_returned;
    reg [31:0] accepted_ids [0:N-1];
    wire if_busy;
    wire if_request = if_req_valid[1] && if_req_ready[1];
    wire if_response = if_rsp_valid[1] && if_rsp_ready[1];
    wire [31:0] next_instruction = if_accepted < N ? instr_seq[if_accepted] : 32'h00000013;
    bounded_response #(.PIPELINED(1), .STALL(STALL), .MAX_WAIT(MAX_WAIT)) instruction_server (
        .clk(clk), .reset(reset), .enable(if_accepted < N),
        .allow_request(if_allow_request), .response_delay(if_response_delay),
        .req_valid(if_req_valid[1]), .req_ready(if_req_ready[1]),
        .response_payload(next_instruction), .rsp_valid(if_rsp_valid[1]),
        .rsp_ready(if_rsp_ready[1]), .rsp_payload(if_rsp_data[1]), .busy(if_busy)
    );
    always @(posedge clk) begin
        if (reset) begin
            if_accepted <= 0;
            if_returned <= 0;
            for (integer i = 0; i < N; i = i + 1) accepted_ids[i] <= 0;
        end else begin
            if (if_request) begin
                assert(if_accepted < N);
                // Address is checked only as an independent straight-line IF
                // contract. It is NOT used to pair architectural event records.
                assert(if_req_addr[1] == RESET_PC + 4*if_accepted);
                assert(if_req_op[1] == 4'h2);
                assert(if_req_wdata[1] == 0);
                if (if_accepted < N) accepted_ids[if_accepted] <= if_accepted;
                if_accepted <= if_accepted + 1;
            end
            if (if_response) begin
                assert(if_returned < if_accepted);
                if (if_returned < N) assert(accepted_ids[if_returned] == if_returned);
                if_returned <= if_returned + 1;
            end
            assert(if_returned <= if_accepted);
            assert(if_accepted <= N);
            // After N accepted fetches the environment stops serving. A held
            // speculative fetch is allowed, but not additional side effects.
        end
    end

    wire [1:0] mem_busy;
    for (genvar s = 0; s < 2; s = s + 1) begin : memory_side
        symbolic_memory #(.MEM_BYTES(MEM_BYTES), .ZERO_LATENCY(s == 0),
                          .STALL(STALL), .MAX_WAIT(MAX_WAIT)) memory_model (
            .clk(clk), .reset(reset), .initial_mem(initial_mem),
            .allow_request(mem_allow_request), .response_delay(mem_response_delay),
            .req_valid(mem_req_valid[s]), .req_ready(mem_req_ready[s]),
            .req_addr(mem_req_addr[s]), .req_wdata(mem_req_wdata[s]), .req_op(mem_req_op[s]),
            .rsp_valid(mem_rsp_valid[s]), .rsp_ready(mem_rsp_ready[s]),
            .rsp_data(mem_rsp_data[s]), .raw_data(mem_raw_data[s]), .busy(mem_busy[s])
        );
    end
    request_stability if_protocol (
        .clk(clk), .reset(reset), .valid(if_req_valid[1]), .ready(if_req_ready[1]),
        .payload({if_req_addr[1], if_req_op[1], if_req_wdata[1]})
    );
    request_stability mem_protocol (
        .clk(clk), .reset(reset), .valid(mem_req_valid[1]), .ready(mem_req_ready[1]),
        .payload({mem_req_addr[1], mem_req_op[1], mem_req_wdata[1]})
    );

    instruction_record_t ref_records [0:N-1], dut_records [0:N-1];
    wire [31:0] mem_requests, mem_responses;
    wire mem_pending;
    ref_monitor #(.N(N)) reference_monitor (
        .clk(clk), .reset(reset), .execute(ref_execute), .inst_done(inst_done[0]),
        .gpr_wen(gpr_wen[0]), .gpr_waddr(gpr_waddr[0]), .gpr_wdata(gpr_wdata[0]),
        .mem_req(mem_req_valid[0] && mem_req_ready[0]),
        .mem_rsp(mem_rsp_valid[0] && mem_rsp_ready[0]),
        .mem_addr(mem_req_addr[0]), .mem_op(mem_req_op[0]), .mem_wdata(mem_req_wdata[0]),
        .mem_raw_data(mem_raw_data[0]), .csr_wen(csr_wen[0]), .trap_en(trap_en[0]),
        .records(ref_records), .executed_count(ref_executed), .retired_count(ref_retired)
    );
    dut_monitor #(.N(N)) pipeline_monitor (
        .clk(clk), .reset(reset), .is_mem(is_mem), .returned_count(if_returned),
        .inst_done(inst_done[1]), .gpr_wen(gpr_wen[1]),
        .gpr_waddr(gpr_waddr[1]), .gpr_wdata(gpr_wdata[1]),
        .mem_req(mem_req_valid[1] && mem_req_ready[1]),
        .mem_rsp(mem_rsp_valid[1] && mem_rsp_ready[1]),
        .mem_addr(mem_req_addr[1]), .mem_op(mem_req_op[1]), .mem_wdata(mem_req_wdata[1]),
        .mem_rdata(mem_rsp_data[1]), .csr_wen(csr_wen[1]), .trap_en(trap_en[1]),
        .records(dut_records), .retired_count(dut_retired),
        .mem_request_count(mem_requests), .mem_response_count(mem_responses),
        .mem_pending(mem_pending)
    );
    wire [31:0] compared_count;
    wire records_complete;
    event_scoreboard #(.N(N)) scoreboard (
        .clk(clk), .reset(reset), .ref_records(ref_records), .dut_records(dut_records),
        .compared_count(compared_count), .complete(records_complete)
    );
    wire complete = records_complete && ref_retired == N && dut_retired == N &&
                    if_accepted == N && if_returned == N && !if_busy &&
                    !mem_busy[1] && !mem_pending && mem_requests == mem_responses;
    reg previous_retire;
    always @(posedge clk) begin
        if (reset) previous_retire <= 0;
        else begin
            previous_retire <= inst_done[1];
            // Explicit x0 diagnostic probes, not a substitute for port-event
            // comparison. These two paths are the only GPR hierarchy dependency.
            assert(reference_core.m_gprs.x[0] == 0);
            assert(dut.m_gprs.x[0] == 0);
            if (!WITH_MEM) assert(!mem_req_valid[0] && !mem_req_valid[1]);
            if (!ref_execute) begin
                assert(!(gpr_wen[0] && gpr_waddr[0] != 0));
                assert(!mem_req_valid[0] && !csr_wen[0] && !trap_en[0]);
            end
            if (dut_retired == N) begin
                assert(!inst_done[1]);
                assert(!(gpr_wen[1] && gpr_waddr[1] != 0));
                assert(!mem_req_valid[1] && !mem_pending && !mem_busy[1]);
            end
`ifdef CHECK_PROGRESS
            if (cycle_count == MAX_CYCLES) assert(complete);
`endif
            cover(complete);
            if (N >= 2) begin
                cover(previous_retire && inst_done[1]);
                cover(if_accepted > dut_retired + 1);
            end
            if (STALL && MAX_WAIT > 0) begin
                cover(if_busy && !if_rsp_valid[1]);
                cover(if_accepted < N && if_req_valid[1] && !if_req_ready[1]);
            end
            if (WITH_MEM) begin
                if (STALL && MAX_WAIT > 0) begin
                    cover(mem_req_valid[1] && !mem_req_ready[1]);
                    cover(mem_busy[1] && !mem_rsp_valid[1]);
                end
                cover(complete && mem_requests != 0);
            end
        end
    end
    for (genvar i = 1; i < N; i = i + 1) begin : dependency_coverage
        always @(posedge clk) if (!reset) begin
            cover(complete && instr_seq[i-1][6:0] != 7'h23 &&
                  instr_seq[i-1][11:7] != 0 && instr_seq[i][6:0] != 7'h37 &&
                  instr_seq[i][19:15] == instr_seq[i-1][11:7]);
            cover(complete && instr_seq[i-1][6:0] != 7'h23 &&
                  instr_seq[i][6:0] != 7'h23 && instr_seq[i][11:7] != 0 &&
                  instr_seq[i][11:7] == instr_seq[i-1][11:7]);
        end
    end
    for (genvar op = 0; op < 8; op = op + 1) begin : memory_coverage
        if (WITH_MEM && (op <= 2 || op == 4 || op == 5)) begin
            always @(posedge clk) if (!reset)
                cover(mem_req_valid[1] && mem_req_ready[1] && mem_req_op[1] == op);
        end
        if (WITH_MEM && op <= 2) begin
            always @(posedge clk) if (!reset)
                cover(mem_req_valid[1] && mem_req_ready[1] && mem_req_op[1] == op + 8);
        end
    end
endmodule
