#ifndef __DEBUG_H__
#define __DEBUG_H__

#include <common.h>

#define Log(format, ...) \
  printf("\33[1;32m[%s,%d,%s] " format "\33[0m\n", \
      __FILE__, __LINE__, __func__, ## __VA_ARGS__)

#undef panic
#define panic(format, ...) \
  do { \
    Log("\33[1;31msystem panic: " format, ## __VA_ARGS__); \
    halt(1); \
  } while (0)

// #define DEBUG(fmt, ...) printf("\33[1;34mDebug:\33[0m " fmt "\n", ##__VA_ARGS__)
#define DEBUG(fmt, ...) printf(fmt "\n", ##__VA_ARGS__)
#define INFO(fmt, ...) printf("\33[1;32mInfo:\33[0m " fmt "\n", ##__VA_ARGS__)
#define ERROR(fmt, ...) printf("\33[1;31mError:\33[0m " fmt "\n", ##__VA_ARGS__)
#define FATAL(fmt, ...)                            \
    do                                             \
    {                                              \
        printf("\33[1;35mFatal:\33[0m " fmt "\n", ##__VA_ARGS__); \
        halt(1);                                   \
    } while (0)

#define nullptr 0

#ifdef assert
# undef assert
#endif

#define assert(cond) \
  do { \
    if (!(cond)) { \
      panic("Assertion failed: %s", #cond); \
    } \
  } while (0)

#define TODO() panic("please implement me")

#endif
