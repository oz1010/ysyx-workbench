#ifndef __MTRACE_H__
#define __MTRACE_H__

#include "common.h"

typedef enum {
    mtrace_opt_read,
    mtrace_opt_write,
} mtrace_opt_t;

void init_mtrace();
void add_mtrace(mtrace_opt_t opt, vaddr_t pc, vaddr_t mem_addr, word_t mem_value);
void dump_mtrace();

#endif
