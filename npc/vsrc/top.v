import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);

module top
(
    input clk,
    input rst,
    input [31:0] data,
    output reg [31:0] out_regs[32:0],
    output [31:0] addr
);

wire [11:0] imm = data[31:20];
wire [4:0] rs1 = data[19:15];
wire [4:0] rd = data[11:7];

wire inst_addi = (data[6:0]==7'b0010011) && (data[14:12]==3'b000);
wire inst_ebreak = data==32'h00100073;
wire inst_invalid = !(rst || inst_addi || inst_ebreak);

wire regs_wen[31:0];
wire [31:0] regs_output[31:0];
wire [31:0] regs_input[31:0];

PC32 pc(clk, rst, addr+4, addr);

genvar i;
generate
    for (i=0; i<32; ++i) begin : gen_regs
        Reg32 regs(clk, rst, regs_input[i] & {32{i!=0}}, regs_output[i], regs_wen[i]);
        assign out_regs[i] = regs_output[i];
    end
endgenerate

assign out_regs[32] = addr;

wire [31:0] a,b,adder_output;
wire carray;
MuxKey #(32, 5, 32) regs_sel(a, rs1, {
    5'd00, regs_output[00],
    5'd01, regs_output[01],
    5'd02, regs_output[02],
    5'd03, regs_output[03],
    5'd04, regs_output[04],
    5'd05, regs_output[05],
    5'd06, regs_output[06],
    5'd07, regs_output[07],
    5'd08, regs_output[08],
    5'd09, regs_output[09],
    5'd10, regs_output[10],
    5'd11, regs_output[11],
    5'd12, regs_output[12],
    5'd13, regs_output[13],
    5'd14, regs_output[14],
    5'd15, regs_output[15],
    5'd16, regs_output[16],
    5'd17, regs_output[17],
    5'd18, regs_output[18],
    5'd19, regs_output[19],
    5'd20, regs_output[20],
    5'd21, regs_output[21],
    5'd22, regs_output[22],
    5'd23, regs_output[23],
    5'd24, regs_output[24],
    5'd25, regs_output[25],
    5'd26, regs_output[26],
    5'd27, regs_output[27],
    5'd28, regs_output[28],
    5'd29, regs_output[29],
    5'd30, regs_output[30],
    5'd31, regs_output[31]
});
// b=sext(imm)
assign b = {{20{imm[11]}}, imm};

generate
    for (i=0; i<32; ++i) begin : gen_regs
        assign regs_wen[i] = (i==rd) && (inst_addi);
        assign regs_input[i] = {32{i==rd}} & adder_output;
    end
endgenerate

adder32 adder(1'b0, a, b, carray, adder_output);

always @(posedge clk) begin
    if (inst_ebreak) begin
        // call with a0
        exit_simu(regs_output[10]);
    end

    if (inst_invalid) begin
        // call with pc and inst
        invalid_inst(addr, data);
    end
end

endmodule
