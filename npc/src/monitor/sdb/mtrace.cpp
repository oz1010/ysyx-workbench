#include "common/list.h"
#include "common.h"

#define NR_MTRACE_MAX 128

typedef struct
{
    list_head_t item;
    vaddr_t pc;        // 访问内存的指令地址
    vaddr_t mem_addr;  // 访问内存的地址
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
}

mtrace_item_t *new_mtrace(){
    mtrace_item_t *mtrace = list_entry(free_head.next, mtrace_item_t, item);
    if (&mtrace->item == &free_head) {
        mtrace = list_entry(used_head.prev, mtrace_item_t, item);
    }

    list_del(&mtrace->item);
    memset(mtrace, 0, sizeof(*mtrace));
    list_add_tail(&mtrace->item, &used_head);

    return mtrace;
}

void add_mtrace(vaddr_t pc, vaddr_t mem_addr)
{
    mtrace_item_t*mtrace = new_mtrace();
    mtrace->pc = pc;
    mtrace->mem_addr = mem_addr;
}

void dump_mtrace()
{
    // TODO 当调用时，将数据写入文件
}
