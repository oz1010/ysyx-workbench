.include "riscv32_macros.S"

/* first stage bootloader */
.section entry, "ax"
.globl _start
.type _start, @function
_start:
    LOAD_TO_RAM _ssbl_load, _ssbl_start, _ssbl_end
    la a0, _ssbl_start
    fence.i // 无效化icache，强制触发重新缓存
    jalr a0

/* second stage bootloader */
.section entry.ssbl, "ax"
.global _start_ssbl
.type _start_ssbl, @function
_start_ssbl:
    /* 快速加载模式 */
    la t0, _bin_flag
    lw t1, 0(t0)
    la t0, 0x1
    and t2, t1, t0        # t2 = t1 & 0x1 (提取最低位)
    beq t2, t0, _skip_to_fast_load # if (t2 == t0) 跳到_skip_to_fast_load
    /* .text段加载到RAM */
    LOAD_TO_RAM   _text_load, _text_start, _text_end
    /* .data段加载到RAM */
    LOAD_TO_RAM   _data_load, _data_start, _data_end
    /* .bss段直接清理 */
    LOAD_TO_RAM   0, _bss_start, _bss_end

_skip_to_fast_load:
    // 通过寄存器进行单向跳转，直接jal xxx跳转会出错
    mv s0, zero
    la sp, _stack_pointer
    la a0, _trm_init
    fence.i // 无效化icache，强制触发重新缓存
    jalr a0
1:  j 1b // 不会跳转到此处
