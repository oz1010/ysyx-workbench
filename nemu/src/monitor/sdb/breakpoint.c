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
#include "isa.h"

#define NR_WP 32
#define WP_STR_BUF_MAX 64

typedef struct breakpoint {
  int NO;
  struct breakpoint *next;

  /* Add more members if necessary */
  paddr_t addr;
} BP;

static BP wp_pool[NR_WP] = {};
static BP *head = NULL, *free_ = NULL;

void init_bp_pool() {
  int i;
  for (i = 0; i < NR_WP; i ++) {
    wp_pool[i].NO = i;
    wp_pool[i].next = (i == NR_WP - 1 ? NULL : &wp_pool[i + 1]);
  }

  head = NULL;
  free_ = wp_pool;
}

/* Implement the functionality of breakpoint */
BP* new_bp()
{
  assert(free_);
  BP* node = free_;
  free_ = node->next;
  node->next = head;
  head = node;
  return node;
}

void free_bp(BP *bp)
{
  assert(bp);
  assert(head);
  BP* node = head;
  BP* bp_next = bp->next;

  bp->next = free_;
  free_ = bp;

  if (head == bp){
    head = head->next;
    return;
  }

  do{
    if (node->next==bp){
      node->next = bp_next;
      return;
    }
    node = node->next;
  }
  while(node);

  assert(node);
}

void add_bp(paddr_t addr)
{
  BP* bp = new_bp();
  bp->addr = addr;
  printf("breakpoint %d: 0x%x\n", bp->NO, bp->addr);
}

void show_bp()
{
  printf("%-8s %-15s %-s\n", "Num", "Type", "Address");
  BP* node = head;
  while (node){
  printf("%-8d %-15s 0x%-x\n", node->NO, "breakpoint", node->addr);
    node = node->next;
  }
}

bool scan_bp()
{
  bool stop = false;
  BP* node = head;
  while (node){
    if (cpu.pc == node->addr){
      stop = true;
      printf("Matched breakpoint %d at 0x%x\n", node->NO, node->addr);
    }
    node = node->next;
  }

  return stop;
}
