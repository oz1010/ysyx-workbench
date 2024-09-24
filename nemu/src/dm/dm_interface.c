#include "dm/dm_interface.h"
#include "debug.h"

#define DMI_REGISTER(T, I, N, RS) T*N=(T*)&RS[(I)];(void)N
#define DMI_REG(S, N) DMI_REGISTER(dm_reg_##S##_t, dm_ri_##S, N, dmi_registers)
#define DMI_R(N) DMI_REG(N, r_##N)

static uint32_t dmi_registers[dm_ri_count] = {0};
static uint32_t dmi_registers_last[dm_ri_count] = {0};

static void dmi_init_regs(void)
{
    memset(&dmi_registers, 0, sizeof(dmi_registers));

    DMI_R(dmstatus);
    r_dmstatus->version = 2;
    r_dmstatus->authenticated = 1;
}

static void dmi_sync_regs(void)
{
    memcpy(&dmi_registers_last[0], &dmi_registers[0], sizeof(dmi_registers));
}

int dmi_init()
{
    dmi_init_regs();

    dmi_sync_regs();
    return 0;
}

int dmi_read(dm_regs_idx_t idx, uint32_t *val)
{
    assert(idx<dm_ri_count && "reading reg idx is out of range");
    *val = dmi_registers[idx];
    return 0;
}

int dmi_write(dm_regs_idx_t idx, uint32_t val)
{
    assert(idx<dm_ri_count && "writing reg idx is out of range");
    dmi_registers[idx] = val;
    return 0;
}

int dmi_execute(uint32_t addr, uint32_t in_val, uint32_t *out_val, uint32_t op)
{
    static uint32_t last_addr;
    static uint32_t last_in_val;
    static uint32_t last_op;
    int ret = 0;

    if (op == 0) {
        // LOG_INFO("execute nop command, repeat last op");
        addr = last_addr;
        in_val = last_in_val;
        op = last_op;
    }

    switch(op)
    {
        // nop
        case 0:
        {
            break;
        }

        // read
        case 1:
        {
            ret = dmi_read(addr, out_val);
            LOG_DEBUG("dmi read [%#x]=>%#x %d", addr, *out_val, ret);
            break;
        }
        
        // write
        case 2:
        {
            ret = dmi_write(addr, in_val);
            LOG_DEBUG("dmi write [%#x]=>%#x %d", addr, in_val, ret);
            break;
        }

        default:
        {
            LOG_ERROR("unknown op %u", op);
            ret = -1;
            break;
        }
    }

    if (op==1 || op==2)
    {
        last_addr = addr;
        last_in_val = in_val;
        last_op = op;
    }

    return ret;
}

int dmi_update_status(void)
{
    for (uint32_t i=0; i<dm_ri_count; ++i)
    {
        if (0 != memcmp(&dmi_registers[i], &dmi_registers_last[i], sizeof(dmi_registers[i])))
        {
            LOG_DEBUG("found dmi register modify [%u]%#.8x => %#.8x", i, dmi_registers_last[i], dmi_registers[i]);
        }
    }
    
    dmi_sync_regs();
    return 0;
}
