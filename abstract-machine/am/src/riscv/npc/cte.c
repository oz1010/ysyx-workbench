#include <am.h>
#include <riscv/riscv.h>
#include <klib.h>

static Context* (*user_handler)(Event, Context*) = NULL;

Context* __am_irq_handle(Context *c) {
  if (user_handler) {
    Event ev = {0};
    uint32_t code = (c->mcause & 0x7fffffff)-16;
    switch (code) {
      case EVENT_YIELD: 
        ev.event = code;
        ev.msg = "yield";
        break;

      default: ev.event = EVENT_ERROR; break;
    }

    c = user_handler(ev, c);
    assert(c != NULL);
  }

  return c;
}

extern void __am_asm_trap(void);

bool cte_init(Context*(*handler)(Event, Context*)) {
  // initialize exception entry
  asm volatile("csrw mtvec, %0" : : "r"(__am_asm_trap));

  // register event handler
  user_handler = handler;

  return true;
}

Context *kcontext(Area kstack, void (*entry)(void *), void *arg) {
  return NULL;
}

void yield() {
  /**
   * ref. riscv-privileged-20211203-The RISC-V Instruction Set Manual Volume II - Privileged Architecture.pdf
   *   Table 3.6: Machine cause register (mcause) values after trap.
   *   1 ≥16 Designated for platform use
   * 1<<31 | (16+n)<<0
   *   n=1 -- yield
  */
  uint32_t yield_code = 1<<31 | (16+1)<<0;
#ifdef __riscv_e
  asm volatile("mv a5, %0; ecall" : : "r"(yield_code) : "a5");
#else
  asm volatile("mv a7, %0; ecall" : : "r"(yield_code) : "a7");
#endif
}

bool ienabled() {
  return false;
}

void iset(bool enable) {
}
