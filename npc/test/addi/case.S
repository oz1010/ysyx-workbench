.section .text
.globl _start

_start:
    addi a0, a0, -1
    addi a0, x0, 0x123
    addi a1, a0, 0x456
    addi x0, a0, 0x789
    addi a0, x0, -1
    addi a1, a0, -5
    addi a0, x0, -5
    addi a1, a0, 6
    addi a0, x0, 8
    addi a1, a0, -5
    
    // ecall

    addi a0, x0, 0
    ebreak
