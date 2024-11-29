#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
#include <stdint.h>
#include <memory>
#include <getopt.h>
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "Vtop.h"
#include "Vtop___024root.h"
#include "isa.h"
#include "dm/cpu_interface.h"
#include "dm/dm_define.h"
#include "dm/dtm.h"
#include "debug.h"
#include "memory/vaddr.h"
#include "memory/paddr.h"
#include "cpu/decode.h"
#include "common/point_pool.h"
#include "trace.h"
#include "cpu/difftest.h"

/* The assembly code of instructions executed is only output to the screen
 * when the number of instructions executed is less than this value.
 * This is useful when you use the `si' command.
 * You can modify this value as you want.
 */
#define MAX_INST_TO_PRINT 10

#if VM_TRACE_VCD
static void record_trace_vcd(VerilatedVcdC *tfp, VerilatedContext *contextp)
{
    tfp->dump(contextp->time());
}
#define RECORD_TRACE_VCD() record_trace_vcd(tfp.get(), contextp.get())
#else
#define RECORD_TRACE_VCD()
#endif

std::unique_ptr<VerilatedContext> contextp;
std::unique_ptr<TOP_NAME> top;
std::unique_ptr<VerilatedVcdC> tfp;

CPU_state cpu;
static bool g_print_step = false;

void isa_reg_display();

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

word_t *rv_get_gpr(CPU_state *c, size_t idx)
{
    assert(idx < ARRAY_SIZE(c->gpr) && "get gpr is out of range");
    return &c->gpr[idx];
}
int rv_access_mem(uint32_t write, uint32_t pc, uint32_t size, uint8_t *data)
{
    const uint32_t idx = pc - CONFIG_MBASE;

    if (idx <= CONFIG_MSIZE)
    {
        // 内存区域
        if (write)
        {
            vaddr_write(pc, size, *(uint32_t *)data);
        }
        else
        {
            word_t mem_val = vaddr_read(pc, size);
            memcpy(data, &mem_val, 4);
        }
    }
    else
    {
        LOG_ERROR("%s memory is out of range, pc:%#x idx:%#x size:%u check:%d CONFIG_MSIZE:%u",
                  write ? "write" : "read", pc, idx, size, (idx <= CONFIG_MSIZE), CONFIG_MSIZE);
        assert(0);
    }

    return 0;
}

static void trace_and_difftest(Decode *_this, vaddr_t dnpc)
{
#ifdef CONFIG_ITRACE_COND
    if (ITRACE_COND)
    {
        _log_raw("%s\n", _this->logbuf);
    }
#endif
#ifdef CONFIG_WATCHPOINT
    if (npc_ctx.state == NPC_RUNNING && scan_point(POINT_WATCH))
        npc_ctx.state = NPC_STOP;
#endif
#ifdef CONFIG_BREAKPOINT
    if (npc_ctx.state == NPC_RUNNING && scan_point(POINT_BREAK))
        npc_ctx.state = NPC_STOP;
#endif
    if (g_print_step)
    {
        IFDEF(CONFIG_ITRACE, puts(_this->logbuf));
    }
    IFDEF(CONFIG_DIFFTEST, difftest_step(_this->pc, dnpc));

    IRINGBUF_UPDATE(MUXDEF(CONFIG_ISA_x86, _this->snpc, _this->pc), _this->logbuf,
                    npc_ctx.state == NPC_RUNNING);
}

static void exec_once(Decode *s, vaddr_t _pc)
{
    word_t inst;

    // 更新cpu信息
    cpu.pc = top->rootp->top__DOT__pc;
    s->pc = top->rootp->top__DOT__pc;

#if CONFIG_DEBUG_MODULE
    // read instruction before debug
    inst = vaddr_ifetch(cpu.pc, 4);
    dtm_update(DM_EXEC_INST_BEFORE, inst, &cpu);
#endif

    // read instruction before execution
    inst = vaddr_ifetch(cpu.pc, 4);
    s->snpc = top->rootp->top__DOT__pc + 4;

    // 电路仿真
    s->inst = inst;
    top->inst = inst;
    top->clk = 1;
    top->contextp()->timeInc(1);
    top->eval();
    RECORD_TRACE_VCD();

    IFDEF(CONFIG_DEBUG_MODULE, dtm_update(DM_EXEC_INST_AFTER, inst, &cpu));

    top->clk = 0;
    top->contextp()->timeInc(1);
    top->eval();
    RECORD_TRACE_VCD();

    memcpy(&cpu.gpr[0], &top->rootp->top__DOT__x.m_storage[0], sizeof(cpu.gpr));
    s->dnpc = top->rootp->top__DOT__pc;
    cpu.pc = s->dnpc;
#ifdef CONFIG_ITRACE
    char *p = s->logbuf;
    p += snprintf(p, sizeof(s->logbuf), FMT_WORD ":", s->pc);
    int ilen = s->snpc - s->pc;
    int i;
    uint8_t *inst_byte = (uint8_t *)&(s->inst);
    for (i = ilen - 1; i >= 0; i--)
    {
        p += snprintf(p, 4, " %02x", inst_byte[i]);
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
                (uint8_t *)&(s->inst), ilen);
#else
    p[0] = '\0';  // the upstream llvm does not support loongarch32r
#endif
#endif
}

static void execute(uint64_t n)
{
    Decode s;
    for (; n > 0; --n)
    {
        exec_once(&s, cpu.pc);
        npc_ctx.nr_guest_inst++;
        trace_and_difftest(&s, cpu.pc);
        if (top->contextp()->gotFinish() || npc_ctx.state != NPC_RUNNING)
            break;
        // IFDEF(CONFIG_DEVICE, device_update());
    }
}

void assert_fail_msg()
{
    isa_reg_display();
    statistic();
    LOG_ERROR("assert failed, current pc:%#.8x", cpu.pc);
}

/* Simulate how the CPU works. */
void cpu_exec(uint64_t n)
{
    g_print_step = (n < MAX_INST_TO_PRINT);
    switch (npc_ctx.state)
    {
        case NPC_END:
        case NPC_ABORT:
            LOG_ERROR(
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
            IRINGBUF_SHOW();
            Log("nemu: %s at pc = " FMT_WORD,
                (npc_ctx.state == NPC_ABORT
                     ? ANSI_FMT("ABORT", ANSI_FG_RED)
                     : (npc_ctx.halt_ret == 0 ? ANSI_FMT("HIT GOOD TRAP", ANSI_FG_GREEN)
                                              : ANSI_FMT("HIT BAD TRAP", ANSI_FG_RED))),
                npc_ctx.halt_pc);
            // fall through
        case NPC_QUIT:
            statistic();
    }
}

void init_cpu(int argc, char *argv[])
{
    contextp = std::make_unique<VerilatedContext>();
    contextp->debug(0);                 // Set debug level, 0 is off, 9 is highest
    contextp->randReset(2);             // Randomization reset policy
    contextp->commandArgs(argc, argv);  // Pass arguments so Verilated code can see them

    top = std::make_unique<TOP_NAME>(contextp.get(), "top");

#if VM_TRACE_VCD
    Verilated::mkdir("build/logs");
    top->contextp()->traceEverOn(true);  // Verilator must compute traced signals
    tfp = std::make_unique<VerilatedVcdC>();
    top->trace(tfp.get(), 99);  // Trace 99 levels of hierarchy (or see below)
    tfp->open("build/logs/simu_top.vcd");
    LOG_INFO("Start trace ...\n");
#endif

    // 上电复位
    uint32_t clk = 0;
    top->rst = 1;
    for (int i = 0; i < 10; ++i)
    {
        clk = !clk;
        top->clk = clk;
        top->eval();
    }
    top->rst = 0;

    cpu.pc = top->rootp->top__DOT__pc;
}

const char *regs[] = {"$0", "ra", "sp", "gp", "tp",  "t0",  "t1", "t2", "s0", "s1", "a0",
                      "a1", "a2", "a3", "a4", "a5",  "a6",  "a7", "s2", "s3", "s4", "s5",
                      "s6", "s7", "s8", "s9", "s10", "s11", "t3", "t4", "t5", "t6"};

void isa_reg_display()
{
    int i;
    for (i = 0; i < sizeof(regs) / sizeof(regs[0]); ++i)
    {
        uint32_t reg_val = cpu.gpr[i];
        printf("%-16s0x%-14x%-16d\n", regs[i], reg_val, reg_val);
    }
}

const char *isa_reg_name(size_t idx)
{
    return regs[idx];
}

word_t isa_reg_str2val(const char *s, bool *success)
{
    int i;
    for (i = 0; i < sizeof(regs) / sizeof(regs[0]); ++i)
    {
        uint32_t reg_val = cpu.gpr[i];
        if (strcmp(regs[i], s) == 0)
        {
            *success = true;
            return reg_val;
        }
    }
    return 0;
}

vaddr_t *isa_get_cpu_pc(void)
{
    return &cpu.pc;
}
