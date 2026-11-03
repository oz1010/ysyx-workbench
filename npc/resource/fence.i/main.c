#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"
#include "generated/autoconf.h"

typedef int (*code_fn_t)(void);

/*
 * 放在可写、可执行的 RAM 段中：
 *
 * 0xfff00513 = addi a0, zero, -1
 * 0x00008067 = ret
 */
__attribute__((section(".text.patch"), aligned(64),
               used)) static volatile uint32_t patch_code[2] = {
    0xfff00513u,
    0x00008067u,
};

int main()
{
    code_fn_t fn = (code_fn_t)(uintptr_t)&patch_code[0];

#if !CONFIG_ICACHE
    printf("Need to open icache\n");
    return 2;
#endif

    /* 第一次执行：返回 -1，同时让旧指令进入取指路径/I-cache。 */
    if (fn() != -1) {
        printf("Environment error\n");
        return 1; /* 测试环境本身异常 */
    }

    /*
     * 将第一条指令改为：
     * 0x00000513 = addi a0, zero, 0
     */
    patch_code[0] = 0x00000513u;

    /* "memory" 防止编译器把存储、fence.i 和调用乱序。 */
    __asm__ volatile("fence.i" ::: "memory");

    if (!fn()) {
        printf("All done\n");
        return 0;
    } else {
        printf("fence.i is error\n");
        return -1;
    }
}
