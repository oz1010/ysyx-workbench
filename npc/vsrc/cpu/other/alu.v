`include "common/riscv32e_defines.v"

module alu (
    input [15:0] inst_code,
    input [31:0] src1,
    input [31:0] src2,
    input [31:0] imm,
    output var [31:0] result
);
    
always @(*) begin
    case(inst_code)
        `INST_ADDI:     result = src1 + imm;
        `INST_ADD:      result = src1 + src2;
        `INST_SUB:      result = src1 - src2;
        default: result = 0;
    endcase
end

endmodule