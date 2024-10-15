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

bool dmi_is_hart_running(void)
{
    dm_reg_dmstatus_t *r_dmstatus = (dm_reg_dmstatus_t *)&cur_dm_ctx->regs[dm_ri_dmstatus];

    return r_dmstatus->allrunning == 1;
}

int dmi_prepare_status(dm_exec_inst_period_t period, uint32_t inst)
{
    // 按最简单的方式更新PC
    extern int dm_access_cpu_csr(uint32_t write, int reg_idx, word_t *reg_value);
    extern CPU_state *cur_cpu;
    dm_access_cpu_csr(1, cd_ri_dpc, &cur_cpu->pc);

    // 根据情况判断是否需要切换到调试状态
    cur_dm_ctx->exec_inst_period = period;
    dm_prepare_status(cur_dm_ctx, inst);

    return 0;
}
