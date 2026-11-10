/* 公共汇编宏定义 */

#ifndef __RISCV32_MACROS_S__
#define __RISCV32_MACROS_S__

#include "file/bin_header_types.h"
#include "generated/autoconf.h"

/* 初始化加载进度输出使用的UART16550，与平台trm.c中的配置保持一致。 */
.macro RAM_PROGRESS_UART_INIT
    li a3, 0x10000000
    lbu a4, 3(a3)
    ori a5, a4, 0x80
    sb a5, 3(a3)
    sb zero, 1(a3)
    li a5, 1
    sb a5, 0(a3)
    andi a4, a4, 0x7f
    sb a4, 3(a3)
.endm

/* a3为串口基地址，a4和a5用作输出临时寄存器。 */
.macro RAM_PROGRESS_PUTC char
    li a5, \char
9:
    lbu a4, 5(a3)
    andi a4, a4, 0x40
    beqz a4, 9b
    sb a5, 0(a3)
.endm

/*
 * 宏：加载代码或数据到RAM
 * 参数：
 *   title -- 进度标题字符，例如'T'对应.text段；
 *   load_sym -- 数据加载位置符号；
 *   start_sym -- 数据存储开始位置符号；
 *   end_sym -- 数据存储结束位置符号，不包含；
 * 使用示例：
 *   LOAD_MEM   'T', _text_load, _text_start, _text_end
 */
.macro LOAD_MEM title, load_sym, start_sym, end_sym
    la a0, \load_sym
    la a1, \start_sym
    la a2, \end_sym
    li a3, 0x10000000
    RAM_PROGRESS_PUTC \title
    RAM_PROGRESS_PUTC ':'

    /* t0为总字数，t1为已完成进度的16倍，t2为下一个1/16阈值。 */
    sub t0, a2, a1
    addi t0, t0, 3
    srli t0, t0, 2
    li t1, 0
    mv t2, t0

1:  /* 加载数据 */
    bge a1, a2, 3f
    lw a5, 0(a0)
    sw a5, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4

    /* 每完成1/16打印一个'.' */
    addi t1, t1, 16
2:
    blt t1, t2, 1b
    RAM_PROGRESS_PUTC '.'
    add t2, t2, t0
    j 2b

3:
    RAM_PROGRESS_PUTC 10
.endm

/*
 * 宏：设置内存范围为指定数据，数据位宽32
 * 参数：
 *   title -- 进度标题字符，例如'B'对应.bss段；
 *   data_value -- 指定的数据值
 *   start_sym -- 数据存储开始位置符号；
 *   end_sym -- 数据存储结束位置符号，不包含；
 * 使用示例：
 *   SET_MEM   'B', 0, _bss_start, _bss_end
 */
.macro SET_MEM title, data_value, start_sym, end_sym
    la a0, \data_value
    la a1, \start_sym
    la a2, \end_sym
    li a3, 0x10000000
    RAM_PROGRESS_PUTC \title
    RAM_PROGRESS_PUTC ':'

    sub t0, a2, a1
    addi t0, t0, 3
    srli t0, t0, 2
    li t1, 0
    mv t2, t0

1:  /* 循环设置32值 */
    bge a1, a2, 4f
    sw a0, 0(a1)
    addi a1, a1, 4
    addi t1, t1, 16
5:
    blt t1, t2, 1b
    RAM_PROGRESS_PUTC '.'
    add t2, t2, t0
    j 5b

4:
    RAM_PROGRESS_PUTC 10
.endm

/* 默认异常入口：通过a0-a2保留原始异常信息，并以ebreak上报。 */
.section entry, "ax"
.global _trap_handle_def
.type _trap_handle_def, @function
_trap_handle_def:
    csrr a0, mepc
    csrr a1, mcause
    csrr a2, mtval
    ebreak
.size _trap_handle_def, . - _trap_handle_def

/*
 * 宏：初始化内存，主要用于辅助加载。当发现是快速加载模式，则会跳过初始化。
 * 需位于镜像前导区所在的FLASH等上电即可执行的区域，
 * 因此显式放入entry段（链接脚本将其紧随镜像头部布置）。
 * 参数：无
 * 使用示例：
 *   jal _init_ram
 */
.section entry, "ax"
.global _init_ram
.type _init_ram, @function
_init_ram:
    la t0, _trap_handle_def
    csrw mtvec, t0

    /* 快速加载模式 */
    la t0, _bin_flag
    lw t1, 0(t0)
    la t0, 0x1
    and t2, t1, t0        # t2 = t1 & 0x1 (提取最低位)
    beq t2, t0, _init_ram_skiped # if (t2 == t0) 跳过_init_ram_skiped
    RAM_PROGRESS_UART_INIT
    /* .text段加载到RAM */
    LOAD_MEM    'T', _text_load, _text_start, _text_end
    /* .data段加载到RAM */
    LOAD_MEM    'D', _data_load, _data_start, _data_end
    /* .bss段直接清理 */
    SET_MEM     'B', 0, _bss_start, _bss_end
_init_ram_skiped:
    ret

/*
 * 宏：生成镜像前导区，4字节复位跳转指令 + 36字节段元数据
 * 需在各start.S中于_start之前声明，并传入跳转目标（如_start）；
 * 段元数据的符号地址在链接期通过绝对地址重定位填入。
 * 参数：
 *   entry_sym -- 复位向量跳转目标符号，通常为_start；
 * 使用示例：
 *   DECLARE_BIN_ENTRY _start
 */
.macro DECLARE_BIN_ENTRY entry_sym
    .pushsection .bin_entry, "ax", @progbits
    .option push
    .option norvc
    .option norelax
    .balign 4
    .globl _bin_entry
    .type _bin_entry, @function
_bin_entry:
    jal x0, \entry_sym
    .size _bin_entry, . - _bin_entry
    .option pop
    .popsection

    .pushsection .bin_header, "aw", @progbits
    .balign 4
    .globl _bin_flag
    .type _bin_flag, @object
_bin_flag:
    /* flag：bit0为BIN_HEADER_FLAG_FAST_BOOT */
    .word BIN_HEADER_FLAG_VALUE
    /* .text段元数据 */
    .word _text_load
    .word _text_start
    .word _text_end
    /* .data段元数据 */
    .word _data_load
    .word _data_start
    .word _data_end
    /* .bss段元数据 */
    .word _bss_start
    .word _bss_end
    .size _bin_flag, . - _bin_flag
    .popsection
.endm

#endif
