#include "common/mtrace.h"
#include "common/list.h"
#include "generated/autoconf.h"

#define NR_MTRACE_MAX 128

static const char *mtrace_file = "mtrace.log";
static FILE *mtrace_fp = NULL;

typedef struct
{
    list_head_t item;
    mtrace_opt_t opt;  // 访问内存的操作
    vaddr_t pc;        // 访问内存的指令地址
    vaddr_t mem_addr;  // 访问内存的地址
    word_t mem_value;  // 访问内存的值
} mtrace_item_t;

static mtrace_item_t items[NR_MTRACE_MAX] = {};
static list_head_t used_head = LIST_HEAD_INIT(used_head);
static list_head_t free_head = LIST_HEAD_INIT(free_head);

void init_mtrace()
{
    for (size_t i = 0; i < NR_MTRACE_MAX; i++)
    {
        mtrace_item_t *mtrace = &items[i];
        memset(mtrace, 0, sizeof(*mtrace));
        list_add_tail(&free_head, &mtrace->item);
    }

    mtrace_fp = fopen(mtrace_file, "w");
    Assert(mtrace_fp, "Can not open '%s'", mtrace_file);
    Log("mtrace is written to %s", mtrace_file);
}

mtrace_item_t *new_mtrace()
{
    mtrace_item_t *mtrace = list_entry(free_head.next, mtrace_item_t, item);
    if (&mtrace->item == &free_head)
    {
        mtrace = list_entry(used_head.prev, mtrace_item_t, item);
    }

    list_del(&mtrace->item);
    memset(mtrace, 0, sizeof(*mtrace));
    list_add_tail(&mtrace->item, &used_head);

    return mtrace;
}

void add_mtrace(mtrace_opt_t opt, vaddr_t pc, vaddr_t mem_addr, word_t mem_value)
{
    mtrace_item_t *mtrace = list_entry(free_head.next, mtrace_item_t, item);
    if (&mtrace->item == &free_head)
    {
        dump_mtrace();
    }

    mtrace = new_mtrace();
    mtrace->opt = opt;
    mtrace->pc = pc;
    mtrace->mem_addr = mem_addr;
}

void dump_mtrace()
{
    // 当调用时，将数据写入文件
    mtrace_item_t *mtrace = NULL;
    while ((mtrace = list_entry(used_head.next, mtrace_item_t, item)) &&
           &mtrace->item != &used_head)
    {
        list_del(&mtrace->item);
        fprintf(mtrace_fp, "%s [%#.8x] %#.8x\n", (mtrace->opt == mtrace_opt_read ? "r" : "w"),
                mtrace->mem_addr, mtrace->mem_value);
        memset(mtrace, 0, sizeof(*mtrace));
        list_add_tail(&mtrace->item, &free_head);
    }
}
