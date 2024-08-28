#include "dm/dm_interface.h"

static uint32_t dmi_registers[dmri_count] = {0};

int init_dm_interface()
{
    return 0;
}

int dmi_read(dmr_idx_t idx, uint32_t *val)
{
    *val = dmi_registers[idx];
    return 0;
}

int dmi_write(dmr_idx_t idx, uint32_t val)
{
    dmi_registers[idx] = val;
    return 0;
}
