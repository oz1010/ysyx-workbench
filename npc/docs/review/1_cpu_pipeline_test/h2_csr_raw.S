/* h2_csr_raw.S — Bug H2: 流水线中 CSR RAW 冒险未检测
 *
 * 根因：risk_raw 只检测 GPR rs1/rs2 vs rd 的写后读，对 CSR 完全无处理。
 * CSR 读（csrs.rdata）是组合逻辑；CSR 写来自 WBU 的 csr_wch（同步，下一 clk 生效）。
 * 当 csrw 在 EXU 而 csrr 在 IDU（同一周期），IDU 读到的是写入前的旧值。
 *
 * 测试用例：写 mscratch 后立即读回
 *   正确（有 RAW 检测/stall）：t1 == t0 = 0xDEADBEEF
 *   缺陷（无 RAW 检测）：      t1 == 旧值（reset 后通常为 0）
 */
.section .text
.global _start
_start:
    li   t0, 0xDEADBEEF
    csrw mscratch, t0     /* 写 mscratch；下一条立即读，触发 RAW 冒险 */
    csrr t1, mscratch     /* IDU 读到旧值（Bug）还是新值（正确）？ */
    bne  t1, t0, fail

    /* 再次验证：连续两次 CSR 写后读 */
    li   t0, 0x12345678
    csrw mscratch, t0
    csrr t1, mscratch
    bne  t1, t0, fail

    li   a0, 0
    ebreak
fail:
    li   a0, 1
    ebreak
