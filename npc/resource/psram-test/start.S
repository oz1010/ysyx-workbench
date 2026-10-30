#include "riscv32_macros.S"

DECLARE_BIN_ENTRY _start, BIN_HEADER_FLAG_VALUE

/* first stage bootloader */
.section entry, "ax"
.globl _start
.type _start, @function
_start:
    mv s0, zero
    la sp, _stack_pointer
    jal _init_ram
    // 通过寄存器进行单向跳转，直接jal _trm_init跳转会出错
    la a0, _test_init
    fence.i // 无效化icache，强制触发重新缓存
    jalr a0
1:  j 1b // 不会跳转到此处
