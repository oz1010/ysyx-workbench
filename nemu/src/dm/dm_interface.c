#include "dm/dm.h"
#include "dm/dm_interface.h"
#include "debug.h"

#define DMI_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DMI_REG(S, N) DMI_REGISTER(dm_reg_##S##_t, dm_ri_##S, N, dmi_registers)
#define DMI_R(N) DMI_REG(N, r_##N)

extern dm_ctx_t dm_ctx_list[DM_CTX_MAX];
static dm_ctx_t *cur_dm_ctx = NULL;

int dmi_init()
{
    dmi_select(0);

    return 0;
}

int dmi_select(uint32_t ctx_idx)
{
    assert(ctx_idx < DM_ARRAY_SIZE(dm_ctx_list) && "dmi select ctx_idx is too large");
    cur_dm_ctx = &dm_ctx_list[ctx_idx];
    return 0;
}

int dmi_execute(uint32_t addr, uint32_t *val, uint32_t op)
{
    return dm_execute(cur_dm_ctx, addr, val, op);
}

int dmi_update_status(void)
{
    return dm_update_status(cur_dm_ctx);
}

dm_debug_status_t dmi_get_debug_status(void)
{
    return dm_get_debug_status(cur_dm_ctx);
}
