MEMORY {
    FLASH   (rx)  : ORIGIN = 0x30000000, LENGTH = 16M
    MROM    (rx)  : ORIGIN = 0x20000000, LENGTH = 4096
    SRAM    (xrw) : ORIGIN = 0x0f000000, LENGTH = 8K
    PSRAM   (xrw) : ORIGIN = 0x80000000, LENGTH = 4M
}

/* 定义堆栈大小 */
/* _STACK_SIZE = 0x1000; */
_STACK_SIZE = 0x1000;    /* 4KB栈 */
_HEAP_SIZE = 0x0400;     /* 1KB堆 */

ENTRY(_start)
/* PHDRS { text PT_LOAD; data PT_LOAD; } */

SECTIONS {
    /* -------- bin_header segment (放在最前面) -------- */
    .bin_header : {
        KEEP(*(.bin_header)) /* 确保bin_header被保留 */
    } > FLASH

    .text : {
        _text_start = .;
        *(entry)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        _text_end = ALIGN(4);
    } >FLASH
    etext = .;
    _etext = .;

    /* .data : {
        *(.data)
    } >PSRAM AT>FLASH */
    /* .data 的加载地址紧跟 .text，VMA 在 PSRAM */
    .data : AT(_text_end) {
        _data_start = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        _data_end = ALIGN(4);
    } >PSRAM
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
    } >PSRAM
    _bss_size = _bss_end - _bss_start;

    /* 用户栈 */
    ._user_stack : {
        /* _stack_top = ALIGN(0x1000); */
        _stack_top = ALIGN(16);
        . = _stack_top + _STACK_SIZE;
        _stack_pointer = .;
        end = .;
        _end = .;
    } >SRAM
    /* 用户堆 */
    ._user_heap : {
        /* _heap_start = ALIGN(0x1000); */
        _heap_start = ALIGN(16);
        _pmem_start = .;
    } >PSRAM
}
