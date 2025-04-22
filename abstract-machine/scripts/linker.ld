MEMORY {
    MROM    (rx)  : ORIGIN = 0x20000000, LENGTH = 4096
    SRAM    (xrw) : ORIGIN = 0x0f000000, LENGTH = 8K
}

/* 定义堆栈大小 */
_STACK_SIZE = 0x0400;    /* 1KB栈 */
_HEAP_SIZE = 0x0400;     /* 1KB堆 */

ENTRY(_start)
/* PHDRS { text PT_LOAD; data PT_LOAD; } */

SECTIONS {
    /* -------- bin_header segment (放在最前面) -------- */
    .bin_header : {
        KEEP(*(.bin_header)) /* 确保bin_header被保留 */
    } > MROM

    .text : {
        _text_start = .;
        *(entry)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        _text_end = .;
    } >MROM
    etext = .;
    _etext = .;

    /* .data : {
        *(.data)
    } >SRAM AT>MROM */
    /* .data 的加载地址紧跟 .text，VMA 在 SRAM */
    .data : AT(_text_end) {
        _data_start = .;
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        _data_end = .;
    } >SRAM
    edata = .;
    _data = .;
    _data_load = LOADADDR(.data);  /* 在 MROM 中的地址 */
    _data_size = _data_end - _data_start;

    .bss : {
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(.scommon)
        _bss_end = .;
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
    } >SRAM
}
