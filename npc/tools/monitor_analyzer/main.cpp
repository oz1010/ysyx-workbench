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
#include "perf_monitor.h"

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
const vector<string> MEM_STRS = {"sram", "mrom", "flash", "psram", "sdram"};

struct Instruction
{
    uint8_t inst_code = 255;
    uint8_t mem_index;
    uint8_t icache_hit;
    uint8_t icache_miss;
    uint64_t start_tick;
    uint64_t end_tick;
    unordered_map<uint8_t, uint64_t> stages;
    bool has_exu = false;
    bool has_lsu = false;
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

void parse_binary_log(const char *filepath)
{
    ifstream file(filepath, ios::binary | ios::ate);
    if (!file)
    {
        cerr << "无法打开文件: " << filepath << endl;
        exit(1);
    }

    streamsize size = file.tellg();
    file.seekg(0, ios::beg);
    vector<unsigned char> buffer(size);
    file.read(reinterpret_cast<char *>(buffer.data()), size);

    vector<Instruction> instructions;
    Instruction current_inst;
    uint64_t current_tick = 0, start_tick = 0;
    size_t pos = 0, last_idx = 0, show_mix_size = 1024 * 1024;

    show_progress(pos, size);

    try
    {
        while (pos < buffer.size())
        {
            if (pos - last_idx >= show_mix_size)
            {
                show_progress(pos, size);
                last_idx = pos;
                analyze_instructions(instructions);
            }

            unsigned char first_byte = buffer[pos++];
            int entry_type = first_byte & 0x3F;
            int time_len_shift = (first_byte >> 6) & 0x03;
            int time_len = 1 << time_len_shift;

            if (entry_type == PERF_MONITOR_TYPE_EVENT)
            {
                if (pos >= buffer.size())
                    throw runtime_error("缺少阶段类型");
                uint8_t event_type = buffer[pos++];
                if (pos + time_len > buffer.size())
                    throw runtime_error("缺少时间差值");
                uint64_t time_diff = 0;
                memcpy(&time_diff, &buffer[pos], time_len);
                pos += time_len;
                current_tick += time_diff;

                if (event_type == EVENT_IFU)
                {
                    if (current_inst.inst_code != 255)
                        instructions.push_back(current_inst);
                    current_inst = {};
                    current_inst.start_tick = start_tick;
                    current_inst.end_tick = current_tick;
                    current_inst.stages[event_type] = time_diff;
                }
                else
                {
                    if (event_type == EVENT_EXU)
                    {
                        if (current_inst.has_lsu)
                            throw runtime_error("指令同时包含EXU和LSU");
                        current_inst.has_exu = true;
                    }
                    else if (event_type == EVENT_LSU)
                    {
                        if (current_inst.has_exu)
                            throw runtime_error("指令同时包含EXU和LSU");
                        current_inst.has_lsu = true;
                    }
                    current_inst.stages[event_type] = time_diff;
                    current_inst.end_tick = current_tick;
                    start_tick = current_tick;
                }
            }
            else if (entry_type == PERF_MONITOR_TYPE_ICACHE)
            {
                if (pos >= buffer.size())
                    throw runtime_error("缺少icache数据");
                perf_monitor_icache_data_t data;
                data.raw_val = buffer[pos++];
                current_inst.mem_index = data.mem_index;
                current_inst.icache_hit = data.hit_count;
                current_inst.icache_miss = data.miss_count;
            }
            else if (entry_type == PERF_MONITOR_TYPE_CODE)
            {
                if (pos >= buffer.size())
                    throw runtime_error("缺少指令编码");
                uint8_t inst_code = buffer[pos++];
                current_inst.inst_code = inst_code;
            }
            else
            {
                throw runtime_error("未知条目类型: " + to_string(entry_type));
            }
        }
    }
    catch (const exception &e)
    {
        show_progress(pos, size);
        cerr << "\n解析错误位置 pos=" << pos << ": " << e.what() << endl;
        exit(1);
    }

    show_progress(pos, size);
    if (current_inst.inst_code != 255)
        instructions.push_back(current_inst);
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
            cout << setw(8) << MEM_STRS[mem_idx] << ": " << fixed << setprecision(1) << p * 100
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
