#include <am.h>
#include <riscv/riscv.h>
#include <klib.h>

static Context* (*user_handler)(Event, Context*) = NULL;

Context* __am_irq_handle(Context *c) {
  if (user_handler) {
    Event ev = {0};
    uint32_t exception = c->mcause & 0x7fffffff;
    uint32_t event = EVENT_NULL;

    // GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0)
    if (exception==11) event = c->GPR1;

    switch (event) {
      case EVENT_YIELD: 
        ev.event = event;
        ev.msg = "yield";
        c->mepc += 4; // mepc保存的是当前地址，需要再一次加4才能继续运行。ref. https://ysyx.oscc.cc/docs/ics-pa/3.2.html#%E6%81%A2%E5%A4%8D%E4%B8%8A%E4%B8%8B%E6%96%87
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
   * GPR1 is event when mcause is Environment call from M-mode (0<<31 | 11<<0)
   *   n=1 -- yield
  */
  uint32_t event = EVENT_YIELD;
#ifdef __riscv_e
  asm volatile("mv a5, %0; ecall" : : "r"(event) : "a5");
#else
  asm volatile("mv a7, %0; ecall" : : "r"(event) : "a7");
#endif
}

bool ienabled() {
  return false;
}

void iset(bool enable) {
}
