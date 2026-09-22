#include <common.h>
#include <utils.h>
#include <device/vdev.h>
#include "memory/paddr.h"
#include "memory/vmem.h"
#ifndef CONFIG_TARGET_AM
#include <SDL2/SDL.h>
#endif
#include "isa.h"
#include "trace.h"
#include "device/alarm.h"

static int vdev_items_cnt = 0;
vdev_item_t vdev_items[NR_VDEV_ITEMS] = {};

void init_clint();
void init_uart16550();
void init_spi_master();
void init_gpio();
void init_ps2();
void init_vga();
void send_key(uint8_t, bool);
void vga_update_screen();

static void report_vdev_overlap(const char* name1, paddr_t l1, paddr_t r1, const char* name2,
                                paddr_t l2, paddr_t r2)
{
    panic("VDEV region %s@[" FMT_PADDR ", " FMT_PADDR
          ") is overlapped "
          "with %s@[" FMT_PADDR ", " FMT_PADDR ")",
          name1, l1, r1, name2, l2, r2);
}

const char* vdev_type_str(vdev_type_t type)
{
    static const char* strs[] = {
        "IVALID",
        "MEMORY",
        "INNER",
        "EXTER",
    };

    return strs[type];
}

void vdev_update()
{
    static uint64_t last = 0;
    uint64_t now = get_time();
    if ((now - last) < 1000000 / VDEV_UPDATE_HZ)
    {
        return;
    }
    last = now;

    IFDEF(CONFIG_HAS_VGA, vga_update_screen());

#if CONFIG_HAS_VGA
    SDL_Event event;
    while (SDL_PollEvent(&event))
    {
        switch (event.type)
        {
            case SDL_QUIT:
                npc_ctx.state = NPC_QUIT;
                break;
#if defined(CONFIG_HAS_KEYBOARD)
            // If a key was pressed
            case SDL_KEYDOWN:
            case SDL_KEYUP:
            {
                uint8_t k = event.key.keysym.scancode;
                bool is_keydown = (event.key.type == SDL_KEYDOWN);
                send_key(k, is_keydown);
                break;
            }
#endif
            default:
                break;
        }
    }
#endif
}

void vdev_vga_clear_event_queue()
{
    // TODO 实现 sdl_clear_event_queue 功能
    panic("TODO %s %s:%d", __FUNCTION__, __FILE__, __LINE__);
}

void init_vdev()
{
    IFDEF(CONFIG_HAS_CLINT, init_clint());
    IFDEF(CONFIG_HAS_UART, init_uart16550());
    IFDEF(CONFIG_HAS_SPI_MASTER, init_spi_master());
    IFDEF(CONFIG_HAS_GPIO, init_gpio());
    IFDEF(CONFIG_HAS_PS2, init_ps2());
    IFDEF(CONFIG_HAS_NVBOARD_VGA, init_vga());
}

word_t vdev_read_with_trace(vdev_item_t* vdev, paddr_t addr, int len, bool trace_en)
{
    if (vdev == NULL)
    {
        panic("read item address (" FMT_PADDR ") is out of bound at pc = " FMT_WORD, addr, cpu.pc);
        return 0;
    }

    word_t data;
    if (vdev->handler)
        vdev->handler(vdev, false, addr, len, &data);

    if (!trace_en)
        return data;

    if (vdev->type == VDEV_MEM)
    {
        MTRACE_ADD("%s R [%#.8x] => %#.8x %d", vdev->name, addr, data, len);
    }
    else if (vdev->type == VDEV_EXTER)
    {
        DTRACE_LOG("<DT> <VDEV> %s R [%#.8x] => %#.8x %d", vdev->name, addr, data, len);
    }
    return data;
}

void vdev_write_with_trace(vdev_item_t* vdev, paddr_t addr, int len, word_t data, bool trace_en)
{
    if (vdev == NULL)
    {
        panic("write item address (" FMT_PADDR ") is out of bound at pc = " FMT_WORD, addr, cpu.pc);
        return;
    }

    if (vdev->handler)
        vdev->handler(vdev, true, addr, len, &data);

    if (!trace_en)
        return;

    if (vdev->type == VDEV_MEM)
    {
        MTRACE_ADD("%s W [%#.8x] <= %#.8x %d", vdev->name, addr, data, len);
    }
    else if (vdev->type == VDEV_EXTER)
    {
        DTRACE_LOG("<DT> <VDEV> %s W [%#.8x] <= %#.8x %d", vdev->name, addr, data, len);
    }
}

word_t vdev_read(vdev_item_t* vdev, paddr_t addr, int len)
{
    return vdev_read_with_trace(vdev, addr, len, false);
}

void vdev_write(vdev_item_t* vdev, paddr_t addr, int len, word_t data)
{
    vdev_write_with_trace(vdev, addr, len, data, false);
}

vdev_item_t* add_vdev_item(vdev_type_t type, const char* name, paddr_t addr, uint8_t* raw_mem,
                           uint32_t len, uint32_t attr, vdev_handler_t handler)
{
    assert(vdev_items_cnt < NR_VDEV_ITEMS);
    paddr_t startaddr = addr, endaddr = addr + len;
    vdev_item_t* new_item = &vdev_items[vdev_items_cnt];

    vdev_item_t* start_item = find_vdev_item(startaddr);
    vdev_item_t* end_item = find_vdev_item(endaddr);
    if (start_item)
    {
        report_vdev_overlap(name, startaddr, endaddr, start_item->name, start_item->startaddr,
                            start_item->endaddr);
    }
    else if (end_item)
    {
        report_vdev_overlap(name, startaddr, endaddr, end_item->name, end_item->startaddr,
                            end_item->endaddr);
    }

    *new_item = (vdev_item_t){
        .type = type,
        .name = name,
        .startaddr = startaddr,
        .endaddr = endaddr,
        .raw_mem = raw_mem,
        .handler = handler,
        .attr = attr,
    };
    if (type != VDEV_MEM)
    {
        Log("Add vdev '%s'(%s) at  [" FMT_PADDR ", " FMT_PADDR ")-%s", new_item->name,
            vdev_type_str(new_item->type), new_item->startaddr, new_item->endaddr, size_str(len));
    }

    ++vdev_items_cnt;

    return new_item;
}

vdev_item_t* find_vdev_item(paddr_t addr)
{
    vdev_item_t* matched_vdev = NULL;

    for (int idx = 0; idx < ARRLEN(vdev_items); ++idx)
    {
        vdev_item_t* vdev = &vdev_items[idx];
        if (!vdev->name)
            continue;

        if (addr < vdev->endaddr && addr >= vdev->startaddr)
        {
            matched_vdev = vdev;
            break;
        }
    }

    return matched_vdev;
}

/**
 * 查找地址所属存储体在STORAGE列表（记录文件中存储体名称列表）中的索引
 *   - 仅匹配VDEV_MEM类型的设备，索引按注册顺序从0开始编号
 *   - 地址不属于任何存储体时返回-1
 */
int find_vdev_storage_index(paddr_t addr)
{
    int storage_idx = 0;

    for (int idx = 0; idx < ARRLEN(vdev_items); ++idx)
    {
        vdev_item_t* vdev = &vdev_items[idx];
        if (!vdev->name || vdev->type != VDEV_MEM)
            continue;

        if (addr < vdev->endaddr && addr >= vdev->startaddr)
        {
            return storage_idx;
        }
        storage_idx++;
    }

    return -1;
}

void show_vdev(void)
{
    raw_stdout("valid vdev info is below:\n");
    for (int idx = 0; idx < ARRLEN(vdev_items); ++idx)
    {
        vdev_item_t* vdev = &vdev_items[idx];
        if (!vdev->name)
            continue;

        raw_stdout("    %-12s - [0x%08x 0x%08x) attr: %s%s%s type:%-8s\n", vdev->name,
                   vdev->startaddr, vdev->endaddr, (vdev->attr & VDEV_ATTR_READ) != 0 ? "r" : "-",
                   (vdev->attr & VDEV_ATTR_WRITE) != 0 ? "w" : "-",
                   (vdev->attr & VDEV_ATTR_EXEC) != 0 ? "x" : "-", vdev_type_str(vdev->type));
    }
}
