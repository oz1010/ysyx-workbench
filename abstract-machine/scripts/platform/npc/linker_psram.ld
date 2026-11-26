MEMORY {
    PSRAM   (xrw) : ORIGIN = 0x80000000, LENGTH = 4M
}

_pmem_start = ORIGIN(PSRAM);
_pmem_size = LENGTH(PSRAM);
_pmem_end = _pmem_start + _pmem_size;

_STACK_SIZE = 0x10000;
_HEAP_SIZE = 0x1000;

ENTRY(_bin_entry)

SECTIONS {
    .bin_entry ORIGIN(PSRAM) : {
        _bin_start = .;
        KEEP(*(.bin_entry))
    } >PSRAM
    .bin_header : SUBALIGN(4) {
        _bin_header_start = .;
        KEEP(*(.bin_header))
        _bin_header_end = .;
    } >PSRAM
    _bin_flag = _bin_header_start;
    .bootloader : ALIGN(4) {
        KEEP(*(entry))
    } >PSRAM
    ASSERT(SIZEOF(.bin_entry) == 4, "reset vector must be 4 bytes")
    ASSERT(_bin_header_start == _bin_start + 4, "metadata must start at offset 0x04")
    ASSERT(SIZEOF(.bin_header) == 36, "metadata must be 36 bytes")
    ASSERT(ADDR(.bootloader) == _bin_start + 40, "startup must start at offset 0x28")
    ASSERT((_start & 3) == 0, "startup must be 4-byte aligned")

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
    } >PSRAM
    etext = .;
    _etext = .;
    _text_load = LOADADDR(.text);

    .data : {
        _data_start = ALIGN(4);
        *(.data)
        *(.data*)
        *(.sdata)
        *(.sdata*)
        _data_end = ALIGN(4);
    } >PSRAM
    edata = .;
    _data = .;
    _data_load = LOADADDR(.data);
    _data_size = _data_end - _data_start;
    ASSERT((_text_load & 3) == 0, "text load address must be 4-byte aligned")
    ASSERT((_data_load & 3) == 0, "data load address must be 4-byte aligned")

    .bss : {
        _bss_start = ALIGN(4);
        *(.bss*)
        *(.sbss*)
        *(.scommon)
        _bss_end = ALIGN(4);
    } >PSRAM
    _bss_size = _bss_end - _bss_start;

    ._user_stack : {
        _stack_top = ALIGN(16);
        . = _stack_top + _STACK_SIZE;
        _stack_pointer = .;
    } >PSRAM

    ._user_heap : {
        _heap_start = ALIGN(16);
    } >PSRAM
}
