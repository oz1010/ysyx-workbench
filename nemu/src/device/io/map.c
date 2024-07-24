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
#include <memory/host.h>
#include <memory/vaddr.h>
#include <device/map.h>
#include <time.h>
#include "common/flog.h"

#define IO_SPACE_MAX (2 * 1024 * 1024)

typedef struct _dtrace_limit_s {
  paddr_t start_addr;
  paddr_t end_addr;
} dtrace_limit_t;

static uint8_t *io_space = NULL;
static uint8_t *p_space = NULL;

#if CONFIG_DTRACE
static FILE* pdtrace_file = NULL;
static const char dtrace_file_path[] = "dtrace.txt";
static dtrace_limit_t dtrace_limits[8] = {0};
static int dtrace_limits_cnt = 0;

#define DTRACE_LOG(fmt, ...) flog_printf(pdtrace_file, fmt "\n", ##__VA_ARGS__)
#define DTRACE_LOG_LIMIT(fmt, ...) do\
  {\
    bool is_output = dtrace_limits_cnt == 0;\
    if (dtrace_limits_cnt > 0) {\
      for (int i=0; i<dtrace_limits_cnt; ++i) {\
        dtrace_limit_t *plimit = &dtrace_limits[i];\
        if ( (addr >= plimit->start_addr && addr <= plimit->end_addr) && \
             ((addr+len) >= plimit->start_addr && (addr+len) <= plimit->end_addr) ) {\
          is_output = true;\
          break;\
        }\
      }\
    }\
    if (is_output) \
      flog_printf(pdtrace_file, fmt "\n", ##__VA_ARGS__);\
  } while (false)
#else
#define DTRACE_LOG(fmt, ...)
#define DTRACE_LOG_LIMIT(fmt, ...)
#endif

uint8_t* new_space(int size) {
  uint8_t *p = p_space;
  // page aligned;
  size = (size + (PAGE_SIZE - 1)) & ~PAGE_MASK;
  p_space += size;
  assert(p_space - io_space < IO_SPACE_MAX);
  return p;
}

static void check_bound(IOMap *map, paddr_t addr) {
  if (map == NULL) {
    Assert(map != NULL, "address (" FMT_PADDR ") is out of bound at pc = " FMT_WORD, addr, cpu.pc);
  } else {
    Assert(addr <= map->high && addr >= map->low,
        "address (" FMT_PADDR ") is out of bound {%s} [" FMT_PADDR ", " FMT_PADDR "] at pc = " FMT_WORD,
        addr, map->name, map->low, map->high, cpu.pc);
  }
}

static void invoke_callback(io_callback_t c, paddr_t offset, int len, bool is_write) {
  if (c != NULL) { c(offset, len, is_write); }
}

void init_map() {
#if CONFIG_DTRACE
  pdtrace_file = fopen(dtrace_file_path, "w+");
  Assert(pdtrace_file, "Open file %s failed", dtrace_file_path);
  Log("Device trace log is written to %s", dtrace_file_path);
  DTRACE_LOG("Start record device trace.");

#if CONFIG_DTRACE_OPTIONS
  dtrace_limit_t *plimit = &dtrace_limits[dtrace_limits_cnt++];
  plimit->start_addr = CONFIG_DTRACE_START_ADDR1;
  plimit->end_addr = CONFIG_DTRACE_END_ADDR1;
  Log("Device trace limit %d [%#x, %#x].",dtrace_limits_cnt, plimit->start_addr, plimit->end_addr);
#endif

#endif

  io_space = malloc(IO_SPACE_MAX);
  assert(io_space);
  p_space = io_space;
}

word_t map_read(paddr_t addr, int len, IOMap *map) {
  assert(len >= 1 && len <= 8);
  check_bound(map, addr);
  paddr_t offset = addr - map->low;
  invoke_callback(map->callback, offset, len, false); // prepare data to read
  word_t ret = host_read(map->space + offset, len);
  DTRACE_LOG_LIMIT("%s %#x %d read %#x", map->name, addr, len, ret);  
  return ret;
}

void map_write(paddr_t addr, int len, word_t data, IOMap *map) {
  assert(len >= 1 && len <= 8);
  check_bound(map, addr);
  paddr_t offset = addr - map->low;
  host_write(map->space + offset, len, data);
  invoke_callback(map->callback, offset, len, true);
  DTRACE_LOG_LIMIT("%s %#x %d write %#x", map->name, addr, len, data);
}
