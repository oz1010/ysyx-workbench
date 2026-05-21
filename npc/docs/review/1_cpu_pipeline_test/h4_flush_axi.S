/* h4_flush_axi.S — Bug H4: IFU flush 期间 in-flight AXI 读未取消
 *
 * 根因：流水线 flush 时 IFU 的 r_read_en 不被清零，
 * 已发出的 AXI 读事务仍会完成并写入 r_read_inst，
 * 造成额外的总线带宽消耗（若 ICache miss 还会触发多余的 DRAM 访问）。
 * 由于 con_if_valid 在 flush 期间被屏蔽，stale 数据最终被丢弃，
 * 功能上正确，但性能下降。
 *
 * 本测试验证：在大量 flush 触发（每次循环跳转均 mispredicted）后，
 * 计算结果仍然正确（功能验证）。
 *
 * PASS（a0=0）：100 次循环后 t1 计数正确
 * FAIL（a0=1）：计数不正确（flush 期间 stale 指令影响了执行）
 */
.section .text
.global _start
_start:
    li   t0, 100          /* 循环计数 */
    li   t1, 0            /* 累加器 */
loop:
    addi t1, t1, 1        /* 每次迭代 +1 */
    addi t0, t0, -1
    bnez t0, loop         /* 向后跳转：静态预测 not-taken，每次均 mispredicted → flush */

    /* 验证 t1 == 100，t0 == 0 */
    li   t2, 100
    bne  t1, t2, fail
    bnez t0, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
