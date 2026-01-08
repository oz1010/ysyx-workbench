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

#include <string>
#include <common.h>

#ifndef CONFIG_TARGET_AM
FILE *log_fp = NULL;
const char *log_file_path = "";
FILE *perf_fp = NULL;
FILE *icbin_fp = NULL;
FILE *dcbin_fp = NULL;
extern std::string cfg_output;
extern std::string cfg_log_name;
extern std::string cfg_perf_name;
extern std::string cfg_icbin_name;
extern std::string cfg_dcbin_name;

void init_log() {
  Assert(!cfg_output.empty(), "Output directory is empty");

#if CONFIG_LOG_FILE
  std::string log_file = cfg_output + "/" + (cfg_log_name.empty() ? "npc-log.txt" : cfg_log_name);
  log_file_path = log_file.c_str();
  if (!log_file.empty()) {
    FILE *fp = fopen(log_file.c_str(), "w");
    Assert(fp, "Can not open '%s'", log_file.c_str());
    log_fp = fp;
  }
  Log("Log is written to %s", log_file.c_str());
#else
  Log("Log is written to none");
#endif

#if CONFIG_PERF_MONITOR
  std::string perf_file = cfg_output + "/" + (cfg_perf_name.empty() ? "npc-monitor.bin" : cfg_perf_name);
  FILE *fp = fopen(perf_file.c_str(), "wb");
  Assert(fp, "Can not open '%s'", perf_file.c_str());
  perf_fp = fp;
  Log("Perf data is written to %s", perf_file.c_str());
#else
  Log("Perf data is written to none");
#endif

#if CONFIG_ICACHE_BIN
  std::string icbin_file = cfg_output + "/" + (cfg_icbin_name.empty() ? "npc-inst.bin" : cfg_icbin_name);
  icbin_fp = fopen(icbin_file.c_str(), "wb");
  Assert(icbin_fp, "Can not open '%s'", icbin_file.c_str());
  Log("icache bin is written to %s", icbin_file.c_str());
#else
  Log("icache bin is written to none");
#endif

#if CONFIG_DCACHE_BIN
  std::string dcbin_file = cfg_output + "/" + (cfg_dcbin_name.empty() ? "npc-data.bin" : cfg_dcbin_name);
  dcbin_fp = fopen(dcbin_file.c_str(), "wb");
  Assert(dcbin_fp, "Can not open '%s'", dcbin_file.c_str());
  Log("dcache bin is written to %s", dcbin_file.c_str());
#else
  Log("dcache bin is written to none");
#endif

}

#endif
