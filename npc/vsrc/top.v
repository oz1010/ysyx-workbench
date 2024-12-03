import "DPI-C" function void exit_simu(input int code);
import "DPI-C" function void invalid_inst(input int pc, input int inst);
import "DPI-C" function void Mw(input int addr, input int len, input int data);
import "DPI-C" function int Mr(input int addr, input int len);

module top
(
    input clk,
    input rst,
    input [31:0] inst
);

wire regs_wen[31:0];
wire [31:0] x[31:0];
wire [31:0] regs_input[31:0];
genvar i;
generate
    for (i=0; i<32; ++i) begin : gen_regs
        Reg32 regs(clk, rst, regs_input[i] & {32{i!=0}}, x[i], regs_wen[i]);
    end
endgenerate

// register alias, ch2.3
wire [31:0] zero = x[0];
wire [31:0] ra = x[1];
wire [31:0] sp = x[2];
wire [31:0] gp = x[3];
wire [31:0] tp = x[4];
wire [31:0] a[7:0];
assign a[7:0] = x[17:10];

wire pc_jump;
wire [31:0] pc_jump_addr;
wire [31:0] pc;
wire [31:0] snpc = pc + 4;
wire [31:0] dnpc = ({32{!pc_jump}} & snpc) |
                    ({32{pc_jump}} & pc_jump_addr);
PC32 pcR(clk, rst, dnpc, pc);

// decode_operand
wire [11:0] immI = inst[31:20];
wire [11:0] immS = {inst[31:25], inst[11:7]};
wire [12:0] immB = {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0};
wire [31:0] immU = {inst[31:12], {12{1'b0}}};
wire [20:0] immJ = {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0};
wire [4:0] rs1 = inst[19:15];
wire [4:0] rs2 = inst[24:20];
wire [4:0] rd = inst[11:7];
wire [6:0] opcode = inst[6:0];
wire [2:0] funct3 = inst[14:12];
wire [6:0] funct7 = inst[31:25];

// regs selector
wire [31:0] src1;
MuxKey #(32, 5, 32) src1R(src1, rs1, {
    5'd00, x[00],
    5'd01, x[01],
    5'd02, x[02],
    5'd03, x[03],
    5'd04, x[04],
    5'd05, x[05],
    5'd06, x[06],
    5'd07, x[07],
    5'd08, x[08],
    5'd09, x[09],
    5'd10, x[10],
    5'd11, x[11],
    5'd12, x[12],
    5'd13, x[13],
    5'd14, x[14],
    5'd15, x[15],
    5'd16, x[16],
    5'd17, x[17],
    5'd18, x[18],
    5'd19, x[19],
    5'd20, x[20],
    5'd21, x[21],
    5'd22, x[22],
    5'd23, x[23],
    5'd24, x[24],
    5'd25, x[25],
    5'd26, x[26],
    5'd27, x[27],
    5'd28, x[28],
    5'd29, x[29],
    5'd30, x[30],
    5'd31, x[31]
});

// regs selector
wire [31:0] src2;
MuxKey #(32, 5, 32) src2R(src2, rs2, {
    5'd00, x[00],
    5'd01, x[01],
    5'd02, x[02],
    5'd03, x[03],
    5'd04, x[04],
    5'd05, x[05],
    5'd06, x[06],
    5'd07, x[07],
    5'd08, x[08],
    5'd09, x[09],
    5'd10, x[10],
    5'd11, x[11],
    5'd12, x[12],
    5'd13, x[13],
    5'd14, x[14],
    5'd15, x[15],
    5'd16, x[16],
    5'd17, x[17],
    5'd18, x[18],
    5'd19, x[19],
    5'd20, x[20],
    5'd21, x[21],
    5'd22, x[22],
    5'd23, x[23],
    5'd24, x[24],
    5'd25, x[25],
    5'd26, x[26],
    5'd27, x[27],
    5'd28, x[28],
    5'd29, x[29],
    5'd30, x[30],
    5'd31, x[31]
});

// instruction
// wire inst_lui       =   (opcode==7'b00000_00);
wire inst_auipc     =   (opcode==7'b00101_11);
wire inst_jal       =   (opcode==7'b11011_11);
// wire inst_jalr       =   (opcode==7'b00000_00);
wire inst_beq       =   (opcode==7'b11000_11) && (funct3==3'b000);
// wire inst_bne       =   (opcode==7'b00000_00);
// wire inst_blt       =   (opcode==7'b00000_00);
// wire inst_bge       =   (opcode==7'b00000_00);
// wire inst_bltu       =   (opcode==7'b00000_00);
// wire inst_bgeu       =   (opcode==7'b00000_00);
// wire inst_lb       =   (opcode==7'b00000_00);
// wire inst_lh       =   (opcode==7'b00000_00);
wire inst_lw        =   (opcode==7'b00000_11) && (funct3==3'b010);
// wire inst_lbu       =   (opcode==7'b00000_00);
// wire inst_lhu       =   (opcode==7'b00000_00);
// wire inst_sb       =   (opcode==7'b00000_00);
// wire inst_sh       =   (opcode==7'b00000_00);
wire inst_sw        =   (opcode==7'b01000_11) && (funct3==3'b010);
wire inst_addi      =   (opcode==7'b00100_11) && (funct3==3'b000);
// wire inst_slti       =   (opcode==7'b00000_00);
wire inst_sltiu     =   (opcode==7'b00100_11) && (funct3==3'b011);
// wire inst_xori       =   (opcode==7'b00000_00);
// wire inst_ori       =   (opcode==7'b00000_00);
// wire inst_andi       =   (opcode==7'b00000_00);
// wire inst_slli       =   (opcode==7'b00000_00);
// wire inst_srli       =   (opcode==7'b00000_00);
// wire inst_srai       =   (opcode==7'b00000_00);
wire inst_add       =   (opcode==7'b01100_11) && (funct3==3'b000) && (funct7==7'b0000000);
wire inst_sub       =   (opcode==7'b01100_11) && (funct3==3'b000) && (funct7==7'b0100000);
// wire inst_sll       =   (opcode==7'b00000_00);
// wire inst_slt       =   (opcode==7'b00000_00);
// wire inst_sltu       =   (opcode==7'b00000_00);
// wire inst_xor       =   (opcode==7'b00000_00);
// wire inst_srl       =   (opcode==7'b00000_00);
// wire inst_sra       =   (opcode==7'b00000_00);
// wire inst_or       =   (opcode==7'b00000_00);
// wire inst_and       =   (opcode==7'b00000_00);
// wire inst_fence       =   (opcode==7'b00000_00);
// wire inst_fence_i       =   (opcode==7'b00000_00);
// wire inst_ecall       =   (opcode==7'b00000_00);
wire inst_ebreak    =   inst==32'h00100073;
// wire inst_csrrw       =   (opcode==7'b00000_00);
// wire inst_csrrs       =   (opcode==7'b00000_00);
// wire inst_csrrc       =   (opcode==7'b00000_00);
// wire inst_csrrwi       =   (opcode==7'b00000_00);
// wire inst_csrrsi       =   (opcode==7'b00000_00);
// wire inst_csrrci       =   (opcode==7'b00000_00);
// wire inst_mul       =   (opcode==7'b00000_00);
// wire inst_mulh       =   (opcode==7'b00000_00);
// wire inst_mulhsu       =   (opcode==7'b00000_00);
// wire inst_mulhu       =   (opcode==7'b00000_00);
// wire inst_div       =   (opcode==7'b00000_00);
// wire inst_divu       =   (opcode==7'b00000_00);
// wire inst_rem       =   (opcode==7'b00000_00);
// wire inst_remu       =   (opcode==7'b00000_00);
// wire inst_lui       =   (opcode==7'b00000_00);

wire inst_invalid   =   !(
                            inst_auipc ||
                            inst_jal ||
                            inst_beq ||
                            inst_addi || 
                            inst_lw ||
                            inst_sw ||
                            inst_add || 
                            inst_sub || 
                            inst_sltiu ||
                            inst_ebreak || 
                            rst
                        );
assign pc_jump      =   (inst_jal || ((src1==src2) && inst_beq));
assign pc_jump_addr =   {32{pc_jump}} & adder_output;
wire modify_rd      =   (
        inst_lw ||
        inst_sltiu
    );
reg [31:0] modify_rd_val;

generate
    for (i=0; i<32; ++i) begin : gen_regs
        assign regs_wen[i] = (i==rd) && 
                            (
                                inst_add || 
                                inst_sub || 
                                inst_addi || 
                                inst_auipc ||
                                pc_jump ||
                                modify_rd
                            );
        assign regs_input[i] = ({32{!pc_jump & !modify_rd}} & {32{i==rd}} & adder_output) | 
                                ({32{pc_jump & !modify_rd}} & {32{i==rd}} & snpc) |
                                ({32{modify_rd}} & {32{i==rd}} & modify_rd_val);
    end
endgenerate

// sext(imm)
wire [31:0] ext_immI = {{20{immI[11]}}, immI};
wire [31:0] ext_immJ = {{11{immJ[20]}}, immJ};
wire [31:0] ext_immS = {{20{immS[11]}}, immS};
wire [31:0] ext_immB = {{19{immB[12]}}, immB};

// ALU
wire [31:0] add_a = ({32{inst_add}} & src1) | 
                    ({32{inst_sub}} & src1) | 
                    ({32{inst_addi}} & src1) | 
                    ({32{inst_auipc}} & pc) |
                    ({32{inst_jal}} & pc) |
                    ({32{inst_lw}} & src1) |
                    ({32{inst_sw}} & src1) |
                    ({32{inst_beq}} & pc) |
                    0;
wire [31:0] add_b = ({32{inst_add}} & src2) |
                    ({32{inst_sub}} & src2) |
                    ({32{inst_addi}} & ext_immI) |
                    ({32{inst_auipc}} & immU) |
                    ({32{inst_jal}} & ext_immJ) |
                    ({32{inst_lw}} & ext_immI) |
                    ({32{inst_sw}} & ext_immS) |
                    ({32{inst_beq}} & ext_immB) |
                    0;
wire carray;
wire [31:0] adder_output;
adder32 adder(1'b0, add_a, add_b, carray, adder_output);

always @(posedge clk) begin
    if (inst_ebreak) begin exit_simu(a[0]); end
    if (inst_lw) begin modify_rd_val <= Mr(adder_output, 4); end
    if (inst_sltiu) begin modify_rd_val <= {{31{1'b0}}, (src1 < ext_immI)}; end
    if (inst_sw) begin Mw(adder_output, 4, src2); end
    if (inst_invalid) begin invalid_inst(pc, inst); end
end

endmodule
