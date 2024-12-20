#ifndef __MTRACE_H__
#define __MTRACE_H__

#include "common.h"

void init_mtrace();
void add_mtrace(vaddr_t pc, vaddr_t mem_addr);

#endif
