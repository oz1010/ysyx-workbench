/* s1_fence.S — Bug S1: IDU 中 FENCE 指令被注释掉，导致解码为 INST_INVALID
 *
 * 预期行为（修复后）：fence 指令正常执行，流水线继续，最终 a0=0 ebreak 正常退出。
 * 缺陷行为（有 Bug）：fence 在 EXU 触发非法指令异常，DPI-C func_invalid_inst 终止仿真，
 *                     程序永远无法到达 ebreak。
 *
 * 判断方法：仿真正常退出（a0=0）= PASS（Bug 已修复）；
 *           仿真因 invalid_inst 中断  = FAIL（Bug 存在）。
 */
.section .text
.global _start
_start:
    li   a0, 1            /* 预设失败码，若 fence 崩溃则不会被覆盖 */
    fence iorw, iorw      /* S1：此处会触发 illegal-inst（有 Bug 时） */
    fence.i               /* 同样被注释掉的指令变体 */
    li   a0, 0            /* 到达这里说明 fence 被正常解码执行 */
    ebreak
