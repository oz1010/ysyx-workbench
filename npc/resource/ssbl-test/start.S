.include "riscv32_macros.S"

.section entry, "ax"
.globl _start
.type _start, @function
_start:
    LOAD_TO_RAM _ssbl_load, _ssbl_start, _ssbl_end
    la a0, _ssbl_start
    jalr a0

.section entry.ssbl, "ax"
.global _start_ssbl
.type _start_ssbl, @function
_start_ssbl:
    /* .text段加载到RAM */
    LOAD_TO_RAM   _text_load, _text_start, _text_end
    /* .data段加载到RAM */
    LOAD_TO_RAM   _data_load, _data_start, _data_end
    /* .bss段直接清理 */
    LOAD_TO_RAM   0, _bss_start, _bss_end

    // 通过寄存器进行单向跳转，直接jal _trm_init跳转会出错
    mv s0, zero
    la sp, _stack_pointer
    la a0, _test_init
    jalr a0
1:  j 1b // 不会跳转到此处
