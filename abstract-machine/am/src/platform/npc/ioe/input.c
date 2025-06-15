#include <am.h>
#include <npc.h>

void __am_input_init()
{
}

void __am_input_keybrd(AM_INPUT_KEYBRD_T *kbd)
{
    uint32_t key_value = 0;
    uint8_t ps_code;
    bool key_release = false;
    ps_code = inb(KBD_ADDR);
    while (ps_code > 0) {
        switch (ps_code)
        {
        case 0xe0:
            key_value = key_value | ((uint32_t)ps_code<<8);
            break;
        
        case 0xf0:
            key_release = true;
            break;
        
        default:
            key_value = key_value | (ps_code);
            break;
        }

        if (ps_code == 0xe0 || ps_code == 0xf0) {
            ps_code = inb(KBD_ADDR);
            continue;
        } else {
            break;
        }
    }

    kbd->keydown = !key_release;
    kbd->keycode = key_value;
}
