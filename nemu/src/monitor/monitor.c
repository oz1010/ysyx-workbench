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

#include <isa.h>
#include <memory/paddr.h>
#include <generated/autoconf.h>
#include <utils.h>
#include "file/bin_header.h"

// this is not consistent with uint8_t
// but it is ok since we do not access the array directly
static const uint32_t img [] = {
  0x00000297,  // auipc t0,0
  0x00028823,  // sb  zero,16(t0)
  0x0102c503,  // lbu a0,16(t0)
  0x00100073,  // ebreak (used as nemu_trap)
  0xdeadbeef,  // some data
};

void init_rand();
void init_log(const char *log_file);
void init_mem();
void init_difftest(char *ref_so_file, long img_size, int port);
void init_device();
void init_sdb();
void init_disasm(const char *triple);
void set_pc(paddr_t addr);

static void welcome() {
  Log("Trace: %s", MUXDEF(CONFIG_TRACE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
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
  Log("Watchpoint: %s", MUXDEF(CONFIG_WATCHPOINT, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
  Log("Breakpoint: %s", MUXDEF(CONFIG_BREAKPOINT, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
  Log("Debug Module: %s", MUXDEF(CONFIG_DEBUG_MODULE, ANSI_FMT("ON", ANSI_FG_GREEN), ANSI_FMT("OFF", ANSI_FG_RED)));
  Log("Build time: %s, %s", __TIME__, __DATE__);
  raw_stdout("Welcome to %s-NEMU!\n", ANSI_FMT(str(__GUEST_ISA__), ANSI_FG_YELLOW ANSI_BG_RED));
  raw_stdout("For help, type \"help\"\n");
  // Log("Exercise: Please remove me in the source code and compile NEMU again.");
  // assert(0);
}

#ifndef CONFIG_TARGET_AM
#include <getopt.h>

void sdb_set_batch_mode();

static char *log_file = NULL;
static char *diff_so_file = NULL;
static char *file_path = NULL;
static int difftest_port = 1234;
bin_header_t bin_header;

static long load_img() {
  mem_item_t *mem_item = find_mem_item(CONFIG_IMG_LOAD);
  assert(mem_item);
  uint8_t * pmem = guest_to_host(CONFIG_IMG_LOAD);

  if (file_path == NULL) {
    Log("No image is given. Use the default build-in image.");
    /* Load built-in image. */
    memcpy(pmem, img, sizeof(img));
    return 4096; // built-in image size
  }

  int ret;
  FILE *fd = fopen(file_path, "rb");
  Assert(fd, "Can not open '%s'", file_path);

  fseek(fd, 0, SEEK_END);
  size_t readsize = ftell(fd);

  Log("The image is %s, size %#x", file_path, (uint32_t)readsize);

  if (readsize < BIN_HEADER_OFFSET + sizeof(bin_header_t))
  {
    Log("The file is too small for bin_header, size %#x", (uint32_t)readsize);
    exit(-1);
  }
  Assert(readsize <= mem_item->endaddr - CONFIG_IMG_LOAD,
         "Image does not fit in %s at %#x", mem_item->name, CONFIG_IMG_LOAD);
  /* 加载bin文件到flash */
  fseek(fd, 0, SEEK_SET);
  ret = fread(&pmem[0], readsize, 1, fd);
  assert(ret == 1 && "read bin to flash failed");
  /* 校验复位向量并读取偏移0x04处的段元数据。 */
  uint32_t reset_vector = 0;
  memcpy(&reset_vector, pmem, sizeof(reset_vector));
  if ((reset_vector & 0x7f) != 0x6f || ((reset_vector >> 7) & 0x1f) != 0)
  {
    Log("The file is missing the RISC-V reset vector, instruction %#x", reset_vector);
    exit(-1);
  }
  memcpy(&bin_header, pmem + BIN_HEADER_OFFSET, sizeof(bin_header_t));
  /* 快速加载到ram */
  if (bin_header.flag & BIN_HEADER_FLAG_FAST_BOOT)
  {
    // 加载text段
    for (uint32_t addr = bin_header.text_start, load_addr = bin_header.text_load;
        addr < bin_header.text_end; addr += 4, load_addr += 4)
    {
        uint32_t data = paddr_read(load_addr, 4);
        paddr_write(addr, 4, data);
    }
    // 加载data段
    for (uint32_t addr = bin_header.data_start, load_addr = bin_header.data_load;
        addr < bin_header.data_end; addr += 4, load_addr += 4)
    {
        uint32_t data = paddr_read(load_addr, 4);
        paddr_write(addr, 4, data);
    }
    // 清理bss段
    for (uint32_t addr = bin_header.bss_start; addr < bin_header.bss_end; addr += 4)
    {
        paddr_write(addr, 4, 0);
    }
    Log("Fast load done");
  }
  Log("Load bin_header flag %#x", bin_header.flag);
  /* 复位后从镜像基址取指，首条指令负责跳转到_start。 */
  set_pc(CONFIG_IMG_LOAD);
  Log("Load code to %s %#x size %#x reset %#x", mem_item->name, mem_item->startaddr,
    (uint32_t)readsize, CONFIG_IMG_LOAD);
  Log("Section text [%#x] => [%#x, %#x)-%s", bin_header.text_load, bin_header.text_start,
    bin_header.text_end, size_str(bin_header.text_end - bin_header.text_start));
  Log("Section data [%#x] => [%#x, %#x)-%s", bin_header.data_load, bin_header.data_start,
    bin_header.data_end, size_str(bin_header.data_end - bin_header.data_start));
  Log("Section bss 0 => [%#x %#x)-%s", bin_header.bss_start, bin_header.bss_end,
    size_str(bin_header.bss_end - bin_header.bss_start));

  fclose(fd);
  return readsize;
}

static int parse_args(int argc, char *argv[]) {
  const struct option table[] = {
    {"batch"    , no_argument      , NULL, 'b'},
    {"log"      , required_argument, NULL, 'l'},
    {"diff"     , required_argument, NULL, 'd'},
    {"port"     , required_argument, NULL, 'p'},
    {"help"     , no_argument      , NULL, 'h'},
    {0          , 0                , NULL,  0 },
  };
  int o;
  while ( (o = getopt_long(argc, argv, "-bhl:d:p:", table, NULL)) != -1) {
    switch (o) {
      case 'b': sdb_set_batch_mode(); break;
      case 'p': sscanf(optarg, "%d", &difftest_port); break;
      case 'l': log_file = optarg; break;
      case 'd': diff_so_file = optarg; break;
      case 1: file_path = optarg; return 0;
      default:
        raw_stdout("Usage: %s [OPTION...] IMAGE [args]\n\n", argv[0]);
        raw_stdout("\t-b,--batch              run with batch mode\n");
        raw_stdout("\t-l,--log=FILE           output log to FILE\n");
        raw_stdout("\t-d,--diff=REF_SO        run DiffTest with reference REF_SO\n");
        raw_stdout("\t-p,--port=PORT          run DiffTest with port PORT\n");
        raw_stdout("\n");
        exit(0);
    }
  }
  return 0;
}

void init_monitor(int argc, char *argv[]) {
  /* Perform some global initialization. */

  /* Parse arguments. */
  parse_args(argc, argv);

  /* Set random seed. */
  init_rand();

  /* Open the log file. */
  init_log(log_file);

  /* Perform ISA dependent initialization. */
  init_isa();

  /* Initialize memory. */
  init_mem();

  /* Initialize devices. */
  IFDEF(CONFIG_DEVICE, init_device());

  /* Load the image to memory. This will overwrite the built-in image. */
  long img_size = load_img();

  /* Initialize differential testing. */
  // 需要拷贝整个内存，否则可能因为image重定向而读取到非法值
  init_difftest(diff_so_file, img_size, difftest_port);

  /* Initialize the simple debugger. */
  init_sdb();

#ifndef CONFIG_ISA_loongarch32r
  IFDEF(CONFIG_ITRACE, init_disasm(
    MUXDEF(CONFIG_ISA_x86,     "i686",
    MUXDEF(CONFIG_ISA_mips32,  "mipsel",
    MUXDEF(CONFIG_ISA_riscv,
      MUXDEF(CONFIG_RV64,      "riscv64",
                               "riscv32"),
                               "bad"))) "-pc-linux-gnu"
  ));
#endif

  /* Display welcome message. */
  welcome();
}
#else // CONFIG_TARGET_AM
static long load_img() {
  extern char bin_start, bin_end;
  size_t size = &bin_end - &bin_start;
  Log("img size = %ld", size);
  memcpy(guest_to_host(RESET_VECTOR), &bin_start, size);
  return size;
}

void am_init_monitor() {
  init_rand();
  init_mem();
  init_isa();
  load_img();
  IFDEF(CONFIG_DEVICE, init_device());
  welcome();
}
#endif
