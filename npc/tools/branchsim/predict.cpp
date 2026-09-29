// 分支预测算法表：新增算法只需实现处理函数并在此表注册一项
#include "predict.h"
#include <cstring>

// =============================================================================
// 预测算法实现
// =============================================================================

/**
 * 静态不跳转策略：恒预测不跳转
 */
static bool predict_static_not_taken(const branch_ctx_t&)
{
    return false;
}

/**
 * 静态跳转策略：恒预测跳转
 */
static bool predict_static_taken(const branch_ctx_t&)
{
    return true;
}

/**
 * BTFN策略：若分支的跳转目标位于后方(符号位为0)，则预测跳转，反之则预测不跳转。
 */
static bool predict_btfn(const branch_ctx_t& ctx)
{
    // B-type immediate bit 12 is encoded in instruction bit 31.  A set
    // sign bit means the branch target is behind the current PC, which is
    // the backward-taken half of the BTFN policy.
    const uint16_t type = ctx.dec.inst_code & 0x0F00;  // INST_TYPE_xxx位
    bool jump_pc = false;                           // 默认保持跳转
    if (type == recorder::INST_TYPE_B)
    {
        jump_pc = (ctx.inst & (1u << 31)) == 0;
    }

    return jump_pc;
}

// =============================================================================
// 算法表
// =============================================================================

const branch_predictor_t BRANCH_PREDICTORS[] = {
    {"static_not_taken", "静态不跳转", predict_static_not_taken},
    {"static_taken", "静态跳转", predict_static_taken},
    {"btfn", "BTFN", predict_btfn},
};

const int BRANCH_PREDICTOR_COUNT = sizeof(BRANCH_PREDICTORS) / sizeof(BRANCH_PREDICTORS[0]);

const branch_predictor_t* find_predictor(const char* name)
{
    for (int i = 0; i < BRANCH_PREDICTOR_COUNT; ++i)
    {
        if (strcmp(BRANCH_PREDICTORS[i].name, name) == 0)
            return &BRANCH_PREDICTORS[i];
    }
    return nullptr;
}
