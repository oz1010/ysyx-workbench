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
#include "local-include/reg.h"

const char *regs[] = {
  "$0", "ra", "sp", "gp", "tp", "t0", "t1", "t2",
  "s0", "s1", "a0", "a1", "a2", "a3", "a4", "a5",
  "a6", "a7", "s2", "s3", "s4", "s5", "s6", "s7",
  "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"
};

void isa_reg_display() {
  int i;
  for(i=0; i<sizeof(regs)/sizeof(regs[0]); ++i) {
    uint32_t reg_val = cpu.gpr[check_reg_idx(i)];
    printf("%-16s0x%-14x%-16d\n", regs[i], reg_val, reg_val);
  }
}

const char* isa_reg_name(size_t idx) {
  return regs[check_reg_idx(idx)];
}

word_t isa_reg_str2val(const char *s, bool *success) {
  int i;
  for(i=0; i<sizeof(regs)/sizeof(regs[0]); ++i) {
    uint32_t reg_val = cpu.gpr[check_reg_idx(i)];
    if(strcmp(regs[i], s)==0){
      *success = true;
      return reg_val;
    }
  }
  return 0;
}

word_t *isa_get_cpu_gpr(size_t idx)
{
  return &cpu.gpr[check_reg_idx(idx)];
}

vaddr_t *isa_get_cpu_pc(void)
{
  return &cpu.pc;
}
