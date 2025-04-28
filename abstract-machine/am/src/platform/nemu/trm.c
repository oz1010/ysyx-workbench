#include <am.h>
#include <nemu.h>
#include "file/bin_header.h"

DECLARE_BIN_HEADER(bin_header);

extern char _heap_start;
int main(const char *args);

Area heap = RANGE(&_heap_start, PMEM_END);
#ifndef MAINARGS
#define MAINARGS ""
#endif
static const char mainargs[] = MAINARGS;

void putch(char ch) {
  SERILAL_STATUE_CHECK();
  outb(SERIAL_PORT, ch);
}

void halt(int code) {
  nemu_trap(code);

  // should not reach here
  while (1);
}

void init_uart16550()
{
    // uint8_t val = inb(UART16550_REG_LCR);
    // outb(UART16550_REG_LCR, val|=bits(7));
    // // 115200 : 1c200，暂时随便填写的值
    // outb(UART16550_REG_DL1, 0x00);
    // outb(UART16550_REG_DL0, 0x01);
    // outb(UART16550_REG_LCR, val&=~bits(7));
}

void _trm_init() {
  init_uart16550();

  int ret = main(mainargs);
  halt(ret);
}
