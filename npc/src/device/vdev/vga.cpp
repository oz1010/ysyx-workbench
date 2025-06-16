#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

static uint8_t *fb_base = NULL;
static const uint32_t fb_size = 2*1024*1024;
static uint8_t *ctrl_base = NULL;
static const uint32_t ctrl_size = 4096;

void init_vga()
{
    fb_base = new_vmem(fb_size);
    add_vdev_item(VDEV_INNER, "vga fb", CONFIG_NVBOARD_VGA_FB_BASE_ADDR, fb_base, fb_size, (VDEV_ATTR_READ|VDEV_ATTR_WRITE), NULL);

    ctrl_base = new_vmem(ctrl_size);
    add_vdev_item(VDEV_INNER, "vga ctrl", CONFIG_NVBOARD_VGA_CTRL_BASE_ADDR, ctrl_base, ctrl_size, (VDEV_ATTR_READ|VDEV_ATTR_WRITE), NULL);
}
