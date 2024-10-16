#ifndef __CPU_INTERFACE_H__
#define __CPU_INTERFACE_H__

#include "common.h"
#include "isa.h"

/**
 * CPU操作接口
 */
typedef struct {
    word_t * (*get_gpr)(CPU_state *c, size_t idx);
    // void (*vaddr_write)(vaddr_t addr, int len, word_t data);
    // word_t (*vaddr_read)(vaddr_t addr, int len);
    int (*access_mem)(uint32_t write, uint32_t addr, uint32_t size, uint8_t *data);
} cpu_opt_t;

#endif
