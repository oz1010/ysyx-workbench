#ifndef ARCH_H__
#define ARCH_H__
#include "macro.h"

struct concat(__GUEST_ISA__, _Context) {
  // TODO: fix the order of these members to match trap.S
  uintptr_t esi, ebx, eax, eip, edx, eflags, ecx, cs, esp, edi, ebp;
  void *cr3;
  int irq;
};

#define GPR1 eax
#define GPR2 eip
#define GPR3 eip
#define GPR4 eip
#define GPRx eip

#endif
