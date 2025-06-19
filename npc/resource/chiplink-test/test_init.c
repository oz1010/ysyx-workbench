#include <am.h>
#include <npc.h>
#include "klib.h"

int main(const char *args);
void init_uart16550();
void print_machine_info();

#ifndef MAINARGS
#define MAINARGS ""
#endif
static const char mainargs[] = MAINARGS;

void _test_init() {
  init_uart16550();
  // print_machine_info();

  int ret = main(mainargs);
  halt(ret);
}
