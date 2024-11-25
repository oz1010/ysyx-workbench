#ifndef __CPU_EXEC_H__
#define __CPU_EXEC_H__

#include "isa.h"

extern CPU_state cpu;

void cpu_exec(uint64_t n);
void init_cpu(int argc, char *argv[]);

void isa_reg_display();
const char* isa_reg_name(size_t idx);
word_t isa_reg_str2val(const char *s, bool *success);
vaddr_t *isa_get_cpu_pc(void);

#endif
