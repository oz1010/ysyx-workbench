// 编译命令 g++ -std=c++17 -O3 <FILE>
// 优化EVENT_STRS和CODE_STRS的使用

#include <cstdio>
#include <array>
#include <set>
#include <iostream>
#include <fstream>
#include <vector>
#include <unordered_map>
#include <map>
#include <string>
#include <cstring>
#include <cmath>
#include <algorithm>
#include <iomanip>
#include <numeric>
#include "recorder.h"
#include "inst_decode.h"

using namespace std;

#define show_progress(POS, SIZE)                                                           \
    do                                                                                     \
    {                                                                                      \
        cout << ((POS) == 0 ? "\n" : "\r") << "解析文件进度: " << fixed << setprecision(2) \
             << (100.0 * (POS) / (SIZE)) << "% (" << (POS) << "/" << (SIZE) << ")";        \
        cout.flush();                                                                      \
    } while (0)
enum
{
    EVENT_INVALID,
    EVENT_IFU,
    EVENT_IDU,
    EVENT_LSU,
    EVENT_EXU,
    EVENT_WBU,
    EVENT_COUNT
};
const vector<string> EVENT_STRS = {"INVALID", "IFU", "IDU", "LSU", "EXU", "WBU"};

struct Instruction
{
    uint16_t inst_code = recorder::INST_INVALID_CODE;  // 指令码，名称由recorder::inst_code_name查询
    uint8_t mem_index;
    uint8_t icache_hit;
    uint8_t icache_miss;
    bool valid;
    uint64_t start_tick;
    uint64_t end_tick;
    unordered_map<uint8_t, uint64_t> stages;
};

struct Stat
{
    unordered_map<uint16_t, int> inst_counts;
    unordered_map<uint16_t, uint64_t> inst_cycles_avg_total;
    unordered_map<uint16_t, uint64_t> inst_cycles_avg_count;
    unordered_map<uint8_t, uint64_t> stage_delays_avg_total;
    unordered_map<uint8_t, uint64_t> stage_delays_avg_count;
    unordered_map<uint8_t, uint64_t> mem_icache_hit;
    unordered_map<uint8_t, uint64_t> mem_icache_miss;
    unordered_map<uint8_t, uint64_t> mem_icache_hit_atime;
    unordered_map<uint8_t, uint64_t> mem_icache_miss_atime;
    uint64_t total_instructions = 0;
    uint64_t total_cycles = 0;
};

Stat stats;
vector<string> g_storages;  // 描述信息中的存储体名称列表，索引即Storage Index的指令存储索引

void analyze_instructions(vector<Instruction> &instructions)
{
    for (const auto &inst : instructions)
    {
        if (inst.inst_code == recorder::INST_INVALID_CODE)
            continue;

        const auto &s = inst.stages;

        // 缓存统计包含无效记录（被flush的指令）：其取指缓存访问真实发生，
        // 与硬件计数器统计口径一致
        if (inst.icache_hit > 0 || inst.icache_miss > 0)
        {
            uint8_t mem_index = inst.mem_index;
            stats.mem_icache_hit[mem_index] += inst.icache_hit;
            stats.mem_icache_miss[mem_index] += inst.icache_miss;
            if (inst.icache_miss > 0)
            {
                stats.mem_icache_miss_atime[mem_index] += s.at(EVENT_IFU);
            }
            else
            {
                stats.mem_icache_hit_atime[mem_index] += s.at(EVENT_IFU);
            }
        }

        // 无效记录（被flush的指令，各阶段数据不完整）不参与指令与阶段统计
        if (!inst.valid)
            continue;

        stats.total_instructions++;
        stats.inst_counts[inst.inst_code]++;
        int cycles = inst.end_tick - inst.start_tick;
        stats.inst_cycles_avg_total[inst.inst_code] += cycles;
        stats.inst_cycles_avg_count[inst.inst_code] += 1;
        // 指令总周期为最后一条指令完成时的tick值，即所有指令结束tick的最大值
        if (inst.end_tick > stats.total_cycles)
            stats.total_cycles = inst.end_tick;

        for (uint8_t event_type = EVENT_IFU; event_type < EVENT_COUNT; ++event_type)
        {
            if (s.count(event_type))
            {
                stats.stage_delays_avg_total[event_type] += s.at(event_type);
                stats.stage_delays_avg_count[event_type] += 1;
            }
        }
    }

    instructions.clear();
}

void parse_binary_log(const char *filepath)
{
    recorder::Recorder re;
    if (re.init(filepath) != 0)
    {
        cerr << "初始化失败: " << re.error() << endl;
        exit(1);
    }
    cout << "\n镜像文件: " << re.desc().image_path << "\nELF文件:  " << re.elf_path() << endl;
    g_storages = re.desc().storages;

    vector<Instruction> instructions;
    uint64_t last_idx = 0;
    const uint64_t show_mix_size = 1 << 20;

    show_progress(0, re.file_size());

    recorder::rc_decode_item_t item;
    for (;;)
    {
        int ret = re.next(&item);
        if (ret == 0) break;
        if (ret < 0)
        {
            show_progress(re.bytes_consumed(), re.file_size());
            cerr << "\n解析错误: " << re.error() << endl;
            exit(1);
        }

        // 寄存器写记录不参与指令统计
        if (item.rec_type == RC_BIN_TYPE_REG) continue;

        if (item.index - last_idx >= show_mix_size)
        {
            show_progress(re.bytes_consumed(), re.file_size());
            last_idx = item.index;
            analyze_instructions(instructions);
        }

        // 无效记录（被flush的指令，各阶段数据不完整）不参与指令与阶段统计，
        // 但其取指缓存访问真实发生，缓存统计仍纳入（见analyze_instructions）
        Instruction inst;
        inst.valid      = item.valid;
        inst.inst_code  = item.inst_code;
        inst.mem_index  = item.storage_index;
        // 缓存状态：0无 1命中 2未命中；每条取指指令都有icache统计数据
        inst.icache_hit  = item.icache_stat == RC_BIN_CACHE_STAT_HIT ? 1 : 0;
        inst.icache_miss = item.icache_stat == RC_BIN_CACHE_STAT_MISS ? 1 : 0;
        // 指令周期为IF阶段起始到WB阶段结束，即各阶段持续时间之和
        inst.start_tick = item.stage_ticks[recorder::STAGE_INDEX_IFU][0];
        inst.end_tick   = item.stage_ticks[recorder::STAGE_INDEX_WBU][1];
        inst.stages[EVENT_IFU] = item.durations[recorder::STAGE_INDEX_IFU];
        inst.stages[EVENT_IDU] = item.durations[recorder::STAGE_INDEX_IDU];
        inst.stages[EVENT_EXU] = item.durations[recorder::STAGE_INDEX_EXU];
        inst.stages[EVENT_LSU] = item.durations[recorder::STAGE_INDEX_LSU];
        inst.stages[EVENT_WBU] = item.durations[recorder::STAGE_INDEX_WBU];
        instructions.push_back(inst);
    }

    show_progress(re.file_size(), re.file_size());
    analyze_instructions(instructions);
}

void print_stats(const char *filepath)
{
    map<uint16_t, double> inst_avg_cycles, inst_percentage;
    for (const auto &p : stats.inst_counts)
    {
        uint16_t code = p.first;
        int count = p.second;
        inst_avg_cycles[code] =
            stats.inst_cycles_avg_total[code] * 1.0 / stats.inst_cycles_avg_count[code];
        inst_percentage[code] = (count * 100.0 / stats.total_instructions);
    }

    cout << "\n分析结果 (文件: " << filepath << ")\n";
    cout << "\n指令统计:\n";
    if (stats.inst_counts.empty())
    {
        cout << "  无有效指令数据\n";
    }
    else
    {
        vector<uint16_t> sorted_codes;
        for (auto &[code, _] : stats.inst_counts) sorted_codes.push_back(code);
        sort(sorted_codes.begin(), sorted_codes.end(),
             [&](uint16_t a, uint16_t b)
             {
                 if (inst_avg_cycles[a] != inst_avg_cycles[b])
                     return inst_avg_cycles[a] > inst_avg_cycles[b];
                 if (stats.inst_counts[a] != stats.inst_counts[b])
                     return stats.inst_counts[a] > stats.inst_counts[b];
                 return a < b;
             });

        for (uint16_t code : sorted_codes)
        {
            cout << "  " << setw(7) << recorder::inst_code_name(code) << ": " << fixed
                 << setprecision(1) << inst_avg_cycles[code] << " | " << stats.inst_counts[code]
                 << " (" << inst_percentage[code] << "%)\n";
        }
    }

    cout << "指令总周期：" << stats.total_cycles << endl;
    cout << "指令总数：" << stats.total_instructions << endl;
    cout << "IPC：" << fixed << setprecision(3)
         << (double)stats.total_instructions / max((uint64_t)1, stats.total_cycles) << endl;

    cout << "\n阶段延迟统计:\n";
    if (stats.stage_delays_avg_total.empty())
    {
        cout << "  无有效阶段延迟数据\n";
    }
    else
    {
        vector<pair<uint8_t, double>> delay_avg;
        for (const auto &p : stats.stage_delays_avg_total)
        {
            const auto &total = p.second;
            const auto &count = stats.stage_delays_avg_count[p.first];
            delay_avg.emplace_back(p.first, total * 1.0 / count);
        }
        sort(delay_avg.begin(), delay_avg.end(),
             [](auto &a, auto &b)
             {
                 // if (a.second != b.second)
                 //     return a.second > b.second;
                 return a.first < b.first;
             });
        for (const auto &[event_type, avg] : delay_avg)
        {
            cout << setw(5) << EVENT_STRS[event_type] << ": " << fixed << setprecision(1) << avg
                 << " | " << stats.stage_delays_avg_count[event_type] << endl;
        }
    }

    cout << "\n指令缓存统计:\n";
    if (stats.mem_icache_hit.empty())
    {
        cout << "  无有效的指令缓存数据\n";
    }
    else
    {
        uint64_t total_hit_count = 0;
        uint64_t total_miss_count = 0;
        for (const auto &[mem_idx, hit_count] : stats.mem_icache_hit)
        {
            const auto &miss_count = stats.mem_icache_miss[mem_idx];
            const auto &hit_atime = stats.mem_icache_hit_atime[mem_idx];
            const auto &miss_atime = stats.mem_icache_miss_atime[mem_idx];
            total_hit_count += hit_count;
            total_miss_count += miss_count;
            /* ref.
             * https://ysyx.oscc.cc/docs/2306/basic/1.9.html#%E7%BC%93%E5%AD%98%E7%9A%84%E4%BC%98%E5%8C%96
             */
            double access_time = hit_atime * 1.0 / hit_count;
            double miss_penalty = miss_atime * 1.0 / miss_count - access_time;
            double p = hit_count * 1.0 / (hit_count + miss_count);
            double amat = access_time + (1 - p) * miss_penalty;
            string name = (mem_idx < g_storages.size())
                              ? g_storages[mem_idx]
                              : "UNKNOWN_" + to_string(mem_idx);
            cout << setw(8) << name << ": " << fixed << setprecision(1) << p * 100
                 << "% (" << hit_count << " " << (hit_count + miss_count) << ")" << std::endl;
            cout << setw(8) << ""
                 << "  " << fixed << setprecision(1) << amat << " (" << access_time << " "
                 << miss_penalty << ")" << endl;
        }
        {
            double p = total_hit_count * 1.0 / (total_hit_count + total_miss_count);
            cout << "合计"
                 << ": " << fixed << setprecision(1) << p * 100 << "% (" << total_hit_count << " "
                 << (total_hit_count + total_miss_count) << ")" << std::endl;
        }
    }
}

// =============================================================================
// 流水线停顿点分析 (--type stall)：功能对齐 scripts/stall_analyze.py，
// 基于 include/recorder_types.h 定义的二进制记录格式，统计5级流水线各阶段
// 时延与占用、CPI/吞吐、IFU/ICache与LSU/DCache供给、RAW数据相关停顿、
// 分支/控制冲刷及流水线气泡，用于定位流水线性能瓶颈和分析停顿来源。
//
// 分析模型：单发射顺序5级流水线，各级同一条指令的占用窗口按程序序互不重叠
//   T(总周期) = Σ_k retire_gap[k]，retire_gap[k] = wb_end[k] - wb_end[k-1]
//   CPI = mean(if_dur) + mean(if_gap)
//   阻塞点定位 = 把 Σ(retire_gap-1) 按互斥特征优先级归因到具体机制，
//   并以"干净指令"的 g 均值作为结构基线（串行取指延迟），二者之差即净代价。
// =============================================================================
namespace stall
{

constexpr int    RAW_RELEASE_EXTRA = 2;  // risk_raw释放到WB后还需~2拍才真正放行ID
constexpr int    CACHE_NONE = 0, CACHE_HIT = 1, CACHE_MISS = 2;
constexpr size_t REPORT_W = 78;

// Σ(g-1) 互斥归因类别（赋值顺序即优先级：flush回填>flush触发>load未命中>乘除>RAW>其它）
enum
{
    ATTR_RAW,
    ATTR_REFILL,    // flush回填
    ATTR_TRIGGER,   // flush触发
    ATTR_LOAD_MISS, // load未命中
    ATTR_MDR,       // 乘除多周期
    ATTR_OTHER,
    ATTR_COUNT
};
static const char* ATTR_NAMES[ATTR_COUNT] = {"RAW",      "flush回填", "flush触发",
                                             "load未命中", "乘除多周期", "其它"};

struct Rec
{
    uint32_t pc    = 0;
    bool     valid = false;
    uint64_t if_b  = 0;
    uint32_t dur[STAGE_COUNT] = {};
    uint32_t icache_stat = CACHE_NONE;
    uint32_t dcache_stat = CACHE_NONE;
    uint32_t mem_index   = 0;
    recorder::inst_dec_t dec;  // 指令解码结果（指令码+rd/rs1/rs2），由recorder::decode_inst填充
};

static double percentile(std::vector<uint64_t> v, double q)
{
    if (v.empty()) return 0.0;
    std::sort(v.begin(), v.end());
    const double rank = q / 100.0 * (v.size() - 1);
    const size_t lo   = static_cast<size_t>(std::floor(rank));
    const size_t hi   = static_cast<size_t>(std::ceil(rank));
    return static_cast<double>(v[lo]) +
           (static_cast<double>(v[hi]) - v[lo]) * (rank - static_cast<double>(lo));
}

static double mean_of(const std::vector<uint64_t>& v)
{
    if (v.empty()) return 0.0;
    long double s = 0;
    for (uint64_t x : v) s += x;
    return static_cast<double>(s / v.size());
}

static std::string pct_str(long double x, long double total)
{
    char buf[32];
    snprintf(buf, sizeof(buf), "%6.2f%%", total > 0 ? static_cast<double>(100.0 * x / total) : 0.0);
    return buf;
}

static std::string f2(double x)
{
    char buf[32];
    snprintf(buf, sizeof(buf), "%.2f", x);
    return buf;
}

int analysis(const char* filepath)
{
    recorder::Recorder re;
    if (re.init(filepath) != 0)
    {
        cerr << "初始化失败: " << re.error() << endl;
        return 1;
    }
    g_storages = re.desc().storages;

    // ---- 流式解析全部指令记录 ----
    std::vector<Rec> recs;
    uint64_t         last_idx = 0;
    const uint64_t   show_mix_size = 1 << 20;
    show_progress(0, re.file_size());
    recorder::rc_decode_item_t item;
    for (;;)
    {
        int ret = re.next(&item);
        if (ret == 0) break;
        if (ret < 0)
        {
            show_progress(re.bytes_consumed(), re.file_size());
            cerr << "\n解析错误: " << re.error() << endl;
            return 1;
        }
        if (item.rec_type == RC_BIN_TYPE_REG) continue;  // 寄存器写记录不参与分析
        if (item.index - last_idx >= show_mix_size)
        {
            show_progress(re.bytes_consumed(), re.file_size());
            last_idx = item.index;
        }
        Rec r;
        r.pc          = item.pc;
        r.valid       = item.valid;
        r.if_b        = item.inst_begin;
        r.icache_stat = item.icache_stat;
        r.dcache_stat = item.dcache_stat;
        r.mem_index   = item.storage_index;
        for (int s = 0; s < STAGE_COUNT; ++s) r.dur[s] = item.durations[s];
        recorder::decode_inst(item.inst, &r.dec);
        recs.push_back(r);
    }
    show_progress(re.file_size(), re.file_size());
    cout << "\n";

    // ---- 有效指令（退休序）数组 ----
    std::vector<const Rec*> V;
    for (const auto& r : recs)
        if (r.valid) V.push_back(&r);
    const size_t N = V.size(), M = recs.size() - N;
    if (N == 0)
    {
        cout << "\n无有效指令记录\n";
        return 0;
    }

    std::vector<uint64_t> if_b(N), if_e(N), id_b(N), wb_b(N), wb_e(N);
    std::vector<std::array<uint32_t, STAGE_COUNT>> dur(N);
    std::vector<uint32_t> icache(N), dcache(N), memidx(N);
    uint64_t              T = 0;
    for (size_t i = 0; i < N; ++i)
    {
        const Rec* r = V[i];
        if_b[i] = r->if_b;
        for (int s = 0; s < STAGE_COUNT; ++s) dur[i][s] = r->dur[s];
        uint64_t t = if_b[i];
        if_e[i] = t += dur[i][STAGE_INDEX_IFU];
        id_b[i] = t;
        t += dur[i][STAGE_INDEX_IDU];
        t += dur[i][STAGE_INDEX_EXU];
        t += dur[i][STAGE_INDEX_LSU];
        wb_b[i] = t;
        wb_e[i] = t + dur[i][STAGE_INDEX_WBU];
        icache[i] = r->icache_stat;
        dcache[i] = r->dcache_stat;
        memidx[i] = r->mem_index;
        if (wb_e[i] > T) T = wb_e[i];
    }

    // ---- 退休间隙 g 与取指重启间隙 gap ----
    std::vector<int64_t> g(N, 0);
    for (size_t i = 1; i < N; ++i) g[i] = static_cast<int64_t>(wb_e[i]) - wb_e[i - 1];
    std::vector<int64_t> gap;  // gap[i] = if_b[i+1] - if_e[i]
    for (size_t i = 0; i + 1 < N; ++i)
        gap.push_back(static_cast<int64_t>(if_b[i + 1]) - if_e[i]);

    // ---- RAW 数据冒险：consumer进ID时最近写者尚未"释放"(wb_b + RAW_RELEASE_EXTRA) ----
    std::vector<bool>    dep(N, false);
    std::vector<int64_t> raw_stall(N, 0);
    {
        int last_writer[32] = {-1};
        for (size_t i = 0; i < N; ++i)
        {
            int64_t best = 0;
            for (uint8_t rr : {V[i]->dec.rs1, V[i]->dec.rs2})
            {
                int j = rr ? last_writer[rr] : -1;
                if (j >= 0)
                {
                    const int64_t rel = static_cast<int64_t>(wb_b[j]) + RAW_RELEASE_EXTRA;
                    if (rel > static_cast<int64_t>(id_b[i]))
                        best = std::max(best, rel - static_cast<int64_t>(id_b[i]));
                }
            }
            if (best > 0)
            {
                dep[i]       = true;
                raw_stall[i] = best;
            }
            if (V[i]->dec.rd) last_writer[V[i]->dec.rd] = static_cast<int>(i);
        }
    }

    // ---- flush 事件：记录序中连续无效记录为一组 ----
    std::vector<bool>    is_trigger(N, false), is_after_flush(N, false);
    std::map<std::string, int> trig_ops;
    std::vector<size_t>  flush_slots;
    int64_t              refill_bubbles = 0;
    {
        std::vector<size_t> valid_seq_of_rec(recs.size(), SIZE_MAX);
        size_t vv = 0;
        for (size_t k = 0; k < recs.size(); ++k)
            if (recs[k].valid) valid_seq_of_rec[k] = vv++;

        struct FlushEvt
        {
            size_t              trig_valid;  // 触发者valid序（无效事件为SIZE_MAX）
            std::vector<size_t> grp;         // 无效记录序号
        };
        std::vector<FlushEvt> events;
        std::vector<size_t>   cur;
        size_t                prev = SIZE_MAX;
        for (size_t k = 0; k < recs.size(); ++k)
        {
            if (recs[k].valid)
            {
                if (!cur.empty())
                {
                    events.push_back({prev, cur});
                    cur.clear();
                }
                prev = k;
            }
            else
            {
                if (prev != SIZE_MAX && recs[prev].valid)
                {
                    const size_t vs        = valid_seq_of_rec[prev];
                    is_trigger[vs]         = true;
                    trig_ops[recorder::inst_code_name(recs[prev].dec.inst_code)]++;
                }
                cur.push_back(k);
                prev = k;
            }
        }
        if (!cur.empty()) events.push_back({prev, cur});

        for (const auto& e : events)
        {
            flush_slots.push_back(e.grp.size());
            uint64_t g_end = 0;
            for (size_t ik : e.grp)
            {
                uint64_t t = recs[ik].if_b;
                for (int s = 0; s < STAGE_COUNT; ++s) t += recs[ik].dur[s];
                if (t > g_end) g_end = t;
            }
            size_t nxt = e.grp.back() + 1;
            while (nxt < recs.size())
            {
                if (recs[nxt].valid)
                {
                    is_after_flush[valid_seq_of_rec[nxt]] = true;
                    const int64_t d = static_cast<int64_t>(recs[nxt].if_b) - g_end;
                    if (d > 0) refill_bubbles += d;
                    break;
                }
                ++nxt;
            }
        }
    }
    const size_t flush_cnt = flush_slots.size();

    // ---- 周期占用深度直方图（差分数组对账=总周期） ----
    std::vector<uint64_t> depth_hist(6, 0);  // 多少拍流水线有k级在忙
    {
        std::vector<int32_t> diff(static_cast<size_t>(T) + 2, 0);
        auto add_window = [&](uint64_t b, uint64_t e)
        {
            diff[static_cast<size_t>(b)]++;
            diff[static_cast<size_t>(e)]--;
        };
        for (size_t i = 0; i < N; ++i)
        {
            uint64_t t = if_b[i];
            for (int s = 0; s < STAGE_COUNT; ++s)
            {
                const uint64_t e = t + dur[i][s];
                add_window(t, e);
                t = e;
            }
        }
        int32_t d = 0;
        for (uint64_t t = 0; t < T; ++t)
        {
            d += diff[static_cast<size_t>(t)];
            depth_hist[d <= 5 ? d : 5]++;
        }
    }
    long double inflight_acc = 0;
    for (size_t k = 0; k < 6; ++k)
        inflight_acc += static_cast<long double>(depth_hist[k]) * k;
    const double mean_inflight = static_cast<double>(inflight_acc / T);

    // ---- Σ(g-1) 互斥归因 ----
    std::vector<int> attr(N, ATTR_OTHER);
    for (size_t i = 0; i < N; ++i)
    {
        const bool load_miss =
            recorder::inst_is_load(V[i]->dec.inst_code) && dcache[i] == CACHE_MISS;
        if (dep[i] && !recorder::inst_is_mdr(V[i]->dec.inst_code) && !is_trigger[i] &&
            !is_after_flush[i] && !load_miss)
            attr[i] = ATTR_RAW;
        if (recorder::inst_is_mdr(V[i]->dec.inst_code)) attr[i] = ATTR_MDR;
        if (load_miss) attr[i] = ATTR_LOAD_MISS;
        if (is_trigger[i]) attr[i] = ATTR_TRIGGER;
        if (is_after_flush[i]) attr[i] = ATTR_REFILL;
    }
    int64_t              total_bub = 0;
    double               g_base    = 0;
    size_t               base_cnt  = 0;
    std::vector<int64_t> attr_cnt(ATTR_COUNT, 0), attr_bub(ATTR_COUNT, 0);
    std::vector<long double> attr_gsum(ATTR_COUNT, 0);
    for (size_t i = 0; i < N; ++i)
    {
        const int64_t bub = std::max<int64_t>(g[i] - 1, 0);
        attr_cnt[attr[i]]++;
        attr_bub[attr[i]] += bub;
        attr_gsum[attr[i]] += g[i];
        total_bub += bub;
        if (attr[i] == ATTR_OTHER)
        {
            g_base += static_cast<double>(g[i]);
            base_cnt++;
        }
    }
    g_base = base_cnt ? g_base / base_cnt : 0.0;

    // ---- 依赖距离与生产者类型（RAW明细） ----
    std::map<int, int>         dep_dist;
    std::map<std::string, int> prod_type;
    {
        int last_writer[32] = {-1};
        for (size_t i = 0; i < N; ++i)
        {
            int pj = -1;
            for (uint8_t rr : {V[i]->dec.rs1, V[i]->dec.rs2})
            {
                int j = rr ? last_writer[rr] : -1;
                if (j >= 0 && static_cast<int64_t>(wb_b[j]) + RAW_RELEASE_EXTRA >
                                   static_cast<int64_t>(id_b[i]))
                    pj = (pj < 0) ? j : std::min(pj, j);
            }
            if (pj >= 0)
            {
                dep_dist[static_cast<int>(i) - pj]++;
                prod_type[recorder::inst_code_name(V[pj]->dec.inst_code)]++;
            }
            if (V[i]->dec.rd) last_writer[V[i]->dec.rd] = static_cast<int>(i);
        }
    }

    // ================= 报告 =================
    const auto& desc = re.desc();
    auto        hline = [&]()
    { cout << std::string(REPORT_W, '=') << "\n"; };

    hline();
    cout << "一、总体\n";
    hline();
    const size_t dep_cnt = std::count(dep.begin(), dep.end(), true);
    cout << "  有效指令        : " << N << "\n";
    cout << "  被flush指令     : " << M << "\n";
    cout << "  总周期          : " << T << "  (记录头 max_tick=" << desc.max_tick << ")\n";
    cout << fixed << setprecision(3);
    cout << "  IPC             : " << static_cast<double>(N) / T << "    CPI = "
         << static_cast<double>(T) / N << "\n";
    cout << "  非退休周期(T-N) : " << (T - N) << "  (" << pct_str(T - N, T) << ")\n";

    cout << "\n";
    hline();
    cout << "二、周期占用深度（多少拍流水线是空的；对账=总周期）\n";
    hline();
    for (size_t k = 0; k < 6; ++k)
    {
        const uint64_t c   = depth_hist[k];
        const size_t   bar = static_cast<size_t>(50.0 * c / T);
        cout << "  " << k << " 级忙 : " << setw(9) << c << " (" << pct_str(c, T)
             << ") " << std::string(bar, '#') << "\n";
    }
    cout << "  平均在飞指令数 = " << fixed << setprecision(2) << mean_inflight << " / 5\n";

    cout << "\n";
    hline();
    cout << "三、每指令时延预算（5 级时长之和 = 单指令端到端延迟）\n";
    hline();
    static const char* STAGE_NAMES[STAGE_COUNT] = {"IFU", "IDU", "EXU", "LSU", "WBU"};
    uint64_t           sum_dur_total            = 0;
    cout << "  " << left << setw(6) << "阶段" << right << setw(8) << "均值" << setw(6)
         << "p50" << setw(8) << "p90" << setw(8) << "max" << setw(12) << "Σ时长"
         << setw(10) << "占总周期" << "\n";
    for (int s = 0; s < STAGE_COUNT; ++s)
    {
        std::vector<uint64_t> dd;
        uint64_t              sum = 0, mx = 0;
        for (size_t i = 0; i < N; ++i)
        {
            dd.push_back(dur[i][s]);
            sum += dur[i][s];
            if (dur[i][s] > mx) mx = dur[i][s];
        }
        sum_dur_total += sum;
        cout << "  " << left << setw(6) << STAGE_NAMES[s] << right << fixed
             << setprecision(2) << setw(8) << mean_of(dd) << setprecision(0)
             << setw(6) << percentile(dd, 50) << setw(8) << percentile(dd, 90)
             << setw(8) << mx << setw(12) << sum << pct_str(sum, T) << "\n";
    }
    const double mean_total_dur = static_cast<double>(sum_dur_total) / N;
    cout << "  合计  " << fixed << setprecision(2) << mean_total_dur
         << " 拍/指令 (退休间隔只有 " << static_cast<double>(T) / N
         << "，重叠因子 " << mean_total_dur / (static_cast<double>(T) / N) << "/5)\n";

    cout << "\n";
    hline();
    cout << "四、CPI 分解：CPI = 取指时长 + 取指重启间隙（恒等式）\n";
    hline();
    std::vector<uint64_t> if_durs, if_hit, if_miss;
    for (size_t i = 0; i < N; ++i)
    {
        if_durs.push_back(dur[i][STAGE_INDEX_IFU]);
        if (icache[i] == CACHE_HIT) if_hit.push_back(dur[i][STAGE_INDEX_IFU]);
        if (icache[i] == CACHE_MISS) if_miss.push_back(dur[i][STAGE_INDEX_IFU]);
    }
    std::vector<int64_t> normal_gap, flush_gap;
    for (size_t i = 0; i < gap.size(); ++i)
        (is_after_flush[i + 1] ? flush_gap : normal_gap).push_back(gap[i]);
    const int64_t gap_sum = std::accumulate(gap.begin(), gap.end(), int64_t(0));
    const int64_t flush_gap_sum =
        std::accumulate(flush_gap.begin(), flush_gap.end(), int64_t(0));
    const double gap_mean = gap.empty() ? 0.0 : static_cast<double>(gap_sum) / gap.size();
    cout << fixed << setprecision(3);
    cout << "  取指时长项 mean(if_dur) = " << mean_of(if_durs) << " 拍\n";
    cout << "    - 命中 " << if_hit.size() << " 次, 均值 " << setprecision(2)
         << mean_of(if_hit) << " 拍 (p50 " << setprecision(0)
         << percentile(if_hit, 50) << setprecision(2) << ")\n";
    cout << "    - 未命中 " << if_miss.size() << " 次, 均值 " << mean_of(if_miss)
         << " 拍\n";
    cout << setprecision(3);
    cout << "  取指重启间隙 mean(gap) = " << gap_mean << " 拍\n";
    cout << "    - 正常重启 (非flush后): " << normal_gap.size() << " 次, 均值 "
         << setprecision(2)
         << (normal_gap.empty() ? 0.0
                                : static_cast<double>(std::accumulate(normal_gap.begin(), normal_gap.end(), int64_t(0))) /
                                      normal_gap.size())
         << " 拍\n";
    cout << "    - flush 回填气泡     : " << flush_gap.size() << " 次, 均值 "
         << (flush_gap.empty() ? 0.0
                               : static_cast<double>(flush_gap_sum) / flush_gap.size())
         << " 拍, 合计 " << flush_gap_sum << "\n";
    cout << "    => flush 回填占取指间隙项的 " << pct_str(flush_gap_sum, gap_sum) << "\n";
    cout << setprecision(3);
    cout << "  CPI = " << mean_of(if_durs) << " + " << gap_mean << " = "
         << mean_of(if_durs) + gap_mean << "\n";

    cout << "\n";
    hline();
    cout << "五、Σ(g-1) 互斥归因（g=退休间隙；优先级: "
            "flush回填>flush触发>load未命中>乘除>RAW>其它）\n";
    hline();
    const int print_order[ATTR_COUNT] = {ATTR_RAW,      ATTR_REFILL, ATTR_TRIGGER,
                                         ATTR_LOAD_MISS, ATTR_MDR,    ATTR_OTHER};
    cout << "  " << left << setw(12) << "归因" << right << setw(9) << "指令数"
         << setw(11) << "Σ(g-1)" << setw(8) << "占比" << setw(8) << "g均值"
         << setw(8) << "vs基线" << "\n";
    for (int a : print_order)
    {
        const double gm =
            attr_cnt[a] ? static_cast<double>(attr_gsum[a]) / attr_cnt[a] : 0.0;
        cout << "  " << left << setw(12) << ATTR_NAMES[a] << right << setw(9)
             << attr_cnt[a] << setw(11) << attr_bub[a] << pct_str(attr_bub[a], total_bub)
             << setw(8) << fixed << setprecision(2) << gm << setw(8) << showpos
             << gm - g_base << noshowpos << "\n";
    }
    cout << "  " << left << setw(12) << "合计" << right << setw(9) << N << setw(11)
         << total_bub << pct_str(total_bub, T) << "   (基线 g0=" << fixed
         << setprecision(2) << g_base << ")\n";
    cout << "  注: 基线 g0≈" << g_base
         << " = 串行取指~3拍 + 重启间隙1拍，即结构地板；\n";
    cout << "      消除全部冒险后 IPC 上限 ≈ 1/" << g_base << " = "
         << (g_base > 0 ? 1.0 / g_base : 0.0) << "（不改取指微架构）\n";

    cout << "\n";
    hline();
    cout << "六、取指供给明细（指令供给能力）\n";
    hline();
    if (!g_storages.empty())
    {
        cout << "  按存储体 (icache):\n";
        std::set<uint32_t> idx_set(memidx.begin(), memidx.end());
        for (uint32_t mi : idx_set)
        {
            std::vector<uint64_t> h_dur, m_dur;
            for (size_t i = 0; i < N; ++i)
                if (memidx[i] == mi)
                {
                    if (icache[i] == CACHE_HIT) h_dur.push_back(dur[i][STAGE_INDEX_IFU]);
                    if (icache[i] == CACHE_MISS) m_dur.push_back(dur[i][STAGE_INDEX_IFU]);
                }
            const std::string name = mi < g_storages.size() ? g_storages[mi]
                                                            : "idx" + std::to_string(mi);
            cout << "    " << left << setw(10) << name << right << "命中" << h_dur.size()
                 << "/" << f2(mean_of(h_dur)) << "拍  miss" << m_dur.size() << "/"
                 << f2(mean_of(m_dur)) << "拍\n";
        }
    }
    {
        int64_t backpressure = 0;
        for (size_t i = 0; i < N; ++i)
            backpressure += std::max<int64_t>(
                static_cast<int64_t>(dur[i][STAGE_INDEX_IFU]) - 3, 0);
        cout << "  取指窗口吸收的下游背压(IF时长-命中基线3拍)合计 " << backpressure
             << " 拍\n";
    }

    cout << "\n";
    hline();
    cout << "七、数据供给明细（load/store）\n";
    hline();
    std::vector<uint64_t> load_ls, store_ls, load_hit_ls, load_miss_ls;
    size_t                load_cnt = 0, store_cnt = 0;
    for (size_t i = 0; i < N; ++i)
    {
        if (recorder::inst_is_load(V[i]->dec.inst_code))
        {
            load_cnt++;
            load_ls.push_back(dur[i][STAGE_INDEX_LSU]);
            if (dcache[i] == CACHE_HIT) load_hit_ls.push_back(dur[i][STAGE_INDEX_LSU]);
            if (dcache[i] == CACHE_MISS) load_miss_ls.push_back(dur[i][STAGE_INDEX_LSU]);
        }
        else if (recorder::inst_is_store(V[i]->dec.inst_code))
        {
            store_cnt++;
            store_ls.push_back(dur[i][STAGE_INDEX_LSU]);
        }
    }
    cout << fixed << setprecision(2);
    cout << "  load  " << setw(7) << load_cnt << " 条: LSU均值 " << mean_of(load_ls)
         << " 拍 (命中 " << mean_of(load_hit_ls) << " / 未命中 " << mean_of(load_miss_ls)
         << ")\n";
    cout << "  store " << setw(7) << store_cnt << " 条: LSU均值 " << mean_of(store_ls)
         << " 拍\n";
    cout << "  dcache miss " << load_miss_ls.size() << " 次 × 均值 "
         << mean_of(load_miss_ls) << " 拍\n";

    cout << "\n";
    hline();
    cout << "八、RAW 数据冒险明细（无旁路，等生产者进 WB）\n";
    hline();
    const int64_t raw_stall_sum =
        std::accumulate(raw_stall.begin(), raw_stall.end(), int64_t(0));
    cout << "  RAW 停顿指令 " << dep_cnt << " 条 (" << pct_str(dep_cnt, N)
         << " 的指令), 停顿合计 " << raw_stall_sum << " 拍, 均值 "
         << (dep_cnt ? static_cast<double>(raw_stall_sum) / dep_cnt : 0.0)
         << " 拍/条\n";
    cout << "  依赖距离分布: {";
    {
        bool first = true;
        int  shown = 0;
        for (const auto& [d, c] : dep_dist)
        {
            if (shown++ >= 6) break;
            cout << (first ? "" : ", ") << d << ": " << c;
            first = false;
        }
        cout << "}\n";
    }
    cout << "  生产者类型  : {";
    {
        bool first = true;
        for (const auto& [t, c] : prod_type)
        {
            cout << (first ? "" : ", ") << t << ": " << c;
            first = false;
        }
        cout << "}\n";
    }

    cout << "\n";
    hline();
    cout << "九、控制冒险明细（flush / 静态预测恒不跳）\n";
    hline();
    std::map<size_t, int> slot_dist;
    for (size_t s : flush_slots) slot_dist[s]++;
    cout << "  flush 事件   : " << flush_cnt << " 次\n";
    cout << "  触发类型     : {";
    {
        bool first = true;
        for (const auto& [t, c] : trig_ops)
        {
            cout << (first ? "" : ", ") << t << ": " << c;
            first = false;
        }
        cout << "}\n";
    }
    const double mean_slots =
        flush_slots.empty()
            ? 0.0
            : static_cast<double>(std::accumulate(flush_slots.begin(), flush_slots.end(),
                                                   size_t(0))) /
                  flush_slots.size();
    cout << fixed << setprecision(2);
    cout << "  浪费槽位     : 平均 " << mean_slots << " 条/次, 分布 {";
    {
        bool first = true;
        for (const auto& [s, c] : slot_dist)
        {
            cout << (first ? "" : ", ") << s << ": " << c;
            first = false;
        }
        cout << "}\n";
    }
    cout << "  回填气泡合计 : " << refill_bubbles << " 拍 (" << pct_str(refill_bubbles, T)
         << ")\n";
    cout << "  被flush指令  : " << M << " 条\n";
    return 0;
}

}  // namespace stall

int main(int argc, char** argv)
{
    std::string type;
    const char* filepath = nullptr;
    for (int i = 1; i < argc; ++i)
    {
        std::string arg = argv[i];
        if (arg == "--type")
        {
            if (++i >= argc)
            {
                cerr << "--type 缺少参数 (default|stall)" << endl;
                return 1;
            }
            type = argv[i];
        }
        else if (arg.rfind("--type=", 0) == 0)
        {
            type = arg.substr(7);
        }
        else if (arg == "-h" || arg == "--help")
        {
            cerr << "用法: " << argv[0] << " <日志文件> [--type default|stall]\n"
                 << "  --type default  指令/阶段延迟/缓存统计 (默认)\n"
                 << "  --type stall    流水线停顿点分析 (对齐 scripts/stall_analyze.py)\n";
            return 0;
        }
        else if (filepath == nullptr)
        {
            filepath = argv[i];
        }
        else
        {
            cerr << "未知参数: " << arg << endl;
            return 1;
        }
    }
    if (filepath == nullptr)
    {
        cerr << "用法: " << argv[0] << " <日志文件> [--type default|stall]" << endl;
        return 1;
    }

    if (type == "stall") return stall::analysis(filepath);
    if (!type.empty() && type != "default")
    {
        cerr << "未知分析类型: " << type << " (可选 default|stall)" << endl;
        return 1;
    }

    parse_binary_log(filepath);
    print_stats(filepath);
    return 0;
}
