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

#include <utils.h>
#include <cpu/ifetch.h>
#include <isa.h>
#include <cpu/difftest.h>

void set_nemu_state(int state, vaddr_t pc, int halt_ret) {
  difftest_skip_ref();
  nemu_state.state = state;
  nemu_state.halt_pc = pc;
  nemu_state.halt_ret = halt_ret;
}

__attribute__((noinline))
void invalid_inst(vaddr_t thispc) {
  uint32_t temp[2];
  vaddr_t pc = thispc;
  temp[0] = inst_fetch(&pc, 4);
  temp[1] = inst_fetch(&pc, 4);

  uint8_t *p = (uint8_t *)temp;
  printf("invalid opcode(PC = " FMT_WORD "):\n"
      "\t%02x %02x %02x %02x %02x %02x %02x %02x ...\n"
      "\t%08x %08x...\n",
      thispc, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], temp[0], temp[1]);

  printf("There are two cases which will trigger this unexpected exception:\n"
      "1. The instruction at PC = " FMT_WORD " is not implemented.\n"
      "2. Something is implemented incorrectly.\n", thispc);
  printf("Find this PC(" FMT_WORD ") in the disassembling result to distinguish which case it is.\n\n", thispc);
  printf(ANSI_FMT("If it is the first case, see\n%s\nfor more details.\n\n"
        "If it is the second case, remember:\n"
        "* The machine is always right!\n"
        "* Every line of untested code is always wrong!\n\n", ANSI_FG_RED), isa_logo);

  set_nemu_state(NEMU_ABORT, thispc, -1);
}

vaddr_t raise_exception(vaddr_t thispc, word_t inst) {
  /**
   * ref. https://ysyx.oscc.cc/docs/ics-pa/3.2.html#riscv32
   * riscv32触发异常后硬件的响应过程如下:
   * 
   * 将当前PC值保存到mepc寄存
   * 在mcause寄存器中设置异常号
   * 从mtvec寄存器中取出异常入口地址
   * 跳转到异常入口地址
  */
  cpu.csr[CSR_MEPC] = thispc + 4;
  /**
   * ref. riscv-privileged-20211203-The RISC-V Instruction Set Manual Volume II - Privileged Architecture.pdf
   *   Table 3.6: Machine cause register (mcause) values after trap.
   *   1 ≥16 Designated for platform use
  */
  cpu.csr[CSR_MCAUSE] = 1<<31 | 3<<0; // abstract-machine/am/src/riscv/nemu/cte.c约定 GPR1 is event when mcause is Machine software interrupt (1<<31 | 3<<0)
  return cpu.csr[CSR_MTVEC];
}

vaddr_t machine_return() {
  /**
   * 将 PC 设为 mepc，将 mstatus.MPIE 复制到 MIE 字段来恢复之前的中断使能状态，并将特权模式设为 mstatus.MPP 的值。
  */
  return cpu.csr[CSR_MEPC];
}
