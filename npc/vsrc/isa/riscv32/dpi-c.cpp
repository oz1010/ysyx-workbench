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
#include "device/vdev.h"
#include "perf_monitor.h"

#define DPI_MTRACE(fmt, ...) MTRACE_ADD("DPI-" fmt, ##__VA_ARGS__)
#if CONFIG_DTRACE
#define DPI_DTRACE(name, fmt, ...)                           \
    do                                                       \
    {                                                        \
        /* if (dtrace_limit_check(name, addr, len)) */       \
        DTRACE_LOG("<DT> DPI-%s " fmt, name, ##__VA_ARGS__); \
    } while (false)
#else
#define DPI_DTRACE(name, fmt, ...)
#endif
#if CONFIG_DIFFTEST
#define DIFFTEST_SKIP_REF() difftest_skip_ref()
#else
#define DIFFTEST_SKIP_REF()
#endif
#define ADDR_IN_RANGE(_addr, _baseaddr, _maxsize) \
    (((_addr) >= (_baseaddr)) && ((_addr) < ((_baseaddr) + (_maxsize))))
extern void set_npc_state(npc_state_t state, vaddr_t pc, int halt_ret);
hw_cpu_stat_t hw_cpu_stat;
uint32_t hw_flash_idx = 0;
hw_monitor_ctx_t hw_monitor_ctx;
extern FILE *perf_fp;
extern FILE *icbin_fp;
extern FILE *dcbin_fp;
static const char *event_strs[HW_MONITOR_ID_COUNT] = {
    "INVALID", "IFU", "IDU", "LSU", "EXU", "WBU",
};
static const char *code_strs[HW_MONITOR_CODE_COUNT] = {
    "LUI",    "AUIPC", "JAL",   "JALR",  "BEQ",    "BNE",    "BLT",    "BGE",   "BLTU",    "BGEU",
    "LB",     "LH",    "LW",    "LBU",   "LHU",    "SB",     "SH",     "SW",    "ADDI",    "SLTI",
    "SLTIU",  "XORI",  "ORI",   "ANDI",  "SLLI",   "SRLI",   "SRAI",   "ADD",   "SUB",     "SLL",
    "SLT",    "SLTU",  "XOR",   "SRL",   "SRA",    "OR",     "AND",    "FENCE", "FENCE_I", "ECALL",
    "EBREAK", "CSRRW", "CSRRS", "CSRRC", "CSRRWI", "CSRRSI", "CSRRCI", "MUL",   "MULH",    "MULHSU",
    "MULHU",  "DIV",   "DIVU",  "REM",   "REMU",   "MRET",
};

#define PSRAM_SIZE (4 * 1024 * 1024)
#define TEST_INIF_PSRAM_OFFSET 0x00300000
// #if defined(CONFIG_PMEM_MALLOC)
// extern uint8_t *raw_memory;
// uint8_t *raw_psram;
// #else
// extern uint8_t raw_memory[CONFIG_MSIZE];
// uint8_t raw_psram[PSRAM_SIZE];
// #endif
extern vdev_item_t vdev_items[NR_VDEV_ITEMS];

#define FLASH_SIZE (16 * 1024 * 1024)
#define TEST_INIF_FLASH_BASEADDR 0x30f00000

extern paddr_t get_vsimu_pc(void);
extern void set_vsimu_csr(paddr_t addr, uint32_t data);
extern uint32_t get_vsimu_csr(paddr_t addr);

void init_dpi()
{
    // #if defined(CONFIG_PMEM_MALLOC)
    //     raw_psram = (uint8_t *)malloc(PSRAM_SIZE);
    // #endif
    //     assert(raw_psram);
}

void exit_dpi()
{
    if (perf_fp)
    {
        fflush(perf_fp);
        fclose(perf_fp);
        perf_fp = NULL;
    }

    if (icbin_fp)
    {
        fflush(icbin_fp);
        fclose(icbin_fp);
        icbin_fp = NULL;
    }
}

void hw_storage_access(int write, int addr, uint32_t *data, int32_t len)
{
    if (write || len != 4)
    {
        raw_stdout("Hardware storage only support 4-bytes-read, addr:%#.8x len:%d\n", addr, len);
        exit_simu(3);
    }

    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("Hardware storage access is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    *data = vdev_read(vdev, addr, len);
}

void switch_flash_context(uint32_t flash_idx)
{
    vdev_item_t *vdev = NULL;
    hw_flash_idx = flash_idx;

    switch (hw_flash_idx)
    {
        case 1:
            for (size_t i = 0; i < 16; ++i)
            {
                paddr_write(TEST_INIF_FLASH_BASEADDR + i, 1, 0x30 + i);
            }
            break;

        case 2:
        {
            uint32_t flash_codes[] = {
                0x100007b7, 0x04100713, 0x00e78023, 0x00a00713,
                0x00e78023, 0x00000513, 0x00100073, 0x00008067,
            };
            for (size_t i = 0; i < ARRLEN(flash_codes); ++i)
            {
                paddr_write(TEST_INIF_FLASH_BASEADDR + sizeof(flash_codes[0]) * i,
                            sizeof(flash_codes[0]), flash_codes[i]);
            }
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
            for (size_t i = 0; i < 16; ++i)
            {
                paddr_write(TEST_INIF_PSRAM_OFFSET + i, 1, 0x30 + i);
            }
            break;

        default:
            break;
    }
}

void exit_simu(int code)
{
    set_npc_state(NPC_END, get_vsimu_pc(), code);
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

void dpi_cpu_stat_ctrl(int dtype, int delta)
{
    static uint64_t last_update_tick = 0;
    bool flush_file = false;

    if (delta == 0)
    {
        last_update_tick = 0;
        memset(&hw_cpu_stat, 0, sizeof(hw_cpu_stat_t));
        return;
    }

    if (hw_cpu_stat.counts[HW_CPU_STAT_TICK] - last_update_tick > 10000)
    {
        last_update_tick = hw_cpu_stat.counts[HW_CPU_STAT_TICK];
        flush_file = true;
    }

    switch (dtype)
    {
        case HW_CPU_STAT_TICK:
        case HW_CPU_STAT_ICACHE_HIT:
        case HW_CPU_STAT_ICACHE_MISS:
        case HW_CPU_STAT_DCACHE_HIT:
        case HW_CPU_STAT_DCACHE_MISS:
            hw_cpu_stat.counts[dtype] += delta;
            break;

        case HW_CPU_STAT_INST:
        {
#if CONFIG_ICACHE_BIN
            fwrite(&delta, 1, 4, icbin_fp);
            if (flush_file)
            {
                fflush(icbin_fp);
            }
#endif
            break;
        }

        case HW_CPU_STAT_DATA:
        {
#if CONFIG_DCACHE_BIN
            fwrite(&delta, 1, 4, dcbin_fp);
            if (flush_file)
            {
                fflush(dcbin_fp);
            }
#endif
            break;
        }

        default:
            raw_stdout("unknown type %d\n", dtype);
    }
}

int fetch_inst(int addr)
{
    vdev_item_t *vdev = find_vdev_item(addr);
    if (unlikely(vdev == NULL))
    {
        raw_stdout("fetch inst is out of range, addr:%#.8x\n", addr);
        exit_simu(2);
    }
    addr &= ~0x3u;  // 读写地址四字节对齐
    int inst = vdev_read(vdev, addr, 4);
    return inst;
}

void write_raw_mem(int addr, int len, int data)
{
    // raw_stdout("Mw write, addr:%#.8x len:%d data:%#.8x\n", addr, len, data);
    // addr &= ~0x3u;  // 读写地址四字节对齐
    vdev_item_t *vdev = find_vdev_item(addr);
    if (unlikely(vdev == NULL))
    {
        raw_stdout("Write mem is out of range, addr:%#.8x len:%d data:%#.8x\n", addr, len, data);
        exit_simu(2);
    }
    vdev_write(vdev, addr, len, data);
    DPI_MTRACE("W [%#.8x] <= %#.8x %d", addr, data, len);
}

int read_raw_mem(int addr, int len)
{
    // addr &= ~0x3u;  // 读写地址四字节对齐
    vdev_item_t *vdev = find_vdev_item(addr);
    if (unlikely(vdev == NULL))
    {
        raw_stdout("Read mem is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }
    int data = vdev_read(vdev, addr, len);
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
        (uint64_t)__x.n;         \
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
        raw_stdout(ANSI_FMT("%s:%d %s input len(%d) is error\n", ANSI_BG_RED), __FILE__, __LINE__,
                   __FUNCTION__, len);
        set_npc_state(NPC_ABORT, get_vsimu_pc(), -3);
    }

    return ret;
}

void write_raw_csr(int idx, int data)
{
    // printf("write csr %d %d\n", ri, data);
    // int ri = ri % CSR_COUNT;
    set_vsimu_csr(idx & 0xfff, data);
}

int read_raw_csr(int idx)
{
    int ret = get_vsimu_csr(idx & 0xfff);
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

void dpi_uart_write(int addr, int len, int data)
{
    char c = (char)data;
    if (addr != 0xa00003f8)
    {
        LOG_ERROR("uart write is out of range, addr:%#x len:%d", addr, len);
        exit_simu(2);
        return;
    }

    raw_stdout("%c", c);

    DPI_DTRACE("uart", "%#x %d write '%c'(%#x)", (uint32_t)addr, len, c, c);
    DIFFTEST_SKIP_REF();
}

void dpi_dev_skip(int write, int addr, int req_info, int data)
{
    const char *rw_str = write ? "write" : "read";
    int wstrb = (req_info >> 0) & 0xf;          // 单次burst数据有效掩码
    int awsize = 1 << ((req_info >> 4) & 0x7);  // 单次burst数据大小，2^n
    int arlen = (req_info >> 0) & 0xff;         // 读取数据总burst数量，2^n
    int arsize = 1 << ((req_info >> 4) & 0x7);  // 单个burst读取大小，2^n字节
    vdev_item_t *vdev = find_vdev_item(addr);
    if (vdev)
    {
        if (vdev->type == VDEV_EXTER)
        {
            DIFFTEST_SKIP_REF();
#if CONFIG_HAS_UART
            if (vdev->startaddr == CONFIG_UART_BASE_ADDR)
            {
                char c = (char)data;
                DPI_DTRACE(vdev->name, "%s %#x %#x '%c'(%#x)", rw_str, (uint32_t)addr, awsize, c,
                           c);
            }
            else
#endif
#if CONFIG_HAS_SPI_MASTER
                if (vdev->startaddr == CONFIG_SPI_MASTER_BASE_ADDR)
            {
                DPI_DTRACE(vdev->name, "%s %#x %#x %#x", rw_str, (uint32_t)addr, data, req_info);
            }
            else
#endif
            {
                if (write)
                {
                    DPI_DTRACE(vdev->name, "W [%#.8x] <= %#.8x %#x(%d %#x)", (uint32_t)addr, data,
                               req_info, awsize, wstrb);
                }
                else
                {
                    DPI_DTRACE(vdev->name, "R [%#.8x] => %#.8x %#x(%d %#x)", (uint32_t)addr, data,
                               req_info, arsize, arlen);
                }
            }
        }
        else if (vdev->type == VDEV_MEM)
        {
            if (write)
            {
                DPI_MTRACE("%s W [%#.8x] <= %#.8x %d %#x", vdev->name, addr, data, awsize, wstrb);
            }
            else
            {
                DPI_MTRACE("%s R [%#.8x] => %#.8x %d %#x", vdev->name, addr, data, arsize, arlen);
            }
            switch (vdev->startaddr)
            {
                case CONFIG_SRAM_BASE:
                    // 同步对内存的修改，避免调试反汇编异常
                    if (write)
                        vdev_write(vdev, addr, awsize, data);
                    break;

                case CONFIG_MROM_BASE:
                case CONFIG_FLASH_BASE:
                case CONFIG_PSRAM_BASE:
                case CONFIG_SDRAM_BASE:
                    break;

                default:
                    DPI_DTRACE("unknown-mem", "%s %#x %#x %#x", rw_str, (uint32_t)addr, data,
                               req_info);
                    break;
            }
        }
        else if (vdev->type == VDEV_INNER)
        {
            DIFFTEST_SKIP_REF();

            /** 
             * 内部设备不会走vdev机制，需要单独触发此流程
             * 单周期不能接入ysyxSOC外设
             */
            #if !CONFIG_ISA_RISCV_SINGLE
            if (vdev->handler)
            {
                vdev->handler(vdev, write, addr, write ? awsize : arsize, (uint32_t *)&data);
            }
            #endif
        }

        return;
    }
    else
    {
        DPI_DTRACE("unknown", "%s %#x %#x %#x", rw_str, (uint32_t)addr, data, req_info);
    }
}

int dpi_test_intf(int write, int addr, int len, int data)
{
    const char *rw_str = write ? "write" : "read";
    // if (write && addr>=0x0f002000 && addr<=0x0fffffff) {
    if (write && addr >= 0x0f002000 && addr <= 0x0f002000)
    {
        switch_flash_context(data);
        DPI_MTRACE("test_intf flash W [%#.8x] <= %#.8x %d", addr, data, len);
        DIFFTEST_SKIP_REF();
    }
    else if (write && addr >= 0x0f002004 && addr <= 0x0f002004)
    {
        switch_psram_context(data);
        DPI_MTRACE("test_intf psram W [%#.8x] <= %#.8x %d", addr, data, len);
        DIFFTEST_SKIP_REF();
    }
    else
    {
        LOG_ERROR("test_intf only support writing to 0x0f002000, addr:%#x len:%d data:%#x", addr,
                  len, data);
        exit_simu(2);
    }
    return 0;
}

int dpi_rtc_read(int addr, int len)
{
    static hw_time_info_t local_time_info = {0};
    static uint64_t local_execute_time = 0;
    static uint64_t last_tick = 0;
    static uint64_t update_ticks = 10240;
    int ret = 0;

    if ((addr == 0x02000048 || addr == 0x02000050) &&
        ((hw_cpu_stat.counts[HW_CPU_STAT_TICK] - last_tick) >= update_ticks))
    {
        last_tick += update_ticks;
#if CONFIG_CORE_FREQUENCY
        local_execute_time =
            hw_cpu_stat.counts[HW_CPU_STAT_TICK] / (CONFIG_CORE_FREQUENCY / 1000000);  // us
        get_hw_time_info_from_us(local_execute_time, &local_time_info);
#else
        local_execute_time = get_time();
        get_hw_time_info(&local_time_info);
#endif
    }

    switch (addr)
    {
        /* Get up time */
        case 0x02000048:
            ret = (int)local_execute_time;
            break;
        case 0x0200004c:
            ret = (int)(local_execute_time >> 32);
            break;

        /* Get linux date */
        case 0x02000050:
            ret = (int)local_time_info.time_raw_val;
            break;
        case 0x02000054:
            ret = (int)(local_time_info.time_raw_val >> 32);
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

void dpi_psram_write(int addr_idx, int len, int data)
{
    uint32_t addr = addr_idx + CONFIG_PSRAM_BASE;
    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("Write psram is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }
    if (len < 1 || len > 4)
    {
        raw_stdout("Write psram len is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    /* 0b0111数据写入，底层不支持这种方式。需要修改为4字节对齐方式 */
    if (len == 3)
    {
        uint32_t high_data = vdev_read(vdev, addr + 3, 1);
        data = (data & 0x00ffffff) | (high_data << 24);
        len = 4;
    }

    vdev_write(vdev, addr, len, data);
}

int dpi_psram_read(int addr_idx, int len)
{
    uint32_t addr = addr_idx + CONFIG_PSRAM_BASE;
    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("Read psram is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    int data = vdev_read(vdev, addr, 4);
    return data;
}

int dpi_check_dev_addr(int addr, int attr)
{
    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        show_vdev();
        raw_stdout("Request addr(%#.8x) is out of range.\n", addr);
        return 1;
    }

    uint32_t device_attrs[] = {
        VDEV_ATTR_READ,
        VDEV_ATTR_WRITE,
        VDEV_ATTR_EXEC,
    };
    for (int idx = 0; idx < ARRLEN(device_attrs); idx++)
    {
        uint32_t detect_attr = device_attrs[idx];
        if ((attr & detect_attr) == 0)
            continue;

        if ((vdev->attr & detect_attr) == 0)
        {
            raw_stdout("matched vdev info is below:\n");
            raw_stdout("    %-12s - [0x%08x 0x%08x) attr: %s%s%s type:%-8s\n", vdev->name,
                       vdev->startaddr, vdev->endaddr,
                       (vdev->attr & VDEV_ATTR_READ) != 0 ? "r" : "-",
                       (vdev->attr & VDEV_ATTR_WRITE) != 0 ? "w" : "-",
                       (vdev->attr & VDEV_ATTR_EXEC) != 0 ? "x" : "-", vdev_type_str(vdev->type));
            raw_stdout("Request attr(%#x) does not match dev attr(%#x) at addr(%#x).\n", attr,
                       vdev->attr, addr);
            return 2;
        }
    }

    return 0;
}

int dpi_vdev_read(int addr, int len)
{
    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("DPI vdev read is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    int data = vdev_read(vdev, addr, len);

    if (vdev->startaddr == CONFIG_SDRAM_BASE)
    {
        // raw_stdout("====== DPI read sdram addr %#x data %#x len %d\n", addr, data, len);
    }

    return data;
}

void dpi_vdev_write(int addr, int data, int len)
{
    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("DPI vdev write is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    /* 0b0111数据写入，底层不支持这种方式。需要修改为4字节对齐方式 */
    if (len == 3)
    {
        uint32_t high_data = vdev_read(vdev, addr + 3, 1);
        data = (data & 0x00ffffff) | (high_data << 24);
        len = 4;
    }

    if (vdev->startaddr == CONFIG_SDRAM_BASE)
    {
        // raw_stdout("====== DPI write sdram addr %#x data %#x len %d\n", addr, data, len);
    }

    vdev_write(vdev, addr, len, data);
}

void add_monitor_event(int id, int delta)
{
    if (id >= ARRLEN(hw_monitor_ctx.events))
    {
        raw_stdout("DPI monitor event id is out of range, id:%d\n", id);
        exit_simu(2);
        return;
    }

    hw_monitor_ctx.events[id].cnt += delta;
}

void add_monitor_code(int id, int delta)
{
    if (id >= ARRLEN(hw_monitor_ctx.codes))
    {
        raw_stdout("DPI monitor code id is out of range, id:%d\n", id);
        exit_simu(3);
        return;
    }

    hw_monitor_ctx.codes[id].cnt += delta;
}

void clear_monitor_log()
{
    if (perf_fp)
    {
        int fd = fileno(perf_fp);
        int ret = ftruncate(fd, 0);
        if (ret == -1)
        {
            raw_stdout("DPI monitor clear log failed, ret:%d\n", ret);
            exit_simu(3);
            return;
        }
        rewind(perf_fp);
    }
}

void add_monitor_log(int item_idx, int id)
{
    static uint64_t last_hw_tick = 0;
    static uint64_t last_update_tick = 0;

    uint64_t delta = hw_cpu_stat.counts[HW_CPU_STAT_TICK] - last_hw_tick;
    last_hw_tick = hw_cpu_stat.counts[HW_CPU_STAT_TICK];
    (void)delta;

#if CONFIG_PERF_MONITOR_BIN_DATA
    perf_monitor_data_t data;
    perf_monitor_header_t *header = NULL;
    size_t wsize = 0;

    switch (item_idx)
    {
        case PERF_MONITOR_TYPE_EVENT:
            header = &data.event.header;
            data.event.type = id;
            if (delta <= UINT8_MAX)
            {
                header->size = 0;
                data.event.delta0 = delta & 0xff;
            }
            else if (delta <= UINT16_MAX)
            {
                header->size = 1;
                data.event.delta1 = delta & 0xffff;
            }
            else
            {
                raw_stdout("DPI monitor delta is out of range, delta:%lu\n", delta);
                exit_simu(3);
                return;
            }
            wsize += sizeof(data.event.type);
            wsize += 1 << header->size;
            break;

        case PERF_MONITOR_TYPE_CODE:
            header = &data.code.header;
            data.code.inst = id & 0xff;
            wsize += sizeof(data.code.inst);
            break;

        case PERF_MONITOR_TYPE_ICACHE:
            header = &data.icache.header;
            data.icache.d.raw_val = id & 0xff;
            wsize += sizeof(data.icache.d);
            break;

        default:
            break;
    }

    header->type = item_idx;
    wsize += sizeof(perf_monitor_header_t);

    fwrite(header, 1, wsize, perf_fp);

    if (hw_cpu_stat.counts[HW_CPU_STAT_TICK] - last_update_tick > 10000)
    {
        last_update_tick = hw_cpu_stat.counts[HW_CPU_STAT_TICK];
        fflush(perf_fp);
    }
#else
    fprintf(perf_fp, "%lu|%d|%s%c", delta, item_idx,
            item_idx == 1 ? hw_monitor_ctx.events[id].name : hw_monitor_ctx.codes[id].name,
            (item_idx == 1 && id == (HW_MONITOR_ID_COUNT - 1)) ? '\n' : ' ');
    fflush(perf_fp);
#endif
}

void add_monitor_item(int item_type, int id, int delta)
{
#if CONFIG_PERF_MONITOR
    static bool init_monitor_en = true;
    static uint64_t last_icache_hit_count = 0;
    static uint64_t last_icache_miss_count = 0;

    if (item_type >= PERF_MONITOR_TYPE_COUNT || item_type < 0)
    {
        raw_stdout("Unknown item type:%d\n", item_type);
        exit_simu(3);
        return;
    }

    if (item_type == PERF_MONITOR_TYPE_INIT)
    {
        if (init_monitor_en)
        {
            init_monitor_en = false;
            memset(&hw_monitor_ctx, 0, sizeof(hw_monitor_ctx));
            for (int i = 0; i < ARRLEN(event_strs); ++i)
            {
                hw_monitor_ctx.events[i].name = event_strs[i];
            }
            for (int i = 0; i < ARRLEN(code_strs); ++i)
            {
                hw_monitor_ctx.codes[i].name = code_strs[i];
            }

            clear_monitor_log();
            last_icache_hit_count = 0;
            last_icache_miss_count = 0;
        }
    }
    else
    {
        init_monitor_en = true;
        add_monitor_log(item_type, id);
        if (item_type == PERF_MONITOR_TYPE_EVENT && id == 1)  // IFU
        {
            perf_monitor_data_t data;
            data.icache.d.mem_index = hw_cpu_stat.counts[HW_CPU_STAT_ICACHE_MEM_INDEX];
            data.icache.d.hit_count =
                hw_cpu_stat.counts[HW_CPU_STAT_ICACHE_HIT] - last_icache_hit_count;
            data.icache.d.miss_count =
                hw_cpu_stat.counts[HW_CPU_STAT_ICACHE_MISS] - last_icache_miss_count;
            last_icache_hit_count = hw_cpu_stat.counts[HW_CPU_STAT_ICACHE_HIT];
            last_icache_miss_count = hw_cpu_stat.counts[HW_CPU_STAT_ICACHE_MISS];
            add_monitor_log(PERF_MONITOR_TYPE_ICACHE, data.icache.d.raw_val);
        }
    }
#endif
}

void dpi_monitor_item(int item_type, int id, int delta)
{
    add_monitor_item(item_type, id, delta);
}

extern "C" void flash_read(int32_t addr_idx, int32_t *data)
{
    uint32_t addr = addr_idx + CONFIG_FLASH_BASE;
    vdev_item_t *vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("Read flash is out of range, addr:%#.8x len:%d\n", addr, 4);
        exit_simu(2);
    }
    *data = vdev_read(vdev, addr, 4);
}

extern "C" void mrom_read(int32_t addr_idx, int32_t *data)
{
    // assert(0);
    addr_idx &= ~0x3u;  // 读写地址四字节对齐
    uint32_t addr = addr_idx;
    vdev_item_t *vdev = find_vdev_item(addr);
    if (unlikely(vdev == NULL))
    {
        // FIXME 调用这个接口存在异常，只可能硬件初始化时被触发了（具体原因还需探索）
        return;
        raw_stdout("Read mrom is out of range, addr:%#.8x len:%d\n", addr, 4);
        exit_simu(2);
    }
    int inst = vdev_read(vdev, addr, 4);
    // DPI_MTRACE("R [%#.8x] => %#.8x %d", addr, inst, len);
    *data = inst;

    // *data = read_raw_mem(addr, 4);

    // 临时返回固定的ebreak
    // *data = 0x00100073;
}
