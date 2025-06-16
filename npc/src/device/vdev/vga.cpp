#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

#define VGA_CTRL_WIDTH 640
#define VGA_CTRL_HIGH 480

static uint8_t *fb_base = NULL;
static const uint32_t fb_size = 2 * 1024 * 1024;
static uint8_t *ctrl_base = NULL;
static const uint32_t ctrl_size = 4096;

void vga_ctrl_handler(void *item_arg, bool is_write, vaddr_t addr, int len, word_t *data)
{
    // vdev_item_t *vdev = (vdev_item_t *)item_arg;
    if (is_write)
    {
        switch (addr)
        {
            case 0x22000004:
                break;
            default:
                Assert(0, "Write vga ctrl is out of range.");
                break;
        }
    }
    else
    {
        switch (addr)
        {
            case 0x22000000:
                *data = ((VGA_CTRL_WIDTH&0xFFFF)<<16) | (VGA_CTRL_HIGH&0xFFFF);
                break;
            default:
                Assert(0, "Read vga ctrl is out of range.");
                break;
        }
    }
}

void init_vga()
{
    fb_base = new_vmem(fb_size);
    add_vdev_item(VDEV_INNER, "vga fb", CONFIG_NVBOARD_VGA_FB_BASE_ADDR, fb_base, fb_size,
                  (VDEV_ATTR_READ | VDEV_ATTR_WRITE), NULL);

    ctrl_base = new_vmem(ctrl_size);
    add_vdev_item(VDEV_EXTER, "vga ctrl", CONFIG_NVBOARD_VGA_CTRL_BASE_ADDR, ctrl_base, ctrl_size,
                  (VDEV_ATTR_READ | VDEV_ATTR_WRITE), vga_ctrl_handler);
}
