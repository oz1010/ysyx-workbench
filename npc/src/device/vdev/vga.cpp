#include "device/vdev.h"
#include "generated/autoconf.h"
#include "utils.h"

uint32_t *get_vsimu_vga_fb_addr();
uint32_t *get_vsimu_vga_ctrl_regs_addr();

#define VGA_CTRL_WIDTH 640
#define VGA_CTRL_HIGH 480

typedef struct
{
    int x, y;
    int w, h;
    vaddr_t pixels;
} vga_dma_data_t;

static uint32_t *vga_frame_buffer = NULL;
static uint32_t *vga_ctrl_regs = NULL;
static vga_dma_data_t vga_dma_data = {0};
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
                // 强制刷新
                vga_ctrl_regs[1] = *data;
                break;
            
            case 0x22000100:
                vga_dma_data.x = *data;
                break;
            case 0x22000104:
                vga_dma_data.y = *data;
                break;
            case 0x22000108:
                vga_dma_data.w = *data;
                break;
            case 0x2200010c:
                vga_dma_data.h = *data;
                break;
            case 0x22000110:
                vga_dma_data.pixels = (*data);
                if (*data) {
                    // 数据拷贝到frame buffer区域
                    vdev_item_t *vdev = find_vdev_item(vga_dma_data.pixels);
                    if (vdev) {
                        uint8_t *color_buf = &vdev->raw_mem[vga_dma_data.pixels-vdev->startaddr];
                        // printf("====== vga dma update src is %s x %d y %d w %d h %d pixels %x\n", vdev->name, vga_dma_data.x, vga_dma_data.y, vga_dma_data.w, vga_dma_data.h, vga_dma_data.pixels);
                        for (int y=0; y<vga_dma_data.h; ++y)
                            memcpy(&vga_frame_buffer[(vga_dma_data.y+y)*VGA_CTRL_WIDTH + vga_dma_data.x], &color_buf[y*vga_dma_data.w], sizeof(vga_frame_buffer[0])*vga_dma_data.w);
                    }
                } else {
                    // 区域清零
                    // printf("====== vga dma update fb %#lx x %d y %d w %d h %d pixels %x\n", *(uint64_t *)&vga_frame_buffer[0], vga_dma_data.x, vga_dma_data.y, vga_dma_data.w, vga_dma_data.h, vga_dma_data.pixels);
                    for (int y=0; y<vga_dma_data.h; ++y)
                        memset(&vga_frame_buffer[(vga_dma_data.y+y)*VGA_CTRL_WIDTH + vga_dma_data.x], 0x00, sizeof(vga_frame_buffer[0])*vga_dma_data.w);
                }
                memset(&vga_dma_data, 0, sizeof(vga_dma_data));
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
                *data = ((VGA_CTRL_WIDTH & 0xFFFF) << 16) | (VGA_CTRL_HIGH & 0xFFFF);
                break;

            case 0x22000004:
                *data = vga_ctrl_regs[1];
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

    vga_frame_buffer = get_vsimu_vga_fb_addr();
    vga_ctrl_regs = get_vsimu_vga_ctrl_regs_addr();
}
