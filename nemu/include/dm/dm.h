#ifndef __DM_H__
#define __DM_H__

#include <stdint.h>
#include "cpu/decode.h"
#include "cpu/cpu.h"

typedef enum _dm_debug_status_e {
    dmds_none,
    dmds_init,
    dmds_mus_mode,

    dmds_resuming,
    dmds_halting,
    dmds_halted_waiting,

    dmds_command_start,
    dmds_command_transfer,
    dmds_command_done,
    dmds_command_progbuf,

    dmds_error_detected,
    dmds_error_wait,

    dmds_quick_access_halt,
    dmds_quick_access_resume,
    dmds_quick_access_exec,
} dm_debug_status_t;

int init_dm(int argc, char *argv[]);
dm_debug_status_t get_dm_debug_status();
int dm_valid();
void dm_update(int period, Decode *s, CPU_state *c);

#endif
