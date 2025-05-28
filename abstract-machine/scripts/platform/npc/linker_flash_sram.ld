MEMORY {
    FLASH   (rx)  : ORIGIN = 0x30000000, LENGTH = 16M
    MROM    (rx)  : ORIGIN = 0x20000000, LENGTH = 4096
    SRAM    (xrw) : ORIGIN = 0x0f000000, LENGTH = 8K
    PSRAM   (xrw) : ORIGIN = 0x80000000, LENGTH = 4M
}

/* 定义堆栈大小 */
_STACK_SIZE = 0x0400;    /* 1KB栈 */
_HEAP_SIZE = 0x0400;     /* 1KB堆 */

ENTRY(_start)
/* PHDRS { text PT_LOAD; data PT_LOAD; } */

SECTIONS {
    /* -------- 直接从FLASH启动 -------- */
    .bootloader : {
        KEEP(*(.bin_header))
        *(entry)
    } >FLASH

    /* -------- 程序和数据存放在FLASH，需要加载到RAM后跳转执行 -------- */
    .text : {
        _text_start = ALIGN(4);
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        _text_end = ALIGN(4);
    } >SRAM AT>FLASH
    etext = .;
    _etext = .;
    _text_load = LOADADDR(.text);

    /* .data : {
        *(.data)
    } >SRAM AT>FLASH */
    /* .data 的加载地址紧跟 .text，VMA 在 SRAM */
    /* .data : AT(_text_end) { */
    .data : {
        _data_start = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        _data_end = ALIGN(4);
    } >SRAM AT>FLASH
    edata = .;
    _data = .;
    _data_load = LOADADDR(.data);  /* 在存储器中的地址 */
    _data_size = _data_end - _data_start;

    .bss : {
        _bss_start = ALIGN(4);
        *(.bss*)
        *(.sbss*)
        *(.scommon)
        _bss_end = ALIGN(4);
    } >SRAM
    _bss_size = _bss_end - _bss_start;

    /* 用户堆栈段 */
    ._user_heap_stack : {
        /* _stack_top = ALIGN(0x1000); */
        _stack_top = ALIGN(16);
        . = _stack_top + _STACK_SIZE;
        _stack_pointer = .;
        end = .;
        _end = .;
        /* _heap_start = ALIGN(0x1000); */
        _heap_start = ALIGN(16);
        _pmem_start = .;
    } >SRAM
}
