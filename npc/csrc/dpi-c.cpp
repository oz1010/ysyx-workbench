#include <iostream>
#include "svdpi.h"
#include "Vtop__Dpi.h"
#include "debug.h"
#include "isa.h"
#include "cpu/cpu-exec.h"
#include "memory/paddr.h"

npc_context_t npc_ctx = { .state = NPC_STOP, };

void set_npc_state(npc_state_t state, vaddr_t pc, int halt_ret) {
    // difftest_skip_ref();
  npc_ctx.state = state;
  npc_ctx.halt_pc = pc;
  npc_ctx.halt_ret = halt_ret;
}

void exit_simu(int code)
{
    set_npc_state(NPC_END, cpu.pc, code);
}

void invalid_inst(int thispc, int inst)
{
    uint32_t temp[2];
    vaddr_t pc = thispc;
    temp[0] = inst_fetch(pc);
    temp[1] = inst_fetch(pc+4);

    uint8_t *p = (uint8_t *)temp;
    _log_raw("invalid opcode(PC = " FMT_WORD "):\n"
        "\t%02x %02x %02x %02x %02x %02x %02x %02x ...\n"
        "\t%08x %08x...\n",
        thispc, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], temp[0], temp[1]);

    _log_raw("There are two cases which will trigger this unexpected exception:\n"
        "1. The instruction at PC = " FMT_WORD " is not implemented.\n"
        "2. Something is implemented incorrectly.\n", thispc);
    _log_raw("Find this PC(" FMT_WORD ") in the disassembling result to distinguish which case it is.\n\n", thispc);
    _log_raw(ANSI_FMT("If it is the first case, see\n%s\nfor more details.\n\n"
        "If it is the second case, remember:\n"
        "* The machine is always right!\n"
        "* Every line of untested code is always wrong!\n\n", ANSI_FG_RED), isa_logo);
    set_npc_state(NPC_ABORT, thispc, -1);
}
