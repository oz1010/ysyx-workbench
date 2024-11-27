#ifndef __CPU_EXEC_H__
#define __CPU_EXEC_H__

#include "isa.h"

extern CPU_state cpu;

void cpu_exec(uint64_t n);
void init_cpu(int argc, char *argv[]);

#endif
