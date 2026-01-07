#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

extern char _heap_start;

// #define ICACHE_ALIGN 1

typedef struct {
    volatile uint32_t data1 [7];
    volatile uint32_t count;
} item_t;

// 此函数用于控制函数热点数据对齐
void func2(item_t *item)
{
    (void)item->data1[0];
    (void)item->data1[0];
    (void)item->data1[0];

    (void)item->data1[1];
    (void)item->data1[1];
    (void)item->data1[1];

    (void)item->data1[2];
    (void)item->data1[2];
    (void)item->data1[2];
#if ICACHE_ALIGN  
    (void)item->data1[3];
#endif
}

void func1(item_t *item, uint32_t total)
{
    for (uint32_t i=0; i<total; ++i) {
        item->count += 1;
        (void)item->count;
    }
}

int main()
{
    // uint32_t addr = (uint32_t)&_heap_start;
    item_t *item = (item_t *)0x0f000000;

    func2(item);

//     printf("simple sdram icache test, heap: %x align: %s\n", addr, 
// #if ICACHE_ALIGN
//         "true"
// #else
//         "false"
// #endif
//     );

    func1(item, 3000);

    // printf("all done, count: %lu.\n", item->count);

    return 0;
}
