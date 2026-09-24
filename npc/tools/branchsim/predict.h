// 分支预测算法接口与算法表声明
#ifndef __PREDICT_H__
#define __PREDICT_H__

#include <cstdint>
#include "inst_decode.h"

/**
 * 分支预测上下文：当前分支指令及其解码值
 */
struct branch_ctx_t
{
    uint64_t             seq;   // 有效指令序号(退休序，从0开始)
    uint32_t             pc;    // 分支指令PC
    uint32_t             inst;  // 指令字
    recorder::inst_dec_t dec;   // 解码值(指令码+rd/rs1/rs2)，由recorder::decode_inst填充
};

/**
 * 分支预测函数接口：返回true预测跳转，false预测不跳转
 */
using BranchPredictFn = bool (*)(const branch_ctx_t& ctx);

/**
 * 分支预测算法表项：算法名称(命令行匹配) + 描述 + 处理函数
 */
struct branch_predictor_t
{
    const char*     name;  // 算法名称，命令行--predict参数匹配
    const char*     desc;  // 算法描述
    BranchPredictFn fn;    // 预测处理函数
};

// 分支预测算法表，定义于predict.cpp
extern const branch_predictor_t BRANCH_PREDICTORS[];
extern const int                BRANCH_PREDICTOR_COUNT;

/**
 * 按名称查找预测算法
 * @return 命中返回表项指针，未命中返回nullptr
 */
const branch_predictor_t* find_predictor(const char* name);

#endif
