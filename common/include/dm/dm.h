#ifndef __DM_H__
#define __DM_H__

#include "generated/autoconf.h"
#include "dm/dm_define.h"
#include "dm/cpu_interface.h"

#define     DM_CTX_MAX                  1
#define     DM_CTX_MASK                 (DM_CTX_MAX - 1)
#define     DM_CTX_DEBUG_INIT_HALTED    true
#define     DM_ENABLE_DEBUG_LOG         true
#define     DM_ENABLE_REPEAT_LOG        false

#define     DM_ACCESS_OP_READ           1
#define     DM_ACCESS_OP_WRITE          2

#if CONFIG_DM_IO_LOG
#define DM_IO_DEBUG(format, ...) LOG_DEBUG("(dm io) " format, ## __VA_ARGS__)
#else
#define DM_IO_DEBUG(format, ...)
#endif

#if CONFIG_DM_LOG
#define DM_DEBUG(format, ...) LOG_DEBUG("(dm) " format, ## __VA_ARGS__)
#else
#define DM_DEBUG(format, ...)
#endif
#define DM_ERROR(format, ...) LOG_ERROR("(dm) " format, ## __VA_ARGS__)

#if DM_ENABLE_REPEAT_LOG
#define DM_REPEAT(format, ...)                                  \
    do{                                                         \
        if (ctx->repeat_cnt)                                    \
        {                                                       \
            ctx->in_repeat = true;                              \
            _log_raw("\r(repeat log %d)", ctx->repeat_cnt);     \
        } else {                                                \
            if (ctx->in_repeat) {                               \
                _log_raw("\n\r");                               \
                _log_raw("\n\r");                               \
            }                                                   \
            ctx->in_repeat = false;                             \
            DM_DEBUG(format, ##__VA_ARGS__);                    \
        }                                                       \
    }while(0)
#else
#define DM_REPEAT(format, ...) DM_DEBUG(format, ##__VA_ARGS__)
#endif

struct _dm_ctx_s;

typedef int (*dm_handle_reg_func_t)(void *arg);

/**
 * 触发器基本信息
 */
typedef struct _tm_trigger_info_s
{
    /**
     * used
     */
    bool used;

    union {
        struct
        {
            uint32_t id;
        };
        
        struct {
            uint32_t tselect;
            uint32_t tdata[3];

            /**
             * Bit N corresponds to type N. If the bit is set, then that type is 
             * supported by the currently selected trigger.
             */
            uint32_t tinfo;
        } common;

        struct {
            uint32_t id;
            uint32_t mcontrol;
            uint32_t addr;
        } breakpoint;
    };

} tm_trigger_info_t;

/**
 * 调试模块上下文
 */
typedef struct _dm_ctx_s
{
    /**
     * CPU操作接口
     */
    cpu_opt_t *cpu_opt;

    /**
     * 待访问的地址
     */
    uint32_t addr;
    /**
     * 待处理的数据
     */
    uint32_t val;
    /**
     * 读取待访问的地址的数据
     */
    uint32_t last_val;
    /**
     * 操作符。1--读；2--写；其他--重复之前的动作
     */
    uint32_t op;

    bool in_repeat;
    uint32_t repeat_cnt;
    
    /**
     * 寄存器
     */
    uint32_t regs[dm_ri_count];
    /**
     * 寄存器的副本
     */
    uint32_t last_regs[dm_ri_count];
    /**
     * 寄存器处理函数
     */
    dm_handle_reg_func_t handle_reg_funcs[dm_ri_count];

    /**
     * dm自身的调试状态
     */
    dm_debug_status_t debug_status;

    /**
     * ref. The RISC-V Instruction Set Manual Volume II - Privileged Architecture
     *   2.2 CSR Listing
     *     Machine-Level CSRs
     */
    uint32_t csr_regs[0x1000];

    // /**
    //  * tm触发器寄存器
    //  */
    // uint32_t tm_regs[16];
    /**
     * tm触发器数组
    */
    tm_trigger_info_t tm_triggers[TM_TRIGER_COUNT];
    /**
     * tm当前选择的触发器
     */
    tm_trigger_info_t *cur_trigger;

    /**
     * 可访问内存部分
     */
    uint8_t access_memory[DM_ACCESS_MEMORY_MAX];

    /**
     * 当前所处执行周期
     */
    dm_exec_inst_period_t exec_inst_period;
} dm_ctx_t;

int dm_add_def_cpu_opt(cpu_opt_t *cpu_opt);
int dm_init(void);
int dm_execute(dm_ctx_t *ctx, uint32_t addr, uint32_t *val, uint32_t op);
int dm_update_status(dm_ctx_t *ctx);
dm_debug_status_t dm_get_debug_status(dm_ctx_t *ctx);
int dm_select(uint32_t ctx_idx);
int dm_prepare_status(dm_ctx_t *ctx, uint32_t inst);

#endif
