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
#include "common/list.h"

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
extern FILE* perf_fp;
extern FILE* icbin_fp;
extern FILE* dcbin_fp;
static const char* event_strs[HW_MONITOR_ID_COUNT] = {
    "INVALID", "IFU", "IDU", "LSU", "EXU", "WBU",
};
static const char* code_strs[HW_MONITOR_CODE_COUNT] = {
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
extern char g_image_file_path[1024];

#define FLASH_SIZE (16 * 1024 * 1024)
#define TEST_INIF_FLASH_BASEADDR 0x30f00000

extern paddr_t get_vsimu_pc(void);
extern void set_vsimu_csr(paddr_t addr, uint32_t data);
extern uint32_t get_vsimu_csr(paddr_t addr);
extern uint32_t get_csr_index(paddr_t addr);

void init_hw_monitor_record();
void deinit_hw_monitor_record();
void write_record_to_file(hw_monitor_rc_raw_data_t* r);

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
        // 关闭文件前强行将描述信息（含max_tick）回写到文件头部
        rewind(perf_fp);
        fwrite(&hw_monitor_ctx.bin_descript, 1, sizeof(rc_bin_descript_t), perf_fp);
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

    deinit_hw_monitor_record();
}

void hw_storage_access(int write, int addr, uint32_t* data, int32_t len)
{
    if (write || len != 4)
    {
        raw_stdout("Hardware storage only support 4-bytes-read, addr:%#.8x len:%d\n", addr, len);
        exit_simu(3);
    }

    vdev_item_t* vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("Hardware storage access is out of range, addr:%#.8x len:%d\n", addr, len);
        exit_simu(2);
    }

    *data = vdev_read(vdev, addr, len);
}

void switch_flash_context(uint32_t flash_idx)
{
    vdev_item_t* vdev = NULL;
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

    uint8_t* p = (uint8_t*)temp;
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
    set_npc_state(NPC_ABORT, thispc, inst ? inst : -1);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    const char* rw_str = write ? "write" : "read";
    int wstrb = (req_info >> 0) & 0xf;          // 单次burst数据有效掩码
    int awsize = 1 << ((req_info >> 4) & 0x7);  // 单次burst数据大小，2^n
    int arlen = (req_info >> 0) & 0xff;         // 读取数据总burst数量，2^n
    int arsize = 1 << ((req_info >> 4) & 0x7);  // 单个burst读取大小，2^n字节
    vdev_item_t* vdev = find_vdev_item(addr);
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
                vdev->handler(vdev, write, addr, write ? awsize : arsize, (uint32_t*)&data);
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
    const char* rw_str = write ? "write" : "read";
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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
    vdev_item_t* vdev = find_vdev_item(addr);
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

void init_hw_monitor_record()
{
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

    hw_monitor_ctx.record_head.next = &hw_monitor_ctx.record_head;
    hw_monitor_ctx.record_head.prev = &hw_monitor_ctx.record_head;
    int count = 0;
    for (size_t i = 0; i < (STAGE_COUNT * 2); ++i)
    {
        hw_monitor_rc_raw_data_t* r = (hw_monitor_rc_raw_data_t*)malloc(sizeof(hw_monitor_rc_raw_data_t));
        assert(r);
        memset(r, 0, sizeof(hw_monitor_rc_raw_data_t));
        r->icache_mem_index = UINT32_MAX;  // 存储索引默认全1：无存储数据时解析显示为none
        r->dcache_mem_index = UINT32_MAX;
        list_add_tail(&r->node, &hw_monitor_ctx.record_head);
    }

    /**
     * 写入文件描述数据（v2.0.0）
     *   描述结构后紧跟行式字符串数据，每行格式为'KEY\0VALUE0\0...VALUEn\0\n'，
     *   一行内KEY后跟多个\0结尾的VALUE（列表形式），用\n标识一行结束：
     *     'IMG\0<image_path>\0\n'         仿真镜像绝对路径
     *     'STORAGE\0<name>\0...\0\n'     存储体名称列表，顺序固定（与vdev存储体注册顺序一致），
     *                                    Storage Index的低bit位指令存储索引即为该列表的索引
     *   record_offset记录字符串数据之后记录数据的文件偏移
     */
    rc_bin_descript_t *desc = &hw_monitor_ctx.bin_descript;
    desc->magic = RC_BIN_DESCRIPT_MAGIC;
    desc->version = RC_BIN_DESCRIPT_VERSION;
    IFDEF(CONFIG_ICACHE, desc->config.icache_enable = 1);
    IFDEF(CONFIG_DCACHE, desc->config.dcache_enable = 1);

    static const char img_key[] = "IMG";
    static const char storage_key[] = "STORAGE";
    const char *storage_names[NR_VDEV_ITEMS];
    int storage_cnt = 0;
    for (int i = 0; i < NR_VDEV_ITEMS; ++i)
    {
        if (vdev_items[i].name && vdev_items[i].type == VDEV_MEM)
        {
            storage_names[storage_cnt++] = vdev_items[i].name;
        }
    }

    uint64_t record_offset = sizeof(rc_bin_descript_t);
    record_offset += sizeof(img_key) + strlen(g_image_file_path) + 1 + 1;
    record_offset += sizeof(storage_key);
    for (int i = 0; i < storage_cnt; ++i)
    {
        record_offset += strlen(storage_names[i]) + 1;
    }
    record_offset += 1;
    desc->record_offset = record_offset;
    hw_monitor_ctx.storage_cnt = storage_cnt;

    fwrite(desc, 1, sizeof(rc_bin_descript_t), perf_fp);
    fwrite(img_key, 1, sizeof(img_key), perf_fp);
    fwrite(g_image_file_path, 1, strlen(g_image_file_path) + 1, perf_fp);
    fputc('\n', perf_fp);
    fwrite(storage_key, 1, sizeof(storage_key), perf_fp);
    for (int i = 0; i < storage_cnt; ++i)
    {
        fwrite(storage_names[i], 1, strlen(storage_names[i]) + 1, perf_fp);
    }
    fputc('\n', perf_fp);
    fflush(perf_fp);
}

void deinit_hw_monitor_record()
{
    hw_monitor_rc_raw_data_t *pos, *n;
    int count = 0;
    list_for_each_entry_safe(pos, n, &hw_monitor_ctx.record_head, node)
    {
        list_del(&pos->node);
        free(pos);
    }
}

// ULEB128 变长写入
static inline void hw_monitor_bin_write_uleb128(uint64_t val, FILE* fp)
{
    do
    {
        uint8_t byte = val & 0x7F;
        val >>= 7;
        if (val != 0)
            byte |= 0x80;
        fputc(byte, fp);
    } while (val != 0);
}

/**
 * 写入一条寄存器写记录 (v2.1.0新增，v2.2.0起不再携带PC，v2.3.0起Header调整)
 *   Header: 高2位记录类型RC_BIN_TYPE_REG；bit0: 0=GPR 1=CSR；bits[5:1]: 保留
 *   Payload: 写索引index(ULEB128，GPR为寄存器索引/CSR为地址) + 写数据data(ULEB128)
 *   本记录紧随所属指令记录之后写入，对应的pc即前一条指令记录的pc
 */
static void write_reg_record(uint8_t reg_flag, uint32_t index, uint32_t data)
{
    uint8_t header = (RC_BIN_TYPE_REG << RC_BIN_TYPE_SHIFT) | (reg_flag & ((1 << RC_BIN_TYPE_SHIFT) - 1));
    fputc(header, perf_fp);
    hw_monitor_bin_write_uleb128(index, perf_fp);
    hw_monitor_bin_write_uleb128(data, perf_fp);
}

/**
 * WBU进入时采集的寄存器写数据：1组GPR写和2组CSR写，
 * 在所属指令记录之后写入文件
 */
static void write_reg_records(hw_monitor_rc_raw_data_t* r)
{
    if (r->gpr_wen)
    {
        write_reg_record(RC_BIN_REG_GPR, r->gpr_windex, r->gpr_wdata);
    }
    for (int i = 0; i < 2; i++)
    {
        if (r->csr_wen[i])
        {
            write_reg_record(RC_BIN_REG_CSR, r->csr_waddr[i], r->csr_wdata[i]);
        }
    }
}

// static uint64_t to_simutime(uint64_t t) {
//     return t*2+48;
// }

/**
 * @brief 将硬件 Trace 记录压缩编码并写入二进制文件 (HW_MONITOR_BIN 格式)
 * @param r 指向原始硬件 Monitor 记录结构体的指针
 */
static void write_inst_record(hw_monitor_rc_raw_data_t* r) {
    static rc_encode_ctx_t g_hw_mon_ctx = {0};

        // static uint32_t inst_count = 0;
    // raw_stdout(
    //     "=== %02u 0x%08x if|%04lu,%04lu id|%04lu,%04lu ex|%04lu,%04lu ls|%04lu,%04lu wb|%04lu,%04lu "
    //     "%c\n",
    //     inst_count, r->pc, 
    //     to_simutime(r->stage_ticks[STAGE_INDEX_IFU][0]), to_simutime(r->stage_ticks[STAGE_INDEX_IFU][1]),
    //     to_simutime(r->stage_ticks[STAGE_INDEX_IDU][0]), to_simutime(r->stage_ticks[STAGE_INDEX_IDU][1]),
    //     to_simutime(r->stage_ticks[STAGE_INDEX_EXU][0]), to_simutime(r->stage_ticks[STAGE_INDEX_EXU][1]),
    //     to_simutime(r->stage_ticks[STAGE_INDEX_LSU][0]), to_simutime(r->stage_ticks[STAGE_INDEX_LSU][1]),
    //     to_simutime(r->stage_ticks[STAGE_INDEX_WBU][0]), to_simutime(r->stage_ticks[STAGE_INDEX_WBU][1]), ' ');
    // ++inst_count;

    uint8_t header = 0;
    uint64_t base_tick = r->stage_ticks[STAGE_INDEX_IFU][0];

    // 更新描述信息中的最大tick值（指令执行完时的tick值）
    for (int i = 0; i < STAGE_COUNT; i++)
    {
        if (r->stage_ticks[i][1] > hw_monitor_ctx.bin_descript.max_tick)
        {
            hw_monitor_ctx.bin_descript.max_tick = r->stage_ticks[i][1];
        }
    }

    // 更新描述信息中的总取指数
    hw_monitor_ctx.bin_descript.total_inst++;

    // 1. 提取当前指令各流水阶段的持续时间 (stage_end - stage_begin)
    //    被flush的指令存在阶段数据不完整（缺失阶段的tick为0），不完整阶段的持续时间记0；
    //    记录有效性由Header的INST_VALID位标识，完整阶段仍更新描述信息中的最大持续时间
    uint32_t current_durations[STAGE_COUNT];
    for (int i = 0; i < STAGE_COUNT; i++)
    {
        uint64_t begin_tick = r->stage_ticks[i][0];
        uint64_t end_tick   = r->stage_ticks[i][1];
        uint64_t duration   = 0;
        if (begin_tick != 0 && end_tick >= begin_tick)
        {
            duration = end_tick - begin_tick;
            if (duration > hw_monitor_ctx.bin_descript.max_duration)
            {
                hw_monitor_ctx.bin_descript.max_duration = duration;
            }
        }
        current_durations[i] = (uint32_t)duration;
    }

    // 2. 记录有效性标识（WBU完成时为有效指令，同批次其余为被flush的无效指令）
    if (r->inst_valid)
    {
        header |= RC_BIN_FLAG_INST_VALID;
    }

    // 3. 判断 PC 是否连续
    int is_discont_pc = (g_hw_mon_ctx.is_first_record) || (r->pc != g_hw_mon_ctx.last_pc + 4);
    if (is_discont_pc)
    {
        header |= RC_BIN_FLAG_DISCONT_PC;
    }

    // 4. Cache统计数据：bit[1:0]为icache状态，bit[3:2]为dcache状态；
    //    缓存统计只针对读，写为无；任一缓存存在统计数据时Header置CACHE_DATA
    uint8_t cache_data = (r->icache_stat & 0x3) | ((r->dcache_stat & 0x3) << 2);
    if (cache_data != 0)
        header |= RC_BIN_FLAG_CACHE_DATA;

    // 5. Δinst_begin(指令起始tick) 必然写入Payload
    uint64_t delta_inst_begin =
        g_hw_mon_ctx.is_first_record ? 0 : (base_tick - g_hw_mon_ctx.last_inst_begin);

    // --- 写入数据 ---
    // 写入 Header Byte
    fputc(header, perf_fp);

    // 按需写入 PC Delta (ZigZag + ULEB128)
    if (is_discont_pc)
    {
        int64_t pc_delta = (int64_t)r->pc - (int64_t)g_hw_mon_ctx.last_pc;
        uint64_t zigzag_pc = (pc_delta >> 63) ^ (pc_delta << 1);
        hw_monitor_bin_write_uleb128(zigzag_pc, perf_fp);
    }

    // 写入 Δinst_begin(指令起始tick)
    hw_monitor_bin_write_uleb128(delta_inst_begin, perf_fp);

    // 写入 Storage Index：低bit位为指令存储索引，高bit位为数据存储索引；
    // 无存储数据时对应bit位默认为全1，解析时显示为none
    const int storage_bits = rc_storage_index_bits(hw_monitor_ctx.storage_cnt);
    const uint32_t storage_mask =
        storage_bits >= 32 ? UINT32_MAX : ((1u << storage_bits) - 1);
    uint32_t mem_index = (r->icache_mem_index & storage_mask) |
                         ((uint32_t)((r->dcache_mem_index & storage_mask) << storage_bits));
    hw_monitor_bin_write_uleb128(mem_index, perf_fp);

    // 写入各阶段持续时间
    for (int i = 0; i < STAGE_COUNT; i++)
    {
        hw_monitor_bin_write_uleb128(current_durations[i], perf_fp);
    }

    // 写入缓存统计数据（1 Byte）：bit[1:0]为icache状态，bit[3:2]为dcache状态
    if (cache_data != 0)
    {
        fputc(cache_data, perf_fp);
    }

    // 6. 更新上下文状态
    g_hw_mon_ctx.last_pc = r->pc;
    g_hw_mon_ctx.last_inst_begin = base_tick;
    g_hw_mon_ctx.is_first_record = 0;

    // 7. 定时刷盘
    if (hw_cpu_stat.counts[HW_CPU_STAT_TICK] - g_hw_mon_ctx.last_update_tick > 10000)
    {
        g_hw_mon_ctx.last_update_tick = hw_cpu_stat.counts[HW_CPU_STAT_TICK];
        fflush(perf_fp);
    }
}

void write_record_to_file(hw_monitor_rc_raw_data_t* r)
{
    // 写入指令记录
    write_inst_record(r);

    // 寄存器写记录紧跟所属指令记录之后写入
    write_reg_records(r);
}

/**
 * 是否为空记录（正在记录数据，tick和pc不会同时为0）
 */
static inline bool is_empty_record(hw_monitor_rc_raw_data_t* r)
{
    return (r->tick == 0 && r->pc == 0);
}

/**
 * LSU访存目标地址，LSU结束监控项（arg）在有访存时更新，
 * 用于查找数据存储索引（dcache_mem_index）
 */
static uint32_t dcache_mem_addr = 0;

/**
 * 添加监控点数据
 *   id: -1表示初始化监控数据；类型hw_monitor_mid_t
 *   pc: 当前阶段的pc值（寄存器写数据项不需要pc）
 *   mid: IFU/LSU结束项扩展含义——IFU结束arg为icache访问状态（2bit：0无 1命中 2未命中）；
 *        LSU结束kind为dcache访问状态（0无 1命中 2未命中，写为0），wen为访存标识（读或写），
 *        wen为1时arg为访存目标地址；IDU记录inst_code；EXU记录dnpc；
 *        WBU进入时(mid.kind非0)记录寄存器写数据：1组GPR写和2组CSR写，
 *        kind编码：1=CSR写（两个写通道共用） 2=GPR写
 */
// void dpi_monitor_item(int item_type, int id, int delta)
void dpi_add_monitor_item(int mid, int pc, int arg)
{
#if CONFIG_PERF_MONITOR
    static bool init_monitor_en = true;

    // 初始化监控数据
    if (mid == -1)
    {
        if (init_monitor_en)
        {
            init_monitor_en = false;
            init_hw_monitor_record();
        }
        return;
    }

    // 添加监控数据
    rc_mid_t hw_mid;
    memcpy(&hw_mid, &mid, sizeof(rc_mid_t));
    uint32_t is_end = hw_mid.is_end;
    uint32_t is_begin = !is_end;
    uint32_t stage = hw_mid.stage;
    if (stage >= STAGE_COUNT)
    {
        raw_stdout("Unknown stage: %d\n", stage);
        // exit_simu(3);
        return;
    }

    // 获取当前阶段记录值
    list_head_t* head = &hw_monitor_ctx.record_head;
    hw_monitor_rc_raw_data_t* record = NULL;
    hw_monitor_rc_raw_data_t *pos, *n;

    // WBU进入时的寄存器写数据项（mid扩展kind/wen/waddr，arg为写数据）：
    // tick项已先行记录WBU起始tick，这里取最近一条已进入WBU且未完成的记录保存写数据；
    // 寄存器项不携带pc，该记录即上次处理（进入WBU）的指令记录
    // 注意kind仅在WBU阶段表示寄存器写类型，LSU结束项的kind为dcache访问状态
    if (stage == STAGE_INDEX_WBU && hw_mid.kind != 0)
    {
        list_for_each_entry(pos, head, node)
        {
            if (is_empty_record(pos))
            {
                break;
            }
            // WBU已开始且未结束：同一时间至多一条，即上次处理的指令记录
            if (pos->stage_ticks[STAGE_INDEX_WBU][0] != 0 && pos->stage_ticks[STAGE_INDEX_WBU][1] == 0)
            {
                record = pos;
            }
        }
        if (!record)
        {
            return;
        }
        switch (hw_mid.kind)
        {
            case 1:  // CSR写（两个写通道共用，依次存入空闲写通道）
                if (!record->csr_wen[0])
                {
                    record->csr_wen[0]   = hw_mid.wen;
                    record->csr_waddr[0] = hw_mid.waddr;
                    record->csr_wdata[0] = arg;
                }
                else
                {
                    record->csr_wen[1]   = hw_mid.wen;
                    record->csr_waddr[1] = hw_mid.waddr;
                    record->csr_wdata[1] = arg;
                }
                break;
            case 2:  // GPR写
                record->gpr_wen    = hw_mid.wen;
                record->gpr_windex = hw_mid.waddr;
                record->gpr_wdata  = arg;
                break;
            default:
                break;
        }
        return;
    }

    list_for_each_entry(pos, head, node)
    {
        if (stage == STAGE_INDEX_IFU && is_begin)  // IFU第一次记录找一个record即可
        {
            if (is_empty_record(pos))
            {
                record = pos;
                break;
            }
        }
        else  // 需要寻找到之前的记录；注意PC重复但当前阶段不一致
        {
            if (is_empty_record(pos))
            {
                break;
            }

            uint64_t* target_tick = (uint64_t*)(pos->stage_ticks) + (2 * stage + is_end);
            uint64_t* last_tick = target_tick - 1;
            if (pc == pos->pc && *target_tick == 0 && *last_tick != 0)
            {
                record = pos;
                break;
            }
        }
    }
    if (!record)
    {
        return;
    }
    if (is_empty_record(record))
    {
        record->tick = hw_cpu_stat.counts[HW_CPU_STAT_TICK];
        record->pc = pc;
    }

    // 记录各阶段tick值
    record->stage_ticks[stage][is_end] = hw_cpu_stat.counts[HW_CPU_STAT_TICK];

    // IFU结束记录icache访问状态（arg低2bit）；
    // 指令存储索引按pc在存储体列表中查找，不属于任何存储体时保持默认全1
    if (stage == STAGE_INDEX_IFU && is_end)
    {
        record->icache_stat = arg & 0x3;
        int storage_idx = find_vdev_storage_index(record->pc);
        if (storage_idx >= 0)
        {
            record->icache_mem_index = (uint32_t)storage_idx;
        }
    }

    // LSU结束记录dcache访问状态（mid.kind：0无 1命中 2未命中，写为0无）；
    // mid.wen为访存标识（读或写），有访存时arg为访存目标地址，数据存储索引按该地址在存储体列表中查找
    if (stage == STAGE_INDEX_LSU && is_end)
    {
        record->dcache_stat = hw_mid.kind;
        if (hw_mid.wen)
        {
            dcache_mem_addr = (uint32_t)arg;
            int storage_idx = find_vdev_storage_index(dcache_mem_addr);
            if (storage_idx >= 0)
            {
                record->dcache_mem_index = (uint32_t)storage_idx;
            }
        }
    }

    // IDU结束记录inst_code
    if (stage == STAGE_INDEX_IDU && is_end)
        record->inst_code = arg;

    // EXU结束记录dnpc
    if (stage == STAGE_INDEX_EXU && is_end)
        record->dnpc = arg;

    // WBU结束，先记录信息，再清理之前未完成的数据
    if (stage == STAGE_INDEX_WBU && is_end)
    {
        // 清理之前未完成的数据
        list_head_t tmp;
        INIT_LIST_HEAD(&tmp);
        list_cut_position(&tmp, head, &record->node);
        // 按时间顺序记录完成指令及之前被flush的未完成指令；
        // pos==record为完成WBU的指令记为有效，其余为被flush的无效指令（部分阶段数据缺失），
        // 有效性写入Header的INST_VALID位，无效记录可用于计算flush流水线占用的时间，正常打印时屏蔽
        list_for_each_entry(pos, &tmp, node)
        {
            if (!is_empty_record(pos))
            {
                pos->inst_valid = (pos == record);
                write_record_to_file(pos);
            }
            list_head_t node = pos->node;
            memset(pos, 0, sizeof(*pos));
            pos->node = node;
            // 存储索引恢复默认全1：无对应存储数据时保持全1，清零会被误解析为存储体0
            pos->icache_mem_index = UINT32_MAX;
            pos->dcache_mem_index = UINT32_MAX;
        }
        list_splice_tail_init(&tmp, head);
    }
#endif
}

extern "C" void flash_read(int32_t addr_idx, int32_t* data)
{
    uint32_t addr = addr_idx + CONFIG_FLASH_BASE;
    vdev_item_t* vdev = find_vdev_item(addr);
    if (!vdev)
    {
        raw_stdout("Read flash is out of range, addr:%#.8x len:%d\n", addr, 4);
        exit_simu(2);
    }
    *data = vdev_read(vdev, addr, 4);
}

extern "C" void mrom_read(int32_t addr_idx, int32_t* data)
{
    // assert(0);
    addr_idx &= ~0x3u;  // 读写地址四字节对齐
    uint32_t addr = addr_idx;
    vdev_item_t* vdev = find_vdev_item(addr);
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

int dpi_get_csr_index(int addr)
{
    return get_csr_index(addr);
}
