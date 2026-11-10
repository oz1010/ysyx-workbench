MEMORY {
    FLASH   (rx)  : ORIGIN = 0x30000000, LENGTH = 16M
    MROM    (rx)  : ORIGIN = 0x20000000, LENGTH = 4096
    SRAM    (xrw) : ORIGIN = 0x0f000000, LENGTH = 4M    /* nemu等模拟使用，可以占用大一点 */
}

/* 定义主内存区域，便于RT-Thread等操作系统初始化堆 */
_pmem_start = ORIGIN(SRAM);
_pmem_size = LENGTH(SRAM);
_pmem_end = _pmem_start + _pmem_size;

/* 定义堆栈大小 */
_STACK_SIZE = 0x1000;    /* 4KB栈 */
_HEAP_SIZE = 0x1000;     /* 4KB堆 */

ENTRY(_bin_entry)
/* PHDRS { text PT_LOAD; data PT_LOAD; } */

SECTIONS {
    /* -------- 直接从FLASH启动 -------- */
    .bin_entry ORIGIN(FLASH) : {
        _bin_start = .;
        KEEP(*(.bin_entry))
    } >FLASH
    .bin_header : SUBALIGN(4) {
        _bin_header_start = .;
        KEEP(*(.bin_header))
        _bin_header_end = .;
    } >FLASH
    _bin_flag = _bin_header_start;
    .bootloader : ALIGN(4) {
        KEEP(*(entry))
    } >FLASH
    ASSERT(SIZEOF(.bin_entry) == 4, "reset vector must be 4 bytes")
    ASSERT(_bin_header_start == _bin_start + 4, "metadata must start at offset 0x04")
    ASSERT(SIZEOF(.bin_header) == 36, "metadata must be 36 bytes")
    ASSERT(ADDR(.bootloader) == _bin_start + 40, "startup must start at offset 0x28")
    ASSERT((_start & 3) == 0, "startup must be 4-byte aligned")

    /* -------- 程序和数据存放在FLASH，需要加载到RAM后跳转执行 -------- */
    .text : {
        _text_start = ALIGN(4);
        *(.text)
        *(.text*)
        *(.rodata)
        *(.rodata*)
        *(.srodata)
        *(.srodata*)
        . = ALIGN(4);
        _text_end = .;
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
    ASSERT((_text_load & 3) == 0, "text load address must be 4-byte aligned")
    ASSERT((_data_load & 3) == 0, "data load address must be 4-byte aligned")

    .bss : {
        _bss_start = ALIGN(4);
        *(.bss*)
        *(.sbss*)
        *(.scommon)
        _bss_end = ALIGN(4);
    } >SRAM
    _bss_size = _bss_end - _bss_start;

    /* 用户栈段 */
    ._user_stack : {
        _stack_top = ALIGN(16);
        . = _stack_top + _STACK_SIZE;
        _stack_pointer = .;
    } >SRAM

    /* 用户堆段 */
    ._user_heap : {
        _heap_start = ALIGN(16);
    } >SRAM
}
