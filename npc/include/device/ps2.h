#ifndef __DEVICE_PS2_H__
#define __DEVICE_PS2_H__

#include <stdbool.h>
#include <stdint.h>

void terminal_ps2_init(uint8_t *clk, uint8_t *data);
void terminal_ps2_update();
void terminal_ps2_set_active(bool active);
void terminal_ps2_shutdown();

#endif
