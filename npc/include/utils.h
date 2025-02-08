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

#ifndef __UTILS_H__
#define __UTILS_H__

#include <time.h>
#include <stdbool.h>
#include "common.h"

#define ENABLE_LOG_TIME_STAMP true
#define LOG_TIME_STAMP_STR_MAX 48

// ----------- state -----------

typedef enum { NPC_RUNNING, NPC_STOP, NPC_END, NPC_ABORT, NPC_QUIT } npc_state_t;

typedef struct {
  npc_state_t state;
  vaddr_t halt_pc;
  uint32_t halt_ret;

  /* for statistic */
  uint64_t timer;
  uint64_t nr_guest_inst;
  bool print_step;
} npc_context_t;

extern npc_context_t npc_ctx;

// ----------- timer -----------
typedef union hw_time_info
{
    uint64_t time_raw_val;
    struct
    {
        uint64_t year : 12;
        uint64_t month : 4;
        uint64_t day : 5;
        uint64_t hour : 5;
        uint64_t minute : 6;
        uint64_t second : 6;
    };
} hw_time_info_t;

uint64_t get_time();
void get_hw_time_info(hw_time_info_t *info);

extern FILE *log_fp;

// ----------- log -----------

#define ANSI_FG_BLACK "\33[1;30m"
#define ANSI_FG_RED "\33[1;31m"
#define ANSI_FG_GREEN "\33[1;32m"
#define ANSI_FG_YELLOW "\33[1;33m"
#define ANSI_FG_BLUE "\33[1;34m"
#define ANSI_FG_MAGENTA "\33[1;35m"
#define ANSI_FG_CYAN "\33[1;36m"
#define ANSI_FG_WHITE "\33[1;37m"
#define ANSI_BG_BLACK "\33[1;40m"
#define ANSI_BG_RED "\33[1;41m"
#define ANSI_BG_GREEN "\33[1;42m"
#define ANSI_BG_YELLOW "\33[1;43m"
#define ANSI_BG_BLUE "\33[1;44m"
#define ANSI_BG_MAGENTA "\33[1;35m"
#define ANSI_BG_CYAN "\33[1;46m"
#define ANSI_BG_WHITE "\33[1;47m"
#define ANSI_NONE "\33[0m"

#define ANSI_FMT(str, fmt) fmt str ANSI_NONE

// 不可配置输出
#define raw_puts(s) puts(s)
// 不可配置输出fp
#define raw_out_fp(fp, ...)       \
  do                              \
  {                               \
    if (fp)                       \
    {                             \
      fprintf(fp, ##__VA_ARGS__); \
      fflush(fp);                 \
    }                             \
  } while (0)
// 不可配置输出
#define raw_stdout(...) raw_out_fp(stdout, ##__VA_ARGS__)
// 不可配置同时输出fp
#define raw_all_fp(fp, fmt, ...)            \
  do                                        \
  {                                         \
    raw_out_fp(stdout, fmt, ##__VA_ARGS__); \
    raw_out_fp(fp, fmt, ##__VA_ARGS__);     \
  } while (0)
// 不可配置同时输出
#define raw_all(fmt, ...) raw_all_fp(log_fp, fmt, ##__VA_ARGS__)
// 不可配置同时输出并附带时间戳fp
#define raw_all_timestamp_fp(fp, fmt, ...)             \
  do                                                   \
  {                                                    \
    const char *str = get_time_stamp_str();            \
    raw_out_fp(stdout, "%s " fmt, str, ##__VA_ARGS__); \
    raw_out_fp(fp, "%s " fmt, str, ##__VA_ARGS__);     \
  } while (0)

#ifdef CONFIG_LOG_STDOUT
#define log_stdout(...) raw_out_fp(stdout, __VA_ARGS__)
#else
#define log_stdout(...)
#endif

#ifdef CONFIG_LOG_FILE
#define log_file(...) raw_out_fp(log_fp, __VA_ARGS__)
#else
#define log_file(...)
#endif

#if defined(CONFIG_LOG_STDOUT) || defined(CONFIG_LOG_FILE)
#define log_all(...)         \
  do                         \
  {                          \
    log_stdout(__VA_ARGS__); \
    log_file(__VA_ARGS__);   \
  } while (0)
#define log_all_timestamp(fmt, ...)            \
  do                                           \
  {                                            \
    const char *str = get_time_stamp_str();    \
    log_stdout("%s " fmt, str, ##__VA_ARGS__); \
    log_file("%s " fmt, str, ##__VA_ARGS__);   \
  } while (0)
#else
#define log_all(...)
#define log_all_timestamp(fmt, ...)
#endif

const char* get_time_stamp_str(void);

#endif
