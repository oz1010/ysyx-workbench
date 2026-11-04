#include "riscv32_macros.S"

DECLARE_BIN_ENTRY _start

.section entry, "ax"
.globl _start
.type _start, @function
_start:
    jal _init_ram
#if !CONFIG_ICACHE
    addi a0, zero, 0xa // 没定义icache，直接异常
    ebreak
#endif
    la a0, fencei_test
    fence.i
    jalr a0
1:
    j 1b

.section .text, "ax"
.balign 4
.type fencei_test, @function
fencei_test:
    la t0, patch_site // 读取修改指令的地址
    lw t1, new_instruction // 读取正常的指令，0x00000513 => addi a0, zero, 0
    sw t1, 0(t0) // 修改fence.i后一条指令
    fence.i // 强制icache刷新

.balign 4
patch_site:
    addi a0, zero, 1 // icache没有刷新则执行异常指令
    ebreak

new_instruction:
    .word 0x00000513
.size fencei_test, . - fencei_test
