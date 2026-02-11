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

#ifndef __ISA_RISCV_H__
#define __ISA_RISCV_H__

#include <common.h>

/**
 * ref. riscv-privileged-20211203-The RISC-V Instruction Set Manual Volume II - Privileged Architecture.pdf
 *   CSR Address: [9:8]为权限等级，0--User-Level 1--Supervisor-Level 2--Hypervisor and VS 3--Machine-Level
 *   Table 2.5: Currently allocated RISC-V machine-level CSR addresses.
*/
enum {
  /* Machine Trap Setup */
  CSR_MSTATUS       = 0x300,  // mstatus寄存器 - 存放处理器的状态
  CSR_MTVEC         = 0x305,  // mtvec寄存器 - 存放trap-handler基地址
  /* Machine Trap Handling */
  CSR_MEPC          = 0x341,  // mepc寄存器 - 存放触发异常的PC
  CSR_MCAUSE        = 0x342,  // mcause寄存器 - 存放触发异常的原因

  /* Machine Information Registers */
  CSR_MVENDORID     = 0xf11, // Vendor ID, ysyx的ASCII码, 即0x79737978
  CSR_MARCHID       = 0xf12, // Architecture ID, 学号数字部分（23060295）的十进制表示，即0x15FDF47

  CSR_COUNT         = 4096    // 查看csrrw中csr占12位推算需要占用4096个csr寄存器
};

typedef struct {
  word_t gpr[MUXDEF(CONFIG_RVE, 16, 32)];
  vaddr_t pc;
  // IFDEF(CONFIG_ISA_RISCV_SINGLE, word_t csr[CSR_COUNT]);
  word_t csr[CSR_COUNT]; // TODO ref会使用这个结构，不能直接屏蔽。否则会造成coredump，暂时先不处理。
} MUXDEF(CONFIG_RV64, riscv64_CPU_state, concat(__GUEST_ISA__, _CPU_state));

// decode
typedef struct {
  union {
    uint32_t val;
  } inst;
} MUXDEF(CONFIG_RV64, riscv64_ISADecodeInfo, riscv32_ISADecodeInfo);

#define isa_mmu_check(vaddr, len, type) (MMU_DIRECT)

#endif
