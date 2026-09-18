// 编译命令 g++ -std=c++17 -O3 <FILE>
// 优化EVENT_STRS和CODE_STRS的使用

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
const vector<string> CODE_STRS = {
    "LUI",    "AUIPC", "JAL",   "JALR",  "BEQ",    "BNE",    "BLT",    "BGE",   "BLTU",    "BGEU",
    "LB",     "LH",    "LW",    "LBU",   "LHU",    "SB",     "SH",     "SW",    "ADDI",    "SLTI",
    "SLTIU",  "XORI",  "ORI",   "ANDI",  "SLLI",   "SRLI",   "SRAI",   "ADD",   "SUB",     "SLL",
    "SLT",    "SLTU",  "XOR",   "SRL",   "SRA",    "OR",     "AND",    "FENCE", "FENCE_I", "ECALL",
    "EBREAK", "CSRRW", "CSRRS", "CSRRC", "CSRRWI", "CSRRSI", "CSRRCI", "MUL",   "MULH",    "MULHSU",
    "MULHU",  "DIV",   "DIVU",  "REM",   "REMU",   "MRET"};

struct Instruction
{
    uint8_t inst_code = 255;
    uint8_t mem_index;
    uint8_t icache_hit;
    uint8_t icache_miss;
    uint64_t start_tick;
    uint64_t end_tick;
    unordered_map<uint8_t, uint64_t> stages;
};

struct Stat
{
    unordered_map<uint8_t, int> inst_counts;
    unordered_map<uint8_t, uint64_t> inst_cycles_avg_total;
    unordered_map<uint8_t, uint64_t> inst_cycles_avg_count;
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
        if (inst.inst_code == 255)
            continue;

        stats.total_instructions++;
        stats.inst_counts[inst.inst_code]++;
        int cycles = inst.end_tick - inst.start_tick;
        stats.inst_cycles_avg_total[inst.inst_code] += cycles;
        stats.inst_cycles_avg_count[inst.inst_code] += 1;
        stats.total_cycles += cycles;

        const auto &s = inst.stages;
        for (uint8_t event_type = EVENT_IFU; event_type < EVENT_COUNT; ++event_type)
        {
            if (s.count(event_type))
            {
                stats.stage_delays_avg_total[event_type] += s.at(event_type);
                stats.stage_delays_avg_count[event_type] += 1;
            }
        }

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
    }

    instructions.clear();
}

/**
 * 16位硬件指令码映射为统计使用的紧凑索引(与CODE_STRS对应)
 * 低字节0x01-0x37对应LUI..REMU，0x41对应MRET，其余为无效
 */
static uint8_t to_code_index(uint16_t code)
{
    if (code == recorder::INST_INVALID_CODE) return 255;
    uint8_t low = code & 0xFF;
    if (low >= 0x01 && low <= 0x37) return low - 1;
    if (low == 0x41) return 55;
    return 255;
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

        // 无效记录（被flush的指令，各阶段数据不完整）不参与统计
        if (!item.valid) continue;

        Instruction inst;
        inst.inst_code  = to_code_index(item.inst_code);
        inst.mem_index  = item.storage_index;
        // 缓存状态：0无 1命中 2未命中；每条取指指令都有icache统计数据
        inst.icache_hit  = item.icache_stat == RC_BIN_CACHE_STAT_HIT ? 1 : 0;
        inst.icache_miss = item.icache_stat == RC_BIN_CACHE_STAT_MISS ? 1 : 0;
        // 指令周期为IF阶段结束到WB阶段结束，与原EVENT统计口径一致
        inst.start_tick = item.stage_ticks[recorder::STAGE_INDEX_IFU][1];
        uint64_t end_tick = inst.start_tick;
        for (int i = recorder::STAGE_INDEX_IDU; i < recorder::STAGE_COUNT; ++i)
        {
            end_tick += item.durations[i];
        }
        inst.end_tick  = end_tick;
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
    map<uint8_t, double> inst_avg_cycles, inst_percentage;
    for (const auto &p : stats.inst_counts)
    {
        uint8_t code = p.first;
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
        vector<uint8_t> sorted_codes;
        for (auto &[code, _] : stats.inst_counts) sorted_codes.push_back(code);
        sort(sorted_codes.begin(), sorted_codes.end(),
             [&](uint8_t a, uint8_t b)
             {
                 if (inst_avg_cycles[a] != inst_avg_cycles[b])
                     return inst_avg_cycles[a] > inst_avg_cycles[b];
                 if (stats.inst_counts[a] != stats.inst_counts[b])
                     return stats.inst_counts[a] > stats.inst_counts[b];
                 return a < b;
             });

        for (uint8_t code : sorted_codes)
        {
            string name =
                (code < CODE_STRS.size()) ? CODE_STRS[code] : "UNKNOWN_" + to_string(code);
            cout << "  " << setw(7) << name << ": " << fixed << setprecision(1)
                 << inst_avg_cycles[code] << " | " << stats.inst_counts[code] << " ("
                 << inst_percentage[code] << "%)\n";
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

    cout << "\n缓存统计:\n";
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

int main(int argc, char **argv)
{
    if (argc != 2)
    {
        cerr << "用法: " << argv[0] << " <日志文件>" << endl;
        return 1;
    }

    parse_binary_log(argv[1]);
    print_stats(argv[1]);
    return 0;
}
