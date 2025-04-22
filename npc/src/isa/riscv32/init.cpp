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
#include <memory/paddr.h>

extern void init_vsimu(int argc, char *argv[]);

vaddr_t reset_pc = RESET_VECTOR;

static void restart() {
  /* Set the initial program counter. */
  cpu.pc = reset_pc;

  /* The zero register is always 0. */
  cpu.gpr[0] = 0;

  /** https://ysyx.oscc.cc/docs/ics-pa/3.2.html#%E8%A7%A6%E5%8F%91%E8%87%AA%E9%99%B7%E6%93%8D%E4%BD%9C 让DiffTest支持异常响应机制
   * 针对riscv32, 你需要将mstatus初始化为0x1800.
   * 针对riscv64, 你需要将mstatus初始化为0xa00001800.
   */
  cpu.csr[CSR_MSTATUS] = MUXDEF(CONFIG_RV64, 0xa00001800, 0x1800);
}

void init_isa(int argc, char *argv[]) {
  /* Initialize this virtual computer system. */
  restart();

  /* Initialize verilog simu env. */
  init_vsimu(argc, argv);
}
