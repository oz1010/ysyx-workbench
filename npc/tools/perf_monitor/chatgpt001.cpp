// 编译命令 clang++ -std=c++17 -O3 chatgpt000.cpp
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

using namespace std;

const vector<string> EVENT_STRS = { "INVALID", "IFU", "IDU", "LSU", "EXU", "WBU" };
const vector<string> CODE_STRS = {
    "LUI", "AUIPC", "JAL", "JALR", "BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU",
    "LB", "LH", "LW", "LBU", "LHU", "SB", "SH", "SW", "ADDI", "SLTI",
    "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI", "SRAI", "ADD", "SUB", "SLL",
    "SLT", "SLTU", "XOR", "SRL", "SRA", "OR", "AND", "FENCE", "FENCE_I", "ECALL",
    "EBREAK", "CSRRW", "CSRRS", "CSRRC", "CSRRWI", "CSRRSI", "CSRRCI", "MUL", "MULH", "MULHSU",
    "MULHU", "DIV", "DIVU", "REM", "REMU", "MRET"
};

struct Instruction {
    uint8_t inst_code = 255;
    uint64_t start_tick;
    uint64_t end_tick;
    unordered_map<uint8_t, uint64_t> stages;
    bool has_exu = false;
    bool has_lsu = false;
};

struct Stat {
    unordered_map<uint8_t, int> inst_counts;
    unordered_map<uint8_t, vector<int>> inst_cycles;
    unordered_map<string, vector<int>> stage_delays;
    vector<int> lsu_avg_delays;
    unordered_map<string, int> exec_unit_usage = {{"EXU", 0}, {"LSU", 0}};
    int total_instructions = 0;
    int total_cycles = 0;
};

Stat stats;

void analyze_instructions(vector<Instruction> &instructions) {
    for (const auto &inst : instructions) {
        if (inst.inst_code == 255) continue;

        stats.total_instructions++;
        stats.inst_counts[inst.inst_code]++;
        int cycles = inst.end_tick - inst.start_tick;
        stats.inst_cycles[inst.inst_code].push_back(cycles);
        stats.total_cycles += cycles;

        if (inst.has_exu) stats.exec_unit_usage["EXU"]++;
        if (inst.has_lsu) {
            stats.exec_unit_usage["LSU"]++;
            if (inst.stages.count(2) && inst.stages.count(3)) // IDU -> LSU
                stats.lsu_avg_delays.push_back(inst.stages.at(3) - inst.stages.at(2));
        }

        const auto &s = inst.stages;
        if (s.count(1))
            stats.stage_delays["STR_IFU"].push_back(s.at(1) - inst.start_tick);
        if (s.count(1) && s.count(2))
            stats.stage_delays["IFU_IDU"].push_back(s.at(2) - s.at(1));
        if (s.count(2)) {
            if (s.count(4))
                stats.stage_delays["IDU_EXU"].push_back(s.at(4) - s.at(2));
            else if (s.count(3))
                stats.stage_delays["IDU_LSU"].push_back(s.at(3) - s.at(2));
        }
        if (s.count(4) && s.count(5))
            stats.stage_delays["EXU_WBU"].push_back(s.at(5) - s.at(4));
        if (s.count(3) && s.count(5))
            stats.stage_delays["LSU_WBU"].push_back(s.at(5) - s.at(3));
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
                uint8_t stage_type = buffer[i++];
                if (i + time_len > buffer.size()) throw runtime_error("缺少时间差值");
                uint64_t time_diff = 0;
                memcpy(&time_diff, &buffer[i], time_len);
                i += time_len;
                current_tick += time_diff;

                if (stage_type == 1) {
                    if (current_inst.inst_code != 255)
                        instructions.push_back(current_inst);
                    current_inst = {};
                    current_inst.start_tick = start_tick;
                    current_inst.end_tick = current_tick;
                    current_inst.stages[1] = current_tick;
                } else {
                    if (current_inst.inst_code != 255) {
                        if (stage_type == 4) {
                            if (current_inst.has_lsu)
                                throw runtime_error("指令同时包含EXU和LSU");
                            current_inst.has_exu = true;
                        } else if (stage_type == 3) {
                            if (current_inst.has_exu)
                                throw runtime_error("指令同时包含EXU和LSU");
                            current_inst.has_lsu = true;
                        }
                        current_inst.stages[stage_type] = current_tick;
                        current_inst.end_tick = current_tick;
                        start_tick = current_tick;
                    }
                }
            } else if (entry_type == 2) {
                if (i >= buffer.size()) throw runtime_error("缺少指令编码");
                uint8_t inst_code = buffer[i++];
                current_inst.inst_code = inst_code;
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
    if (current_inst.inst_code != 255)
        instructions.push_back(current_inst);
    analyze_instructions(instructions);
}

void print_stats(const char* filepath) {
    map<uint8_t, double> inst_avg_cycles, inst_percentage;
    for (const auto &p : stats.inst_counts) {
        uint8_t code = p.first;
        int count = p.second;
        double avg = 0.0;
        const auto &cycles = stats.inst_cycles[code];
        if (!cycles.empty())
            avg = accumulate(cycles.begin(), cycles.end(), 0.0) / cycles.size();
        inst_avg_cycles[code] = avg;
        inst_percentage[code] = (count * 100.0 / stats.total_instructions);
    }

    double lsu_avg = 0.0;
    if (!stats.lsu_avg_delays.empty())
        lsu_avg = accumulate(stats.lsu_avg_delays.begin(), stats.lsu_avg_delays.end(), 0.0) / stats.lsu_avg_delays.size();

    cout << "\n分析结果 (文件: " << filepath << ")\n";
    cout << "\n指令统计:\n";
    if (stats.inst_counts.empty()) {
        cout << "  无有效指令数据\n";
    } else {
        vector<uint8_t> sorted_codes;
        for (auto &[code, _] : stats.inst_counts)
            sorted_codes.push_back(code);
        sort(sorted_codes.begin(), sorted_codes.end(), [&](uint8_t a, uint8_t b) {
            if (inst_avg_cycles[a] != inst_avg_cycles[b])
                return inst_avg_cycles[a] > inst_avg_cycles[b];
            if (stats.inst_counts[a] != stats.inst_counts[b])
                return stats.inst_counts[a] > stats.inst_counts[b];
            return a < b;
        });

        for (uint8_t code : sorted_codes) {
            string name = (code < CODE_STRS.size()) ? CODE_STRS[code] : "UNKNOWN_" + to_string(code);
            cout << "  " << setw(7) << name << ": "
                 << fixed << setprecision(1) << inst_avg_cycles[code]
                 << " | " << stats.inst_counts[code]
                 << " (" << inst_percentage[code] << "%)\n";
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
