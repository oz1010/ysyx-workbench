/***************************************************************************************
 * Copyright (c) 2014-2022 Zihao Yu, Nanjing University
 *
 * NPC is licensed under Mulan PSL v2.
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

#include <string>
#include <isa.h>
#include <memory/paddr.h>
#include "device/vdev.h"
#include <generated/autoconf.h>
#include <utils.h>
#include "file/bin_header.h"

// this is not consistent with uint8_t
// but it is ok since we do not access the array directly
static const uint32_t img[] = {
    0x00000297,  // auipc t0,0
    0x00028823,  // sb  zero,16(t0)
    0x0102c503,  // lbu a0,16(t0)
    0x00100073,  // ebreak (used as npc_trap)
    0xdeadbeef,  // some data
};

void init_rand();
void init_log();
void init_mem();
void init_difftest(char *ref_so_file, long img_size, int port);
// void init_device();
void init_vdev();
void init_sdb();
void init_disasm(const char *triple);
extern void set_pc(paddr_t addr);

static void welcome()
{
    IFDEF(CONFIG_ISA_riscv, Log("Processor type: %s", ANSI_FMT(
        MUXDEF(CONFIG_ISA_RISCV_SINGLE, "single", 
            MUXDEF(CONFIG_ISA_RISCV_MULTIPLE, "multiple", 
                MUXDEF(CONFIG_ISA_RISCV_PIPELINE, "pipeline", 
                    "unknown"
                )
            )
        ), 
        ANSI_FG_GREEN)));
    Log("Trace: %s",
        MUXDEF(CONFIG_TRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
#if CONFIG_TRACE
    Log("Instruction Trace: %s",
        MUXDEF(CONFIG_ITRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Device Trace: %s",
        MUXDEF(CONFIG_DTRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Exception Trace: %s",
        MUXDEF(CONFIG_ETRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Memory Trace: %s",
        MUXDEF(CONFIG_MTRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    IFDEF(CONFIG_TRACE, Log("If trace is enabled, a log file will be generated "
                            "to record the trace. This may lead to a large log file. "
                            "If it is not necessary, you can disable it in menuconfig"));
#endif
    Log("Watchpoint: %s",
        MUXDEF(CONFIG_WATCHPOINT, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Breakpoint: %s",
        MUXDEF(CONFIG_BREAKPOINT, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Debug Module: %s",
        MUXDEF(CONFIG_DEBUG_MODULE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("ICache: %s"
        IFDEF(CONFIG_ICACHE, ANSI_FMT(", W-N-M: %d-%d-%d", ANSI_FG_BLUE))
        ,
        MUXDEF(CONFIG_ICACHE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED))
        #ifdef CONFIG_ICACHE
        , CONFIG_ICACHE_PARAMETER_W, CONFIG_ICACHE_PARAMETER_N, CONFIG_ICACHE_PARAMETER_M
        #endif
    );
    Log("DCache: %s"
        IFDEF(CONFIG_DCACHE, ANSI_FMT(", W-N-M: %d-%d-%d", ANSI_FG_BLUE))
        ,
        MUXDEF(CONFIG_DCACHE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED))
        #ifdef CONFIG_DCACHE
        , CONFIG_DCACHE_PARAMETER_W, CONFIG_DCACHE_PARAMETER_N, CONFIG_DCACHE_PARAMETER_M
        #endif
    );
    Log("Build time: %s, %s", __TIME__, __DATE__);
    raw_stdout("Welcome to %s-NPC!\n", ANSI_FMT(str(__GUEST_ISA__), ANSI_FG_YELLOW ANSI_BG_RED));
    raw_stdout("For help, type \"help\"\n");
}

#ifndef CONFIG_TARGET_AM
#include <getopt.h>

void sdb_set_batch_mode();

#if defined(CONFIG_PMEM_MALLOC)
extern uint8_t *raw_memory;
#else
extern uint8_t raw_memory[CONFIG_MSIZE];
#endif
std::string cfg_log_name;
std::string cfg_output = "";
std::string cfg_perf_name = "";
std::string cfg_icbin_name = "";
std::string cfg_dcbin_name = "";
static char *cfg_img_file = NULL;
int cfg_dm_port = MUXDEF(CONFIG_DEBUG_MODULE, CONFIG_DM_PORT, 0);
static char *cfg_difftest_so_file = NULL;
static int cfg_difftest_port = 1234;
bin_header_t bin_header;

static size_t load_img()
{
    uint8_t *pmem = NULL;
    vdev_item_t* vdev = NULL;

    if (cfg_img_file == NULL)
    {
        vdev = find_vdev_item(CONFIG_IMG_LOAD);
        assert(vdev);
        pmem = vdev->raw_mem;

        Log("No image is given. Use the default build-in image to %#x.", CONFIG_IMG_LOAD);
        /* Load built-in image. */
        memcpy(pmem, img, sizeof(img));
        return 4096;  // built-in image size
    }

    const char *fpath = cfg_img_file;
    char file_path[1024] = {0};

    if (fpath[0] != '/')
    {
        const char *npc_home = getenv("NPC_HOME");
        Assert(npc_home, "Miss set NPC_HOME");
        strcat(&file_path[strlen(file_path)], npc_home);
        strcat(&file_path[strlen(file_path)], "/../");
        strcat(&file_path[strlen(file_path)], fpath);
    }
    else
    {
        strcat(&file_path[strlen(file_path)], fpath);
    }

    int ret;
    FILE *fd = fopen(file_path, "rb");
    Assert(fd, "Can not open '%s'", file_path);

    fseek(fd, 0, SEEK_END);
    size_t readsize = ftell(fd);

    Log("The image is %s, size %#x", file_path, (uint32_t)readsize);

    /* 加载bin文件头部信息 */
    fseek(fd, 0, SEEK_SET);
    ret = fread(&bin_header, sizeof(bin_header_t), 1, fd);
    assert(ret == 1 && "read bin header failed");
    /* 解析bin_header信息 */
    if (bin_header.magic != BIN_HEADER_MAGIC)
    {
        Log("The file is missing bin_header information, magic %u", bin_header.magic);
        exit(-1);
    }
    /* 根据entry找到程序需要加载的位置 */
    vdev = find_vdev_item(bin_header.entry);
    assert(vdev);
    pmem = vdev->raw_mem;
    fseek(fd, 0, SEEK_SET);
    ret = fread(&pmem[0], readsize, 1, fd);
    assert(ret == 1 && "read bin to memory failed");
    
    /* 快速加载到ram */
    if (bin_header.flag & BIN_HEADER_FLAG_FAST_BOOT)
    {
        // 加载text段
        if (bin_header.text_start != bin_header.text_load) {
            for (uint32_t addr = bin_header.text_start, load_addr = bin_header.text_load;
                addr < bin_header.text_end; addr += 4, load_addr += 4)
            {
                uint32_t data = paddr_read(load_addr, 4);
                paddr_write(addr, 4, data);
            }
        }
        // 加载data段
        if (bin_header.data_start != bin_header.data_load) {
            for (uint32_t addr = bin_header.data_start, load_addr = bin_header.data_load;
                addr < bin_header.data_end; addr += 4, load_addr += 4)
            {
                uint32_t data = paddr_read(load_addr, 4);
                paddr_write(addr, 4, data);
            }
        }
        // 清理bss段
        for (uint32_t addr = bin_header.bss_start; addr < bin_header.bss_end; addr += 4)
        {
            paddr_write(addr, 4, 0);
        }
        Log("Fast load done");
    }
    Log("Load bin_header flag %#x", bin_header.flag);
    /* 根据entry重置pc */
    set_pc(bin_header.entry);
    Log("Load code to %s %#x size %#x entry %#x", vdev->name, vdev->startaddr,
        (uint32_t)readsize, bin_header.entry);
    Log("Section text [%#x] => [%#x, %#x)-%s", bin_header.text_load, bin_header.text_start,
        bin_header.text_end, size_str(bin_header.text_end - bin_header.text_start));
    Log("Section data [%#x] => [%#x, %#x)-%s", bin_header.data_load, bin_header.data_start,
        bin_header.data_end, size_str(bin_header.data_end - bin_header.data_start));
    Log("Section bss 0 => [%#x %#x)-%s", bin_header.bss_start, bin_header.bss_end,
        size_str(bin_header.bss_end - bin_header.bss_start));

    fclose(fd);
    return readsize;
}

static int parse_args(int argc, char *argv[])
{
    const struct option table[] = {
        {"batch", no_argument, NULL, 'b'},     {"port", required_argument, NULL, 'p'},
        {"log", required_argument, NULL, 'l'}, {"diff", required_argument, NULL, 'd'},
        {"help", no_argument, NULL, 'h'},      {"perf", required_argument, NULL, 'f'},
        {"output", required_argument, NULL, 'o'},
        {0, 0, NULL, 0},
    };
    int o;
    while ((o = getopt_long(argc, argv, "-hbl:d:p:o:f:", table, NULL)) != -1)
    {
        switch (o)
        {
            case 'b':
                sdb_set_batch_mode();
                break;
            case 'p':
                sscanf(optarg, "%d", &cfg_difftest_port);
                break;
            case 'l':
                cfg_log_name = optarg;
                break;
            case 'f':
                cfg_perf_name = optarg;
                break;
            case 'd':
                cfg_difftest_so_file = optarg;
                break;
            case 'o':
                cfg_output = optarg;
                break;
            case 1:
                cfg_img_file = optarg;
                return 0;
            default:
                raw_stdout("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
                raw_stdout("\t-b,--batch              run with batch mode\n");
                raw_stdout("\t-l,--log=NAME           specify the name of log file\n");
                raw_stdout("\t-f,--perf=NAME          specify the name of perf-data file\n");
                raw_stdout("\t-o,--output=PATH        specify the output directory\n");
                raw_stdout("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
                raw_stdout("\t-p,--port=PORT          run DiffTest with port PORT\n");
                raw_stdout("\n");
                exit(0);
        }
    }
    return 0;
}

void init_monitor(int argc, char *argv[])
{
    /* Perform some global initialization. */

    /* Parse arguments. */
    parse_args(argc, argv);

    /* Set random seed. */
    init_rand();

    /* Open the log file. */
    init_log();

    /* Perform ISA dependent initialization. */
    init_isa(argc, argv);

    /* Initialize memory. */
    init_mem();

    /* Initialize devices. */
    // IFDEF(CONFIG_DEVICE, init_device());
    IFDEF(CONFIG_DEVICE, init_vdev());

    /* Load the image to memory. This will overwrite the built-in image. */
    long img_size = load_img();

    /* Initialize differential testing. */
    // 需要拷贝整个内存，否则可能因为image重定向而读取到非法值
    init_difftest(cfg_difftest_so_file, img_size, cfg_difftest_port);

    /* Initialize the simple debugger. */
    init_sdb();

#ifndef CONFIG_ISA_loongarch32r
    IFDEF(CONFIG_ITRACE, init_disasm(MUXDEF(CONFIG_ISA_x86, "i686",
                                            MUXDEF(CONFIG_ISA_mips32, "mipsel",
                                                   MUXDEF(CONFIG_ISA_riscv,
                                                          MUXDEF(CONFIG_RV64, "riscv64", "riscv32"),
                                                          "bad"))) "-pc-linux-gnu"));
#endif

    /* Display welcome message. */
    welcome();
}
#else  // CONFIG_TARGET_AM
static size_t load_img()
{
    extern char bin_start, bin_end;
    size_t size = &bin_end - &bin_start;
    Log("img size = %ld", size);
    memcpy(guest_to_host(RESET_VECTOR), &bin_start, size);
    return size;
}

void am_init_monitor()
{
    init_rand();
    init_mem();
    init_isa();
    load_img();
    // IFDEF(CONFIG_DEVICE, init_device());
    IFDEF(CONFIG_DEVICE, init_vdev());
    welcome();
}
#endif
