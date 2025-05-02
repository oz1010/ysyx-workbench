#include <am.h>
#include <npc.h>
#include "file/bin_header.h"
#include "klib.h"

DECLARE_BIN_HEADER(bin_header);

extern char _heap_start;
int main(const char *args);

extern char _pmem_start;
#define PMEM_SIZE (128 * 1024 * 1024)
#define PMEM_END  ((uintptr_t)&_pmem_start + PMEM_SIZE)

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
  npc_trap(code);

  // should not reach here
  while (1);
}

void init_uart16550()
{
    uint8_t val = inb(UART16550_REG_LCR);
    outb(UART16550_REG_LCR, val|=bits(7));
    // 115200 : 1c200，暂时随便填写的值
    outb(UART16550_REG_DL1, 0x00);
    outb(UART16550_REG_DL0, 0x01);
    outb(UART16550_REG_LCR, val&=~bits(7));
}

void print_machine_info()
{
    union
    {
        uint32_t id;
        uint8_t str[8];
    } vendor_info;
    uint32_t mvendorid, marchid;
    asm volatile("csrr %0, mvendorid" : "=r"(mvendorid));
    asm volatile("csrr %0, marchid" : "=r"(marchid));
    memset(&vendor_info, 0, sizeof(vendor_info));
    vendor_info.id=mvendorid;
    printf("Machine info: %s_%d\n", vendor_info.str, marchid);
}

void _trm_init() {
  init_uart16550();
  print_machine_info();

  int ret = main(mainargs);
  halt(ret);
}
