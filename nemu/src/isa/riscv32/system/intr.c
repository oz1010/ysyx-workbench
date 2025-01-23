/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <isa.h>

word_t isa_raise_intr(word_t NO, vaddr_t epc) {
  /* Trigger an interrupt/exception with ``NO''.
   * Then return the address of the interrupt/exception vector.
   */

    /**
   * ref. https://ysyx.oscc.cc/docs/ics-pa/3.2.html#riscv32
   * riscv32触发异常后硬件的响应过程如下:
   * 
   * 将当前PC值保存到mepc寄存
   * 在mcause寄存器中设置异常号
   * 从mtvec寄存器中取出异常入口地址
   * 跳转到异常入口地址
  */
  cpu.csr[CSR_MEPC] = epc;
  /**
   * ref. riscv-privileged-20211203-The RISC-V Instruction Set Manual Volume II - Privileged Architecture.pdf
   *   Table 3.6: Machine cause register (mcause) values after trap.
   *   1 ≥16 Designated for platform use
  */
  cpu.csr[CSR_MCAUSE] = NO; // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0)

  return cpu.csr[CSR_MTVEC];
}

word_t isa_query_intr() {
  /**
   * 将 PC 设为 mepc，将 mstatus.MPIE 复制到 MIE 字段来恢复之前的中断使能状态，并将特权模式设为 mstatus.MPP 的值。
  */
  return cpu.csr[CSR_MEPC];
}
