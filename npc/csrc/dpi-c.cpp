#include <iostream>
#include "svdpi.h"
#include "Vtop__Dpi.h"
#include "debug.h"
#include "isa.h"

extern CPU_state *cur_cpu;

void exit_simu(int code)
{
    if (code == 0) {
        LOG_INFO("Normal exit simu with %d, pc:%#.8x", code, cur_cpu->pc);
    } else {
        LOG_ERROR("Normal exit simu with %d, pc:%#.8x", code, cur_cpu->pc);
    }
    exit(code);
}

void invalid_inst(int pc, int inst)
{
    LOG_INFO("Invalid inst:%#.8x pc:%#.8x", inst, pc);
    exit(-1);
}
