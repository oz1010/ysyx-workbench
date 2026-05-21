/* s5a_mulh.S — Bug S5（之一）：多周期 MDR 对 MULH/MULHSU/MULHU 始终返回低 32 位
 *
 * 根因：ex_muldivrem_multi S_MUL 状态末尾 `result <= mul_res[31:0]`，
 * 无论是 MUL（需低位）还是 MULH/MULHSU/MULHU（需高位）一律取低 32 位。
 * 此外多周期版本使用无符号移位加法，对有符号 MULH 乘积高位也不正确。
 *
 * 测试用例 1：mulh a0, -1, -1
 *   正确：(-1)×(-1)=1，64-bit=0x00000001，高32位=0x00000000 → a0=0
 *   缺陷：mul_res[31:0]=0x00000001（无符号乘积低位）→ a0=1
 *
 * 测试用例 2：mulhu a0, 0xFFFFFFFF, 0xFFFFFFFF
 *   正确：高32位=0xFFFFFFFE → a0=0xFFFFFFFE
 *   缺陷：mul_res[31:0]=0x00000001（低位）→ a0=1
 */
.section .text
.global _start
_start:
    /* 用例 1：mulh (-1)*(-1) 高位应为 0 */
    li   t0, -1
    li   t1, -1
    mulh a0, t0, t1       /* 正确=0x00000000，Bug=0x00000001 */
    bnez a0, fail

    /* 用例 2：mulhu 0xFFFFFFFF*0xFFFFFFFF 高位应为 0xFFFFFFFE */
    li   t0, -1           /* 0xFFFFFFFF */
    li   t1, -1           /* 0xFFFFFFFF */
    mulhu a0, t0, t1      /* 正确=0xFFFFFFFE，Bug=0x00000001 */
    li   t2, -2           /* 0xFFFFFFFE */
    bne  a0, t2, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
