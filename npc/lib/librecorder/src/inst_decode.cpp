#include "inst_decode.h"

#include "recorder.h"

namespace recorder
{

/**
 * 按 vsrc/core/pipeline/inst_decode.v 中 casez 解码表实现，
 * 注意该表中 FENCE/CSRRC/CSRRWI/CSRRSI/CSRRCI 被注释掉，统一解码为无效指令
 */
uint16_t decode_inst_code(uint32_t inst)
{
    const uint32_t opcode = inst & 0x7F;
    const uint32_t funct3 = (inst >> 12) & 0x07;
    const uint32_t funct7 = inst >> 25;

    switch (opcode)
    {
        case 0b0110111: return INST_LUI;
        case 0b0010111: return INST_AUIPC;
        case 0b1101111: return INST_JAL;
        case 0b1100111:  // JALR
            if (funct3 == 0b000) return INST_JALR;
            break;
        case 0b1100011:  // BRANCH
            switch (funct3)
            {
                case 0b000: return INST_BEQ;
                case 0b001: return INST_BNE;
                case 0b100: return INST_BLT;
                case 0b101: return INST_BGE;
                case 0b110: return INST_BLTU;
                case 0b111: return INST_BGEU;
                default: break;
            }
            break;
        case 0b0000011:  // LOAD
            switch (funct3)
            {
                case 0b000: return INST_LB;
                case 0b001: return INST_LH;
                case 0b010: return INST_LW;
                case 0b100: return INST_LBU;
                case 0b101: return INST_LHU;
                default: break;
            }
            break;
        case 0b0100011:  // STORE
            switch (funct3)
            {
                case 0b000: return INST_SB;
                case 0b001: return INST_SH;
                case 0b010: return INST_SW;
                default: break;
            }
            break;
        case 0b0010011:  // OP-IMM
            switch (funct3)
            {
                case 0b000: return INST_ADDI;
                case 0b010: return INST_SLTI;
                case 0b011: return INST_SLTIU;
                case 0b100: return INST_XORI;
                case 0b110: return INST_ORI;
                case 0b111: return INST_ANDI;
                case 0b001:
                    if (funct7 == 0b0000000) return INST_SLLI;
                    break;
                case 0b101:
                    if (funct7 == 0b0000000) return INST_SRLI;
                    if (funct7 == 0b0100000) return INST_SRAI;
                    break;
                default: break;
            }
            break;
        case 0b0110011:  // OP
            if (funct7 == 0b0000000 || funct7 == 0b0100000)
            {
                switch (funct3)
                {
                    case 0b000: return funct7 == 0b0100000 ? INST_SUB : INST_ADD;
                    case 0b001: return INST_SLL;
                    case 0b010: return INST_SLT;
                    case 0b011: return INST_SLTU;
                    case 0b100: return INST_XOR;
                    case 0b101: return funct7 == 0b0100000 ? INST_SRA : INST_SRL;
                    case 0b110: return INST_OR;
                    case 0b111: return INST_AND;
                    default: break;
                }
            }
            else if (funct7 == 0b0000001)  // RV32M
            {
                switch (funct3)
                {
                    case 0b000: return INST_MUL;
                    case 0b001: return INST_MULH;
                    case 0b010: return INST_MULHSU;
                    case 0b011: return INST_MULHU;
                    case 0b100: return INST_DIV;
                    case 0b101: return INST_DIVU;
                    case 0b110: return INST_REM;
                    case 0b111: return INST_REMU;
                    default: break;
                }
            }
            break;
        case 0b0001111:  // FENCE_I (FENCE被注释掉，解码为无效)
            if (inst == 0b0000000'00000'00000'001'00000'00011'11) return INST_FENCE_I;
            break;
        case 0b1110011:  // SYSTEM
            if (inst == 0b0000000'00000'00000'000'00000'11100'11) return INST_ECALL;
            if (inst == 0b0000000'00001'00000'000'00000'11100'11) return INST_EBREAK;
            if (inst == 0b0011000'00010'00000'000'00000'11100'11) return INST_MRET;
            switch (funct3)
            {
                case 0b001: return INST_CSRRW;
                case 0b010: return INST_CSRRS;
                default: break;
            }
            break;
        default: break;
    }
    return INST_INVALID_CODE;
}

int decode_inst(uint32_t inst, inst_dec_t* out)
{
    if (!out) return -1;
    out->inst_code = decode_inst_code(inst);
    out->rs1 = out->rs2 = out->rd = 0;
    if (out->inst_code == INST_INVALID_CODE) return 0;
    const uint16_t type = out->inst_code & 0x0F00;  // INST_TYPE_xxx位
    if (type == INST_TYPE_R || type == INST_TYPE_I || type == INST_TYPE_U ||
        type == INST_TYPE_J)
        out->rd = (inst >> 7) & 0x1F;
    if (type == INST_TYPE_R || type == INST_TYPE_I || type == INST_TYPE_S ||
        type == INST_TYPE_B)
        out->rs1 = (inst >> 15) & 0x1F;
    if (type == INST_TYPE_R || type == INST_TYPE_S || type == INST_TYPE_B)
        out->rs2 = (inst >> 20) & 0x1F;
    return 0;
}

bool inst_is_load(uint16_t inst_code)  { return inst_code >= INST_LB && inst_code <= INST_LHU; }
bool inst_is_store(uint16_t inst_code) { return inst_code >= INST_SB && inst_code <= INST_SW; }
bool inst_is_mdr(uint16_t inst_code)   { return inst_code >= INST_MUL && inst_code <= INST_REMU; }

const char* inst_code_name(uint16_t inst_code)
{
    switch (inst_code)
    {
        case INST_LUI:    return "LUI";
        case INST_AUIPC:  return "AUIPC";
        case INST_JAL:    return "JAL";
        case INST_JALR:   return "JALR";
        case INST_BEQ:    return "BEQ";
        case INST_BNE:    return "BNE";
        case INST_BLT:    return "BLT";
        case INST_BGE:    return "BGE";
        case INST_BLTU:   return "BLTU";
        case INST_BGEU:   return "BGEU";
        case INST_LB:     return "LB";
        case INST_LH:     return "LH";
        case INST_LW:     return "LW";
        case INST_LBU:    return "LBU";
        case INST_LHU:    return "LHU";
        case INST_SB:     return "SB";
        case INST_SH:     return "SH";
        case INST_SW:     return "SW";
        case INST_ADDI:   return "ADDI";
        case INST_SLTI:   return "SLTI";
        case INST_SLTIU:  return "SLTIU";
        case INST_XORI:   return "XORI";
        case INST_ORI:    return "ORI";
        case INST_ANDI:   return "ANDI";
        case INST_SLLI:   return "SLLI";
        case INST_SRLI:   return "SRLI";
        case INST_SRAI:   return "SRAI";
        case INST_ADD:    return "ADD";
        case INST_SUB:    return "SUB";
        case INST_SLL:    return "SLL";
        case INST_SLT:    return "SLT";
        case INST_SLTU:   return "SLTU";
        case INST_XOR:    return "XOR";
        case INST_SRL:    return "SRL";
        case INST_SRA:    return "SRA";
        case INST_OR:     return "OR";
        case INST_AND:    return "AND";
        case INST_FENCE_I: return "FENCE.I";
        case INST_ECALL:  return "ECALL";
        case INST_EBREAK: return "EBREAK";
        case INST_CSRRW:  return "CSRRW";
        case INST_CSRRS:  return "CSRRS";
        case INST_MUL:    return "MUL";
        case INST_MULH:   return "MULH";
        case INST_MULHSU: return "MULHSU";
        case INST_MULHU:  return "MULHU";
        case INST_DIV:    return "DIV";
        case INST_DIVU:   return "DIVU";
        case INST_REM:    return "REM";
        case INST_REMU:   return "REMU";
        case INST_MRET:   return "MRET";
        default:          return "?";
    }
}

}  // namespace recorder
