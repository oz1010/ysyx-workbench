// 分支预测模拟器：输入npc perf monitor二进制记录文件，统计分支预测成功率与
// 无条件跳转(JAL/JALR)的记录预测准确率，并在参数化流水线模型(N级/W发射/第B级解析分支)
// 下估算预期周期数与IPC。
// 分支策略由函数接口实现(BranchPredictFn)。
//
// 编译参考: make -C tools/branchsim (依赖 $(NPC_HOME)/build/lib/librecorder.a)

#include <cstdio>
#include <cstdint>
#include <cmath>
#include <cstring>
#include <iostream>
#include <iomanip>
#include <string>
#include <map>
#include "recorder.h"
#include "inst_decode.h"
#include "predict.h"

using namespace std;

// =============================================================================
// 模拟器配置与统计
// =============================================================================

struct SimConfig
{
    int stages = 5;  // 流水线级数N
    int width = 1;   // 发射宽度W
    int bstage = 3;  // 分支结果所在阶段B(1..N)
};

struct SimStats
{
    uint64_t total_inst = 0;      // 总指令数(有效/退休指令)
    uint64_t branch_cnt = 0;      // 分支指令数(条件分支)
    uint64_t checked_cnt = 0;     // 有后继指令、可判定结果的分支数
    uint64_t taken_cnt = 0;       // 实际跳转数
    uint64_t pred_cnt = 0;        // 预测跳转数
    uint64_t correct_cnt = 0;     // 预测成功数
    uint64_t hw_checked_cnt = 0;  // 记录中有后继指令的分支数
    uint64_t hw_correct_cnt = 0;  // 记录dnpc与实际后继PC一致数
    uint64_t hw_jump_checked_cnt = 0;  // 记录中有后继指令、可判定记录预测的跳转数
    uint64_t hw_jump_correct_cnt = 0;  // 记录dnpc与实际后继PC一致的跳转数
    // 选定策略的分支类型 -> {总数, 预测正确数}
    std::map<std::string, std::pair<uint64_t, uint64_t>> branch_types;
    // 记录的分支类型 -> {总数, 预测正确数}
    std::map<std::string, std::pair<uint64_t, uint64_t>> hw_branch_types;
    // 记录的跳转类型(JAL/JALR) -> {总数, 预测正确数}
    std::map<std::string, std::pair<uint64_t, uint64_t>> hw_jump_types;
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

    // 待裁决分支：下一条有效指令PC用于确定实际目标；流末尾分支无后继，不参与准确率。
    bool has_pending = false;
    bool pending_is_jump = false;  // 待决项为无条件跳转(恒跳转，仅统计记录预测)
    branch_ctx_t pending{};

    recorder::rc_decode_item_t item;
    for (;;)
    {
        int ret = re.next(&item);
        if (ret == 0)
            break;
        if (ret < 0)
        {
            cerr << "\n解析错误: " << re.error() << endl;
            exit(1);
        }
        if (item.rec_type == RC_BIN_TYPE_REG)
            continue;  // 寄存器写记录不参与分析
        if (!item.valid)
            continue;  // 被flush的无效指令不属于退休路径

        // 先裁决上一条待决分支：本条有效指令即其后继。
        // 同时使用记录中的dnpc统计硬件实际预测是否正确。
        if (has_pending)
        {
            if (pending_is_jump)
            {
                // 无条件跳转必跳转，仅需对照记录dnpc与实际后继PC统计记录预测准确率
                const bool hw_correct = (pending.dnpc == item.pc);
                stats.hw_jump_checked_cnt++;
                stats.hw_jump_correct_cnt += hw_correct;
                stats.hw_jump_types[recorder::inst_code_name(pending.dec.inst_code)]
                    .second += hw_correct;
            }
            else
            {
                const bool taken = (item.pc != pending.pc + 4);
                const bool pred = predict(pending);
                stats.checked_cnt++;
                stats.taken_cnt += taken;
                stats.pred_cnt += pred;
                stats.correct_cnt += (pred == taken);
                stats.hw_checked_cnt++;
                stats.hw_correct_cnt += (pending.dnpc == item.pc);
                auto& type_stat =
                    stats.branch_types[recorder::inst_code_name(pending.dec.inst_code)];
                type_stat.second += (pred == taken);
                auto& hw_type_stat =
                    stats.hw_branch_types[recorder::inst_code_name(pending.dec.inst_code)];
                hw_type_stat.second += (pending.dnpc == item.pc);
            }
            has_pending = false;
        }

        stats.total_inst++;
        if (recorder::inst_is_branch(item.inst_code))
        {
            pending.seq = stats.total_inst - 1;
            pending.pc = item.pc;
            pending.dnpc = item.dnpc;
            pending.inst = item.inst;
            recorder::decode_inst(item.inst, &pending.dec);
            pending_is_jump = false;
            has_pending = true;
            stats.branch_cnt++;
            stats.branch_types[recorder::inst_code_name(item.inst_code)].first++;
            stats.hw_branch_types[recorder::inst_code_name(item.inst_code)].first++;
        }
        else if (recorder::inst_is_jump(item.inst_code))
        {
            // 无条件跳转同样挂起，待下一条有效指令到来后按记录dnpc判定记录预测
            pending.seq = stats.total_inst - 1;
            pending.pc = item.pc;
            pending.dnpc = item.dnpc;
            pending.inst = item.inst;
            recorder::decode_inst(item.inst, &pending.dec);
            pending_is_jump = true;
            has_pending = true;
            stats.hw_jump_types[recorder::inst_code_name(item.inst_code)].first++;
        }
    }
}

// =============================================================================
// 周期模型与报告
// =============================================================================

static void print_report(const char* filepath, const SimConfig& cfg, const SimStats& stats,
                         const branch_predictor_t* predictor)
{
    // 理想周期(无控制冒险): 发射周期 + 流水线填充(排空)
    const uint64_t issue_cycles = (stats.total_inst + cfg.width - 1) / cfg.width;
    const uint64_t ideal_cycles = issue_cycles + (cfg.stages - 1);

    // 误预测惩罚: 分支在第B级解析，解析前已进入流水线的错误路径指令需冲刷
    // 并重新取指，重取W*(B-1)条错误路径指令在宽度W下花费(B-1)拍
    const uint64_t mispredict_cnt = stats.checked_cnt - stats.correct_cnt;
    const int penalty = cfg.bstage - 1;
    const uint64_t branch_penalty = mispredict_cnt * penalty;
    const uint64_t cycles = ideal_cycles + branch_penalty;
    const double ipc = cycles ? static_cast<double>(stats.total_inst) / cycles : 0.0;

    cout << "\n================ 分支预测模拟报告 ================\n";
    cout << "  记录文件      : " << filepath << "\n";
    cout << "  流水配置      : N=" << cfg.stages << " 级, W=" << cfg.width << " 发射, 分支解析于第 "
         << cfg.bstage << " 级\n";
    cout << "  预测策略      : " << predictor->name << " (" << predictor->desc << ")\n";
    cout << "------------------------------------------------\n";
    cout << "  总指令数      : " << stats.total_inst << "\n";
    cout << "  分支指令数    : " << stats.branch_cnt << " (" << fixed << setprecision(2)
         << (stats.total_inst ? 100.0 * stats.branch_cnt / stats.total_inst : 0.0)
         << "%)\n";
    cout << "  分支预测      : "  << setprecision(2)
             << (stats.checked_cnt ? 100.0 * stats.correct_cnt / stats.checked_cnt : 0.0) << "% ("
             << stats.correct_cnt << "/" << stats.checked_cnt << ")";
    cout << " {";
    {
        bool first = true;
        for (const auto& [type, counts] : stats.branch_types)
        {
            cout << (first ? "" : ", ") << type << ": " << counts.second << "/" << counts.first;
            first = false;
        }
        cout << "}\n";
    }
    cout << "  分支记录预测  : "  << setprecision(2)
             << (stats.hw_checked_cnt ? 100.0 * stats.hw_correct_cnt / stats.hw_checked_cnt : 0.0)
             << "% (" << stats.hw_correct_cnt << "/" << stats.hw_checked_cnt << ")";
    cout << " {";
    {
        bool first = true;
        for (const auto& [type, counts] : stats.hw_branch_types)
        {
            cout << (first ? "" : ", ") << type << ": " << counts.second << "/" << counts.first;
            first = false;
        }
        cout << "}\n";
    }
    cout << "  跳转指令数    : " << stats.hw_jump_checked_cnt << " (" << fixed << setprecision(2)
         << (stats.total_inst ? 100.0 * stats.hw_jump_checked_cnt / stats.total_inst : 0.0)
         << "%)\n";
    cout << "  跳转记录预测  : "  << setprecision(2)
             << (stats.hw_jump_checked_cnt
                     ? 100.0 * stats.hw_jump_correct_cnt / stats.hw_jump_checked_cnt
                     : 0.0)
             << "% (" << stats.hw_jump_correct_cnt << "/" << stats.hw_jump_checked_cnt << ")";
    cout << " {";
    {
        bool first = true;
        for (const auto& [type, counts] : stats.hw_jump_types)
        {
            cout << (first ? "" : ", ") << type << ": " << counts.second << "/" << counts.first;
            first = false;
        }
        cout << "}\n";
    }
    cout << "------------------------------------------------\n";
    cout << "  预期周期数    : " << cycles << " = 理想 " << ideal_cycles << " + 分支惩罚 "
         << branch_penalty << " (误预测 " << mispredict_cnt << " × (B-1)=" << penalty << ")\n";
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
        int v = stoi(arg, &pos);
        if (arg[pos] != '\0')
            throw invalid_argument("trailing");
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
    SimConfig cfg;
    const char* filepath = nullptr;
    string predict_name = "static_not_taken";
    for (int i = 1; i < argc; ++i)
    {
        string arg = argv[i];
        auto next_val = [&]() -> const char*
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
