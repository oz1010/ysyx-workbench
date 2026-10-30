/* 公共汇编宏定义 */

#ifndef __RISCV32_MACROS_S__
#define __RISCV32_MACROS_S__

/* 镜像头部flag常量，与common/include/file/bin_header.h保持一致；
 * 汇编侧无法包含C头文件，经预处理在此定义，未定义CONFIG_FAST_LOAD时flag为0 */
#ifndef BIN_HEADER_FLAG_FAST_BOOT
#define BIN_HEADER_FLAG_FAST_BOOT (1<<0)
#endif
#ifndef BIN_HEADER_FLAG_VALUE
#ifdef CONFIG_FAST_LOAD
#define BIN_HEADER_FLAG_VALUE BIN_HEADER_FLAG_FAST_BOOT
#else
#define BIN_HEADER_FLAG_VALUE 0
#endif
#endif

/*
 * 宏：加载代码或数据到RAM
 * 参数：
 *   load_sym -- 数据加载位置符号；为0时会变为清零模式
 *   start_sym -- 数据存储开始位置符号；
 *   end_sym -- 数据存储结束位置符号，不包含；
 * 使用示例：
 *   LOAD_TO_RAM   _text_load, _text_start, _text_end
 *   LOAD_TO_RAM   0, _bss_start, _bss_end
 */
.macro LOAD_TO_RAM load_sym, start_sym, end_sym
    la a0, \load_sym
    la a1, \start_sym
    la a2, \end_sym
    beq a0, zero, 2f

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

/*
 * 宏：设置内存范围为指定数据，数据位宽32
 * 参数：
 *   data_value -- 指定的数据值
 *   start_sym -- 数据存储开始位置符号；
 *   end_sym -- 数据存储结束位置符号，不包含；
 * 使用示例：
 *   SET_MEM32   _text_load, _text_start, _text_end
 *   SET_MEM32   0, _bss_start, _bss_end
 */
.macro SET_MEM32 data_value, start_sym, end_sym
    la a0, \data_value
    la a1, \start_sym
    la a2, \end_sym

1:  /* 循环设置32值 */
    bge a1, a2, 2f
    sw a0, 0(a1)
    addi a1, a1, 4
    j 1b

2:
.endm

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
    /* 快速加载模式 */
    la t0, _bin_flag
    lw t1, 0(t0)
    la t0, 0x1
    and t2, t1, t0        # t2 = t1 & 0x1 (提取最低位)
    beq t2, t0, _init_ram_skiped # if (t2 == t0) 跳过_init_ram_skiped
    /* .text段加载到RAM */
    LOAD_TO_RAM   _text_load, _text_start, _text_end
    /* .data段加载到RAM */
    LOAD_TO_RAM   _data_load, _data_start, _data_end
    /* .bss段直接清理 */
    SET_MEM32     0, _bss_start, _bss_end
_init_ram_skiped:
    ret

/*
 * 宏：生成镜像前导区，4字节复位跳转指令 + 36字节段元数据
 * 需在各start.S中于_start之前声明，并传入跳转目标（如_start）；
 * 段元数据的符号地址在链接期通过绝对地址重定位填入。
 * 参数：
 *   entry_sym -- 复位向量跳转目标符号，通常为_start；
 *   flag_value -- 元数据flag字段值，通常为BIN_HEADER_FLAG_VALUE；
 * 使用示例：
 *   DECLARE_BIN_ENTRY _start, BIN_HEADER_FLAG_VALUE
 */
.macro DECLARE_BIN_ENTRY entry_sym, flag_value
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
    .word \flag_value
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
