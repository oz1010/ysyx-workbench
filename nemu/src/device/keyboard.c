/***************************************************************************************
* Copyright (c) 2014-2022 Zihao Yu, Nanjing University
*
* NEMU is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include <device/map.h>
#include <device/keyboard.h>
#include <utils.h>

#if !defined(CONFIG_TARGET_AM) && !defined(CONFIG_HAS_VGA)
#include <fcntl.h>
#include <signal.h>
#include <termios.h>
#include <unistd.h>
#endif

#define KEYDOWN_MASK 0x8000

#ifndef CONFIG_TARGET_AM
#include <SDL2/SDL.h>

// Note that this is not the standard
#define NEMU_KEYS(f) \
  f(ESCAPE) f(F1) f(F2) f(F3) f(F4) f(F5) f(F6) f(F7) f(F8) f(F9) f(F10) f(F11) f(F12) \
f(GRAVE) f(1) f(2) f(3) f(4) f(5) f(6) f(7) f(8) f(9) f(0) f(MINUS) f(EQUALS) f(BACKSPACE) \
f(TAB) f(Q) f(W) f(E) f(R) f(T) f(Y) f(U) f(I) f(O) f(P) f(LEFTBRACKET) f(RIGHTBRACKET) f(BACKSLASH) \
f(CAPSLOCK) f(A) f(S) f(D) f(F) f(G) f(H) f(J) f(K) f(L) f(SEMICOLON) f(APOSTROPHE) f(RETURN) \
f(LSHIFT) f(Z) f(X) f(C) f(V) f(B) f(N) f(M) f(COMMA) f(PERIOD) f(SLASH) f(RSHIFT) \
f(LCTRL) f(APPLICATION) f(LALT) f(SPACE) f(RALT) f(RCTRL) \
f(UP) f(DOWN) f(LEFT) f(RIGHT) f(INSERT) f(DELETE) f(HOME) f(END) f(PAGEUP) f(PAGEDOWN)

#define NEMU_KEY_NAME(k) NEMU_KEY_ ## k,

enum {
  NEMU_KEY_NONE = 0,
  MAP(NEMU_KEYS, NEMU_KEY_NAME)
};

#define SDL_KEYMAP(k) keymap[SDL_SCANCODE_ ## k] = NEMU_KEY_ ## k;
static uint32_t keymap[256] = {};

static void init_keymap() {
  MAP(NEMU_KEYS, SDL_KEYMAP)
}

#define KEY_QUEUE_LEN 1024
static int key_queue[KEY_QUEUE_LEN] = {};
static int key_f = 0, key_r = 0;

static void key_enqueue(uint32_t am_scancode) {
  key_queue[key_r] = am_scancode;
  key_r = (key_r + 1) % KEY_QUEUE_LEN;
  Assert(key_r != key_f, "key queue overflow!");
}

static uint32_t key_dequeue() {
  uint32_t key = NEMU_KEY_NONE;
  if (key_f != key_r) {
    key = key_queue[key_f];
    key_f = (key_f + 1) % KEY_QUEUE_LEN;
  }
  return key;
}

void send_key(uint8_t scancode, bool is_keydown) {
  if (nemu_state.state == NEMU_RUNNING && keymap[scancode] != NEMU_KEY_NONE) {
    uint32_t am_scancode = keymap[scancode] | (is_keydown ? KEYDOWN_MASK : 0);
    key_enqueue(am_scancode);
  }
}

#ifndef CONFIG_HAS_VGA
#define TERMINAL_QUEUE_RESERVE 12

static struct termios saved_termios;
static int saved_stdin_flags = -1;
static bool terminal_active = false;
static bool terminal_is_tty = false;
static bool stdin_eof = false;
static char escape_sequence[17];
static size_t escape_sequence_len = 0;
static uint64_t escape_started = 0;

static const int terminal_signals[] = {SIGINT, SIGQUIT, SIGTERM, SIGHUP};
static struct sigaction saved_signal_actions[4];
static bool signal_handlers_installed = false;

static const uint8_t terminal_ascii_keymap[128] = {
  ['a'] = NEMU_KEY_A, ['b'] = NEMU_KEY_B, ['c'] = NEMU_KEY_C,
  ['d'] = NEMU_KEY_D, ['e'] = NEMU_KEY_E, ['f'] = NEMU_KEY_F,
  ['g'] = NEMU_KEY_G, ['h'] = NEMU_KEY_H, ['i'] = NEMU_KEY_I,
  ['j'] = NEMU_KEY_J, ['k'] = NEMU_KEY_K, ['l'] = NEMU_KEY_L,
  ['m'] = NEMU_KEY_M, ['n'] = NEMU_KEY_N, ['o'] = NEMU_KEY_O,
  ['p'] = NEMU_KEY_P, ['q'] = NEMU_KEY_Q, ['r'] = NEMU_KEY_R,
  ['s'] = NEMU_KEY_S, ['t'] = NEMU_KEY_T, ['u'] = NEMU_KEY_U,
  ['v'] = NEMU_KEY_V, ['w'] = NEMU_KEY_W, ['x'] = NEMU_KEY_X,
  ['y'] = NEMU_KEY_Y, ['z'] = NEMU_KEY_Z,
  ['1'] = NEMU_KEY_1, ['2'] = NEMU_KEY_2, ['3'] = NEMU_KEY_3,
  ['4'] = NEMU_KEY_4, ['5'] = NEMU_KEY_5, ['6'] = NEMU_KEY_6,
  ['7'] = NEMU_KEY_7, ['8'] = NEMU_KEY_8, ['9'] = NEMU_KEY_9,
  ['0'] = NEMU_KEY_0, ['`'] = NEMU_KEY_GRAVE, ['-'] = NEMU_KEY_MINUS,
  ['='] = NEMU_KEY_EQUALS, ['['] = NEMU_KEY_LEFTBRACKET,
  [']'] = NEMU_KEY_RIGHTBRACKET, ['\\'] = NEMU_KEY_BACKSLASH,
  [';'] = NEMU_KEY_SEMICOLON, ['\''] = NEMU_KEY_APOSTROPHE,
  [','] = NEMU_KEY_COMMA, ['.'] = NEMU_KEY_PERIOD, ['/'] = NEMU_KEY_SLASH,
  [' '] = NEMU_KEY_SPACE, ['\t'] = NEMU_KEY_TAB, ['\r'] = NEMU_KEY_RETURN,
  ['\n'] = NEMU_KEY_RETURN, ['\b'] = NEMU_KEY_BACKSPACE,
  [0x7f] = NEMU_KEY_BACKSPACE,
};

static int terminal_key_queue_room(void) {
  return (key_f - key_r - 1 + KEY_QUEUE_LEN) % KEY_QUEUE_LEN;
}

static void terminal_send_key(uint32_t keycode, bool keydown) {
  key_enqueue(keycode | (keydown ? KEYDOWN_MASK : 0));
}

static void terminal_enqueue_key(uint32_t keycode, bool shift, bool ctrl, bool alt) {
  if (shift) terminal_send_key(NEMU_KEY_LSHIFT, true);
  if (ctrl) terminal_send_key(NEMU_KEY_LCTRL, true);
  if (alt) terminal_send_key(NEMU_KEY_LALT, true);

  terminal_send_key(keycode, true);
  terminal_send_key(keycode, false);

  if (alt) terminal_send_key(NEMU_KEY_LALT, false);
  if (ctrl) terminal_send_key(NEMU_KEY_LCTRL, false);
  if (shift) terminal_send_key(NEMU_KEY_LSHIFT, false);
}

static bool terminal_enqueue_ascii(uint8_t ch, bool alt) {
  if (ch >= 128) return false;

  uint8_t keycode = terminal_ascii_keymap[ch];
  bool shift = false;
  bool ctrl = false;
  if (ch >= 'A' && ch <= 'Z') {
    keycode = terminal_ascii_keymap[ch - 'A' + 'a'];
    shift = true;
  } else if (strchr("!@#$%^&*()_+{}|:\"<>?~", ch) != NULL) {
    switch (ch) {
      case '!': keycode = NEMU_KEY_1; break;
      case '@': keycode = NEMU_KEY_2; break;
      case '#': keycode = NEMU_KEY_3; break;
      case '$': keycode = NEMU_KEY_4; break;
      case '%': keycode = NEMU_KEY_5; break;
      case '^': keycode = NEMU_KEY_6; break;
      case '&': keycode = NEMU_KEY_7; break;
      case '*': keycode = NEMU_KEY_8; break;
      case '(': keycode = NEMU_KEY_9; break;
      case ')': keycode = NEMU_KEY_0; break;
      case '~': keycode = NEMU_KEY_GRAVE; break;
      case '_': keycode = NEMU_KEY_MINUS; break;
      case '+': keycode = NEMU_KEY_EQUALS; break;
      case '{': keycode = NEMU_KEY_LEFTBRACKET; break;
      case '}': keycode = NEMU_KEY_RIGHTBRACKET; break;
      case '|': keycode = NEMU_KEY_BACKSLASH; break;
      case ':': keycode = NEMU_KEY_SEMICOLON; break;
      case '"': keycode = NEMU_KEY_APOSTROPHE; break;
      case '<': keycode = NEMU_KEY_COMMA; break;
      case '>': keycode = NEMU_KEY_PERIOD; break;
      case '?': keycode = NEMU_KEY_SLASH; break;
      default: break;
    }
    shift = true;
  } else if (ch >= 1 && ch <= 26 && keycode == NEMU_KEY_NONE) {
    keycode = terminal_ascii_keymap[ch - 1 + 'a'];
    ctrl = true;
  }

  if (keycode == NEMU_KEY_NONE) return false;
  terminal_enqueue_key(keycode, shift, ctrl, alt);
  return true;
}

static bool terminal_enqueue_escape_sequence(void) {
  if (escape_sequence_len == 2) {
    return terminal_enqueue_ascii(escape_sequence[1], true);
  }

  static const struct {
    const char *sequence;
    uint32_t keycode;
  } escape_keymap[] = {
    {"\033[A", NEMU_KEY_UP}, {"\033OA", NEMU_KEY_UP},
    {"\033[B", NEMU_KEY_DOWN}, {"\033OB", NEMU_KEY_DOWN},
    {"\033[C", NEMU_KEY_RIGHT}, {"\033OC", NEMU_KEY_RIGHT},
    {"\033[D", NEMU_KEY_LEFT}, {"\033OD", NEMU_KEY_LEFT},
    {"\033[H", NEMU_KEY_HOME}, {"\033OH", NEMU_KEY_HOME},
    {"\033[1~", NEMU_KEY_HOME}, {"\033[7~", NEMU_KEY_HOME},
    {"\033[F", NEMU_KEY_END}, {"\033OF", NEMU_KEY_END},
    {"\033[4~", NEMU_KEY_END}, {"\033[8~", NEMU_KEY_END},
    {"\033[2~", NEMU_KEY_INSERT}, {"\033[3~", NEMU_KEY_DELETE},
    {"\033[5~", NEMU_KEY_PAGEUP}, {"\033[6~", NEMU_KEY_PAGEDOWN},
    {"\033OP", NEMU_KEY_F1}, {"\033[11~", NEMU_KEY_F1},
    {"\033OQ", NEMU_KEY_F2}, {"\033[12~", NEMU_KEY_F2},
    {"\033OR", NEMU_KEY_F3}, {"\033[13~", NEMU_KEY_F3},
    {"\033OS", NEMU_KEY_F4}, {"\033[14~", NEMU_KEY_F4},
    {"\033[15~", NEMU_KEY_F5}, {"\033[17~", NEMU_KEY_F6},
    {"\033[18~", NEMU_KEY_F7}, {"\033[19~", NEMU_KEY_F8},
    {"\033[20~", NEMU_KEY_F9}, {"\033[21~", NEMU_KEY_F10},
    {"\033[23~", NEMU_KEY_F11}, {"\033[24~", NEMU_KEY_F12},
  };

  for (size_t i = 0; i < sizeof(escape_keymap) / sizeof(escape_keymap[0]); i ++) {
    if (strcmp(escape_sequence, escape_keymap[i].sequence) == 0) {
      terminal_enqueue_key(escape_keymap[i].keycode, false, false, false);
      return true;
    }
  }
  return false;
}

static void terminal_consume_input_byte(uint8_t ch) {
  if (escape_sequence_len == 0) {
    if (ch == 0x1b) {
      escape_sequence[0] = ch;
      escape_sequence[1] = '\0';
      escape_sequence_len = 1;
      escape_started = get_time();
    } else {
      terminal_enqueue_ascii(ch, false);
    }
    return;
  }

  if (escape_sequence_len >= sizeof(escape_sequence) - 1) {
    escape_sequence_len = 0;
    return;
  }
  escape_sequence[escape_sequence_len ++] = ch;
  escape_sequence[escape_sequence_len] = '\0';
  if (escape_sequence_len == 2 && ch != '[' && ch != 'O') {
    terminal_enqueue_escape_sequence();
    escape_sequence_len = 0;
    return;
  }

  if (escape_sequence_len >= 3 && ch >= 0x40 && ch <= 0x7e) {
    terminal_enqueue_escape_sequence();
    escape_sequence_len = 0;
  } else if (escape_sequence_len >= sizeof(escape_sequence) - 1) {
    escape_sequence_len = 0;
  }
}

static void terminal_poll(void) {
  if (stdin_eof || terminal_key_queue_room() < TERMINAL_QUEUE_RESERVE) return;

  while (terminal_key_queue_room() >= TERMINAL_QUEUE_RESERVE) {
    uint8_t ch;
    ssize_t count = read(STDIN_FILENO, &ch, 1);
    if (count > 0) {
      terminal_consume_input_byte(ch);
      continue;
    }
    if (count == 0 && !terminal_is_tty) {
      stdin_eof = true;
      if (escape_sequence_len == 1) {
        terminal_enqueue_key(NEMU_KEY_ESCAPE, false, false, false);
      }
      escape_sequence_len = 0;
    }
    break;
  }

  if (escape_sequence_len > 0 && get_time() - escape_started > 20000) {
    if (escape_sequence_len == 1) {
      terminal_enqueue_key(NEMU_KEY_ESCAPE, false, false, false);
    }
    escape_sequence_len = 0;
  }
}

void terminal_keyboard_update(void) {
  if (terminal_active) terminal_poll();
}

void terminal_keyboard_set_active(bool active) {
  if (active == terminal_active) return;

  if (active) {
    terminal_is_tty = isatty(STDIN_FILENO);
    if (terminal_is_tty && tcgetattr(STDIN_FILENO, &saved_termios) == 0) {
      struct termios raw = saved_termios;
      raw.c_lflag &= ~(ICANON | ECHO);
      raw.c_cc[VMIN] = 0;
      raw.c_cc[VTIME] = 0;
      if (tcsetattr(STDIN_FILENO, TCSANOW, &raw) != 0) return;
    }
    saved_stdin_flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (saved_stdin_flags >= 0) {
      fcntl(STDIN_FILENO, F_SETFL, saved_stdin_flags | O_NONBLOCK);
    }
    terminal_active = true;
  } else {
    if (terminal_is_tty) {
      tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
    }
    if (saved_stdin_flags >= 0) {
      fcntl(STDIN_FILENO, F_SETFL, saved_stdin_flags);
    }
    saved_stdin_flags = -1;
    terminal_active = false;
  }
}

static void terminal_signal_handler(int signal_number) {
  terminal_keyboard_set_active(false);
  for (size_t i = 0; i < sizeof(terminal_signals) / sizeof(terminal_signals[0]); i ++) {
    if (terminal_signals[i] == signal_number) {
      sigaction(signal_number, &saved_signal_actions[i], NULL);
      break;
    }
  }
  raise(signal_number);
}

static void terminal_keyboard_shutdown(void) {
  terminal_keyboard_set_active(false);
  if (signal_handlers_installed) {
    for (size_t i = 0; i < sizeof(terminal_signals) / sizeof(terminal_signals[0]); i ++) {
      sigaction(terminal_signals[i], &saved_signal_actions[i], NULL);
    }
    signal_handlers_installed = false;
  }
}

static void terminal_keyboard_init(void) {
  atexit(terminal_keyboard_shutdown);
  struct sigaction action = {};
  action.sa_handler = terminal_signal_handler;
  sigemptyset(&action.sa_mask);
  for (size_t i = 0; i < sizeof(terminal_signals) / sizeof(terminal_signals[0]); i ++) {
    sigaction(terminal_signals[i], &action, &saved_signal_actions[i]);
  }
  signal_handlers_installed = true;
}
#endif
#else // !CONFIG_TARGET_AM
#define NEMU_KEY_NONE 0

static uint32_t key_dequeue() {
  AM_INPUT_KEYBRD_T ev = io_read(AM_INPUT_KEYBRD);
  uint32_t am_scancode = ev.keycode | (ev.keydown ? KEYDOWN_MASK : 0);
  return am_scancode;
}
#endif

static uint32_t *i8042_data_port_base = NULL;

static void i8042_data_io_handler(uint32_t offset, int len, bool is_write) {
  assert(!is_write);
  assert(offset == 0);
  i8042_data_port_base[0] = key_dequeue();
}

void init_i8042() {
  i8042_data_port_base = (uint32_t *)new_space(4);
  i8042_data_port_base[0] = NEMU_KEY_NONE;
#ifdef CONFIG_HAS_PORT_IO
  add_pio_map ("keyboard", CONFIG_I8042_DATA_PORT, i8042_data_port_base, 4, i8042_data_io_handler);
#else
  add_mmio_map("keyboard", CONFIG_I8042_DATA_MMIO, i8042_data_port_base, 4, i8042_data_io_handler);
#endif
  IFNDEF(CONFIG_TARGET_AM, init_keymap());
#if !defined(CONFIG_TARGET_AM) && !defined(CONFIG_HAS_VGA)
  terminal_keyboard_init();
#endif
}
