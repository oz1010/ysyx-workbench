#include "dm/dm.h"
#include "dm/dm_interface.h"
#include "debug.h"
#include "isa.h"

#define DMI_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DMI_REG(S, N) DMI_REGISTER(dm_reg_##S##_t, dm_ri_##S, N, dmi_registers)
#define DMI_R(N) DMI_REG(N, r_##N)

extern dm_ctx_t *cur_dm_ctx;

int dmi_init()
{
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

int dmi_update_core_debug_register(int period)
{
    uint32_t *csr = &cpu.csr[0];
    
    // 按最简单的方式更新状态
    csr[cd_ri_dpc] = cpu.pc;

    return 0;
}

int dmi_check_ebreak(uint32_t inst)
{
    return dm_check_ebreak(cur_dm_ctx, inst);
}
