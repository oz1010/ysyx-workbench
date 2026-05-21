/* m5_load_use.S — Bug M5: Load-Use 冒险等待周期过多
 *
 * 根因：risk_raw 检测到 Load RAW 后等到 WBU 提交（pc==wb_pc）才释放 IDU，
 * 实际 Load 数据在 LSU 输出时即可前向传播，多引入约 2 个不必要的 bubble。
 *
 * 本测试验证正确性（Load 的值能正确被后续指令使用），
 * 而非性能（不验证气泡数）。若 risk_raw 等待逻辑有 off-by-one 导致读到 0，
 * 测试会报 FAIL。
 *
 * PASS（a0=0）：Load 值正确传播到后续指令
 * FAIL（a0=1）：Load 值为 0 或旧值（RAW 处理有误）
 */
.section .text
.global _start
_start:
    /* 先存一个已知值到内存 */
    la   t0, test_word
    li   t1, 0xCAFEBABE
    sw   t1, 0(t0)

    /* lw 后立即使用（Load-Use 场景） */
    lw   t2, 0(t0)        /* load */
    addi t3, t2, 1        /* 立即使用 t2，触发 Load-Use RAW */

    li   t4, 0xCAFEBABF   /* 0xCAFEBABE + 1 */
    bne  t3, t4, fail

    /* 再测一次：lw 后直接用于分支判断 */
    li   t1, 0x5A5A5A5A
    sw   t1, 0(t0)
    lw   t2, 0(t0)
    li   t3, 0x5A5A5A5A
    bne  t2, t3, fail     /* lw 结果直接参与 bne（更激进的 Load-Use） */

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak

.section .data
test_word:
    .word 0
