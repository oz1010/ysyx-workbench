#ifndef __INST_DECODE_H__
#define __INST_DECODE_H__

#include <cstdint>

#include "recorder_types.h"

namespace recorder
{

/**
 * 指令码位定义，与 vsrc/core/common/riscv32e_defines.v 一致
 */
enum : uint16_t
{
    INST_CODE_JUMP = 0x1000,  // 跳转指令
    INST_CODE_MEM  = 0x2000,  // 存储访问指令

    INST_TYPE_R = 0x0100,
    INST_TYPE_I = 0x0200,
    INST_TYPE_S = 0x0300,
    INST_TYPE_B = 0x0400,
    INST_TYPE_U = 0x0500,
    INST_TYPE_J = 0x0600,

    INST_LUI    = INST_TYPE_U | 0x01,
    INST_AUIPC  = INST_TYPE_U | 0x02,
    INST_JAL    = INST_TYPE_J | 0x03 | INST_CODE_JUMP,
    INST_JALR   = INST_TYPE_I | 0x04 | INST_CODE_JUMP,
    INST_BEQ    = INST_TYPE_B | 0x05 | INST_CODE_JUMP,
    INST_BNE    = INST_TYPE_B | 0x06 | INST_CODE_JUMP,
    INST_BLT    = INST_TYPE_B | 0x07 | INST_CODE_JUMP,
    INST_BGE    = INST_TYPE_B | 0x08 | INST_CODE_JUMP,
    INST_BLTU   = INST_TYPE_B | 0x09 | INST_CODE_JUMP,
    INST_BGEU   = INST_TYPE_B | 0x0A | INST_CODE_JUMP,
    INST_LB     = INST_TYPE_I | 0x0B | INST_CODE_MEM,
    INST_LH     = INST_TYPE_I | 0x0C | INST_CODE_MEM,
    INST_LW     = INST_TYPE_I | 0x0D | INST_CODE_MEM,
    INST_LBU    = INST_TYPE_I | 0x0E | INST_CODE_MEM,
    INST_LHU    = INST_TYPE_I | 0x0F | INST_CODE_MEM,
    INST_SB     = INST_TYPE_S | 0x10 | INST_CODE_MEM,
    INST_SH     = INST_TYPE_S | 0x11 | INST_CODE_MEM,
    INST_SW     = INST_TYPE_S | 0x12 | INST_CODE_MEM,
    INST_ADDI   = INST_TYPE_I | 0x13,
    INST_SLTI   = INST_TYPE_I | 0x14,
    INST_SLTIU  = INST_TYPE_I | 0x15,
    INST_XORI   = INST_TYPE_I | 0x16,
    INST_ORI    = INST_TYPE_I | 0x17,
    INST_ANDI   = INST_TYPE_I | 0x18,
    INST_SLLI   = INST_TYPE_I | 0x19,
    INST_SRLI   = INST_TYPE_I | 0x1A,
    INST_SRAI   = INST_TYPE_I | 0x1B,
    INST_ADD    = INST_TYPE_R | 0x1C,
    INST_SUB    = INST_TYPE_R | 0x1D,
    INST_SLL    = INST_TYPE_R | 0x1E,
    INST_SLT    = INST_TYPE_R | 0x1F,
    INST_SLTU   = INST_TYPE_R | 0x20,
    INST_XOR    = INST_TYPE_R | 0x21,
    INST_SRL    = INST_TYPE_R | 0x22,
    INST_SRA    = INST_TYPE_R | 0x23,
    INST_OR     = INST_TYPE_R | 0x24,
    INST_AND    = INST_TYPE_R | 0x25,
    INST_FENCE_I = INST_TYPE_I | 0x27 | INST_CODE_MEM,
    INST_ECALL  = INST_TYPE_I | 0x28 | INST_CODE_JUMP,
    INST_EBREAK = INST_TYPE_I | 0x29,
    INST_CSRRW  = INST_TYPE_I | 0x2A,
    INST_CSRRS  = INST_TYPE_I | 0x2B,
    INST_MUL    = INST_TYPE_R | 0x30,
    INST_MULH   = INST_TYPE_R | 0x31,
    INST_MULHSU = INST_TYPE_R | 0x32,
    INST_MULHU  = INST_TYPE_R | 0x33,
    INST_DIV    = INST_TYPE_R | 0x34,
    INST_DIVU   = INST_TYPE_R | 0x35,
    INST_REM    = INST_TYPE_R | 0x36,
    INST_REMU   = INST_TYPE_R | 0x37,
    INST_MRET   = INST_TYPE_R | 0x41 | INST_CODE_JUMP,
};

}  // namespace recorder

namespace recorder
{

/**
 * 指令解码结果：指令码与rd/rs1/rs2字段，
 * 指令码与inst_decode.v的casez解码表一致，字段提取规则与inst_decode.v的
 * inst_type一致（类型取自指令码中的INST_TYPE_xxx位，无法识别的指令码字段全0）
 */
struct inst_dec_t
{
    uint16_t inst_code = INST_INVALID_CODE;  // 指令码，枚举INST_xxx
    uint8_t  rs1 = 0;  // 源寄存器1：类型为R/I/S/B时取inst[19:15]
    uint8_t  rs2 = 0;  // 源寄存器2：类型为R/S/B时取inst[24:20]
    uint8_t  rd  = 0;  // 目的寄存器：类型为R/I/U/J时取inst[11:7]
};

/**
 * 将指令字解码为inst_dec_t结构体
 * @return 0成功，-1失败（out为空指针）
 */
int decode_inst(uint32_t inst, inst_dec_t* out);

/**
 * 指令分类判断：编码值按定义顺序连续，用范围判断
 */
bool inst_is_load(uint16_t inst_code);   // LB..LHU
bool inst_is_store(uint16_t inst_code);  // SB..SW
bool inst_is_mdr(uint16_t inst_code);    // 乘除 MUL..REMU

/**
 * 由指令码返回指令缩写（大写字母，如 "ADDI"），无法识别时返回 "?"
 */
const char* inst_code_name(uint16_t inst_code);

}  // namespace recorder

#endif
