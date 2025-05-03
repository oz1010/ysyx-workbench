#include <iostream>
#include "svdpi.h"
#include "top_define.h"
#include "debug.h"
#include "isa.h"
#include "memory/paddr.h"
#include "memory/vaddr.h"
#include "generated/autoconf.h"
#include "common/mtrace.h"
#include "cpu/cpu.h"
#include "trace.h"
#include "device/mmio.h"
#include "cpu/difftest.h"
#include "utils.h"

#define DPI_MTRACE(fmt, ...) MTRACE_ADD("DPI-" fmt, ##__VA_ARGS__)
#if CONFIG_DTRACE
#define DPI_DTRACE(name, fmt, ...)                                  \
do                                                              \
{                                                               \
    if (dtrace_limit_check(name, addr, len))                    \
    DTRACE_LOG("<DT> DPI-%s " fmt, name, ##__VA_ARGS__);    \
} while (false)
#else
#define DPI_DTRACE(name, fmt, ...)
#endif
#if CONFIG_DIFFTEST
#define DIFFTEST_SKIP_REF() difftest_skip_ref()
#else
#define DIFFTEST_SKIP_REF()
#endif
extern void set_npc_state(npc_state_t state, vaddr_t pc, int halt_ret);
static uint64_t hw_tick = 0;
static uint32_t hw_flash_idx = 0;

#define PSRAM_SIZE                          (4*1024*1024)
#if   defined(CONFIG_PMEM_MALLOC)
extern uint8_t *raw_memory;
uint8_t *raw_psram;
#else
extern uint8_t raw_memory[CONFIG_MSIZE];
uint8_t raw_psram[PSRAM_SIZE];
#endif

#define FLASH_SIZE                          (16*1024*1024)
#define TEST_INIF_FLASH_BASEADDR            0x30f00000

void init_dpi()
{
#if   defined(CONFIG_PMEM_MALLOC)
    raw_psram = (uint8_t *)malloc(PSRAM_SIZE);
#endif
    assert(raw_psram);
}

void switch_flash_context(uint32_t flash_idx)
{
    hw_flash_idx = flash_idx;
    switch (hw_flash_idx)
    {
    case 1:
        for(size_t i=0; i<16; ++i) {
            raw_memory[TEST_INIF_FLASH_BASEADDR+i] = 0x30 + i;
        }
        break;
    
    case 2: {
        uint32_t *flash32 = (uint32_t *)&raw_memory[TEST_INIF_FLASH_BASEADDR];
        uint32_t i=0;
        flash32[i++] = 0x100007b7;
        flash32[i++] = 0x04100713;
        flash32[i++] = 0x00e78023;
        flash32[i++] = 0x00a00713;
        flash32[i++] = 0x00e78023;
        flash32[i++] = 0x00000513;
        flash32[i++] = 0x00100073;
        flash32[i++] = 0x00008067;
        break;
    }

    default:
        break;
    }
}

void switch_psram_context(uint32_t psram_idx)
{
    switch (psram_idx)
    {
    case 1:
        for(size_t i=0; i<16; ++i) {
            raw_psram[i] = 0x30 + i;
        }
        break;

    default:
        break;
    }
}

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
    raw_stdout("invalid opcode(PC = " FMT_WORD
             "):\n"
             "\t%02x %02x %02x %02x %02x %02x %02x %02x ...\n"
             "\t%08x %08x...\n",
             thispc, p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7], temp[0], temp[1]);

    raw_stdout(
        "There are two cases which will trigger this unexpected exception:\n"
        "1. The instruction at PC = " FMT_WORD
        " is not implemented.\n"
        "2. Something is implemented incorrectly.\n",
        thispc);
    raw_stdout("Find this PC(" FMT_WORD
             ") in the disassembling result to distinguish which case it is.\n\n",
             thispc);
    raw_stdout(ANSI_FMT("If it is the first case, see\n%s\nfor more details.\n\n"
                      "If it is the second case, remember:\n"
                      "* The machine is always right!\n"
                      "* Every line of untested code is always wrong!\n\n",
                      ANSI_FG_RED),
             isa_logo);
    set_npc_state(NPC_ABORT, thispc, -1);
}

void dpi_execute_time_ctrl(int delta)
{
    if (delta == 0) {
        hw_tick = 0;
    } else {
        hw_tick += delta;
    }
}

int fetch_inst(int addr)
{
    if (unlikely(!in_pmem(addr))) {
        raw_stdout("fetch inst is out of range, addr:%#.8x\n", addr);
        exit_simu(2);
    }
    addr &= ~0x3u;  // 读写地址四字节对齐
    int inst = paddr_read(addr, 4);
    return inst;
}

void write_raw_mem(int addr, int len, int data)
{
    // raw_stdout("Mw write, addr:%#.8x len:%d data:%#.8x\n", addr, len, data);
    // addr &= ~0x3u;  // 读写地址四字节对齐
    if (unlikely(!in_pmem(addr))) {
        raw_stdout("Write mem is out of range, addr:%#.8x len:%d data:%#.8x\n", addr, len, data);
        exit_simu(2);
    }
    paddr_write(addr, len, data);
    DPI_MTRACE("W [%#.8x] <= %#.8x %d", addr, data, len);
}

int read_raw_mem(int addr, int len)
{
    // addr &= ~0x3u;  // 读写地址四字节对齐
    if (unlikely(!in_pmem(addr))) {
        raw_stdout("Read mem is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }
    int data = paddr_read(addr, len);
    DPI_MTRACE("R [%#.8x] => %#.8x %d", addr, data, len);
    return data;
}

int get_reset_pc()
{
    extern vaddr_t reset_pc;
    // return CONFIG_MBASE;
    return reset_pc;
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
        raw_stdout(ANSI_FMT("%s:%d %s input len(%d) is error\n", ANSI_FG_RED), __FILE__, __LINE__,
                 __FUNCTION__, len);
        set_npc_state(NPC_ABORT, cpu.pc, -3);
    }

    return ret;
}

void write_raw_csr(int idx, int data)
{
    int ri = (idx < 0) ? CSR_COUNT + idx : idx;
    if (ri >= CSR_COUNT || ri < 0) {
        LOG_ERROR("write csr is out of range, idx:%d ri:%d data:%x", idx, ri, data);
        exit_simu(2);
    }
    // printf("write csr %d %d\n", ri, data);
    // int ri = ri % CSR_COUNT;
    cpu.csr[ri] = data;
}

int read_raw_csr(int idx)
{
    int ri = (idx < 0) ? CSR_COUNT + idx : idx;
    if (ri >= CSR_COUNT || ri < 0) {
        LOG_ERROR("read csr is out of range, idx:%d ri:%d", idx, ri);
        exit_simu(2);
    }
    
    int ret = cpu.csr[ri];
    // printf("read csr %d %d\n", ri, ret);
    return ret;
}

int dpi_raise_intr(int NO, int epc)
{
    return RAISE_INTR(NO, epc);
}

int dpi_query_intr()
{
    return QUERY_INTR();
}

void dpi_uart_write(int addr, int len, int data){
    char c = (char)data;
    if (addr != 0xa00003f8) {
        LOG_ERROR("uart write is out of range, addr:%#x len:%d", addr, len);
        exit_simu(2);
        return;
    }

    raw_stdout("%c", c);

    DPI_DTRACE("uart", "%#x %d write '%c'(%#x)", (uint32_t)addr, len, c, c);
    DIFFTEST_SKIP_REF();
}

void dpi_dev_skip(int write, int addr, int len, int data)
{
#if CONFIG_DTRACE
    const char *rw_str = write ? "write" : "read";
    // uart 0x1000_0000~0x1000_0fff
    if (addr>=0x0f000000 && addr<=0x0f001fff) {
        if (write) {
            int w_strb = (len>>0)&0xf; // 单次burst数据有效掩码
            int aw_size = 1<<((len>>4)&0x7); // 单次burst数据大小，2^n
            // 同步对内存的修改，避免调试反汇编异常
            switch (aw_size)
            {
                case 1: raw_memory[addr] = data&0xff; break;
                case 2: (*(uint16_t *)&raw_memory[addr]) = data&0xffff; break;
                case 4: (*(uint32_t *)&raw_memory[addr]) = data; break;
                default: break;
            }
                
            // int w_data = 0;
            // int start_bit = 0;
            // for (int i=0; i<4; ++i) {
            //     if (w_strb&(0x1<<i)) {
            //         start_bit = i;
            //         break;
            //     }
            // }
            // w_data = data >> (start_bit*8);
            DPI_DTRACE("sram", "W [%#.8x] <= %#.8x %d", (uint32_t)addr, data, aw_size);
        }
        else {
            int ar_len = (len>>0)&0xff; // 读取数据总burst数量，2^n
            int ar_size = 1<<((len>>4)&0x7); // 单个burst读取大小，2^n字节
            DPI_DTRACE("sram", "R [%#.8x] => %#.8x %d", (uint32_t)addr, data, ar_size);
        }
    } else if (addr>=0x10000000 && addr<=0x10000fff) {
        int aw_size = 1<<((len>>4)&0x7); // 单次burst数据大小，2^n
        char c = (char)data;
        DPI_DTRACE("uart", "%s %#x %#x '%c'(%#x)", rw_str, (uint32_t)addr, aw_size, c, c);
        DIFFTEST_SKIP_REF();
    } else if (addr>=0x10001000 && addr<=0x10001fff) {
        DPI_DTRACE("spi_master", "%s %#x %#x %#x", rw_str, (uint32_t)addr, data, len);
        DIFFTEST_SKIP_REF();
    } else if (addr>=0x20000000 && addr<=0x20000fff) {
        DPI_DTRACE("mrom", "%s %#x %#x %#x", rw_str, (uint32_t)addr, data, len);
        DIFFTEST_SKIP_REF();
    } else if (addr>=0x30000000 && addr<=0x30ffffff) {
        DPI_DTRACE("flash", "%s %#x %#x %#x", rw_str, (uint32_t)addr, data, len);
        DIFFTEST_SKIP_REF();
    } else {
        DPI_DTRACE("unknown", "%s %#x %#x %#x", rw_str, (uint32_t)addr, data, len);
    }
#endif
}

int dpi_test_intf(int write, int addr, int len, int data)
{
    const char *rw_str = write ? "write" : "read";
    // if (write && addr>=0x0f002000 && addr<=0x0fffffff) {
    if (write && addr>=0x0f002000 && addr<=0x0f002000) {
        switch_flash_context(data);
        DPI_MTRACE("test_intf flash W [%#.8x] <= %#.8x %d", addr, data, len);
        DIFFTEST_SKIP_REF();
    } else if (write && addr>=0x0f002004 && addr<=0x0f002004) {
        switch_psram_context(data);
        DPI_MTRACE("test_intf psram W [%#.8x] <= %#.8x %d", addr, data, len);
        DIFFTEST_SKIP_REF();
    } else {
        LOG_ERROR("test_intf only support writing to 0x0f002000, addr:%#x len:%d data:%#x", addr, len, data);
        exit_simu(2);
    }
    return 0;
}

int dpi_rtc_read(int addr, int len)
{
    static hw_time_info_t local_time_info = {0};
    static uint64_t local_execute_time = 0;
    static uint64_t last_tick = 0;
    int ret = 0;

    switch ((uint32_t)addr) {
        /* Get up time */
        case 0xa0000048:
            if ((hw_tick - last_tick) > 10000) {
                last_tick = hw_tick;
                local_execute_time = get_time();
            }
            ret = (int)local_execute_time;
            break;
        case 0xa000004c:
            ret = (int)(local_execute_time>>32);
            break;

        /* Get linux date */
        case 0xa0000050:
            get_hw_time_info(&local_time_info);
            ret = (int)local_time_info.time_raw_val;
            break;
        case 0xa0000054:
            ret = (int)(local_time_info.time_raw_val>>32);
            break;

        default:
            LOG_ERROR("rtc read is out of range, addr:%#x len:%d", addr, len);
            exit_simu(2);
            break;
    }

    DPI_DTRACE("rtc", "%#x %d read %#x", addr, len, ret);
    DIFFTEST_SKIP_REF();

    return ret;
}

void dpi_psram_write(int addr, int len, int data)
{
    if (!(addr>=0 && addr<PSRAM_SIZE)) {
        raw_stdout("Write psram is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }
    
    (*(int32_t *)(&raw_psram[addr])) = data;
}

int dpi_psram_read(int addr, int len)
{
    if (!(addr>=0 && addr<PSRAM_SIZE)) {
        raw_stdout("Read psram is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    int data = (*(int32_t *)(&raw_psram[addr]));
    return data;
}

extern "C" void flash_read(int32_t addr, int32_t *data)
{
    // assert(0);
    // if (!(addr>=0x30000000 && addr<=0x30ffffff)) {
    if (!(addr>=0 && addr<FLASH_SIZE)) {
        raw_stdout("Read flash is out of range, addr:%#.8x len:%d\n", addr, 4);
        exit_simu(2);
    }

    // SPI需要支持非对齐访问
    // if (addr&0x3u) {
    //     raw_stdout("Read flash dont support unalign-read, addr:%#.8x\n", addr);
    //     exit_simu(2);
    // }

    *data = (*(int32_t *)(&raw_memory[0x30000000+addr]));
}

extern "C" void mrom_read(int32_t addr, int32_t *data)
{
    // assert(0);
    addr &= ~0x3u;  // 读写地址四字节对齐
    if (unlikely(!in_pmem(addr))) {
        raw_stdout("Read mem is out of range, addr:%#.8x len:%d\n", addr, 4);
        exit_simu(2);
    }
    int inst = paddr_read(addr, 4);
    // DPI_MTRACE("R [%#.8x] => %#.8x %d", addr, inst, len);
    *data = inst;

    // *data = read_raw_mem(addr, 4);

    // 临时返回固定的ebreak
    // *data = 0x00100073;
}
