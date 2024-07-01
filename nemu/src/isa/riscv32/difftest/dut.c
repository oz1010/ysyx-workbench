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
#include <cpu/difftest.h>
#include "../local-include/reg.h"

bool isa_difftest_checkregs(CPU_state *ref_r, vaddr_t pc) {
  // cpu.pc = RESET_VECTOR;
  // cpu.gpr[0] = 0;
  if (memcmp(cpu.gpr, ref_r->gpr, sizeof(ref_r->gpr)) != 0)
  {
    int i = 0;
    for (i=0; i<sizeof(ref_r->gpr); ++i)  {
      if (cpu.gpr[i]!=ref_r->gpr[i]) {
        break;
      }
    }
    printf("Found register is different, %s(0x%x 0x%x) PC(0x%x)\n", isa_reg_name(i), cpu.gpr[i], ref_r->gpr[i], pc);
    return false;
  } else if (cpu.pc != ref_r->pc) {
    printf("Found PC is different, PC(0x%x 0x%x)\n", cpu.pc, ref_r->pc);
    return false;
  }

  printf("All thing is OK, PC 0x%x\n", pc);

  return true;
}

void isa_difftest_attach() {
}
