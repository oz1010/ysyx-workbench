/* h1_mstatus.S — Bug H1: ECALL/MRET 未更新 mstatus
 *
 * 根因：execute.v 的 ECALL 路径只写 mepc/mcause，不清零 mstatus.MIE；
 *       MRET 路径跳转到 mepc，但不恢复 mstatus.MIE←MPIE。
 *
 * 测试流程：
 *   1. 设置 mtvec 指向 trap_handler
 *   2. 置 mstatus.MIE=1（使能全局中断）
 *   3. 执行 ecall（进入 trap handler）
 *   4. handler 中读取 mstatus.MIE，期望为 0（ECALL 应清零）
 *   5. mret 返回
 *   6. 返回后读取 mstatus.MIE，期望恢复为 1
 *
 * PASS（a0=0）：mstatus 管理正确（Bug 已修复）
 * FAIL（a0=1）：进入 handler 时 MIE 未被清零（ECALL 不保存 mstatus）
 * FAIL（a0=2）：mret 后 MIE 未恢复为 1（MRET 不恢复 mstatus）
 *
 * s0 用于跨 ECALL 传递 handler 检测结果（saved registers 不被约定破坏）。
 */
.section .text
.global _start
_start:
    /* 1. 设置 mtvec */
    la   t0, trap_handler
    csrw mtvec, t0
    nop
    nop
    nop                   /* 等待 csrw 提交（规避 H2 CSR RAW 问题） */

    /* 2. 置 mstatus.MIE=1 */
    li   t0, 8            /* mstatus.MIE bit[3] */
    csrrs x0, mstatus, t0
    nop
    nop
    nop

    li   s0, 0            /* handler 结果标志初始化为"未运行" */

    /* 3. 触发 ecall */
    ecall

    /* 5. mret 返回后：检查 mstatus.MIE 是否已恢复为 1 */
    csrr t0, mstatus
    andi t0, t0, 8
    beqz t0, mie_not_restored  /* MIE=0：mret 未恢复 MIE → FAIL a0=2 */

    /* 检查 handler 是否报告了 MIE 已清零 */
    li   t1, 1
    bne  s0, t1, handler_saw_mie_on  /* s0!=1 → handler 中 MIE 未清零 → FAIL a0=1 */

    li   a0, 0
    ebreak

mie_not_restored:
    li   a0, 2
    ebreak

handler_saw_mie_on:
    li   a0, 1
    ebreak

/* ---- trap handler ---- */
trap_handler:
    /* 4. 检查 mstatus.MIE（ECALL 应已清零） */
    csrr t0, mstatus
    andi t0, t0, 8        /* 取 MIE bit */
    bnez t0, mie_still_on /* MIE 仍为 1：Bug 确认 */
    li   s0, 1            /* MIE 已正确清零 */
    j    handler_ret
mie_still_on:
    li   s0, 2            /* MIE 未清零（bug） */
handler_ret:
    /* 推进 mepc 越过 ecall（ecall 编码 4 字节） */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    nop
    nop
    nop
    mret
