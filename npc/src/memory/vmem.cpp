#include "memory/vmem.h"
#include "memory/vaddr.h"
#include "memory/paddr.h"

#define VDEV_RAW_MEM_MAX (1024 * 1024 * 1024)
static uint8_t* vdev_raw_mem = NULL;
static uint8_t* new_raw_mem = NULL;

void init_vmem(void)
{
    if (!vdev_raw_mem)
    {
        vdev_raw_mem = (uint8_t*)malloc(VDEV_RAW_MEM_MAX+PAGE_MASK);
        assert(vdev_raw_mem);
        new_raw_mem = vdev_raw_mem;

        Log("Init vdev memory, p:%p size:%s", vdev_raw_mem, size_str(VDEV_RAW_MEM_MAX));
    }
}

uint8_t* new_vmem(int size)
{
    uint8_t* p = new_raw_mem;
    // page aligned
    size = (size + (PAGE_SIZE - 1)) & ~PAGE_MASK;
    new_raw_mem += size;
    assert(new_raw_mem - vdev_raw_mem < VDEV_RAW_MEM_MAX);
    return p;
}
