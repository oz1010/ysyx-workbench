#include <am.h>
#include <klib.h>
#include <klib-macros.h>
#include "peripheral/test_intf.h"

__attribute__((noinline))
void check(bool cond) {
  if (!cond) halt(1);
}

int main() {
    printf("using psram test case\n");
    return 0;
}
