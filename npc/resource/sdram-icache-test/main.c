#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

extern char _heap_start;

int main()
{
    uint32_t addr = (uint32_t)&_heap_start;

    printf("simple sdram icache test, heap: %x\n", addr);
    printf("done.\n");

    return 0;
}
