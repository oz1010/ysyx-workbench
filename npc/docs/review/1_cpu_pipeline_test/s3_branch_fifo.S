/* s3_branch_fifo.S — Bug S3: risk_control FIFO 出队条件错误
 *
 * 根因：FIFO 出队条件为「EXU 有有效指令 && FIFO 非空」，而非「EXU 处理的是跳转指令」。
 * 当 NOP 在 EXU、BEQ 在 IDU 的同一周期，IDU 将 BEQ 的预测信息推入 FIFO（阻塞赋值），
 * EXU 的 NOP 立即将该 FIFO 条目出队。下一周期 BEQ 进入 EXU 时 FIFO 已空，
 * 误判无需 flush，流水线继续在错误路径（fall-through）执行。
 *
 * 预期行为（修复后）：beq 被检测为分支，flush 触发，跳到 pass，a0=0。
 * 缺陷行为（有 Bug）：beq 的 FIFO 条目被 nop 消费，误判断无需 flush，
 *                     fall-through 继续执行 fail 路径，a0=1。
 */
.section .text
.global _start
_start:
    nop                   /* 进入 EXU 时，beq 正好在 IDU → 触发 FIFO 出队 bug */
    beq  x0, x0, pass    /* 恒成立的条件跳转；有 Bug 时 misprediction 漏检 */
    li   a0, 1            /* FAIL：错误路径 */
    ebreak
pass:
    li   a0, 0            /* PASS：正确路径 */
    ebreak
