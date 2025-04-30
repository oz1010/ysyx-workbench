#ifndef __MACRO_H__
#define __MACRO_H__

// macro concatenation
#define concat_temp(x, y) x ## y
#define concat(x, y) concat_temp(x, y)

#define UNUSED_FUNC static __attribute__((unused))

#endif
