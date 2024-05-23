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
#include <cpu/cpu.h>
#include <errno.h>
#include <readline/readline.h>
#include <readline/history.h>
#include "sdb.h"
#include "memory/vaddr.h"

static int is_batch_mode = false;

void init_regex();
void init_wp_pool();
extern void add_wp(char *str);
extern void show_wp();

/* We use the `readline' library to provide more flexibility to read from stdin. */
static char* rl_gets() {
  static char *line_read = NULL;

  if (line_read) {
    free(line_read);
    line_read = NULL;
  }

  line_read = readline("(nemu) ");

  if (line_read && *line_read) {
    add_history(line_read);
  }

  return line_read;
}

static int cmd_c(char *args) {
  cpu_exec(-1);
  return 0;
}

static int cmd_si(char *args)
{
  uint64_t next = 1;
  if (args)
  {
    next = strtoull(args, NULL, 10);
  }
  cpu_exec(next);
  return 0;
}

static int cmd_info(char *args)
{
  if (args)
  {
    if (strcmp(args, "r") == 0)
      isa_reg_display();
    else if (strcmp(args, "w") == 0)
      show_wp();
    else
      printf("Error format: info r/w\n");
  }
  else
  {
    printf("Miss args: info r/w\n");
  }
  return 0;
}

static int cmd_x(char *args)
{
  char *argv[2] = {0};
  char *args_end = args + (args!=NULL?strlen(args):0);
  int argc = 0;
  while (args<args_end && argc<2)
  {
    argv[argc] = strtok(args, " ");
    if (!argv[argc])
    {
      break;
    }
    args+= strlen(argv[argc]) + 1;
    ++argc;
  }

  if (argc < 1)
  {
    printf("Miss args: x <LEN> [ADDR]\n");
    return 0;
  }

  uint32_t len = strtoul(argv[0], NULL, 10);
  vaddr_t addr = 0x80000000;
  size_t line_len = 16;

  if (argc > 1)
  {
    addr = strtoul(argv[1], NULL, 16);
  }
  uint32_t i=0,j=0;
  for (i=0; i<len; ) {
    printf("0x%8x:", addr);
    for (j=0; j<line_len&&i<len; ++i,++j){
      word_t value = vaddr_ifetch(addr, 1) & 0xFF;
      printf("%s%02x", (j!=0&&j%4==0?"   ":" "), value);
      addr += 1;
    }
    if (j%line_len == 0)
    printf("\n");
  }

  if (j%line_len != 0)
    printf("\n");

  return 0;
}

static int cmd_p(char *args) {
  bool success = true;
  if (!args)
  {
    printf("miss args\n");
    return 0;
  }
  word_t val = expr(args, &success);
  if (success)
  {
    printf("val = %u\n", val);
    printf("hex = %#x\n", val);
  }
  else
    printf("expression is error\n");
  return 0;
}

static int cmd_w(char *args) {
  if (!args){
    printf("miss args\n");
    return 0;
  }

  add_wp(args);
  return 0;
}

static int cmd_q(char *args) {
  nemu_state.state = NEMU_QUIT;
  return -1;
}

static int cmd_test(char *args) {
  static uint32_t result;
  static char buf[65536 + 128] = {};
  const char* file_name = NULL;

  if (!args) {
    printf("miss test case, support: expr\n");
    return 0;
  }

  char *args_end = args + strlen(args);
  char *test_case = strtok(args, " ");
  if (!test_case) {
    printf("miss input test case\n");
    return 0;
  }
  args = test_case + strlen(test_case) + 1;
  if (args>=args_end){
    args = NULL;
  }

  if (0==strcmp(test_case, "expr")){
    if (args) {
      file_name = args;
    }

    const char* nemu_home = getenv("NEMU_HOME");
    if (!nemu_home) {
      nemu_home = "/home/johnny/big-proj/mk-cpu-lesson-dev/NJU-ProjectN_nemu";
    }

    char file_path[1024] = {0};
    if (file_name) {
      strcat(file_path, file_name);
    } else {
      strcat(&file_path[strlen(file_path)], nemu_home);
      strcat(&file_path[strlen(file_path)], "/tools/gen-expr/build/input");
    }
    
  printf("load test expr file|%s\n", file_path);

    FILE* fd = fopen(file_path, "rb");
    if (!fd) {
      printf("open file error, file|%s err|%s\n", file_path, strerror(errno));
      return 0;
    }

    uint32_t cnt = 0;
    uint32_t suc_cnt=0;
    uint32_t err_cnt=0;
    while( EOF != fscanf(fd, "%u %s\n", &result, buf)){
      bool success = false;
      ++cnt;
      uint32_t expr_ret = expr(buf, &success);
      if (!success || expr_ret!=result){
        printf("case-%u failed: %u %u %lu\n", cnt, result, expr_ret, strlen(buf));
        ++err_cnt;
      } else {
        ++suc_cnt;
      }
    }

    printf("test expr case total|%u error|%u success|%u\n", cnt, err_cnt, suc_cnt);
  }else{
    printf("unknown test case|%s, support: expr.\n", test_case);
  }

  return 0;
}

static int cmd_help(char *args);

static struct {
  const char *name;
  const char *description;
  int (*handler) (char *);
} cmd_table [] = {
  { "help", "Display information about all supported commands", cmd_help },
  { "c", "Continue the execution of the program", cmd_c },
  { "si", "Step program until it reaches a different source line.", cmd_si},
  { "info", "Generic command for showing things about the program being debugged.", cmd_info},
  { "x", "Show the value of memory.", cmd_x},
  { "p", "Print value of expression EXP.", cmd_p},
  { "w", "Set a watchpoint for EXPRESSION.", cmd_w},
  { "test", "Test program.", cmd_test},
  { "q", "Exit NEMU", cmd_q },

  /* Add more commands */

};

#define NR_CMD ARRLEN(cmd_table)

static int cmd_help(char *args) {
  /* extract the first argument */
  char *arg = strtok(NULL, " ");
  int i;

  if (arg == NULL) {
    /* no argument given */
    for (i = 0; i < NR_CMD; i ++) {
      printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
    }
  }
  else {
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(arg, cmd_table[i].name) == 0) {
        printf("%s - %s\n", cmd_table[i].name, cmd_table[i].description);
        return 0;
      }
    }
    printf("Unknown command '%s'\n", arg);
  }
  return 0;
}

void sdb_set_batch_mode() {
  is_batch_mode = true;
}

void sdb_mainloop() {
  if (is_batch_mode) {
    cmd_c(NULL);
    return;
  }

  static char last_str[1024] = "";
  for (char *str; (str = rl_gets()) != NULL; ) {

    /* record last command string */
    if (*str)
    {
      strcpy(last_str, str);
    } 
    else
    {
      if (strcmp(last_str, "si") == 0)
        str = last_str;
    }

    char *str_end = str + strlen(str);

    /* extract the first token as the command */
    char *cmd = strtok(str, " ");
    if (cmd == NULL) { continue; }

    /* treat the remaining string as the arguments,
     * which may need further parsing
     */
    char *args = cmd + strlen(cmd) + 1;
    if (args >= str_end) {
      args = NULL;
    }

#ifdef CONFIG_DEVICE
    extern void sdl_clear_event_queue();
    sdl_clear_event_queue();
#endif

    int i;
    for (i = 0; i < NR_CMD; i ++) {
      if (strcmp(cmd, cmd_table[i].name) == 0) {
        if (cmd_table[i].handler(args) < 0) { return; }
        break;
      }
    }

    if (i == NR_CMD) { printf("Unknown command '%s'\n", cmd); }
  }
}

void init_sdb() {
  /* Compile the regular expressions. */
  init_regex();

  /* Initialize the watchpoint pool. */
  init_wp_pool();
}
