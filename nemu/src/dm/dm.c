#include "debug.h"
#include "dm/dm.h"
#include "isa.h"
#include "memory/paddr.h"
#include "memory/vaddr.h"
#include "device/mmio.h"

#define DECLARE_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DECLARE_REG(PREFIX, S, N, RS) DECLARE_REGISTER(PREFIX##_reg_##S##_t, PREFIX##_ri_##S, N, RS)
#define DM_R(N) DECLARE_REG(dm, N, r_##N, cur_dm_ctx->regs)
#define CD_R(N) DECLARE_REG(cd, N, r_##N, cur_dm_ctx->csr_regs)
#define TM_R(N) DECLARE_REG(tm, N, r_##N, cur_dm_ctx->csr_regs)
#define STD_R(N) DECLARE_REG(std, N, r_##N, cur_dm_ctx->csr_regs)

#define DM_RI_STR_ITEM(N) [dm_ri_##N] = #N

#define DM_DMSTATUS_SET(S, V) do{       \
    r_dmstatus->all##S = (V);            \
    r_dmstatus->any##S = (V);            \
}while(0)

static int dm_handle_dmcontrol(void *arg);
static int dm_handle_abstractcs(void *arg);
static int dm_handle_command(void *arg);
static bool dm_is_csr_trigger(int reg_idx);
static int dm_access_csr_trigger(uint32_t write, int reg_idx, word_t *reg_value);
static bool dm_is_csr_standard(int reg_idx);
static int dm_access_csr_standard(uint32_t write, int reg_idx, word_t *reg_value);

int dm_select_trigger(uint32_t trigger_idx);

static dm_ctx_t dm_ctx_list[DM_CTX_MAX] = {0};
dm_ctx_t *cur_dm_ctx = NULL;
CPU_state *cur_cpu = &cpu;
const dm_handle_reg_func_t dm_handle_reg_funcs[dm_ri_count] = {
    [dm_ri_dmcontrol] = dm_handle_dmcontrol,
    [dm_ri_abstractcs] = dm_handle_abstractcs,
    [dm_ri_command] = dm_handle_command,
};

static const char * dm_ri_strs[dm_ri_count] = {
    DM_RI_STR_ITEM(data0),
    DM_RI_STR_ITEM(data1),
    DM_RI_STR_ITEM(data2),
    DM_RI_STR_ITEM(data3),
    DM_RI_STR_ITEM(data4),
    DM_RI_STR_ITEM(data5),
    DM_RI_STR_ITEM(data6),
    DM_RI_STR_ITEM(data7),
    DM_RI_STR_ITEM(data8),
    DM_RI_STR_ITEM(data9),
    DM_RI_STR_ITEM(data10),
    DM_RI_STR_ITEM(data11),
    DM_RI_STR_ITEM(dmcontrol),
    DM_RI_STR_ITEM(dmstatus),
    DM_RI_STR_ITEM(hartinfo),
    DM_RI_STR_ITEM(haltsum1),
    DM_RI_STR_ITEM(hawindowsel),
    DM_RI_STR_ITEM(hawindow),
    DM_RI_STR_ITEM(abstractcs),
    DM_RI_STR_ITEM(command),
    DM_RI_STR_ITEM(abstractauto),
    DM_RI_STR_ITEM(confstrptr0),
    DM_RI_STR_ITEM(confstrptr1),
    DM_RI_STR_ITEM(confstrptr2),
    DM_RI_STR_ITEM(confstrptr3),
    DM_RI_STR_ITEM(nextdm),
    DM_RI_STR_ITEM(progbuf0),
    DM_RI_STR_ITEM(progbuf1),
    DM_RI_STR_ITEM(progbuf2),
    DM_RI_STR_ITEM(progbuf3),
    DM_RI_STR_ITEM(progbuf4),
    DM_RI_STR_ITEM(progbuf5),
    DM_RI_STR_ITEM(progbuf6),
    DM_RI_STR_ITEM(progbuf7),
    DM_RI_STR_ITEM(progbuf8),
    DM_RI_STR_ITEM(progbuf9),
    DM_RI_STR_ITEM(progbuf10),
    DM_RI_STR_ITEM(progbuf11),
    DM_RI_STR_ITEM(progbuf12),
    DM_RI_STR_ITEM(progbuf13),
    DM_RI_STR_ITEM(progbuf14),
    DM_RI_STR_ITEM(progbuf15),
    DM_RI_STR_ITEM(authdata),
    DM_RI_STR_ITEM(haltsum2),
    DM_RI_STR_ITEM(haltsum3),
    DM_RI_STR_ITEM(sbaddress3),
    DM_RI_STR_ITEM(sbcs),
    DM_RI_STR_ITEM(sbaddress0),
    DM_RI_STR_ITEM(sbaddress1),
    DM_RI_STR_ITEM(sbaddress2),
    DM_RI_STR_ITEM(sbdata0),
    DM_RI_STR_ITEM(sbdata1),
    DM_RI_STR_ITEM(sbdata2),
    DM_RI_STR_ITEM(sbdata3),
    DM_RI_STR_ITEM(haltsum0),
};

static const char* dm_ri_2_str(uint32_t idx)
{
    const char* ret_str = dm_ri_strs[idx%dm_ri_count];

    return (idx >= dm_ri_count || !ret_str) ? "" : ret_str;
}

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

int dm_access_cpu_csr(uint32_t write, int reg_idx, word_t *reg_value)
{
    dm_ctx_t *ctx = cur_dm_ctx;
    if (reg_idx < DM_ARRAY_SIZE(ctx->csr_regs)) {
        if (write)
            ctx->csr_regs[reg_idx] = *reg_value;
        else
            *reg_value = ctx->csr_regs[reg_idx];
    } else {
        DM_ERROR("unsupport %s cpu csrs %#.4x", write?"write":"read", reg_idx);
    }

    if (dm_is_csr_trigger(reg_idx)) {
        return dm_access_csr_trigger(write, reg_idx, reg_value);
    }

    if (dm_is_csr_standard(reg_idx)) {
        return dm_access_csr_standard(write, reg_idx, reg_value);
    }

    return 0;
}

static bool dm_is_csr_trigger(int reg_idx)
{
    return (reg_idx>=tm_ri_tselect && reg_idx<=tm_ri_tcontrol) ||
        reg_idx==tm_ri_mcontext ||
        reg_idx==tm_ri_scontext;
}

static int dm_access_csr_trigger(uint32_t write, int reg_idx, word_t *reg_value)
{
    TM_R(tselect);
    TM_R(tinfo);

    switch(reg_idx)
    {
        case tm_ri_tselect:
            if (r_tselect->index >= TM_TRIGER_COUNT) {
                r_tselect->index = TM_TRIGER_COUNT - 1;
                DM_DEBUG("tselect index is out of range");
            }
            dm_select_trigger(r_tselect->index);
            break;

        case tm_ri_mcontrol:
            DM_DEBUG("mcontrol %s value %#.8x", write?"write":"read", *reg_value);
            break;

        default:
            DM_ERROR("unknown csr trigger, %s addr %#.4x", write?"write":"read", reg_idx);
            break;
    }

    return 0;
}

static bool dm_is_csr_standard(int reg_idx)
{
    return (reg_idx>=0x300 && reg_idx<=0x3FF);
}

static int dm_access_csr_standard(uint32_t write, int reg_idx, word_t *reg_value)
{

    switch (reg_idx)
    {
    case std_ri_mstatus:
    {
        STD_R(mstatus);
        if (r_mstatus->vs) {
            DM_DEBUG("unsupport mstatus.vs, clear this bit");
            r_mstatus->vs = 0;
        }
        break;
    }
    
    default:
        DM_DEBUG("%s csr standard, addr %#.4x value %#.8x", write?"write":"read", reg_idx, *reg_value);
        break;
    }

    return 0;
}

static int dm_access_cpu_memory(dm_reg_command_t *cmd, uint32_t size, uint32_t *arg0, uint32_t *arg1, uint32_t *arg2)
{
    uint32_t write = cmd->memory.write;
    paddr_t addr = *arg1;
    uint8_t *val = (uint8_t *)arg0;
    int access_len = 4;

    for (int i=0; i<size; i+=access_len) {
        access_len = size - i;
        access_len = access_len > 4 ? 4 : access_len;

        if (addr >= PMEM_LEFT && addr <= PMEM_RIGHT) {
            if (write) {
                vaddr_write(addr, access_len, *arg0);
            } else {
                word_t mem_val = vaddr_read(addr, access_len);
                memcpy(arg0, &mem_val, access_len);
            }
        } else if (addr >= CONFIG_RTC_MMIO && addr <= CONFIG_RTC_MMIO) {
            if (write) {
                mmio_write(addr, access_len, *arg0);
            } else {
                word_t mem_val = mmio_read(addr, access_len);
                memcpy(arg0, &mem_val, access_len);
            }
        } else {
            DM_ERROR("unknown %s memory addr %#.8x skiped", write?"write":"read", addr);
            // return DM_ABSTRACTCS_CMDERR_BUS;
            return DM_ABSTRACTCS_CMDERR_NONE;
        }

        val += access_len;
        addr += access_len;
        arg0 = (uint32_t *)val;
    }

    if (cmd->memory.aampostincrement) {
        *arg1 = addr;
    }

    return DM_ABSTRACTCS_CMDERR_NONE;
}

static int dm_handle_command_access_register(dm_ctx_t *ctx)
{
    DM_R(command);
    DM_R(abstractcs);

    // 3.6.1.1 Access Register
    // 若访问宽度不满足要求，则需要设置abstractcs.cmderr
    if (r_command->reg.aarsize != 2) {
        r_abstractcs->cmderr = DM_ABSTRACTCS_CMDERR_NOT_SUPPORTED;
        // DM_ERROR("unsupport access register command size %#x", r_command->reg.aarsize);
        return 0;
    }

    uint32_t regno = r_command->reg.regno;
    if (r_command->reg.transfer==1) {
        uint32_t *dm_data0 = &cur_dm_ctx->regs[dm_ri_data0];
        /**
         * Table 3.3: Abstract Register Numbers
         * 0x0000 - 0x0fff CSRs. The \PC" can be accessed here through dpc.
         * 0x1000 - 0x101f GPRs
         * 0x1020 - 0x103f Floating point registers
         */
        if (regno < 0x1000) {
            dm_access_cpu_csr(r_command->reg.write, regno, dm_data0);
            DM_DEBUG("%s cpu csr, regno %#.4x value %#.8x", r_command->reg.write?"write":"read", regno, *dm_data0);
        } else if (regno < 0x1020) {
            dm_access_cpu_gprs(r_command->reg.write, regno-0x1000, dm_data0);
            DM_DEBUG("%s cpu gpr, regno %#.4x value %#.8x", r_command->reg.write?"write":"read", regno, *dm_data0);
        } else if (regno < 0x1040) {
            DM_DEBUG("%s cpu fpr, regno %#.4x", r_command->reg.write?"write":"read", regno);
        } else {
            DM_ERROR("unknown regno %#.4x", regno);
        }
    }
    
    return 0;
}

static int dm_handle_command_access_memory(dm_ctx_t *ctx)
{
    DM_R(command);
    DM_R(abstractcs);
    uint32_t *arg0 = &ctx->regs[dm_ri_data0];
    uint32_t *arg1 = &ctx->regs[dm_ri_data1];
    uint32_t *arg2 = &ctx->regs[dm_ri_data2];
    uint32_t size = 0;

    switch(r_command->memory.aamsize)
    {
        case DM_COMMAND_MEMORY_AAMSIZE_8bits:
            size = 1;
            break;

        case DM_COMMAND_MEMORY_AAMSIZE_16bits:
            size = 2;
            break;

        case DM_COMMAND_MEMORY_AAMSIZE_32bits:
            size = 4;
            break;
        
        case DM_COMMAND_MEMORY_AAMSIZE_64bits:
            size = 8;
            arg0 = &ctx->regs[dm_ri_data0];
            arg1 = &ctx->regs[dm_ri_data2];
            break;
        
        case DM_COMMAND_MEMORY_AAMSIZE_128bits:
            size = 16;
            arg0 = &ctx->regs[dm_ri_data0];
            arg1 = &ctx->regs[dm_ri_data4];
            break;

        default:
            r_abstractcs->cmderr = DM_ABSTRACTCS_CMDERR_NOT_SUPPORTED;
            DM_ERROR("unsupport command access memory size %#x", r_command->memory.aamsize);
            break;
    }

    int access_err = dm_access_cpu_memory(r_command, size, arg0, arg1, arg2);
    if (access_err != DM_ABSTRACTCS_CMDERR_NONE) {
        r_abstractcs->cmderr = access_err;
    }

    return 0;
}

static inline void dm_sync_regs(dm_ctx_t *ctx)
{
    memcpy(&ctx->last_regs[0], &ctx->regs[0], sizeof(ctx->regs));
}

static inline int dm_init_regs(dm_ctx_t *ctx)
{
    memset(ctx->regs, 0, sizeof(ctx->regs));

    DM_R(hartinfo);
    r_hartinfo->nscratch = 0;

    DM_R(abstractcs);
    r_abstractcs->datacount = 1;

    DM_R(dmstatus);
    r_dmstatus->version = 2;
    r_dmstatus->authenticated = 1; 

#if DM_CTX_DEBUG_INIT_HALTED
    DM_DMSTATUS_SET(running, 0);
    DM_DMSTATUS_SET(halted, 1);
#else
    DM_DMSTATUS_SET(running, 1);
    DM_DMSTATUS_SET(halted, 0);
#endif

    dm_sync_regs(ctx);

    CD_R(dcsr);
    r_dcsr->xdebugver = 4;
    r_dcsr->cause = 3;

    CD_R(dpc);
    r_dpc->raw_value = CONFIG_MBASE;

    return 0;
}

static inline int dm_read(dm_ctx_t *ctx, uint32_t addr, uint32_t *val)
{
    *val = ctx->regs[ctx->addr];
    // DM_REPEAT("read [%#x '%s'] => %#.8x", addr, dm_ri_2_str(addr), *val);
    return 0;
}

static inline int dm_write(dm_ctx_t *ctx, uint32_t addr, uint32_t val)
{
    ctx->regs[ctx->addr] = val;
    DM_REPEAT("write [%#x '%s'] <= %#.8x", addr, dm_ri_2_str(addr), val);
    return 0;
}

// TODO dm调试状态迁移
static void dm_trans_debug_status(dm_ctx_t *ctx)
{
    CD_R(dcsr);
    DM_R(dmcontrol);
    DM_R(dmstatus);
    DM_R(abstractcs);
    dm_debug_status_t last_debug_status = dm_ds_none;

    while(last_debug_status != ctx->debug_status)
    {
        if (r_abstractcs->cmderr != 0) {
            ctx->debug_status = dm_ds_error_wait;
        }

        switch(ctx->debug_status)
        {
            case dm_ds_error_wait:
            {
                DM_DEBUG("current is error wait");

                if (r_abstractcs->cmderr == 0) {
                    ctx->debug_status = dm_ds_halted_waiting;
                    DM_DEBUG("current is error wait, => halted waiting");
                }
                break;
            }

            case dm_ds_halted_waiting:
            {
                // DM_DEBUG("current is halted waiting");

                if (r_dmstatus->allhalted == 1 &&
                    r_abstractcs->busy == 0 &&
                    r_abstractcs->cmderr == 0 &&
                    r_dmcontrol->resumereq == 1
                ) {
                    r_dmcontrol->resumereq = 0;
                    DM_DMSTATUS_SET(resumeack, 1);
                    ctx->debug_status = dm_ds_resuming;

                    DM_DEBUG("current is halted waiting, => resuming");
                    DM_DEBUG("status: step:%u cause:%u dcsr:%x", r_dcsr->step, r_dcsr->cause, r_dcsr->raw_value);
                }
                break;
            }

            case dm_ds_resuming:
            {
                DM_DEBUG("current is resuming");

                if (r_dmstatus->allrunning == 0 &&
                    r_abstractcs->busy == 0 &&
                    r_abstractcs->cmderr == 0
                ) {
                    DM_DMSTATUS_SET(running, 1);
                    ctx->debug_status = dm_ds_mus_mode;
                    
                    DM_DEBUG("current is resuming, => mus mode");
                }
                break;
            }

            case dm_ds_mus_mode:
            {
                DM_DEBUG("current is mus mode");

                DM_DMSTATUS_SET(running, 1);
                ctx->debug_status = dm_ds_mus_mode;
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

static int dm_handle_dmcontrol(void *arg)
{
    DM_R(dmcontrol);
    DM_R(dmstatus);
    dm_reg_dmcontrol_t *last_val = (dm_reg_dmcontrol_t *)&cur_dm_ctx->last_val;
    dm_reg_dmcontrol_t *w_val = (dm_reg_dmcontrol_t *)&cur_dm_ctx->val;
    uint32_t hartsel = w_val->hartselhi << 10 | w_val->hartsello;
    uint32_t last_hartsel = last_val->hartselhi << 10 | last_val->hartsello;

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

    uint32_t cur_hartsel = r_dmcontrol->hartselhi << 10 | r_dmcontrol->hartsello;
    if (last_hartsel != cur_hartsel) {
        DM_DEBUG("switch current from hart[%u] to hart[%u]", last_hartsel, cur_hartsel);
    }

    return 0;
}

static int dm_handle_abstractcs(void *arg)
{
    DM_R(abstractcs);
    dm_reg_abstractcs_t *w_val = (dm_reg_abstractcs_t *)&cur_dm_ctx->val;
    dm_reg_abstractcs_t *last_val = (dm_reg_abstractcs_t *)&cur_dm_ctx->last_val;

    if (w_val->cmderr) {
        last_val->cmderr = 0;
    }

    r_abstractcs->raw_value = last_val->raw_value;

    return 0;
}

static int dm_handle_command(void *arg)
{
    dm_ctx_t *ctx = cur_dm_ctx;
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
            dm_handle_command_access_register(ctx);
            break;
        }
        
        // Quick Access
        case 1:
        {
            DM_ERROR("unimplement quick access");
            break;
        }
        
        // Access Memory Command
        case 2:
        {
            dm_handle_command_access_memory(ctx);
            break;
        }

        default:
            break;
    }

    r_command->raw_value = 0;

    return 0;
}

static int dm_init_csr(dm_ctx_t *ctx)
{
    // trigger
    for (size_t i=0; i<DM_ARRAY_SIZE(ctx->tm_triggers); ++i) {
        dm_select_trigger(i);
        tm_trigger_info_t *trigger = &ctx->tm_triggers[i];
        trigger->info = TM_TDATA1_MASK_ADDR_OR_DATA;
    }
    dm_select_trigger(0);

    // standard
    STD_R(misa);
    r_misa->extensions = 0;
    r_misa->mxl = STD_MISA_MXL_32;

    return 0;
}

int dm_init(void)
{

    for (size_t i=0; i<DM_ARRAY_SIZE(dm_ctx_list); ++i)
    {
        dm_select(i);
        dm_ctx_t *ctx = &dm_ctx_list[i];
        memset(ctx, 0, sizeof(dm_ctx_t));
        dm_init_regs(ctx);
        dm_sync_regs(ctx);
        dm_init_csr(ctx);

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
        dm_read(ctx, ctx->addr, &ctx->last_val);
        dm_write(ctx, ctx->addr, ctx->val);

        // dm寄存器处理函数
        dm_handle_reg_func_t handle_reg_func = ctx->handle_reg_funcs[ctx->addr];
        if (handle_reg_func)
        {
            int handle_ret = handle_reg_func(ctx);
            (void)handle_ret;
        }
    }

    return 0;
}

int dm_update_status(dm_ctx_t *ctx)
{
    // dm在执行写寄存器后，调用对应的处理函数
    for (uint32_t i=0; i<DM_ARRAY_SIZE(ctx->regs); ++i)
    {
        if (0 == memcmp(&ctx->regs[i], &ctx->last_regs[i], sizeof(ctx->regs[i])))
            continue;
        
        // DM_DEBUG("register modify [%#x]%#.8x => %#.8x", i, ctx->last_regs[i], ctx->regs[i]);
    }
    
    // dm调试状态进行迁移
    dm_trans_debug_status(ctx);

    dm_sync_regs(ctx);

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

int dm_select_trigger(uint32_t trigger_idx)
{
    assert(cur_dm_ctx && "current dm is invalid");
    assert(trigger_idx < TM_TRIGER_COUNT && "dm trigger select idx is too large");

    // switch to new trigger, need to copy its information
    cur_dm_ctx->cur_trigger = &cur_dm_ctx->tm_triggers[trigger_idx];
    
    TM_R(tinfo);
    r_tinfo->info = cur_dm_ctx->cur_trigger->info;
    
    TM_R(tdata1);
    if (r_tinfo->info&TM_TDATA1_MASK_ADDR_OR_DATA) {
        r_tdata1->type = TM_TDATA1_ADDR_OR_DATA;
    }
    assert((r_tinfo->info&(~TM_TDATA1_MASK_ADDR_OR_DATA))==0 && "dm trigger tinfo unsupport other type");

    return 0;
}

int dm_check_ebreak(dm_ctx_t *ctx, uint32_t inst)
{
    CD_R(dcsr);
    DM_R(dmstatus);

    /**
     * 4.8.1 Debug Control and Status (dcsr, at 0x7b0)
     *   使用ebreak实现单步调试
     */
    if (r_dcsr->ebreakm == 1 &&
        inst == 0x00100073
    ) {
        r_dcsr->cause = CD_DCSR_CAUSE_EBREAK;
        DM_DMSTATUS_SET(running, 0);
        DM_DMSTATUS_SET(halted, 1);
        ctx->debug_status = dm_ds_halted_waiting;
        DM_DEBUG("ebreak => halted waiting");
    }

    return 0;
}
