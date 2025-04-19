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
    .text : {
        *(entry)
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
    } >MROM
    etext = .;
    _etext = .;
    .data : {
        *(.data)
    } >SRAM AT>MROM
    edata = .;
    _data = .;
    .bss : {
        _bss_start = .;
        *(.bss*)
        *(.sbss*)
        *(.scommon)
    } >SRAM

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
