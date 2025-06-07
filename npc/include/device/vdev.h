#ifndef __V_DEV_H__
#define __V_DEV_H__

#include <common.h>

typedef void (*vdev_handler_t)(uint32_t offset, int len, bool is_write);

typedef enum
{
    VDEV_IVALID,        // 无效设备
    VDEV_MEM,           // 内存设备
    VDEV_INNER_DEV,     // 内置设备，比如：serial
    VDEV_EXTER_DEV,     // 外置设备，比如：clint
} vdev_type_t;

typedef struct
{
    vdev_type_t type;
    const char* name;
    paddr_t startaddr;
    paddr_t endaddr; /* 不包含边界 */
    void* raw_mem;
    struct {
        word_t (*read)(void *mem_item_arg, vaddr_t addr, int len);
        void (*write)(void *mem_item_arg, vaddr_t addr, int len, word_t data);
        vdev_handler_t handler;
    };
} vdev_item_t;

void add_vdev_item(vdev_type_t type, const char* name, paddr_t addr, void *raw_mem, uint32_t len, vdev_handler_t handler);
word_t vdev_read(paddr_t addr, int len);
void vdev_write(paddr_t addr, int len, word_t data);
vdev_item_t *find_vdev_item(paddr_t addr);

#endif
