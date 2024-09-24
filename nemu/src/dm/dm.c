#include "debug.h"
#include "dm/dm.h"

dm_ctx_t dm_ctx_list[DM_CTX_MAX] = {0};

#define DM_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DM_REG(S, N) DM_REGISTER(dm_reg_##S##_t, dm_ri_##S, N, ctx->regs)
#define DM_R(N) DM_REG(N, r_##N)

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
    LOG_DEBUG("dm read [%#x] => %#.8x", addr, *val);
    return 0;
}

static inline int dm_write(dm_ctx_t *ctx, uint32_t addr, uint32_t val)
{
    ctx->regs[ctx->addr] = val;
    LOG_DEBUG("dm write [%#x] <= %#.8x", addr, val);
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
    }

    return 0;
}

int dm_execute(dm_ctx_t *ctx, uint32_t addr, uint32_t *val, uint32_t op)
{
    // 记录上次的dm操作
    if (op == 1 || op == 2)
    {
        ctx->addr = addr;
        ctx->val = *val;
        ctx->op = op;
    }

    // 读取dm的寄存器
    if (ctx->op == 1)
    {
        dm_read(ctx, ctx->addr, val);
    }

    // 写入dm的寄存器
    if (ctx->op == 2)
    {
        dm_write(ctx, ctx->addr, ctx->val);
    }

    // 更新dm状态
    dm_update_status(ctx);

    return 0;
}

int dm_update_status(dm_ctx_t *ctx)
{
    for (uint32_t i=0; i<DM_ARRAY_SIZE(ctx->regs); ++i)
    {
        if (0 != memcmp(&ctx->regs[i], &ctx->last_regs[i], sizeof(ctx->regs[i])))
        {
            LOG_DEBUG("found dm register modify [%u]%#.8x => %#.8x", i, ctx->last_regs[i], ctx->regs[i]);
        }
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
