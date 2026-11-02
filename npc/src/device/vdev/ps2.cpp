#include "device/vdev.h"
#include "device/ps2.h"
#include "generated/autoconf.h"
#include "utils.h"

#include <chrono>
#include <cstdlib>
#include <deque>
#include <fcntl.h>
#include <signal.h>
#include <string>
#include <termios.h>
#include <unistd.h>

static uint8_t *base = NULL;
static const uint32_t size = 16;

static uint8_t *ps2_clk = NULL;
static uint8_t *ps2_data = NULL;
static std::deque<uint8_t> scancode_queue;
static std::string escape_sequence;
static std::chrono::steady_clock::time_point escape_started;
static struct termios saved_termios;
static int saved_stdin_flags = -1;
static bool terminal_active = false;
static bool terminal_is_tty = false;
static bool stdin_eof = false;
static uint8_t current_scancode = 0;
static int data_index = 0;
static int clocks_left = 0;
static bool sending_scancode = false;

static const int PS2_HALF_PERIOD = 10;
static const size_t MAX_PENDING_SCANCODES = 1024;
static const int terminal_signals[] = {SIGINT, SIGQUIT, SIGTERM, SIGHUP};
static struct sigaction saved_signal_actions[4];
static bool signal_handlers_installed = false;

static void terminal_signal_handler(int signal_number)
{
    terminal_ps2_set_active(false);
    for (size_t i = 0; i < sizeof(terminal_signals) / sizeof(terminal_signals[0]); ++i)
    {
        if (terminal_signals[i] == signal_number)
        {
            sigaction(signal_number, &saved_signal_actions[i], NULL);
            break;
        }
    }
    raise(signal_number);
}

static void enqueue_scancode(uint16_t code, bool keydown)
{
    if (code & 0xff00)
    {
        scancode_queue.push_back(code >> 8);
    }
    if (!keydown)
    {
        scancode_queue.push_back(0xf0);
    }
    scancode_queue.push_back(code & 0xff);
}

static void enqueue_key(uint16_t code, bool shift = false, bool ctrl = false, bool alt = false)
{
    if (shift)
    {
        enqueue_scancode(0x12, true);
    }
    if (ctrl)
    {
        enqueue_scancode(0x14, true);
    }
    if (alt)
    {
        enqueue_scancode(0x11, true);
    }

    enqueue_scancode(code, true);
    enqueue_scancode(code, false);

    if (alt)
    {
        enqueue_scancode(0x11, false);
    }
    if (ctrl)
    {
        enqueue_scancode(0x14, false);
    }
    if (shift)
    {
        enqueue_scancode(0x12, false);
    }
}

static bool enqueue_ascii(uint8_t ch, bool alt = false)
{
    static const uint8_t letter_codes[] = {
        0x1c, 0x32, 0x21, 0x23, 0x24, 0x2b, 0x34, 0x33, 0x43,
        0x3b, 0x42, 0x4b, 0x3a, 0x31, 0x44, 0x4d, 0x15, 0x2d,
        0x1b, 0x2c, 0x3c, 0x2a, 0x1d, 0x22, 0x35, 0x1a,
    };

    if (ch >= 'a' && ch <= 'z')
    {
        enqueue_key(letter_codes[ch - 'a'], false, false, alt);
        return true;
    }
    if (ch >= 'A' && ch <= 'Z')
    {
        enqueue_key(letter_codes[ch - 'A'], true, false, alt);
        return true;
    }

    switch (ch)
    {
        case '\r':
        case '\n': enqueue_key(0x5a, false, false, alt); return true;
        case '\t': enqueue_key(0x0d, false, false, alt); return true;
        case '\b':
        case 0x7f: enqueue_key(0x66, false, false, alt); return true;
        case ' ': enqueue_key(0x29, false, false, alt); return true;
        case '1': enqueue_key(0x16, false, false, alt); return true;
        case '2': enqueue_key(0x1e, false, false, alt); return true;
        case '3': enqueue_key(0x26, false, false, alt); return true;
        case '4': enqueue_key(0x25, false, false, alt); return true;
        case '5': enqueue_key(0x2e, false, false, alt); return true;
        case '6': enqueue_key(0x36, false, false, alt); return true;
        case '7': enqueue_key(0x3d, false, false, alt); return true;
        case '8': enqueue_key(0x3e, false, false, alt); return true;
        case '9': enqueue_key(0x46, false, false, alt); return true;
        case '0': enqueue_key(0x45, false, false, alt); return true;
        case '!': enqueue_key(0x16, true, false, alt); return true;
        case '@': enqueue_key(0x1e, true, false, alt); return true;
        case '#': enqueue_key(0x26, true, false, alt); return true;
        case '$': enqueue_key(0x25, true, false, alt); return true;
        case '%': enqueue_key(0x2e, true, false, alt); return true;
        case '^': enqueue_key(0x36, true, false, alt); return true;
        case '&': enqueue_key(0x3d, true, false, alt); return true;
        case '*': enqueue_key(0x3e, true, false, alt); return true;
        case '(': enqueue_key(0x46, true, false, alt); return true;
        case ')': enqueue_key(0x45, true, false, alt); return true;
        case '`': enqueue_key(0x0e, false, false, alt); return true;
        case '~': enqueue_key(0x0e, true, false, alt); return true;
        case '-': enqueue_key(0x4e, false, false, alt); return true;
        case '_': enqueue_key(0x4e, true, false, alt); return true;
        case '=': enqueue_key(0x55, false, false, alt); return true;
        case '+': enqueue_key(0x55, true, false, alt); return true;
        case '[': enqueue_key(0x54, false, false, alt); return true;
        case '{': enqueue_key(0x54, true, false, alt); return true;
        case ']': enqueue_key(0x5b, false, false, alt); return true;
        case '}': enqueue_key(0x5b, true, false, alt); return true;
        case '\\': enqueue_key(0x5d, false, false, alt); return true;
        case '|': enqueue_key(0x5d, true, false, alt); return true;
        case ';': enqueue_key(0x4c, false, false, alt); return true;
        case ':': enqueue_key(0x4c, true, false, alt); return true;
        case '\'': enqueue_key(0x52, false, false, alt); return true;
        case '"': enqueue_key(0x52, true, false, alt); return true;
        case ',': enqueue_key(0x41, false, false, alt); return true;
        case '<': enqueue_key(0x41, true, false, alt); return true;
        case '.': enqueue_key(0x49, false, false, alt); return true;
        case '>': enqueue_key(0x49, true, false, alt); return true;
        case '/': enqueue_key(0x4a, false, false, alt); return true;
        case '?': enqueue_key(0x4a, true, false, alt); return true;
        default: break;
    }

    if (ch >= 1 && ch <= 26)
    {
        enqueue_key(letter_codes[ch - 1], false, true, alt);
        return true;
    }
    return false;
}

static bool enqueue_escape_sequence(const std::string &sequence)
{
    if (sequence.size() == 2)
    {
        return enqueue_ascii(static_cast<uint8_t>(sequence[1]), true);
    }

    if (sequence == "\033[A" || sequence == "\033OA") enqueue_key(0xe075);
    else if (sequence == "\033[B" || sequence == "\033OB") enqueue_key(0xe072);
    else if (sequence == "\033[C" || sequence == "\033OC") enqueue_key(0xe074);
    else if (sequence == "\033[D" || sequence == "\033OD") enqueue_key(0xe06b);
    else if (sequence == "\033[H" || sequence == "\033OH" || sequence == "\033[1~" || sequence == "\033[7~") enqueue_key(0xe06c);
    else if (sequence == "\033[F" || sequence == "\033OF" || sequence == "\033[4~" || sequence == "\033[8~") enqueue_key(0xe069);
    else if (sequence == "\033[2~") enqueue_key(0xe070);
    else if (sequence == "\033[3~") enqueue_key(0xe071);
    else if (sequence == "\033[5~") enqueue_key(0xe07d);
    else if (sequence == "\033[6~") enqueue_key(0xe07a);
    else if (sequence == "\033OP" || sequence == "\033[11~") enqueue_key(0x05);
    else if (sequence == "\033OQ" || sequence == "\033[12~") enqueue_key(0x06);
    else if (sequence == "\033OR" || sequence == "\033[13~") enqueue_key(0x04);
    else if (sequence == "\033OS" || sequence == "\033[14~") enqueue_key(0x0c);
    else if (sequence == "\033[15~") enqueue_key(0x03);
    else if (sequence == "\033[17~") enqueue_key(0x0b);
    else if (sequence == "\033[18~") enqueue_key(0x83);
    else if (sequence == "\033[19~") enqueue_key(0x0a);
    else if (sequence == "\033[20~") enqueue_key(0x01);
    else if (sequence == "\033[21~") enqueue_key(0x09);
    else if (sequence == "\033[23~") enqueue_key(0x78);
    else if (sequence == "\033[24~") enqueue_key(0x07);
    else return false;
    return true;
}

static void consume_input_byte(uint8_t ch)
{
    if (escape_sequence.empty())
    {
        if (ch == 0x1b)
        {
            escape_sequence = '\033';
            escape_started = std::chrono::steady_clock::now();
        }
        else
        {
            enqueue_ascii(ch);
        }
        return;
    }

    escape_sequence.push_back(ch);
    if (escape_sequence.size() == 2 && ch != '[' && ch != 'O')
    {
        enqueue_escape_sequence(escape_sequence);
        escape_sequence.clear();
        return;
    }

    if (escape_sequence.size() >= 3 && ch >= 0x40 && ch <= 0x7e)
    {
        enqueue_escape_sequence(escape_sequence);
        escape_sequence.clear();
    }
    else if (escape_sequence.size() > 16)
    {
        escape_sequence.clear();
    }
}

static void poll_terminal()
{
    if (stdin_eof || scancode_queue.size() >= MAX_PENDING_SCANCODES)
    {
        return;
    }

    uint8_t buffer[64];
    while (scancode_queue.size() < MAX_PENDING_SCANCODES)
    {
        ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
        if (count > 0)
        {
            for (ssize_t i = 0; i < count; ++i)
            {
                consume_input_byte(buffer[i]);
            }
            continue;
        }
        if (count == 0)
        {
            if (!terminal_is_tty)
            {
                stdin_eof = true;
                if (escape_sequence == "\033")
                {
                    enqueue_key(0x76);
                }
                escape_sequence.clear();
            }
        }
        break;
    }

    if (!escape_sequence.empty() &&
        std::chrono::steady_clock::now() - escape_started > std::chrono::milliseconds(20))
    {
        if (escape_sequence == "\033")
        {
            enqueue_key(0x76);
        }
        escape_sequence.clear();
    }
}

static void update_ps2_pins()
{
    if (!sending_scancode)
    {
        if (scancode_queue.empty())
        {
            return;
        }
        current_scancode = scancode_queue.front();
        data_index = 0;
        clocks_left = PS2_HALF_PERIOD;
        sending_scancode = true;
    }

    if (clocks_left > 0)
    {
        --clocks_left;
        return;
    }

    *ps2_clk = !*ps2_clk;
    clocks_left = PS2_HALF_PERIOD;
    if (*ps2_clk)
    {
        if (data_index == 9)
        {
            *ps2_data = !__builtin_parity(scancode_queue.front());
        }
        else if (data_index == 10)
        {
            *ps2_data = 1;
        }
        else
        {
            *ps2_data = (data_index >= 1 && data_index <= 8) ? (current_scancode & 1) : 0;
        }
        if (data_index >= 1 && data_index <= 8)
        {
            current_scancode >>= 1;
        }
        ++data_index;
    }
    else if (data_index == 11)
    {
        scancode_queue.pop_front();
        sending_scancode = false;
        data_index = 0;
    }
}

void terminal_ps2_init(uint8_t *clk, uint8_t *data)
{
    ps2_clk = clk;
    ps2_data = data;
    *ps2_clk = 0;
    *ps2_data = 1;
    scancode_queue.clear();
    escape_sequence.clear();
    sending_scancode = false;
    stdin_eof = false;
    std::atexit(terminal_ps2_shutdown);

    struct sigaction action = {};
    action.sa_handler = terminal_signal_handler;
    sigemptyset(&action.sa_mask);
    for (size_t i = 0; i < sizeof(terminal_signals) / sizeof(terminal_signals[0]); ++i)
    {
        sigaction(terminal_signals[i], &action, &saved_signal_actions[i]);
    }
    signal_handlers_installed = true;
}

void terminal_ps2_update()
{
    if (!terminal_active || ps2_clk == NULL)
    {
        return;
    }
    poll_terminal();
    update_ps2_pins();
}

void terminal_ps2_set_active(bool active)
{
    if (active == terminal_active || ps2_clk == NULL)
    {
        return;
    }

    if (active)
    {
        terminal_is_tty = isatty(STDIN_FILENO);
        if (terminal_is_tty && tcgetattr(STDIN_FILENO, &saved_termios) == 0)
        {
            struct termios raw = saved_termios;
            raw.c_lflag &= ~(ICANON | ECHO);
            raw.c_cc[VMIN] = 0;
            raw.c_cc[VTIME] = 0;
            if (tcsetattr(STDIN_FILENO, TCSANOW, &raw) != 0)
            {
                return;
            }
        }
        saved_stdin_flags = fcntl(STDIN_FILENO, F_GETFL, 0);
        if (saved_stdin_flags >= 0)
        {
            fcntl(STDIN_FILENO, F_SETFL, saved_stdin_flags | O_NONBLOCK);
        }
        terminal_active = true;
    }
    else
    {
        if (terminal_is_tty)
        {
            tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
        }
        if (saved_stdin_flags >= 0)
        {
            fcntl(STDIN_FILENO, F_SETFL, saved_stdin_flags);
        }
        saved_stdin_flags = -1;
        terminal_active = false;
    }
}

void terminal_ps2_shutdown()
{
    terminal_ps2_set_active(false);
    if (signal_handlers_installed)
    {
        for (size_t i = 0; i < sizeof(terminal_signals) / sizeof(terminal_signals[0]); ++i)
        {
            sigaction(terminal_signals[i], &saved_signal_actions[i], NULL);
        }
        signal_handlers_installed = false;
    }
    ps2_clk = NULL;
    ps2_data = NULL;
}

void init_ps2()
{
    base = new_vmem(size);
    add_vdev_item(VDEV_INNER, "ps2", CONFIG_PS2_BASE_ADDR, base, size,
                  (VDEV_ATTR_READ | VDEV_ATTR_WRITE), NULL);
}
