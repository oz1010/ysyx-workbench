#ifndef __V_DEV_H__
#define __V_DEV_H__

#include "common.h"
#include "memory/vmem.h"

#define NR_VDEV_ITEMS 16
#define VDEV_UPDATE_HZ 60

#define VDEV_ATTR_READ           (1<<0)
#define VDEV_ATTR_WRITE          (1<<1)
#define VDEV_ATTR_EXEC           (1<<2)

// 读写处理函数
typedef void (*vdev_handler_t)(void *item_arg, bool is_write, vaddr_t addr, int len, word_t *data);

typedef enum
{
    VDEV_IVALID,        // 无效设备
    VDEV_MEM,           // 内存设备
    VDEV_INNER,         // 内置设备，比如：serial
    VDEV_EXTER,         // 外置设备，比如：clint
} vdev_type_t;

typedef struct
{
    vdev_type_t type;
    const char* name;
    paddr_t startaddr;
    paddr_t endaddr; /* 不包含边界 */
    uint8_t* raw_mem;
    vdev_handler_t handler;
    uint32_t attr;  /* 属性权限 */
} vdev_item_t;

vdev_item_t* add_vdev_item(vdev_type_t type, const char* name, paddr_t addr, uint8_t *raw_mem, uint32_t len, uint32_t attr, vdev_handler_t handler);
word_t vdev_read(vdev_item_t* vdev, paddr_t addr, int len);
void vdev_write(vdev_item_t* vdev, paddr_t addr, int len, word_t data);
word_t vdev_read_with_trace(vdev_item_t* vdev, paddr_t addr, int len, bool trace_en);
void vdev_write_with_trace(vdev_item_t* vdev, paddr_t addr, int len, word_t data, bool trace_en);
vdev_item_t *find_vdev_item(paddr_t addr);
int find_vdev_storage_index(paddr_t addr);
void show_vdev(void);
const char* vdev_type_str(vdev_type_t type);

#endif
