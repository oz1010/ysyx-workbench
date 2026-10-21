module instruction_sequence #(
    parameter integer N = 5,
    parameter bit WITH_MEM = 0,
    parameter integer MEM_BYTES = 16
) (
    input wire [N*32-1:0] sequence_bits,
    output wire [31:0] instr_seq [0:N-1],
    output wire is_mem [0:N-1]
);
    // Frozen symbolic slots, independent of DUT outputs. No control flow or CSR.
    for (genvar i = 0; i < N; i = i + 1) begin : slot
        wire [31:0] instruction = sequence_bits[i*32 +: 32];
        wire [6:0] opcode = instruction[6:0];
        wire [2:0] funct3 = instruction[14:12];
        wire [6:0] funct7 = instruction[31:25];
        reg [15:0] initialized;
        reg legal;
        integer j;

        assign instr_seq[i] = instruction;
        assign is_mem[i] = opcode == 7'h03 || opcode == 7'h23;
        always @* begin
            // REF GPRs have no reset initialization. Read only x0 or a register
            // initialized by an earlier instruction, never assume core state equal.
            initialized = 16'h0001;
            for (j = 0; j < i; j = j + 1)
                if (instr_seq[j][6:0] != 7'h23)
                    initialized[instr_seq[j][10:7]] = 1'b1;
            legal = 0;
            case (opcode)
                7'h37: legal = !instruction[11]; // LUI
                7'h13: begin
                    legal = !instruction[11] && !instruction[19] &&
                            initialized[instruction[18:15]];
                    if (funct3 == 3'h1) legal = legal && funct7 == 0;
                    if (funct3 == 3'h5)
                        legal = legal && (funct7 == 0 || funct7 == 7'h20);
                end
                7'h33: begin
                    legal = !instruction[11] && !instruction[19] &&
                            !instruction[24] && initialized[instruction[18:15]] &&
                            initialized[instruction[23:20]] &&
                            (funct7 == 0 || (funct7 == 7'h20 &&
                             (funct3 == 0 || funct3 == 3'h5)));
                end
                7'h03: begin
                    // x0-relative addresses within the small symbolic memory.
                    legal = WITH_MEM && !instruction[31] && !instruction[11] && instruction[19:15] == 0 &&
                            (funct3 == 0 || funct3 == 1 || funct3 == 2 ||
                             funct3 == 4 || funct3 == 5) &&
                            instruction[31:20] < MEM_BYTES;
                    if (funct3[1:0] == 1) legal = legal && !instruction[20];
                    if (funct3[1:0] == 2) legal = legal && instruction[21:20] == 0;
                end
                7'h23: begin
                    legal = WITH_MEM && !instruction[31] && instruction[19:15] == 0 && !instruction[24] &&
                            initialized[instruction[23:20]] && funct3 <= 2 &&
                            {instruction[31:25], instruction[11:7]} < MEM_BYTES;
                    if (funct3 == 1) legal = legal && !instruction[7];
                    if (funct3 == 2) legal = legal && instruction[8:7] == 0;
                end
                default: legal = 0;
            endcase
            assume(legal);
        end
    end
endmodule
