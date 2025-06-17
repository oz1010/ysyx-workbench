#include <am.h>
#include <npc.h>
#include "klib.h"

#define MAP(c, f) c(f)

#define PS2_CODE_SIZE       0x10000
enum {
    PS2_CODE_NONE = 0,

    // 第一排
    PS2_CODE_ESCAPE         = 0x76,
    PS2_CODE_F1             = 0x05,
    PS2_CODE_F2             = 0x06,
    PS2_CODE_F3             = 0x04,
    PS2_CODE_F4             = 0x0C,
    PS2_CODE_F5             = 0x03,
    PS2_CODE_F6             = 0x0B,
    PS2_CODE_F7             = 0x83,
    PS2_CODE_F8             = 0x0A,
    PS2_CODE_F9             = 0x01,
    PS2_CODE_F10            = 0x09,
    PS2_CODE_F11            = 0x78,
    PS2_CODE_F12            = 0x07,
    // 第二排
    PS2_CODE_GRAVE          = 0x0E,   // ` ~
    PS2_CODE_1              = 0x16,   // 1 !
    PS2_CODE_2              = 0x1E,   // 2 @
    PS2_CODE_3              = 0x26,   // 3 #
    PS2_CODE_4              = 0x25,   // 4 $
    PS2_CODE_5              = 0x2E,   // 5 %
    PS2_CODE_6              = 0x36,   // 6 ^
    PS2_CODE_7              = 0x3D,   // 7 &
    PS2_CODE_8              = 0x3E,   // 8 *
    PS2_CODE_9              = 0x46,   // 9 (
    PS2_CODE_0              = 0x45,   // 0 )
    PS2_CODE_MINUS          = 0x4E,   // - _
    PS2_CODE_EQUALS         = 0x55,   // = +
    PS2_CODE_BACKSPACE      = 0x66,
    // 第三排
    PS2_CODE_TAB            = 0x0D,
    PS2_CODE_Q              = 0x15,
    PS2_CODE_W              = 0x1D,
    PS2_CODE_E              = 0x24,
    PS2_CODE_R              = 0x2D,
    PS2_CODE_T              = 0x2C,
    PS2_CODE_Y              = 0x35,
    PS2_CODE_U              = 0x3C,
    PS2_CODE_I              = 0x43,
    PS2_CODE_O              = 0x44,
    PS2_CODE_P              = 0x4D,
    PS2_CODE_LEFTBRACKET    = 0x54,   // [ {
    PS2_CODE_RIGHTBRACKET   = 0x5B,   // ] }
    PS2_CODE_BACKSLASH      = 0x5D,   // \ |
    // 第四排
    PS2_CODE_CAPSLOCK       = 0x58,
    PS2_CODE_A              = 0x1C,
    PS2_CODE_S              = 0x1B,
    PS2_CODE_D              = 0x23,
    PS2_CODE_F              = 0x2B,
    PS2_CODE_G              = 0x34,
    PS2_CODE_H              = 0x33,
    PS2_CODE_J              = 0x3B,
    PS2_CODE_K              = 0x42,
    PS2_CODE_L              = 0x4B,
    PS2_CODE_SEMICOLON      = 0x4C,   // ; :
    PS2_CODE_APOSTROPHE     = 0x52,   // ' "
    PS2_CODE_RETURN         = 0x5A,
    // 第五排
    PS2_CODE_LSHIFT         = 0x12,
    PS2_CODE_Z              = 0x1A,
    PS2_CODE_X              = 0x22,
    PS2_CODE_C              = 0x21,
    PS2_CODE_V              = 0x2A,
    PS2_CODE_B              = 0x32,
    PS2_CODE_N              = 0x31,
    PS2_CODE_M              = 0x3A,
    PS2_CODE_COMMA          = 0x41,   // , <
    PS2_CODE_PERIOD         = 0x49,   // . >
    PS2_CODE_SLASH          = 0x4A,   // / ?
    PS2_CODE_RSHIFT         = 0x59,
    // 第六排
    PS2_CODE_LCTRL          = 0x14,
    PS2_CODE_APPLICATION    = 0xE01F, // 扩展码：Windows键
    PS2_CODE_LALT           = 0x11,
    PS2_CODE_SPACE          = 0x29,
    PS2_CODE_RALT           = 0xE011, // 扩展码：实际为 0xE0 + 0x11
    PS2_CODE_RCTRL          = 0xE014, // 扩展码：实际为 0xE0 + 0x14
    // 其他区域
    PS2_CODE_UP             = 0xE075,
    PS2_CODE_DOWN           = 0xE072,
    PS2_CODE_LEFT           = 0xE06B,
    PS2_CODE_RIGHT          = 0xE074,
    PS2_CODE_INSERT         = 0xE070,
    PS2_CODE_DELETE         = 0xE071,
    PS2_CODE_HOME           = 0xE06C,
    PS2_CODE_END            = 0xE069,
    PS2_CODE_PAGEUP         = 0xE07D,
    PS2_CODE_PAGEDOWN       = 0xE07A,
    
    // PS2_CODE_RIGHT_WIN      = 0xE027,
    // PS2_CODE_MENU           = 0xE02F, // 上下文菜单键
    // PS2_CODE_PRINT_SCREEN = 0xE012, // 扩展码：实际为 0xE0 + 0x12 + 0xE0 + 0x7C（完整序列需特殊处理）
    // PS2_CODE_SCROLL_LOCK  = 0x7E,
    // PS2_CODE_PAUSE        = 0xE114, // 扩展码：实际为 0xE1 + 0x14 + 0x77（完整序列需特殊处理）
    // // 数字小键盘
    // PS2_CODE_NUM_LOCK     = 0x77,
    // PS2_CODE_KP_SLASH     = 0xE04A,
    // PS2_CODE_KP_ASTERISK  = 0x7C,
    // PS2_CODE_KP_MINUS     = 0x7B,
    // PS2_CODE_KP_PLUS      = 0x79,
    // PS2_CODE_KP_ENTER     = 0xE05A,
    // PS2_CODE_KP_0         = 0x70,
    // PS2_CODE_KP_1         = 0x69,
    // PS2_CODE_KP_2         = 0x72,
    // PS2_CODE_KP_3         = 0x7A,
    // PS2_CODE_KP_4         = 0x6B,
    // PS2_CODE_KP_5         = 0x73,
    // PS2_CODE_KP_6         = 0x74,
    // PS2_CODE_KP_7         = 0x6C,
    // PS2_CODE_KP_8         = 0x75,
    // PS2_CODE_KP_9         = 0x7D,
    // PS2_CODE_KP_PERIOD    = 0x71,
};


// Note that this is not the standard
#define PS2_KEYS(f) \
  f(ESCAPE) f(F1) f(F2) f(F3) f(F4) f(F5) f(F6) f(F7) f(F8) f(F9) f(F10) f(F11) f(F12) \
f(GRAVE) f(1) f(2) f(3) f(4) f(5) f(6) f(7) f(8) f(9) f(0) f(MINUS) f(EQUALS) f(BACKSPACE) \
f(TAB) f(Q) f(W) f(E) f(R) f(T) f(Y) f(U) f(I) f(O) f(P) f(LEFTBRACKET) f(RIGHTBRACKET) f(BACKSLASH) \
f(CAPSLOCK) f(A) f(S) f(D) f(F) f(G) f(H) f(J) f(K) f(L) f(SEMICOLON) f(APOSTROPHE) f(RETURN) \
f(LSHIFT) f(Z) f(X) f(C) f(V) f(B) f(N) f(M) f(COMMA) f(PERIOD) f(SLASH) f(RSHIFT) \
f(LCTRL) f(APPLICATION) f(LALT) f(SPACE) f(RALT) f(RCTRL) \
f(UP) f(DOWN) f(LEFT) f(RIGHT) f(INSERT) f(DELETE) f(HOME) f(END) f(PAGEUP) f(PAGEDOWN)

#define PS2_KEYITEM(key)  ps2_map[PS2_CODE_ ##key] = AM_KEY_ ##key;

uint32_t ps2_map[PS2_CODE_SIZE] = {};

void __am_input_init()
{
    static bool init_ps2_code = false;
    if (!init_ps2_code) {
        init_ps2_code = true;
        MAP(PS2_KEYS, PS2_KEYITEM)
        printf("Init ps2 decoder done.\n");
    }
    
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

    if (key_value < PS2_CODE_SIZE) {
        kbd->keydown = !key_release;
        kbd->keycode = ps2_map[key_value];
    } else {
        kbd->keydown = !key_release;
        kbd->keycode = 0;
    }
}
