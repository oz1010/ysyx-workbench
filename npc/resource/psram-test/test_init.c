#include <am.h>
#include <npc.h>
#include "klib.h"

int main(const char *args);
void init_uart16550();

#ifndef MAINARGS
#define MAINARGS ""
#endif
static const char mainargs[] = MAINARGS;

void _test_init() {
  init_uart16550();

  int ret = main(mainargs);
  halt(ret);
}
