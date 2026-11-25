#ifndef VERILATOR
#include <vpi_user.h>
#endif

#include <fcntl.h>
#include <signal.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>

#define SCANCODE_QUEUE_SIZE 4096
#define ESCAPE_TIMEOUT_MS 20.0

static uint8_t scancode_queue[SCANCODE_QUEUE_SIZE];
static size_t queue_head;
static size_t queue_count;
static char escape_sequence[18];
static size_t escape_length;
static struct timespec escape_started;
static struct termios saved_termios;
static int saved_stdin_flags = -1;
static bool initialized;
static bool terminal_active;
static bool terminal_is_tty;
static bool stdin_eof;

static double milliseconds_since(const struct timespec *start)
{
    struct timespec now;
    clock_gettime(CLOCK_MONOTONIC, &now);
    return (now.tv_sec - start->tv_sec) * 1000.0 +
           (now.tv_nsec - start->tv_nsec) / 1000000.0;
}

static void queue_push(uint8_t code)
{
    if (queue_count == SCANCODE_QUEUE_SIZE) {
        return;
    }
    size_t tail = (queue_head + queue_count) % SCANCODE_QUEUE_SIZE;
    scancode_queue[tail] = code;
    ++queue_count;
}

static int queue_pop(void)
{
    if (queue_count == 0) {
        return 0;
    }
    uint8_t code = scancode_queue[queue_head];
    queue_head = (queue_head + 1) % SCANCODE_QUEUE_SIZE;
    --queue_count;
    return code;
}

static void enqueue_scancode(uint16_t code, bool keydown)
{
    if ((code & 0xff00) != 0) {
        queue_push((uint8_t)(code >> 8));
    }
    if (!keydown) {
        queue_push(0xf0);
    }
    queue_push((uint8_t)code);
}

static void enqueue_key(uint16_t code, bool shift, bool ctrl, bool alt)
{
    if (shift) {
        enqueue_scancode(0x12, true);
    }
    if (ctrl) {
        enqueue_scancode(0x14, true);
    }
    if (alt) {
        enqueue_scancode(0x11, true);
    }

    enqueue_scancode(code, true);
    enqueue_scancode(code, false);

    if (alt) {
        enqueue_scancode(0x11, false);
    }
    if (ctrl) {
        enqueue_scancode(0x14, false);
    }
    if (shift) {
        enqueue_scancode(0x12, false);
    }
}

static bool enqueue_ascii(uint8_t ch, bool alt)
{
    static const uint8_t letter_codes[] = {
        0x1c, 0x32, 0x21, 0x23, 0x24, 0x2b, 0x34, 0x33, 0x43,
        0x3b, 0x42, 0x4b, 0x3a, 0x31, 0x44, 0x4d, 0x15, 0x2d,
        0x1b, 0x2c, 0x3c, 0x2a, 0x1d, 0x22, 0x35, 0x1a,
    };

    if (ch >= 'a' && ch <= 'z') {
        enqueue_key(letter_codes[ch - 'a'], false, false, alt);
        return true;
    }
    if (ch >= 'A' && ch <= 'Z') {
        enqueue_key(letter_codes[ch - 'A'], true, false, alt);
        return true;
    }

    switch (ch) {
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

    if (ch >= 1 && ch <= 26) {
        enqueue_key(letter_codes[ch - 1], false, true, alt);
        return true;
    }
    return false;
}

static bool enqueue_escape_sequence(void)
{
    if (escape_length == 2) {
        return enqueue_ascii((uint8_t)escape_sequence[1], true);
    }

    if (!strcmp(escape_sequence, "\033[A") || !strcmp(escape_sequence, "\033OA")) enqueue_key(0xe075, false, false, false);
    else if (!strcmp(escape_sequence, "\033[B") || !strcmp(escape_sequence, "\033OB")) enqueue_key(0xe072, false, false, false);
    else if (!strcmp(escape_sequence, "\033[C") || !strcmp(escape_sequence, "\033OC")) enqueue_key(0xe074, false, false, false);
    else if (!strcmp(escape_sequence, "\033[D") || !strcmp(escape_sequence, "\033OD")) enqueue_key(0xe06b, false, false, false);
    else if (!strcmp(escape_sequence, "\033[H") || !strcmp(escape_sequence, "\033OH") || !strcmp(escape_sequence, "\033[1~") || !strcmp(escape_sequence, "\033[7~")) enqueue_key(0xe06c, false, false, false);
    else if (!strcmp(escape_sequence, "\033[F") || !strcmp(escape_sequence, "\033OF") || !strcmp(escape_sequence, "\033[4~") || !strcmp(escape_sequence, "\033[8~")) enqueue_key(0xe069, false, false, false);
    else if (!strcmp(escape_sequence, "\033[2~")) enqueue_key(0xe070, false, false, false);
    else if (!strcmp(escape_sequence, "\033[3~")) enqueue_key(0xe071, false, false, false);
    else if (!strcmp(escape_sequence, "\033[5~")) enqueue_key(0xe07d, false, false, false);
    else if (!strcmp(escape_sequence, "\033[6~")) enqueue_key(0xe07a, false, false, false);
    else if (!strcmp(escape_sequence, "\033OP") || !strcmp(escape_sequence, "\033[11~")) enqueue_key(0x05, false, false, false);
    else if (!strcmp(escape_sequence, "\033OQ") || !strcmp(escape_sequence, "\033[12~")) enqueue_key(0x06, false, false, false);
    else if (!strcmp(escape_sequence, "\033OR") || !strcmp(escape_sequence, "\033[13~")) enqueue_key(0x04, false, false, false);
    else if (!strcmp(escape_sequence, "\033OS") || !strcmp(escape_sequence, "\033[14~")) enqueue_key(0x0c, false, false, false);
    else if (!strcmp(escape_sequence, "\033[15~")) enqueue_key(0x03, false, false, false);
    else if (!strcmp(escape_sequence, "\033[17~")) enqueue_key(0x0b, false, false, false);
    else if (!strcmp(escape_sequence, "\033[18~")) enqueue_key(0x83, false, false, false);
    else if (!strcmp(escape_sequence, "\033[19~")) enqueue_key(0x0a, false, false, false);
    else if (!strcmp(escape_sequence, "\033[20~")) enqueue_key(0x01, false, false, false);
    else if (!strcmp(escape_sequence, "\033[21~")) enqueue_key(0x09, false, false, false);
    else if (!strcmp(escape_sequence, "\033[23~")) enqueue_key(0x78, false, false, false);
    else if (!strcmp(escape_sequence, "\033[24~")) enqueue_key(0x07, false, false, false);
    else return false;
    return true;
}

static void consume_input_byte(uint8_t ch)
{
    if (escape_length == 0) {
        if (ch == 0x1b) {
            escape_sequence[0] = '\033';
            escape_sequence[1] = '\0';
            escape_length = 1;
            clock_gettime(CLOCK_MONOTONIC, &escape_started);
        } else {
            enqueue_ascii(ch, false);
        }
        return;
    }

    escape_sequence[escape_length++] = (char)ch;
    escape_sequence[escape_length] = '\0';
    if (escape_length == 2 && ch != '[' && ch != 'O') {
        enqueue_escape_sequence();
        escape_length = 0;
        return;
    }

    if (escape_length >= 3 && ch >= 0x40 && ch <= 0x7e) {
        enqueue_escape_sequence();
        escape_length = 0;
    } else if (escape_length > 16) {
        escape_length = 0;
    }
}

static void terminal_restore(void)
{
    if (!terminal_active) {
        return;
    }
    if (terminal_is_tty) {
        tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
    }
    if (saved_stdin_flags >= 0) {
        fcntl(STDIN_FILENO, F_SETFL, saved_stdin_flags);
    }
    saved_stdin_flags = -1;
    terminal_active = false;
}

static void terminal_signal_handler(int signal_number)
{
    terminal_restore();
    signal(signal_number, SIG_DFL);
    raise(signal_number);
}

static void terminal_init(void)
{
    struct sigaction action;
    int signals[] = {SIGINT, SIGQUIT, SIGTERM, SIGHUP};

    initialized = true;
    terminal_is_tty = isatty(STDIN_FILENO);
    if (terminal_is_tty) {
        if (tcgetattr(STDIN_FILENO, &saved_termios) != 0) {
            stdin_eof = true;
            return;
        }
        struct termios raw = saved_termios;
        raw.c_lflag &= ~(ICANON | ECHO);
        raw.c_cc[VMIN] = 0;
        raw.c_cc[VTIME] = 0;
        if (tcsetattr(STDIN_FILENO, TCSANOW, &raw) != 0) {
            stdin_eof = true;
            return;
        }
    }

    saved_stdin_flags = fcntl(STDIN_FILENO, F_GETFL, 0);
    if (saved_stdin_flags < 0 ||
        fcntl(STDIN_FILENO, F_SETFL, saved_stdin_flags | O_NONBLOCK) != 0) {
        if (terminal_is_tty) {
            tcsetattr(STDIN_FILENO, TCSANOW, &saved_termios);
        }
        stdin_eof = true;
        return;
    }

    terminal_active = true;
    atexit(terminal_restore);
    memset(&action, 0, sizeof(action));
    action.sa_handler = terminal_signal_handler;
    sigemptyset(&action.sa_mask);
    for (size_t i = 0; i < sizeof(signals) / sizeof(signals[0]); ++i) {
        sigaction(signals[i], &action, NULL);
    }
}

static int poll_input(void)
{
    uint8_t buffer[64];

    if (!initialized) {
        terminal_init();
    }

    while (!stdin_eof && queue_count + 16 < SCANCODE_QUEUE_SIZE) {
        ssize_t count = read(STDIN_FILENO, buffer, sizeof(buffer));
        if (count > 0) {
            for (ssize_t i = 0; i < count; ++i) {
                consume_input_byte(buffer[i]);
            }
            continue;
        }
        if (count == 0 && !terminal_is_tty) {
            stdin_eof = true;
            if (escape_length == 1) {
                enqueue_key(0x76, false, false, false);
            }
            escape_length = 0;
        }
        break;
    }

    if (escape_length != 0 && milliseconds_since(&escape_started) > ESCAPE_TIMEOUT_MS) {
        if (escape_length == 1) {
            enqueue_key(0x76, false, false, false);
        }
        escape_length = 0;
    }
    return queue_pop();
}

#ifdef VERILATOR
#ifdef __cplusplus
extern "C"
#endif
int iv_ps2_input(void)
{
    return poll_input();
}

#ifdef __cplusplus
extern "C"
#endif
void iv_exit(int code)
{
    exit(code);
}
#else
static PLI_INT32 iv_ps2_input_calltf(PLI_BYTE8 *user_data)
{
    vpiHandle call = vpi_handle(vpiSysTfCall, NULL);
    s_vpi_value value;
    (void)user_data;
    value.format = vpiIntVal;
    value.value.integer = poll_input();
    vpi_put_value(call, &value, NULL, vpiNoDelay);
    return 0;
}

static void iv_ps2_input_register(void)
{
    s_vpi_systf_data data;
    memset(&data, 0, sizeof(data));
    data.type = vpiSysFunc;
    data.sysfunctype = vpiIntFunc;
    data.tfname = "$iv_ps2_input";
    data.calltf = iv_ps2_input_calltf;
    vpi_register_systf(&data);
}

void (*vlog_startup_routines[])(void) = {
    iv_ps2_input_register,
    NULL,
};
#endif
