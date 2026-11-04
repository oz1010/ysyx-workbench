#ifndef __BIN_HEADER_H__
#define __BIN_HEADER_H__

#include <stdint.h>
#include "bin_header_types.h"

typedef struct _bin_header_s {
    uint32_t flag;
    uint32_t text_load;
    uint32_t text_start;
    uint32_t text_end;
    uint32_t data_load;
    uint32_t data_start;
    uint32_t data_end;
    uint32_t bss_start;
    uint32_t bss_end;
} bin_header_t;

#if defined(__cplusplus)
static_assert(sizeof(bin_header_t) == BIN_HEADER_SIZE, "invalid bin metadata size");
#else
_Static_assert(sizeof(bin_header_t) == BIN_HEADER_SIZE, "invalid bin metadata size");
#endif

#endif
