#include <common.h>
#include <utils.h>
#include <device/vdev.h>
#ifndef CONFIG_TARGET_AM
#include <SDL2/SDL.h>
#endif

#define NR_VDEV_ITEMS 16

static int nr_vdev_items = 0;
static vdev_item_t vdev_items[NR_VDEV_ITEMS] = {};

static void report_vdev_overlap(const char* name1, paddr_t l1, paddr_t r1, const char* name2,
                                paddr_t l2, paddr_t r2)
{
    panic("VDEV region %s@[" FMT_PADDR ", " FMT_PADDR
          "] is overlapped "
          "with %s@[" FMT_PADDR ", " FMT_PADDR "]",
          name1, l1, r1, name2, l2, r2);
}

static const char* vdev_type_to_str(vdev_type_t type)
{
    static const char* strs[] = {
        "IVALID",
        "MEM",
        "INNER_DEV",
        "EXTER_DEV",
    };

    return strs[type];
}

void vdev_update()
{
    // TODO 实现 device_update 功能
}

void vdev_vga_clear_event_queue()
{
    // TODO 实现 sdl_clear_event_queue 功能
}

void init_vdev()
{
    // TODO init vdev
    Log("====== Init vdev");
}

word_t vdev_read(paddr_t addr, int len)
{
    // TODO 实现 mmio_read 功能
    return 0;
}

void vdev_write(paddr_t addr, int len, word_t data)
{
    // TODO 实现 mmio_write 功能
}

void add_vdev_item(vdev_type_t type, const char* name, paddr_t addr, void* raw_mem, uint32_t len,
                   vdev_handler_t handler)
{
    assert(nr_vdev_items < NR_VDEV_ITEMS);
    paddr_t startaddr = addr, endaddr = addr + len;
    vdev_item_t* new_item = &vdev_items[nr_vdev_items];

    vdev_item_t* start_item = find_vdev_item(startaddr);
    vdev_item_t* end_item = find_vdev_item(endaddr);
    if (start_item) {
        report_vdev_overlap(name, startaddr, endaddr, start_item->name, start_item->startaddr, start_item->endaddr);
    } else if (end_item) {
        report_vdev_overlap(name, startaddr, endaddr, end_item->name, end_item->startaddr, end_item->endaddr);
    }

    *new_item = (vdev_item_t){
        .type = type,
        .name = name,
        .startaddr = startaddr,
        .endaddr = endaddr,
        .raw_mem = raw_mem,
        .handler = handler,
    };
    Log("Add vdev '%s'(%s) at  [" FMT_PADDR ", " FMT_PADDR ")", new_item->name,
        vdev_type_to_str(new_item->type), new_item->startaddr, new_item->endaddr);

    ++nr_vdev_items;
}

vdev_item_t* find_vdev_item(paddr_t addr)
{
    for (int idx = 0; idx < ARRLEN(vdev_items); ++idx)
    {
        vdev_item_t* item = &vdev_items[idx];
        if (addr < item->endaddr && addr >= item->startaddr)
        {
            return item;
        }
    }

    return NULL;
}
