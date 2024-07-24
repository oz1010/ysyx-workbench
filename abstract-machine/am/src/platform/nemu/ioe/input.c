#include <am.h>
#include <nemu.h>

#define KEYDOWN_MASK 0x8000
#define KEY_VALUE_MASK (KEYDOWN_MASK-1)

void __am_input_keybrd(AM_INPUT_KEYBRD_T *kbd) {
  uint32_t key_value = *(volatile uint32_t*)KBD_ADDR;
  kbd->keydown = (key_value&KEYDOWN_MASK)!=0;
  kbd->keycode = (key_value&KEY_VALUE_MASK);
}
