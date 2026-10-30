#ifndef __BIN_HEADER_H__
#define __BIN_HEADER_H__

#include <stdint.h>

#ifndef concat
// macro concatenation
#define concat_temp(x, y) x ## y
#define concat(x, y) concat_temp(x, y)
#define concat3(x, y, z) concat(concat(x, y), z)
#define concat4(x, y, z, w) concat3(concat(x, y), z, w)
#define concat5(x, y, z, v, w) concat4(concat(x, y), z, v, w)
#endif

#ifndef MUXDEF
// macro testing
// See https://stackoverflow.com/questions/26099745/test-if-preprocessor-symbol-is-defined-inside-macro
#define CHOOSE2nd(a, b, ...) b
#define MUX_WITH_COMMA(contain_comma, a, b) CHOOSE2nd(contain_comma a, b)
#define MUX_MACRO_PROPERTY(p, macro, a, b) MUX_WITH_COMMA(concat(p, macro), a, b)
// define placeholders for some property
#define __P_DEF_0  X,
#define __P_DEF_1  X,
#define __P_ONE_1  X,
#define __P_ZERO_0 X,
// define some selection functions based on the properties of BOOLEAN macro
#define MUXDEF(macro, X, Y)  MUX_MACRO_PROPERTY(__P_DEF_, macro, X, Y)
#endif

// 镜像前导区：4字节复位跳转指令 + 36字节段元数据
#define BIN_HEADER_OFFSET 4
#define BIN_HEADER_SIZE 36
#define BIN_HEADER_FLAG_FAST_BOOT               (1<<0)
#define BIN_HEADER_FLAG_VALUE                   (MUXDEF(CONFIG_FAST_LOAD, BIN_HEADER_FLAG_FAST_BOOT, 0))

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
