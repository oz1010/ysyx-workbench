// 分支预测模拟器：输入npc perf monitor二进制记录文件，统计分支预测成功率，
// 并在参数化流水线模型(N级/W发射/第B级解析分支)下估算预期周期数与IPC。
// 分支策略由函数接口实现(BranchPredictFn)，当前仅实现静态不跳转策略。
//
// 编译参考: make -C tools/branchsim (依赖 $(NPC_HOME)/build/lib/librecorder.a)

#include <cstdio>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <string>
#include "recorder.h"
#include "inst_decode.h"
#include "predict.h"

using namespace std;

// =============================================================================
// 模拟器配置与统计
// =============================================================================

struct SimConfig
{
    int stages  = 5;  // 流水线级数N
    int width   = 1;  // 发射宽度W
    int bstage  = 3;  // 分支结果所在阶段B(1..N)
};

struct SimStats
{
    uint64_t total_inst   = 0;  // 总指令数(有效/退休指令)
    uint64_t branch_cnt   = 0;  // 分支指令数(条件分支)
    uint64_t taken_cnt    = 0;  // 实际跳转数
    uint64_t pred_cnt     = 0;  // 预测跳转数
    uint64_t correct_cnt  = 0;  // 预测成功数
    uint64_t jump_cnt     = 0;  // 无条件跳转数(仅展示，不参与预测统计)
};

// =============================================================================
// 记录解析：流式读取指令记录，退休序(有效记录)即真实执行路径，
// 分支实际跳转与否由后继有效指令的PC是否连续判定(pc != 本分支pc+4即跳转)。
// =============================================================================

static void parse_and_simulate(const char* filepath, const SimConfig& cfg, SimStats& stats,
                               BranchPredictFn predict)
{
    recorder::Recorder re;
    if (re.init(filepath) != 0)
    {
        cerr << "初始化失败: " << re.error() << endl;
        exit(1);
    }
    cout << "镜像文件: " << re.desc().image_path << "\nELF文件:  " << re.elf_path() << endl;

    // 待裁决分支：记录序中一条分支指令之后紧跟的有效指令PC若不连续即为跳转；
    // 流末尾的待裁决分支无后继指令，按不跳转处理。
    bool          has_pending = false;
    branch_ctx_t  pending{};

    recorder::rc_decode_item_t item;
    for (;;)
    {
        int ret = re.next(&item);
        if (ret == 0) break;
        if (ret < 0)
        {
            cerr << "\n解析错误: " << re.error() << endl;
            exit(1);
        }
        if (item.rec_type == RC_BIN_TYPE_REG) continue;  // 寄存器写记录不参与分析
        if (!item.valid) continue;  // 被flush的无效指令不属于退休路径

        // 先裁决上一条待决分支：本条有效指令即其后继
        if (has_pending)
        {
            const bool taken = (item.pc != pending.pc + 4);
            const bool pred  = predict(pending);
            stats.taken_cnt += taken;
            stats.pred_cnt += pred;
            stats.correct_cnt += (pred == taken);
            has_pending = false;
        }

        stats.total_inst++;
        if (recorder::inst_is_branch(item.inst_code))
        {
            pending.seq  = stats.total_inst - 1;
            pending.pc   = item.pc;
            pending.inst = item.inst;
            recorder::decode_inst(item.inst, &pending.dec);
            has_pending  = true;
            stats.branch_cnt++;
        }
        else if (recorder::inst_is_jump(item.inst_code))
        {
            stats.jump_cnt++;
        }
    }
    if (has_pending)
    {
        // 流末尾分支：无后继指令，按不跳转裁决
        const bool pred = predict(pending);
        stats.pred_cnt += pred;
        stats.correct_cnt += (pred == false);
    }
}

// =============================================================================
// 周期模型与报告
// =============================================================================

static void print_report(const char* filepath, const SimConfig& cfg, const SimStats& stats,
                         const branch_predictor_t* predictor)
{
    // 理想周期(无控制冒险): 发射周期 + 流水线填充(排空)
    const uint64_t issue_cycles =
        (stats.total_inst + cfg.width - 1) / cfg.width;
    const uint64_t ideal_cycles = issue_cycles + (cfg.stages - 1);

    // 误预测惩罚: 分支在第B级解析，解析前已进入流水线的错误路径指令需冲刷
    // 并重新取指，重取W*(B-1)条错误路径指令在宽度W下花费(B-1)拍
    const uint64_t mispredict_cnt = stats.branch_cnt - stats.correct_cnt;
    const int      penalty        = cfg.bstage - 1;
    const uint64_t branch_penalty = mispredict_cnt * penalty;
    const uint64_t cycles         = ideal_cycles + branch_penalty;
    const double   ipc = cycles ? static_cast<double>(stats.total_inst) / cycles : 0.0;

    cout << "\n================ 分支预测模拟报告 ================\n";
    cout << "  记录文件      : " << filepath << "\n";
    cout << "  流水配置      : N=" << cfg.stages << " 级, W=" << cfg.width
         << " 发射, 分支解析于第 " << cfg.bstage << " 级\n";
    cout << "  预测策略      : " << predictor->name << " (" << predictor->desc << ")\n";
    cout << "------------------------------------------------\n";
    cout << "  总指令数      : " << stats.total_inst << "\n";
    cout << "  分支指令数    : " << stats.branch_cnt << " ("
         << fixed << setprecision(2)
         << (stats.total_inst ? 100.0 * stats.branch_cnt / stats.total_inst : 0.0)
         << "%), 其中跳转 " << stats.taken_cnt << " 条\n";
    cout << "  无条件跳转    : " << stats.jump_cnt << " 条 (不参与预测统计)\n";
    cout << "  分支预测成功率: " << setprecision(2)
         << (stats.branch_cnt ? 100.0 * stats.correct_cnt / stats.branch_cnt : 0.0)
         << "% (正确 " << stats.correct_cnt << " / 分支 " << stats.branch_cnt << ")\n";
    cout << "------------------------------------------------\n";
    cout << "  预期周期数    : " << cycles << " = 理想 " << ideal_cycles << " + 分支惩罚 "
         << branch_penalty << " (误预测 " << mispredict_cnt << " × (B-1)=" << penalty
         << ")\n";
    cout << "  IPC           : " << setprecision(3) << ipc << "\n";
    cout << "================================================\n";
}

// =============================================================================
// 命令行: branchsim <record.bin> [-N stages] [-W width] [-B stage]
//                  [--predict name]
// =============================================================================

static void print_usage(const char* argv0)
{
    cerr << "用法: " << argv0 << " <record.bin> [-N stages] [-W width] [-B stage]"
         << " [--predict name]\n"
         << "  -N/--stages        流水线级数N，默认5\n"
         << "  -W/--width         发射宽度W，默认1\n"
         << "  -B/--branch-stage  分支结果所在阶段B(1..N)，默认3\n"
         << "  --predict name     预测算法，默认static_not_taken，可选:\n";
    for (int i = 0; i < BRANCH_PREDICTOR_COUNT; ++i)
        cerr << "                       " << BRANCH_PREDICTORS[i].name << " ("
             << BRANCH_PREDICTORS[i].desc << ")\n";
}

static int parse_int_arg(const char* arg, const char* name)
{
    try
    {
        size_t pos = 0;
        int    v   = stoi(arg, &pos);
        if (arg[pos] != '\0') throw invalid_argument("trailing");
        return v;
    }
    catch (...)
    {
        cerr << name << " 参数无效: " << arg << endl;
        exit(1);
    }
}

int main(int argc, char** argv)
{
    SimConfig   cfg;
    const char* filepath = nullptr;
    string      predict_name = "static_not_taken";
    for (int i = 1; i < argc; ++i)
    {
        string arg = argv[i];
        auto   next_val = [&]() -> const char*
        {
            if (++i >= argc)
            {
                cerr << arg << " 缺少参数" << endl;
                exit(1);
            }
            return argv[i];
        };
        if (arg == "-N" || arg == "--stages")
            cfg.stages = parse_int_arg(next_val(), "-N");
        else if (arg == "-W" || arg == "--width")
            cfg.width = parse_int_arg(next_val(), "-W");
        else if (arg == "-B" || arg == "--branch-stage")
            cfg.bstage = parse_int_arg(next_val(), "-B");
        else if (arg.rfind("-N", 0) == 0 && arg.size() > 2)
            cfg.stages = parse_int_arg(arg.c_str() + 2, "-N");
        else if (arg.rfind("-W", 0) == 0 && arg.size() > 2)
            cfg.width = parse_int_arg(arg.c_str() + 2, "-W");
        else if (arg.rfind("-B", 0) == 0 && arg.size() > 2)
            cfg.bstage = parse_int_arg(arg.c_str() + 2, "-B");
        else if (arg == "--predict")
            predict_name = next_val();
        else if (arg.rfind("--predict=", 0) == 0)
            predict_name = arg.substr(10);
        else if (arg == "-h" || arg == "--help")
        {
            print_usage(argv[0]);
            return 0;
        }
        else if (arg[0] != '-' && filepath == nullptr)
            filepath = argv[i];
        else
        {
            cerr << "未知参数: " << arg << endl;
            print_usage(argv[0]);
            return 1;
        }
    }
    if (filepath == nullptr)
    {
        print_usage(argv[0]);
        return 1;
    }
    if (cfg.stages < 1 || cfg.width < 1 || cfg.bstage < 1 || cfg.bstage > cfg.stages)
    {
        cerr << "参数范围错误: 需满足 N>=1, W>=1, 1<=B<=N" << endl;
        return 1;
    }

    const branch_predictor_t* predictor = find_predictor(predict_name.c_str());
    if (predictor == nullptr)
    {
        cerr << "未知预测算法: " << predict_name << endl;
        print_usage(argv[0]);
        return 1;
    }

    SimStats stats;
    parse_and_simulate(filepath, cfg, stats, predictor->fn);
    print_report(filepath, cfg, stats, predictor);
    return 0;
}
