#include <iostream>
#include "svdpi.h"
#include "Vtop__Dpi.h"
#include "debug.h"
#include "isa.h"

extern CPU_state *cur_cpu;
extern uint32_t inst_fetch(vaddr_t pc);

void exit_simu(int code)
{
    if (code == 0) {
        LOG_INFO("Normal exit simu with %d, pc:%#.8x", code, cur_cpu->pc);
    } else {
        LOG_ERROR("Error exit simu with %d, pc:%#.8x", code, cur_cpu->pc);
    }
    exit(code);
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
    exit(-1);
}
