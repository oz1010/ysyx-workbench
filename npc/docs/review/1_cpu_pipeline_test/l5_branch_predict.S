/* l5_branch_predict.S — Bug L5: static_predictor 始终预测顺序执行（predict not-taken）
 *
 * 根因：static_predictor 对所有跳转指令预测 PC+4（不跳转），
 * 导致每次 taken 分支都引发 3 周期 flush 惩罚。
 * 向后跳转（循环）通常为 taken，性能损失显著。
 *
 * 本测试验证功能正确性：在多次 misprediction + flush 后，
 * 累加计数值和循环边界均正确。
 * 若 flush 后 PC 恢复有误导致指令被跳过/重复执行，测试会报 FAIL。
 *
 * PASS（a0=0）：循环 50 次，sum = 1+2+...+50 = 1275，t0=0
 * FAIL（a0=1）：sum 或 t0 不符合预期
 */
.section .text
.global _start
_start:
    li   t0, 50           /* 循环次数 */
    li   t1, 0            /* sum 累加器 */
loop:
    add  t1, t1, t0       /* sum += i（从 50 递减到 1） */
    addi t0, t0, -1
    bnez t0, loop         /* 向后跳转，静态预测错误，每次 flush */

    /* 验证：t0==0，t1==1275（1+2+...+50） */
    bnez t0, fail
    li   t2, 1275
    bne  t1, t2, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
