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
#include "common/list.h"
#include "common/point_pool.h"

#define NR_POINT_MAX 32
#define WP_STR_BUF_MAX 64

typedef struct _point_info_s {
  uint64_t id;
  list_head_t item;
  point_type_t type;

  /* Add more members if necessary */
  union {
    struct {
      paddr_t addr;
    } breakpoint;
    struct {
      word_t expr_val;
      char expr_str[WP_STR_BUF_MAX];
    } watchpoint;
  };
} point_info_t;

static point_info_t point_pool[NR_POINT_MAX] = {};
static list_head_t used_head = LIST_HEAD_INIT(used_head);
static list_head_t free_head = LIST_HEAD_INIT(free_head);
static uint64_t id_cnt = 0;

void init_point_pool() {
  int i;
  for (i = 0; i < NR_POINT_MAX; i ++) {
    memset(&point_pool[i], 0, sizeof(point_info_t ));
    list_add_tail(&point_pool[i].item, &free_head);
  }
}

/* Implement the functionality of point */
point_info_t* new_point()
{
  point_info_t* pnode = list_entry(free_head.next, point_info_t, item);
  if (&pnode->item != &free_head)
  {
    list_del(&pnode->item);
    memset(pnode, 0, sizeof(point_info_t ));
    list_add_tail(&pnode->item, &used_head);
    if (id_cnt==UINT64_MAX) id_cnt = 0;
    pnode->id = ++id_cnt;
  } else {
    pnode = NULL;
  }
  assert(pnode);
  return pnode;
}

void free_point(point_info_t *pnode)
{
  assert(pnode);
  list_del(&pnode->item);
  memset(pnode, 0, sizeof(point_info_t ));
  list_add_tail(&pnode->item, &free_head);
}

void add_point(point_type_t type, char *str)
{
  point_info_t* point = new_point();
  if (!point) {
    printf("new point failed\n");
    return;
  }

  bool success = true;
  word_t val = expr(str, &success);
  if (success) {
    switch (type) {
    case POINT_BREAK:
      point->type = type;
      point->breakpoint.addr = val;
      printf("breakpoint %lu: 0x%x\n", point->id, val);
      break;

    case POINT_WATCH:
      point->type = type;
      strncpy(point->watchpoint.expr_str, str, WP_STR_BUF_MAX - 1);
      point->watchpoint.expr_val = val;
      printf("watchpoint %lu: %s\n", point->id, point->watchpoint.expr_str);
      break;

    default:
      printf("unsupport point type: %d\n", type);
      break;
    }
  } else {
    printf("insert %s expr error\n", (point->type==POINT_BREAK?"breakpoint":"watchpoint"));
  }

  if (point->type == POINT_UNKNOWN) {
    free_point(point);
  }
}

void delete_point(uint64_t id)
{
  point_info_t* pnode;
  point_info_t* ptmp;
  int cnt = 0;
  list_for_each_entry_safe(pnode, ptmp, &used_head, item) {
    if ((id==0) || (id==pnode->id)) {
      printf("delete %s %lu\n", (pnode->type==POINT_BREAK?"breakpoint":"watchpoint"), pnode->id);
      ++cnt;
      free_point(pnode);
    }
  }

  if ((id!=0) && (cnt==0)) {
    printf("No point number %lu\n", id);
  }
}

void show_point(point_type_t type)
{
  printf("%-8s %-15s %-s\n", "Num", "Type", "Condition");

  point_info_t* pnode;
  list_for_each_entry(pnode, &used_head, item) {
    if ((type==POINT_ALL) || (pnode->type==type)) {
      if (pnode->type == POINT_BREAK) {
        printf("%-8lu %-15s 0x%-x\n", pnode->id, "breakpoint", pnode->breakpoint.addr);
      } else if (pnode->type == POINT_WATCH) {
        printf("%-8lu %-15s %-s\n", pnode->id, "watchpoint", pnode->watchpoint.expr_str);
      }
    }
  }
}

bool scan_point(point_type_t type)
{
  bool stop = false;

  point_info_t* pnode;
  list_for_each_entry(pnode, &used_head, item) {
    if ((type==POINT_ALL) || (pnode->type==type)) {
      if (pnode->type == POINT_BREAK) {
        if (cpu.pc == pnode->breakpoint.addr){
          stop = true;
          printf("Matched breakpoint %lu at 0x%x\n", pnode->id, pnode->breakpoint.addr);
        }
      } else if (pnode->type == POINT_WATCH) {
        bool success = true;
        word_t val = expr(pnode->watchpoint.expr_str, &success);
        if (success && val != pnode->watchpoint.expr_val){
          stop = true;
          printf("Matched watchpoint %lu: %s | %u=>%u %#x=>%#x.\n", 
            pnode->id, pnode->watchpoint.expr_str, 
            pnode->watchpoint.expr_val, val, 
            pnode->watchpoint.expr_val, val);
          // pnode->watchpoint.expr_val = val;
        }
      }
    }
  }

  return stop;
}
