#include <am.h>
#include <nemu.h>
#include <klib.h>

#define SYNC_ADDR (VGACTL_ADDR + 4)

static uint32_t screen_width = 0; // default: 400
static uint32_t screen_height = 0; // default: 300

void __am_gpu_init() {
  uint32_t i;
  uint32_t vga_val = inl(VGACTL_ADDR);
  uint32_t w = (vga_val >> 16) & 0xFFFF;
  uint32_t h = (vga_val >> 0) & 0xFFFF;
  screen_width = w;
  screen_height = h;

  uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;
  for (i = 0; i < w * h; i ++) fb[i] = 0;
  outl(SYNC_ADDR, 1);
}

void __am_gpu_config(AM_GPU_CONFIG_T *cfg) {
  *cfg = (AM_GPU_CONFIG_T) {
    .present = true, .has_accel = false,
    .width = screen_width, .height = screen_height,
    .vmemsz = screen_width*screen_height*sizeof(uint32_t)
  };
}

void __am_gpu_fbdraw(AM_GPU_FBDRAW_T *ctl) { 
  uint32_t *fb = (uint32_t *)(uintptr_t)FB_ADDR;
  uint32_t *color_buf = (uint32_t *)ctl->pixels;

  // for (uint32_t y=0; y<ctl->h; ++y)
  //   memcpy(&fb[(ctl->y+y)*screen_width + ctl->x], &color_buf[y*ctl->w], ctl->w*sizeof(color_buf[0]));
  
  for (uint32_t y=0; y<ctl->h; ++y)
    for (uint32_t x=0; x<ctl->w; ++x)
      fb[(ctl->y+y)*screen_width + x + ctl->x] = color_buf[y*ctl->w + x];

  if (ctl->sync) {
    outl(SYNC_ADDR, 1);
  }
}

void __am_gpu_status(AM_GPU_STATUS_T *status) {
  status->ready = true;
}
