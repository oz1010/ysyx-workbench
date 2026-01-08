/* 公共汇编宏定义 */

#ifndef __RISCV32_MACROS_S__
#define __RISCV32_MACROS_S__

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
 * 参数：无
 * 使用示例：
 *   jal _init_ram
 */
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

#endif
