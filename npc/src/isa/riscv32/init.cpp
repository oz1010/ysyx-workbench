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

vaddr_t reset_pc = CONFIG_IMG_LOAD;

static void restart() {
  /* Set the initial program counter. */
  cpu.pc = reset_pc;

  /* The zero register is always 0. */
  cpu.gpr[0] = 0;

  /* Keep the software CSR reset values consistent with csrs. */
  memset(cpu.csr, 0, sizeof(cpu.csr));
  cpu.csr[CSR_MSTATUS] = MUXDEF(CONFIG_RV64, 0xa00001800, 0x1800);
  cpu.csr[CSR_MVENDORID] = 0x79737978;
  cpu.csr[CSR_MARCHID] = 0x15FDF47;
}

void init_isa(int argc, char *argv[]) {
  /* Initialize this virtual computer system. */
  restart();

  /* Initialize verilog simu env. */
  init_vsimu(argc, argv);
}

void set_pc(paddr_t addr) {
    reset_pc = addr;
    cpu.pc = addr;
}
