#ifndef __BIN_HEADER_H__
#define __BIN_HEADER_H__

#include <stdint.h>

// 固定标识，0x7F "BIN"
#define BIN_HEADER_MAGIC 0x7F42494E
#define DECLARE_BIN_HEADER(name)                \
    extern uint8_t _text_start;                 \
    extern uint8_t _text_end;                   \
    extern uint8_t _data_load;                  \
    extern uint8_t _data_start;                 \
    extern uint8_t _data_end;                   \
    extern uint8_t _bss_start;                  \
    extern uint8_t _bss_end;                    \
    extern void _start(void);                   \
    __attribute__((section(".bin_header")))     \
    const bin_header_t name = {                 \
        .magic      = 0x7F42494E,               \
        .entry      = (uint32_t)&_start,        \
        .text_start = (uint32_t)&_text_start,   \
        .text_end   = (uint32_t)&_text_end,     \
        .data_load  = (uint32_t)&_data_load,    \
        .data_start = (uint32_t)&_data_start,   \
        .data_end   = (uint32_t)&_data_end,     \
        .bss_start = (uint32_t)&_bss_start,     \
        .bss_end   = (uint32_t)&_bss_end,       \
    }

typedef struct _bin_header_s {
    uint32_t magic;
    uint32_t entry;
    uint32_t text_start;
    uint32_t text_end;
    uint32_t data_load;
    uint32_t data_start;
    uint32_t data_end;
    uint32_t bss_start;
    uint32_t bss_end;
} bin_header_t;

static __attribute__((used)) int parse_bin_header(void *bin_buf, bin_header_t *bin_header)
{
    if (!bin_header || !bin_buf) return 1;
    
    bin_header_t *new_header = (bin_header_t *)bin_buf;
    if (new_header->magic != BIN_HEADER_MAGIC) return 2;

    *bin_header = *new_header;

    return 0;
}

#endif
