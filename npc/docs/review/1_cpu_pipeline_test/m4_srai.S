/* m4_srai.S — Bug M4: SRAI/SRA 算术右移手工实现的边界风险
 *
 * 根因：execute.v 中 SRAI 实现为：
 *   (src1 >> shamt) | ({32{src1[31]}} & (32'hFFFFFFFF << (32 - shamt)))
 * 当 shamt=0 时，32'hFFFFFFFF << 32 依赖 Verilog 对 32-bit 值左移 >= 宽度的截断行为（结果=0），
 * 功能上碰巧正确，但可移植性差；综合工具行为不保证一致。
 *
 * 本测试验证边界 shamt 值的算术右移结果：
 *   SRAI 负数 by 0  → 原值（符号位不变）
 *   SRAI 负数 by 1  → 保留符号位（高位填 1）
 *   SRAI 负数 by 31 → 全 1（-1）
 *   SRAI 正数 by 1  → 高位填 0
 *
 * 注：若当前实现行为正确，可验证不回归；若 shamt=0 边界有问题则暴露 Bug。
 */
.section .text
.global _start
_start:
    /* SRAI -1 by 0：-1 >> 0 = -1 */
    li   t0, -1
    srai a0, t0, 0
    li   t1, -1
    bne  a0, t1, fail

    /* SRAI -1 by 1：-1 >> 1 = -1（算术，高位填 1） */
    srai a0, t0, 1
    bne  a0, t1, fail

    /* SRAI -1 by 31：-1 >> 31 = -1 */
    srai a0, t0, 31
    bne  a0, t1, fail

    /* SRAI 0x40000000 by 1：正数右移，高位填 0 */
    li   t0, 0x40000000
    srai a0, t0, 1
    li   t1, 0x20000000
    bne  a0, t1, fail

    /* SRA -128 by 3：-128 >> 3 = -16 */
    li   t0, -128
    li   t2, 3
    sra  a0, t0, t2
    li   t1, -16
    bne  a0, t1, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
