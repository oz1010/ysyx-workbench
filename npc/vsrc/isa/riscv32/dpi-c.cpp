#include <iostream>
#include "svdpi.h"
#include "Vtop__Dpi.h"
#include "debug.h"
#include "isa.h"
#include "memory/paddr.h"
#include "memory/vaddr.h"
#include "generated/autoconf.h"
#include "common/mtrace.h"

extern void set_npc_state(npc_state_t state, vaddr_t pc, int halt_ret);

void exit_simu(int code)
{
    set_npc_state(NPC_END, cpu.pc, code);
}

void invalid_inst(int thispc, int inst)
{
    uint32_t temp[2];
    vaddr_t pc = thispc;
    temp[0] = vaddr_ifetch(pc, 4);
    temp[1] = vaddr_ifetch(pc + 4, 4);

    uint8_t *p = (uint8_t *)temp;
    _log_raw("invalid opcode(PC = " FMT_WORD
             "):\n"
             "\t%02x %02x %02x %02x %02x %02x %02x %02x ...\n"
             "\t%08x %08x...\n",
             thispc, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], temp[0], temp[1]);

    _log_raw(
        "There are two cases which will trigger this unexpected exception:\n"
        "1. The instruction at PC = " FMT_WORD
        " is not implemented.\n"
        "2. Something is implemented incorrectly.\n",
        thispc);
    _log_raw("Find this PC(" FMT_WORD
             ") in the disassembling result to distinguish which case it is.\n\n",
             thispc);
    _log_raw(ANSI_FMT("If it is the first case, see\n%s\nfor more details.\n\n"
                      "If it is the second case, remember:\n"
                      "* The machine is always right!\n"
                      "* Every line of untested code is always wrong!\n\n",
                      ANSI_FG_RED),
             isa_logo);
    set_npc_state(NPC_ABORT, thispc, -1);
}

int fetch_inst(int addr)
{
    addr &= ~0x3u;  // 读写地址四字节对齐
    int inst = paddr_read(addr, 4);
    return inst;
}

void write_raw_mem(int addr, int len, int data)
{
    // _log_raw("Mw write, addr:%#.8x len:%d data:%#.8x\n", addr, len, data);
    // addr &= ~0x3u;  // 读写地址四字节对齐
    paddr_write(addr, len, data);
    IFDEF(CONFIG_MTRACE, add_mtrace(mtrace_opt_write, 0, addr, data));
}

int read_raw_mem(int addr, int len)
{
    // addr &= ~0x3u;  // 读写地址四字节对齐
    int data = paddr_read(addr, len);
    // _log_raw("Mr read, addr:%#.8x len:%d data:%#.8x\n", addr, len, data);
    IFDEF(CONFIG_MTRACE, add_mtrace(mtrace_opt_read, 0, addr, data));
    return data;
}

int get_reset_pc()
{
    return CONFIG_MBASE;
}

#define _SEXT(val, bit_len)      \
    ({                           \
        struct                   \
        {                        \
            int64_t n : bit_len; \
        } __x = {.n = val};      \
        (uint64_t) __x.n;        \
    })
int sext(int x, int len)
{
    int ret = 0;

    if (len == 8)
        ret = _SEXT(x, 8);
    else if (len == 16)
        ret = _SEXT(x, 16);
    else if (len == 32)
        ret = _SEXT(x, 32);
    else
    {
        _log_raw(ANSI_FMT("%s:%d %s input len(%d) is error\n", ANSI_FG_RED), __FILE__, __LINE__,
                 __FUNCTION__, len);
        set_npc_state(NPC_ABORT, cpu.pc, -3);
    }

    return ret;
}
