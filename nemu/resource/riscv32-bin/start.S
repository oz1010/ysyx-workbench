.section entry, "ax"
.globl _start
.type _start, @function

// 加载代码或数据到RAM，load_sym为0直接清零
.macro LOAD_TO_RAM load_sym, start_sym, end_sym
    la a0, \load_sym
    la a1, \start_sym
    la a2, \end_sym

1:  /* 加载模式 */
    bge a1, a2, 3f
    lw t0, 0(a0)
    sw t0, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    j 1b

2:  /* 清零模式，load_sym为0 */
    bge a1, a2, 3f
    sw zero, 0(a1)
    addi a1, a1, 4
    j 2b

3:
.endm

_start:
    mv s0, zero
    la sp, _stack_pointer
    jal _init_ram
    // 通过寄存器进行单向跳转，直接jal _trm_init跳转会出错
    la a0, init
    jalr a0
1:  j 1b // 不会跳转到此处

_init_ram:
    // .text段加载到RAM
    LOAD_TO_RAM   _text_load, _text_start, _text_end
    // .data段加载到RAM
    LOAD_TO_RAM   _data_load, _data_start, _data_end
    // .bss段直接清理
    LOAD_TO_RAM   0, _bss_start, _bss_end
    ret
