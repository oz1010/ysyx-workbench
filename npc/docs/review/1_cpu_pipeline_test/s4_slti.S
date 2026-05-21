/* s4_slti.S — Bug S4: SLTI 有符号比较错误
 *
 * 根因：execute.v 中 `s_src1 < imm`，s_src1 为 signed，imm 为 wire（无符号）。
 * Verilog 混合有/无符号比较时，signed 操作数被转换为 unsigned，
 * 导致负数立即数（符号扩展后为大无符号数）的比较结果错误。
 *
 * 测试用例 1：slti a0, t0, -1（t0=0）
 *   正确（有符号）：0 < -1 → FALSE → a0=0
 *   缺陷（无符号）：0 < 0xFFFFFFFF → TRUE  → a0=1
 *
 * 测试用例 2：slti a0, t0, 0（t0=-1）
 *   正确（有符号）：-1 < 0 → TRUE  → a0=1
 *   缺陷（无符号）：0xFFFFFFFF < 0 → FALSE → a0=0
 */
.section .text
.global _start
_start:
    /* 用例 1：0 < -1（有符号应为 FALSE） */
    li   t0, 0
    slti a0, t0, -1       /* 正确=0，Bug=1 */
    bnez a0, fail

    /* 用例 2：-1 < 0（有符号应为 TRUE） */
    li   t0, -1
    slti a0, t0, 0        /* 正确=1，Bug=0 */
    li   t1, 1
    bne  a0, t1, fail

    /* 用例 3：-2 < -1（有符号应为 TRUE） */
    li   t0, -2
    slti a0, t0, -1       /* 正确=1，Bug=0（0xFFFFFFFE < 0xFFFFFFFF 无符号也成立，此用例不区分） */
    bne  a0, t1, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
