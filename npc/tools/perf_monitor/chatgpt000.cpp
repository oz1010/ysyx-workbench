// 编译命令 clang++ -std=c++17 -O3 chatgpt000.cpp
// 完全没有优化
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

using namespace std;

struct Instruction {
    string inst;
    uint64_t start_tick;
    uint64_t end_tick;
    unordered_map<string, uint64_t> stages;
    bool has_exu = false;
    bool has_lsu = false;
};

struct Stat {
    unordered_map<string, int> inst_counts;
    unordered_map<string, vector<int>> inst_cycles;
    unordered_map<string, vector<int>> stage_delays;
    vector<int> lsu_avg_delays;
    unordered_map<string, int> exec_unit_usage = {{"EXU", 0}, {"LSU", 0}};
    int total_instructions = 0;
    int total_cycles = 0;
};

Stat stats;
const vector<string> EVENT_STRS = { "INVALID", "IFU", "IDU", "LSU", "EXU", "WBU" };
const vector<string> CODE_STRS = {
    "LUI", "AUIPC", "JAL", "JALR", "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU",
    "LB", "LH", "LW", "LBU", "LHU", "SB", "SH", "SW", "ADDI", "SLTI",
    "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI", "SRAI", "ADD", "SUB", "SLL",
    "SLT", "SLTU", "XOR", "SRL", "SRA", "OR", "AND", "FENCE", "FENCE_I", "ECALL",
    "EBREAK", "CSRRW", "CSRRS", "CSRRC", "CSRRWI", "CSRRSI", "CSRRCI", "MUL", "MULH", "MULHSU",
    "MULHU", "DIV", "DIVU", "REM", "REMU", "MRET"
};

void analyze_instructions(vector<Instruction> &instructions) {
    for (const auto &inst : instructions) {
        if (inst.inst.empty()) continue;

        stats.total_instructions++;
        stats.inst_counts[inst.inst]++;
        int cycles = inst.end_tick - inst.start_tick;
        stats.inst_cycles[inst.inst].push_back(cycles);
        stats.total_cycles += cycles;

        if (inst.has_exu) stats.exec_unit_usage["EXU"]++;
        if (inst.has_lsu) {
            stats.exec_unit_usage["LSU"]++;
            if (inst.stages.count("IDU") && inst.stages.count("LSU")) {
                stats.lsu_avg_delays.push_back(inst.stages.at("LSU") - inst.stages.at("IDU"));
            }
        }

        const auto &s = inst.stages;
        if (s.count("IFU"))
            stats.stage_delays["STR_IFU"].push_back(s.at("IFU") - inst.start_tick);
        if (s.count("IFU") && s.count("IDU"))
            stats.stage_delays["IFU_IDU"].push_back(s.at("IDU") - s.at("IFU"));
        if (s.count("IDU")) {
            if (s.count("EXU"))
                stats.stage_delays["IDU_EXU"].push_back(s.at("EXU") - s.at("IDU"));
            else if (s.count("LSU"))
                stats.stage_delays["IDU_LSU"].push_back(s.at("LSU") - s.at("IDU"));
        }
        if (s.count("EXU") && s.count("WBU"))
            stats.stage_delays["EXU_WBU"].push_back(s.at("WBU") - s.at("EXU"));
        if (s.count("LSU") && s.count("WBU"))
            stats.stage_delays["LSU_WBU"].push_back(s.at("WBU") - s.at("LSU"));
    }

    instructions.clear();
}

void parse_binary_log(const char* filepath) {
    ifstream file(filepath, ios::binary | ios::ate);
    if (!file) {
        cerr << "无法打开文件: " << filepath << endl;
        exit(1);
    }

    streamsize size = file.tellg();
    file.seekg(0, ios::beg);
    vector<unsigned char> buffer(size);
    file.read(reinterpret_cast<char*>(buffer.data()), size);

    vector<Instruction> instructions;
    Instruction current_inst;
    uint64_t current_tick = 0, start_tick = 0;
    size_t i = 0, last_idx = 0, show_mix_size = 1024 * 1024;

    cout << "\n解析文件进度: 0.00% (0/" << size << ")";
    cout.flush();

    try {
        while (i < buffer.size()) {
            if (i - last_idx >= show_mix_size) {
                cout << "\r解析文件进度: " << fixed << setprecision(2)
                     << (100.0 * i / size) << "% (" << i << "/" << size << ")";
                cout.flush();
                last_idx = i;
                analyze_instructions(instructions);
            }

            unsigned char first_byte = buffer[i++];
            int entry_type = first_byte & 0x3F;
            int time_len_shift = (first_byte >> 6) & 0x03;
            int time_len = 1 << time_len_shift;

            if (entry_type == 1) {
                if (i >= buffer.size()) throw runtime_error("缺少阶段类型");
                int stage_type = buffer[i++];
                if (i + time_len > buffer.size()) throw runtime_error("缺少时间差值");
                uint64_t time_diff = 0;
                memcpy(&time_diff, &buffer[i], time_len);
                i += time_len;
                current_tick += time_diff;

                string stage_name = (stage_type >= 1 && stage_type < EVENT_STRS.size())
                                    ? EVENT_STRS[stage_type]
                                    : "UNKNOWN_" + to_string(stage_type);
                if (stage_name == "IFU") {
                    if (!current_inst.inst.empty())
                        instructions.push_back(current_inst);
                    current_inst = {};
                    current_inst.start_tick = start_tick;
                    current_inst.end_tick = current_tick;
                    current_inst.stages["IFU"] = current_tick;
                } else if (stage_name != "INVALID") {
                    if (!current_inst.inst.empty()) {
                        if (stage_name == "EXU") {
                            if (current_inst.has_lsu)
                                throw runtime_error("指令包含EXU和LSU");
                            current_inst.has_exu = true;
                        } else if (stage_name == "LSU") {
                            if (current_inst.has_exu)
                                throw runtime_error("指令包含EXU和LSU");
                            current_inst.has_lsu = true;
                        }
                        current_inst.stages[stage_name] = current_tick;
                        current_inst.end_tick = current_tick;
                        start_tick = current_tick;
                    }
                }
            } else if (entry_type == 2) {
                if (i >= buffer.size()) throw runtime_error("缺少指令编码");
                int inst_code = buffer[i++];
                if (inst_code >= 0 && inst_code < CODE_STRS.size())
                    current_inst.inst = CODE_STRS[inst_code];
                else
                    throw runtime_error("未知指令编码: " + to_string(inst_code));
            } else {
                throw runtime_error("未知条目类型: " + to_string(entry_type));
            }
        }
    } catch (const exception& e) {
        cout << "\r解析文件进度: " << fixed << setprecision(2)
             << (100.0 * i / size) << "% (" << i << "/" << size << ")";
        cerr << "\n解析错误位置 i=" << i << ": " << e.what() << endl;
        exit(1);
    }

    cout << "\r解析文件进度: 100.00% (" << size << "/" << size << ")\n";
    if (!current_inst.inst.empty())
        instructions.push_back(current_inst);
    analyze_instructions(instructions);
}

void print_stats(const char* filepath) {
    map<string, double> inst_avg_cycles, inst_percentage;
    for (const auto &p : stats.inst_counts) {
        const string &inst = p.first;
        int count = p.second;
        double avg = 0.0;
        const auto &cycles = stats.inst_cycles[inst];
        if (!cycles.empty())
            avg = accumulate(cycles.begin(), cycles.end(), 0.0) / cycles.size();
        inst_avg_cycles[inst] = avg;
        inst_percentage[inst] = (count * 100.0 / stats.total_instructions);
    }

    double lsu_avg = 0.0;
    if (!stats.lsu_avg_delays.empty())
        lsu_avg = accumulate(stats.lsu_avg_delays.begin(), stats.lsu_avg_delays.end(), 0.0) / stats.lsu_avg_delays.size();

    cout << "\n分析结果 (文件: " << filepath << ")\n";
    cout << "\n指令统计:\n";
    if (stats.inst_counts.empty()) {
        cout << "  无有效指令数据\n";
    } else {
        vector<string> sorted_insts;
        for (const auto &p : stats.inst_counts) sorted_insts.push_back(p.first);
        sort(sorted_insts.begin(), sorted_insts.end(), [&](const string &a, const string &b) {
            if (inst_avg_cycles[a] != inst_avg_cycles[b])
                return inst_avg_cycles[a] > inst_avg_cycles[b];
            if (stats.inst_counts[a] != stats.inst_counts[b])
                return stats.inst_counts[a] > stats.inst_counts[b];
            return a < b;
        });

        for (const auto &inst : sorted_insts) {
            cout << "  " << setw(7) << inst << ": "
                 << fixed << setprecision(1) << inst_avg_cycles[inst]
                 << " | " << stats.inst_counts[inst]
                 << " (" << fixed << setprecision(1) << inst_percentage[inst] << "%)\n";
        }
    }

    cout << "指令总周期：" << stats.total_cycles << endl;
    cout << "指令总数：" << stats.total_instructions << endl;
    cout << "IPC：" << fixed << setprecision(3)
         << (double)stats.total_instructions / max(1, stats.total_cycles) << endl;

    cout << "\n阶段延迟统计:\n";
    if (stats.stage_delays.empty()) {
        cout << "  无有效阶段延迟数据\n";
    } else {
        vector<pair<string, double>> delay_avg;
        for (const auto &p : stats.stage_delays) {
            const auto &d = p.second;
            double avg = !d.empty() ? accumulate(d.begin(), d.end(), 0.0) / d.size() : 0;
            delay_avg.emplace_back(p.first, avg);
        }
        sort(delay_avg.begin(), delay_avg.end(), [](auto &a, auto &b) {
            if (a.second != b.second)
                return a.second > b.second;
            return a.first < b.first;
        });
        for (const auto &[stage, avg] : delay_avg) {
            cout << "  " << setw(10) << stage << ": "
                 << fixed << setprecision(1) << avg
                 << " | " << stats.stage_delays[stage].size() << endl;
        }
    }
}

int main(int argc, char** argv) {
    if (argc != 2) {
        cerr << "用法: " << argv[0] << " <日志文件>" << endl;
        return 1;
    }

    parse_binary_log(argv[1]);
    print_stats(argv[1]);
    return 0;
}
