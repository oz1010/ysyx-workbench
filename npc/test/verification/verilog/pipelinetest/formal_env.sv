// Bounded, single-outstanding server. All nondeterminism is environmental;
// no assumption is made about DUT valid, payload, progress or results.
module bounded_response #(
    parameter integer WIDTH = 32,
    parameter bit PIPELINED = 0,
    parameter bit STALL = 0,
    parameter integer MAX_WAIT = 2
) (
    input wire clk, reset, enable,
    input wire allow_request,
    input wire [31:0] response_delay,
    input wire req_valid,
    output wire req_ready,
    input wire [WIDTH-1:0] response_payload,
    output wire rsp_valid,
    input wire rsp_ready,
    output reg [WIDTH-1:0] rsp_payload,
    output reg busy
);
    reg [31:0] ready_wait, remaining;
    assign req_ready = !reset && enable && (!busy || (PIPELINED && rsp_valid && rsp_ready)) &&
                       (!STALL || allow_request || ready_wait >= MAX_WAIT);
    assign rsp_valid = !reset && busy && remaining == 0;
    always @(posedge clk) begin
        if (reset) begin
            busy <= 0;
            ready_wait <= 0;
            remaining <= 0;
            rsp_payload <= 0;
        end else begin
            if (enable && !busy && req_valid && !req_ready)
                ready_wait <= ready_wait + 1;
            else ready_wait <= 0;
            if (req_valid && req_ready) begin
                busy <= 1;
                rsp_payload <= response_payload;
                remaining <= STALL ? response_delay : 0;
                if (STALL) assume(response_delay <= MAX_WAIT);
            end else if (rsp_valid && rsp_ready) busy <= 0;
            else if (busy && remaining != 0) remaining <= remaining - 1;
        end
    end
endmodule

module request_stability #(
    parameter integer WIDTH = 68
) (
    input wire clk, reset, valid, ready,
    input wire [WIDTH-1:0] payload
);
    reg blocked;
    reg [WIDTH-1:0] saved_payload;
    always @(posedge clk) begin
        if (reset) blocked <= 0;
        else begin
            if (blocked) begin
                assert(valid);
                assert(payload == saved_payload);
            end
            blocked <= valid && !ready;
            saved_payload <= payload;
        end
    end
endmodule

// Two instances get identical symbolic initial bytes, then evolve separately.
// Stores are atomic at acceptance and receive a completion response as loads do.
module symbolic_memory #(
    parameter integer MEM_BYTES = 16,
    parameter bit ZERO_LATENCY = 0,
    parameter bit STALL = 0,
    parameter integer MAX_WAIT = 2
) (
    input wire clk, reset,
    input wire [MEM_BYTES*8-1:0] initial_mem,
    input wire allow_request,
    input wire [31:0] response_delay,
    input wire req_valid,
    output wire req_ready,
    input wire [31:0] req_addr, req_wdata,
    input wire [3:0] req_op,
    output wire rsp_valid,
    input wire rsp_ready,
    output wire [31:0] rsp_data,
    output wire [31:0] raw_data,
    output wire busy
);
    reg [MEM_BYTES*8-1:0] bytes;
    wire [31:0] word_addr = req_addr & 32'hfffffffc;
    wire [31:0] raw_word = bytes[word_addr*8 +: 32];
    assign raw_data = raw_word;
    wire [31:0] shifted = raw_word >> (8*req_addr[1:0]);
    reg [31:0] architectural_load;
    integer b;
    always @* begin
        case (req_op)
            4'h0: architectural_load = {{24{shifted[7]}}, shifted[7:0]};
            4'h1: architectural_load = {{16{shifted[15]}}, shifted[15:0]};
            4'h4: architectural_load = {24'b0, shifted[7:0]};
            4'h5: architectural_load = {16'b0, shifted[15:0]};
            default: architectural_load = raw_word;
        endcase
    end
    if (ZERO_LATENCY) begin : reference_response
        // The single-cycle REF expects an already extended load in its execute
        // cycle and does not stall on req_ready/rsp_valid.
        assign req_ready = !reset;
        assign rsp_valid = !reset && req_valid;
        assign rsp_data = req_op[3] ? 32'b0 : architectural_load;
        assign busy = 0;
    end else begin : dut_response
        bounded_response #(.STALL(STALL), .MAX_WAIT(MAX_WAIT)) server (
            .clk(clk), .reset(reset), .enable(1'b1),
            .allow_request(allow_request), .response_delay(response_delay),
            .req_valid(req_valid), .req_ready(req_ready),
            .response_payload(req_op[3] ? 32'b0 : raw_word),
            .rsp_valid(rsp_valid), .rsp_ready(rsp_ready),
            .rsp_payload(rsp_data), .busy(busy)
        );
    end
    always @(posedge clk) begin
        if (reset) bytes <= initial_mem;
        else if (req_valid && req_ready) begin
            assert(req_op == 0 || req_op == 1 || req_op == 2 ||
                   req_op == 4 || req_op == 5 ||
                   req_op == 8 || req_op == 9 || req_op == 10);
            assert(req_addr < MEM_BYTES);
            if (req_op[1:0] == 1) assert(req_addr[0] == 0);
            if (req_op[1:0] == 2) assert(req_addr[1:0] == 0);
            if (req_op[3])
                for (b = 0; b < 4; b = b + 1)
                    if (b < (1 << req_op[1:0]))
                        bytes[(req_addr+b)*8 +: 8] <= req_wdata[b*8 +: 8];
        end
    end
endmodule
