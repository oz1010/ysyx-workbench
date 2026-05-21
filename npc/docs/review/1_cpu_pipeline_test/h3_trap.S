/* h3_trap.S — Bug H3: WBU 异常处理无硬件 Trap 机制
 *
 * 根因：write_back.v 对异常只调用 DPI-C func_invalid_inst（终止仿真），
 * 不执行硬件 trap 流程（写 mepc/mcause、更新 mstatus、跳转 mtvec）。
 * 只有 EXU 的 ECALL 路径有部分 CSR 写（mepc/mcause）并通过 flush 跳到 mtvec。
 *
 * 本测试验证 ECALL 的基本 trap 流程（mepc/mcause 写入 + mtvec 跳转 + mret 返回）。
 * 若 ECALL 触发后无法进入 handler，或 mret 无法返回，仿真会挂死或异常退出。
 *
 * PASS（a0=0）：ecall → handler → mret 全流程正常
 * FAIL（a0=1）：handler 中 mcause 不等于 11（M-mode ECALL 原因码）
 * FAIL（a0=2）：handler 未执行（s0 未被置位，说明 ecall 未跳入 mtvec）
 */
.section .text
.global _start
_start:
    la   t0, trap_handler
    csrw mtvec, t0
    nop
    nop
    nop                   /* 等待 csrw 提交（规避 H2 CSR RAW 问题） */

    li   s0, 0            /* handler 运行标志 */
    ecall

    /* mret 返回后：检查 handler 是否运行 */
    li   t0, 1
    bne  s0, t0, handler_not_run

    li   a0, 0
    ebreak

handler_not_run:
    li   a0, 2
    ebreak

/* ---- trap handler ---- */
trap_handler:
    li   s0, 1            /* 标记 handler 已进入 */

    /* 验证 mcause == 11（M-mode ECALL） */
    csrr t0, mcause
    li   t1, 11
    bne  t0, t1, wrong_cause

    /* 推进 mepc 越过 ecall */
    csrr t0, mepc
    addi t0, t0, 4
    csrw mepc, t0
    nop
    nop
    nop
    mret

wrong_cause:
    li   a0, 1
    ebreak
