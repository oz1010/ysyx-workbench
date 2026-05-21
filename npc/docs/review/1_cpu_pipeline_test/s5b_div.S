/* s5b_div.S — Bug S5（之二）：多周期 MDR 有符号除法/取余忽略符号位
 *
 * 根因：ex_muldivrem_multi S_DIV 状态始终执行无符号恢复除法，
 * `signed_mode` 标志被解码但从不应用于被除数/除数的符号转换。
 *
 * 测试用例 1：div t2, -7, 2
 *   正确（有符号）：-7 / 2 = -3（向零截断）→ t2=0xFFFFFFFD
 *   缺陷（无符号）：0xFFFFFFF9 / 2 = 0x7FFFFFFC  → t2=0x7FFFFFFC
 *
 * 测试用例 2：rem t2, -7, 3
 *   正确（有符号）：-7 % 3 = -1 → t2=0xFFFFFFFF
 *   缺陷（无符号）：0xFFFFFFF9 % 3 = 0 → t2=0
 */
.section .text
.global _start
_start:
    /* 用例 1：div -7 / 2 */
    li   t0, -7
    li   t1, 2
    div  t2, t0, t1       /* 正确=-3=0xFFFFFFFD，Bug=0x7FFFFFFC */
    li   t3, -3
    bne  t2, t3, fail

    /* 用例 2：rem -7 % 3 */
    li   t0, -7
    li   t1, 3
    rem  t2, t0, t1       /* 正确=-1=0xFFFFFFFF，Bug=0 */
    li   t3, -1
    bne  t2, t3, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
