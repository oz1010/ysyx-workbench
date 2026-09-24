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
static bool predict_static_is_taken(const branch_ctx_t&)
{
    return true;
}

// =============================================================================
// 算法表
// =============================================================================

const branch_predictor_t BRANCH_PREDICTORS[] = {
    {"static_not_taken", "静态不跳转", predict_static_not_taken},
    {"static_is_taken", "静态跳转", predict_static_is_taken},
};

const int BRANCH_PREDICTOR_COUNT =
    sizeof(BRANCH_PREDICTORS) / sizeof(BRANCH_PREDICTORS[0]);

const branch_predictor_t* find_predictor(const char* name)
{
    for (int i = 0; i < BRANCH_PREDICTOR_COUNT; ++i)
    {
        if (strcmp(BRANCH_PREDICTORS[i].name, name) == 0)
            return &BRANCH_PREDICTORS[i];
    }
    return nullptr;
}
