/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NEMU is licensed under Mulan PSL v2.
 * You can use this software according to the terms and conditions of the Mulan PSL v2.
 * You may obtain a copy of Mulan PSL v2 at:
 *          http://license.coscl.org.cn/MulanPSL2
 *
 * THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
 * EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
 * MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
 *
 * See the Mulan PSL v2 for more details.
 ***************************************************************************************/

#include <cpu/cpu.h>
#include <cpu/decode.h>
#include <cpu/difftest.h>
#include <locale.h>
#include "trace.h"
#include "common/point_pool.h"

/* The assembly code of instructions executed is only output to the screen
 * when the number of instructions executed is less than this value.
 * This is useful when you use the `si' command.
 * You can modify this value as you want.
 */
#define MAX_INST_TO_PRINT 10

CPU_state cpu = {};

void device_update();
extern bool scan_wp();
extern bool scan_bp();

void trace_and_difftest(Decode *_this, vaddr_t dnpc)
{
    bool print_cond = MUXDEF(CONFIG_ITRACE, ITRACE_COND, true);
#ifdef CONFIG_WATCHPOINT
    if (npc_ctx.state == NPC_RUNNING && scan_point(POINT_WATCH))
        npc_ctx.state = NPC_STOP;
#endif
#ifdef CONFIG_BREAKPOINT
    if (npc_ctx.state == NPC_RUNNING && scan_point(POINT_BREAK))
        npc_ctx.state = NPC_STOP;
#endif
#ifdef CONFIG_ITRACE_START
    print_cond &= (npc_ctx.nr_guest_inst >= (uint64_t)CONFIG_ITRACE_START);
#endif
#ifdef CONFIG_ITRACE_END
    print_cond &= (npc_ctx.nr_guest_inst <= (uint64_t)CONFIG_ITRACE_END);
#endif
    if (npc_ctx.print_step && print_cond)
    {
        IFDEF(CONFIG_ITRACE, raw_puts(_this->logbuf));
    }
    if (print_cond)
        ITRACE_FILE(_this->logbuf);

#ifdef CONFIG_ITRACE_END
    if (npc_ctx.nr_guest_inst == (uint64_t)CONFIG_ITRACE_END)
    {
        raw_out_fp(stdout, "<IT> end instruction trace\n");
        raw_out_fp(trace_fd, "<IT> end instruction trace\n");
    }
#endif
    IFDEF(CONFIG_DIFFTEST, difftest_step(_this->pc, dnpc));

    ITRACE_UPDATE(MUXDEF(CONFIG_ISA_x86, _this->snpc, _this->pc), _this->logbuf,
                  npc_ctx.state == NPC_RUNNING);
}

static void exec_once(Decode *s, vaddr_t pc)
{
    s->pc = pc;
    s->snpc = pc;
    isa_exec_once(s);
    cpu.pc = s->dnpc;
#ifdef CONFIG_ITRACE
    char *p = s->logbuf;
    p += snprintf(p, sizeof(s->logbuf), FMT_WORD ":", s->pc);
    int ilen = s->snpc - s->pc;
    int i;
    uint8_t *inst = (uint8_t *)&s->isa.inst.val;
    for (i = ilen - 1; i >= 0; i--)
    {
        p += snprintf(p, 4, " %02x", inst[i]);
    }
    int ilen_max = MUXDEF(CONFIG_ISA_x86, 8, 4);
    int space_len = ilen_max - ilen;
    if (space_len < 0)
        space_len = 0;
    space_len = space_len * 3 + 1;
    memset(p, ' ', space_len);
    p += space_len;

#ifndef CONFIG_ISA_loongarch32r
    void disassemble(char *str, int size, uint64_t pc, uint8_t *code, int nbyte);
    disassemble(p, s->logbuf + sizeof(s->logbuf) - p, MUXDEF(CONFIG_ISA_x86, s->snpc, s->pc),
                (uint8_t *)&s->isa.inst.val, ilen);
#else
    p[0] = '\0';  // the upstream llvm does not support loongarch32r
#endif
#endif
}

static void execute(uint64_t n)
{
    Decode s;
    for (; n > 0; n--)
    {
        exec_once(&s, cpu.pc);
        npc_ctx.nr_guest_inst++;
        trace_and_difftest(&s, cpu.pc);
        if (npc_ctx.state != NPC_RUNNING)
            break;
        IFDEF(CONFIG_DEVICE, device_update());
    }
}

static void statistic()
{
    IFNDEF(CONFIG_TARGET_AM, setlocale(LC_NUMERIC, ""));
#define NUMBERIC_FMT MUXDEF(CONFIG_TARGET_AM, "%", "%'") "lu"
    Log("host time spent = " NUMBERIC_FMT " us", npc_ctx.timer);
    Log("total guest instructions = " NUMBERIC_FMT, npc_ctx.nr_guest_inst);
    if (npc_ctx.timer > 0)
        Log("simulation frequency = " NUMBERIC_FMT " inst/s",
            npc_ctx.nr_guest_inst * 1000000 / npc_ctx.timer);
    else
        Log("Finish running in less than 1 us and can not calculate the simulation frequency");
}

void assert_fail_msg()
{
    isa_reg_display();
    statistic();
    raw_stdout("assert failed, current pc:%#.8x", cpu.pc);
}

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n)
{
    npc_ctx.print_step = (n < MAX_INST_TO_PRINT);
    switch (npc_ctx.state)
    {
        case NPC_END:
        case NPC_ABORT:
            raw_stdout(
                "Program execution has ended. To restart the program, exit NPC and run again.");
            return;

        default:
            npc_ctx.state = NPC_RUNNING;
    }

    uint64_t timer_start = get_time();

    execute(n);

    uint64_t timer_end = get_time();
    npc_ctx.timer += timer_end - timer_start;

    switch (npc_ctx.state)
    {
        case NPC_RUNNING:
            npc_ctx.state = NPC_STOP;
            break;

        case NPC_END:
        case NPC_ABORT:
            ITRACE_SHOW();
            Log("npc: %s at pc = " FMT_WORD " ret: %d",
                (npc_ctx.state == NPC_ABORT
                     ? ANSI_FMT("ABORT", ANSI_FG_RED)
                     : (npc_ctx.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN)
                                              : ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
                npc_ctx.halt_pc, npc_ctx.halt_ret);
            // fall through
        case NPC_QUIT:
            statistic();
        default:
            break;
    }
}
