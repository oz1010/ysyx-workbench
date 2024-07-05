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

#include "sdb.h"

extern word_t expr(char *e, bool *success);

#define NR_WP 32
#define WP_STR_BUF_MAX 64

typedef struct watchpoint {
  int NO;
  struct watchpoint *next;

  /* Add more members if necessary */
  char expr_str[WP_STR_BUF_MAX];
  word_t expr_val;

} WP;

static WP wp_pool[NR_WP] = {};
static WP *head = NULL, *free_ = NULL;

void init_wp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

/* Implement the functionality of watchpoint */
WP* new_wp()
{
  assert(free_);
  WP* node = free_;
  free_ = node->next;
  node->next = head;
  head = node;
  return node;
}

void free_wp(WP *wp)
{
  assert(wp);
  assert(head);
  WP* node = head;
  WP* wp_next = wp->next;

  wp->next = free_;
  free_ = wp;

  if (head == wp){
    head = head->next;
    return;
  }

  do{
    if (node->next==wp){
      node->next = wp_next;
      return;
    }
    node = node->next;
  }
  while(node);

  assert(node);
}

void add_wp(char *str)
{
  bool success = true;
  word_t val = expr(str, &success);
  if (success){
    WP* wp = new_wp();
    strncpy(wp->expr_str, str, sizeof(wp->expr_str) - 1);
    wp->expr_val = val;
    printf("watchpoint %d: %s\n", wp->NO, wp->expr_str);
  }
  else
    printf("expression is error\n");
}

void show_wp()
{
  printf("%-8s %-15s %-s\n", "Num", "Type", "What");
  WP* node = head;
  while (node){
  printf("%-8d %-15s %-s\n", node->NO, "watchpoint", node->expr_str);
    node = node->next;
  }
}

bool scan_wp()
{
  bool stop = false;
  WP* node = head;
  while (node){
    bool success = true;
    word_t val = expr(node->expr_str, &success);
    if (success && val != node->expr_val){
      stop = true;
      printf("Matched watchpoint %d: %s | %u=>%u %#x=>%#x.\n", node->NO, node->expr_str, node->expr_val, val, node->expr_val, val);
      // node->expr_val = val;
    }
    node = node->next;
  }

  return stop;
}
