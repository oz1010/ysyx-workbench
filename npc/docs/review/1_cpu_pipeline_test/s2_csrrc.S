/* s2_csrrc.S — Bug S2: CSRRC / CSRRWI / CSRRSI / CSRRCI 四条指令未在 IDU 解码
 *
 * 预期行为（修复后）：四条指令均正常执行（均为对 x0 或立即数 0 的无副作用操作），
 *                     a0=0 ebreak 正常退出。
 * 缺陷行为（有 Bug）：IDU 将这些指令解码为 INST_INVALID，EXU 触发非法指令异常，
 *                     func_invalid_inst 终止仿真，无法到达 ebreak。
 *
 * 判断方法：仿真正常退出（a0=0）= PASS；仿真因 invalid_inst 中断 = FAIL。
 */
.section .text
.global _start
_start:
    li   a0, 1            /* 预设失败码 */

    /* CSRRC: rd=x0, rs1=x0 → 对 mstatus 清 0 bit（无副作用） */
    csrrc x0, mstatus, x0

    /* CSRRWI: rd=x0, uimm=0 → 将 0 写入 mscratch，丢弃旧值 */
    csrrwi x0, mscratch, 0

    /* CSRRSI: rd=x0, uimm=0 → 对 mstatus 置位 0 bit（无副作用） */
    csrrsi x0, mstatus, 0

    /* CSRRCI: rd=x0, uimm=0 → 对 mstatus 清 0 bit（无副作用） */
    csrrci x0, mstatus, 0

    li   a0, 0            /* 四条指令均通过，置成功码 */
    ebreak
