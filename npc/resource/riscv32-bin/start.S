.section entry, "ax"
.globl _start
.type _start, @function

_start:
  mv s0, zero
  la sp, _stack_pointer
  jal _init_ram
  jal init

.section .text
_init_ram:
  // 初始化 .data段，从ROM拷贝到RAM
  la a0, _data_load
  la a1, _data_start
  la a2, _data_end

copy_data:
  bge a1, a2, clear_bss_init
  lw t0, 0(a0)
  sw t0, 0(a1)
  addi a0, a0, 4
  addi a1, a1, 4
  j copy_data

clear_bss_init:
  la a1, _bss_start
  la a2, _bss_end

clear_bss:  
  bge a1, a2, init_ram_done
  sw zero, 0(a1)
  addi a1, a1, 4
  j clear_bss

init_ram_done:
  ret
