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

#include <isa.h>
#include <memory/paddr.h>
#include <generated/autoconf.h>
#include <utils.h>

void init_rand();
void init_log(const char *log_file);
void init_mem();
void init_difftest(char *ref_so_file, long img_size, int port);
void init_device();
void init_sdb();
void init_disasm(const char *triple);

static void welcome()
{
    Log("Trace: %s",
        MUXDEF(CONFIG_TRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Device Trace: %s",
        MUXDEF(CONFIG_DTRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    IFDEF(CONFIG_TRACE, Log("If trace is enabled, a log file will be generated "
                            "to record the trace. This may lead to a large log file. "
                            "If it is not necessary, you can disable it in menuconfig"));
    Log("Watchpoint: %s",
        MUXDEF(CONFIG_WATCHPOINT, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Breakpoint: %s",
        MUXDEF(CONFIG_BREAKPOINT, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Debug Module: %s",
        MUXDEF(CONFIG_DEBUG_MODULE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
    Log("Build time: %s, %s", __TIME__, __DATE__);
    printf("Welcome to %s-NPC!\n", ANSI_FMT(str(__GUEST_ISA__), ANSI_FG_YELLOW ANSI_BG_RED));
    printf("For help, type \"help\"\n");
}

#ifndef CONFIG_TARGET_AM
#include <getopt.h>

void sdb_set_batch_mode();

extern uint8_t raw_memory[CONFIG_MSIZE];
static char *cfg_img_file = NULL;
static char *cfg_log_file = NULL;
int cfg_dm_port = MUXDEF(CONFIG_DEBUG_MODULE, CONFIG_DM_PORT, 0);
static char *cfg_difftest_so_file = NULL;
static int cfg_difftest_port = 1234;

static size_t load_img()
{
    if (cfg_img_file == NULL)
    {
        Log("No image is given. Use the default build-in image.");
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

    LOG_INFO("Load memory from file %s", file_path);
    size_t membytes = CONFIG_MSIZE * sizeof(raw_memory[0]);
    unsigned char *pmemstart = (unsigned char *)&raw_memory[0];
    unsigned char *pmemend = pmemstart + membytes;
    FILE *fd = fopen(file_path, "rb");
    Assert(fd, "open file:%s failed", file_path);

    size_t readsize = fread(pmemstart, 1, membytes, fd);
    LOG_INFO("Load memory from file total size %lu", readsize);
    (void)pmemend;
    return readsize;
}

static int parse_args(int argc, char *argv[])
{
    const struct option table[] = {
        {"batch", no_argument, NULL, 'b'},     {"port", required_argument, NULL, 'p'},
        {"log", required_argument, NULL, 'l'}, {"diff", required_argument, NULL, 'd'},
        {"help", no_argument, NULL, 'h'},      {0, 0, NULL, 0},
    };
    int o;
    while ((o = getopt_long(argc, argv, "-hl:d:p:b", table, NULL)) != -1)
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
                cfg_log_file = optarg;
                break;
            case 'd':
                cfg_difftest_so_file = optarg;
                break;
            case 1:
                cfg_img_file = optarg;
                return 0;
            default:
                printf("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
                printf("\t-b,--batch              run with batch mode\n");
                printf("\t-l,--log=FILE           output log to FILE\n");
                printf("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
                printf("\t-p,--port=PORT          run DiffTest with port PORT\n");
                printf("\n");
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
    init_log(cfg_log_file);

    /* Initialize memory. */
    init_mem();

    /* Initialize devices. */
    IFDEF(CONFIG_DEVICE, init_device());

    /* Perform ISA dependent initialization. */
    init_isa(argc, argv);

    /* Load the image to memory. This will overwrite the built-in image. */
    size_t img_size = load_img();

    /* Initialize differential testing. */
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
    IFDEF(CONFIG_DEVICE, init_device());
    welcome();
}
#endif
