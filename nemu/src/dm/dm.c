#include "debug.h"
#include "dm/dm.h"
#include "isa.h"

#define DM_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DM_REG(S, N) DM_REGISTER(dm_reg_##S##_t, dm_ri_##S, N, ctx->regs)
#define DM_R(N) DM_REG(N, r_##N)

static int dm_handle_dmcontrol(dm_ctx_t *ctx);
static int dm_handle_command(dm_ctx_t *ctx);

static dm_ctx_t dm_ctx_list[DM_CTX_MAX] = {0};
dm_ctx_t *cur_dm_ctx = NULL;
const dm_handle_reg_func_t dm_handle_reg_funcs[dm_ri_count] = {
    [dm_ri_dmcontrol] = dm_handle_dmcontrol,
    [dm_ri_command] = dm_handle_command,
};

static int dm_access_cpu_gprs(uint32_t write, int reg_idx, word_t *reg_value)
{
    // extern CPU_state cpu;
    word_t *reg = isa_get_cpu_gpr(reg_idx);
    if (write)
        *reg = *reg_value;
    else
        *reg_value = *reg;
    return 0;
}

static inline void dm_sync_regs(dm_ctx_t *ctx)
{
    memcpy(&ctx->last_regs[0], &ctx->regs[0], sizeof(ctx->regs));
}

static inline int dm_init_regs(dm_ctx_t *ctx)
{
    memset(ctx->regs, 0, sizeof(ctx->regs));

    DM_R(dmstatus);
    r_dmstatus->version = 2;
    r_dmstatus->authenticated = 1;

#if DM_CTX_DEBUG_INIT_HALTED
    r_dmstatus->allrunning = 0;
    r_dmstatus->anyrunning = 0;
    r_dmstatus->allhalted = 1;
    r_dmstatus->anyhalted = 1;
#else
    r_dmstatus->allrunning = 1;
    r_dmstatus->anyrunning = 1;
    r_dmstatus->allhalted = 0;
    r_dmstatus->anyhalted = 0;
#endif

    dm_sync_regs(ctx);

    return 0;
}

static inline int dm_read(dm_ctx_t *ctx, uint32_t addr, uint32_t *val)
{
    *val = ctx->regs[ctx->addr];
    // DM_REPEAT("read [%#x] => %#.8x", addr, *val);
    return 0;
}

static inline int dm_write(dm_ctx_t *ctx, uint32_t addr, uint32_t val)
{
    ctx->regs[ctx->addr] = val;
    DM_REPEAT("write [%#x] <= %#.8x", addr, val);
    return 0;
}

// TODO dm调试状态迁移
static void dm_trans_debug_status(dm_ctx_t *ctx)
{
    dm_debug_status_t last_debug_status = dm_ds_none;

    while(last_debug_status != ctx->debug_status)
    {
        switch(ctx->debug_status)
        {
            case dm_ds_halted_waiting:
            {
                // DM_DEBUG("current is halted");
                break;
            }

            default:
                DM_ERROR("TODO unknown debug status %d", ctx->debug_status);
                assert(false);
                break;
        }
        last_debug_status = ctx->debug_status;
    };
}

static int dm_handle_dmcontrol(dm_ctx_t *ctx)
{
    DM_R(dmcontrol);
    uint32_t hartsel = r_dmcontrol->hartselhi << 10 | r_dmcontrol->hartsello;

    // 调试器在启动时会使用最大值进行探测，返回最大支持的掩码即可
    if (hartsel == 0xFFFFF)
    {
        r_dmcontrol->hartselhi = (DM_CTX_MASK>>10)&0x3FF;
        r_dmcontrol->hartsello = (DM_CTX_MASK>>0)&0x3FF;
    }
    else if (hartsel < DM_CTX_MAX)
    {
        dm_select(hartsel);
    }
    else
    {
        DM_ERROR("found invalid core id %#.8x", hartsel);
    }

    r_dmcontrol->hasel = 0;

    return 0;
}

static int dm_handle_command(dm_ctx_t *ctx)
{
    if (ctx->op != DM_ACCESS_OP_WRITE)
    {
        return 0;
    }

    DM_R(command);
    
    switch(r_command->cmdtype)
    {
        // Access Register Command
        case 0:
        {
            uint32_t regno = r_command->reg.regno;
            if (r_command->reg.transfer==1) {
                /**
                 * Table 3.3: Abstract Register Numbers
                 * 0x0000 - 0x0fff CSRs. The \PC" can be accessed here through dpc.
                 * 0x1000 - 0x101f GPRs
                 * 0x1020 - 0x103f Floating point registers
                 */
                if (regno < 0x1000) {
                    DM_DEBUG("%s cpu csr, regno %#.4x", r_command->reg.write?"write":"read", regno);
                } else if (regno < 0x1020) {
                    dm_access_cpu_gprs(r_command->reg.write, regno-0x1000, &ctx->regs[dm_ri_data0]);
                    DM_DEBUG("%s cpu gpr, regno %#.4x value %#.8x", r_command->reg.write?"write":"read", regno, ctx->regs[dm_ri_data0]);
                } else if (regno < 0x1040) {
                    DM_DEBUG("%s cpu fpr, regno %#.4x", r_command->reg.write?"write":"read", regno);
                } else {
                    DM_ERROR("unknown regno %#.4x", regno);
                }
            }

            break;
        }
        
        // Quick Access
        case 1:
        {
            break;
        }
        
        // Access Memory Command
        case 2:
        {
            break;
        }

        default:
            break;
    }

    r_command->raw_value = 0;

    return 0;
}

int dm_init(void)
{
    for (size_t i=0; i<DM_ARRAY_SIZE(dm_ctx_list); ++i)
    {
        dm_ctx_t *ctx = &dm_ctx_list[i];
        memset(ctx, 0, sizeof(dm_ctx_t));
        dm_init_regs(ctx);
        dm_sync_regs(ctx);

#if DM_CTX_DEBUG_INIT_HALTED
        ctx->debug_status = dm_ds_halted_waiting;
#else
        ctx->debug_status = dm_ds_mus_mode;
#endif

        dm_update_status(ctx);

        memcpy(ctx->handle_reg_funcs, dm_handle_reg_funcs, sizeof(dm_handle_reg_funcs));
    }

    dm_select(0);

    return 0;
}

int dm_execute(dm_ctx_t *ctx, uint32_t addr, uint32_t *val, uint32_t op)
{
    bool repeat = (op == 0) || (ctx->addr==addr && ctx->val==*val && ctx->op==op);
    ctx->repeat_cnt = repeat ? ctx->repeat_cnt + 1 : 0;

    // 记录上次的dm操作
    if (op == DM_ACCESS_OP_READ || op == DM_ACCESS_OP_WRITE)
    {
        ctx->addr = addr;
        ctx->val = *val;
        ctx->op = op;


    }

    // 读取dm的寄存器
    if (ctx->op == DM_ACCESS_OP_READ)
    {
        dm_read(ctx, ctx->addr, val);
    }

    // 写入dm的寄存器
    if (ctx->op == DM_ACCESS_OP_WRITE)
    {
        dm_write(ctx, ctx->addr, ctx->val);

        // dm在执行写寄存器后，调用对应的处理函数
        dm_handle_reg_func_t handle_reg_func = ctx->handle_reg_funcs[ctx->addr];
        if (handle_reg_func)
        {
            int handle_ret = handle_reg_func(ctx);
            (void)handle_ret;
        }
    }

    // 更新dm状态
    dm_update_status(ctx);

    return 0;
}

int dm_update_status(dm_ctx_t *ctx)
{
    // dm在执行写寄存器后，调用对应的处理函数
    for (uint32_t i=0; i<DM_ARRAY_SIZE(ctx->regs); ++i)
    {
        if (0 == memcmp(&ctx->regs[i], &ctx->last_regs[i], sizeof(ctx->regs[i])))
            continue;
        
        DM_DEBUG("register modify [%#x]%#.8x => %#.8x", i, ctx->last_regs[i], ctx->regs[i]);
    }
    
    dm_sync_regs(ctx);

    // dm调试状态进行迁移
    dm_trans_debug_status(ctx);

    return 0;
}

dm_debug_status_t dm_get_debug_status(dm_ctx_t *ctx)
{
    return ctx->debug_status;
}

int dm_select(uint32_t ctx_idx)
{
    assert(ctx_idx < DM_CTX_MAX && "dm select ctx_idx is too large");
    cur_dm_ctx = &dm_ctx_list[ctx_idx];
    return 0;
}
