#include <cstdint>
#include <cstdlib>
#include <string>
#include <fstream>
#include <iostream>
#include <vector>
#include <unordered_map>
#include <iomanip>
#include <tuple>
#include <optional>
#include <unistd.h>
#include <getopt.h>
#include "cache.h"
#include "util.h"
#include "recorder.h"

using namespace std;

#define show_progress(POS, SIZE)                                                           \
    do                                                                                     \
    {                                                                                      \
        cout << ((POS) == 0 ? "\n" : "\r") << "解析文件进度: " << fixed << setprecision(2) \
             << (100.0 * (POS) / (SIZE)) << "% (" << (POS) << "/" << (SIZE) << ")";        \
        cout.flush();                                                                      \
    } while (0)

ICache *cache;

/**
 * 使用librecorder流式解析record二进制文件（格式见include/recorder_types.h），
 * 对每条指令记录的PC进行一次取指访问的cache命中仿真；
 * 被flush的无效指令同样经过IF阶段取指，因此无需判断指令是否完成
 */
int parse_binary_file(std::string filepath)
{
    recorder::Recorder rec;
    if (rec.init(filepath) != 0)
    {
        cerr << "解析文件失败: " << rec.error() << endl;
        return -1;
    }

    const uint64_t size        = rec.file_size();
    const size_t   show_mix_size = 1024 * 1024;
    uint64_t       last_idx    = 0;

    show_progress(0, size);

    rc_decode_item_t item;
    while (true)
    {
        int ret = rec.next(&item);
        if (ret == 0) break;  // 全部解析完毕
        if (ret < 0)
        {
            cerr << "解析记录失败: " << rec.error() << endl;
            return -1;
        }

        uint64_t pos = rec.bytes_consumed();
        if (pos - last_idx >= show_mix_size)
        {
            show_progress(pos, size);
            last_idx = pos;
        }

        if (item.rec_type == RC_BIN_TYPE_INST)
        {
            cache->find_data(item.pc);
        }
    }

    show_progress(size, size);

    return 0;
}

std::optional<std::tuple<uint32_t, uint32_t, uint32_t>> parse_cache_parameter(std::string str)
{
    auto tokens = split(str, ',');
    uint32_t n = 0, m = 0, w = 0;
    switch (tokens.size())
    {
        case 3:
            m = std::stoul(tokens[2]);
        case 2:
            n = std::stoul(tokens[1]);
        case 1:
            w = std::stoul(tokens[0]);
            break;
        default:
            return {};
    }
    return std::tuple(w, n, m);
}

std::optional<std::tuple<std::string, double, double>> parse_mem_parameter(std::string str)
{
    auto tokens = split(str, ',');
    if (tokens.size() == 3)
    {
        auto name = tokens[0];
        auto access_time = std::stod(tokens[1]);
        auto miss_penalty = std::stod(tokens[2]);
        return std::tuple(name, access_time, miss_penalty);
    }

    return {};
}

int main(int argc, char *argv[])
{
    std::string pro_name = argv[0];
    std::string filepath = "";
    cache_cfg_t cfg;

    const struct option table[] = {
        {"help", no_argument, NULL, 'h'},
        {"silence", no_argument, NULL, 's'},
        {"time", required_argument, NULL, 't'},
        {"cache", required_argument, NULL, 'c'},
        {0, 0, NULL, 0},
    };
    int opt;
    uint32_t w = 1, n = 1, m = 2;
    while ((opt = getopt_long(argc, argv, "-hst:c:", table, NULL)) != -1)
    {
        switch (opt)
        {
            case 's':
            {
                cfg.silence = true;
                break;
            }
            case 'c':
            {
                auto ret = parse_cache_parameter(optarg);
                if (ret)
                    std::tie(w, n, m) = *ret;
                break;
            }

            case 't':
            {
                auto ret = parse_mem_parameter(optarg);
                if (ret)
                {
                    auto [name, access_time, miss_penalty] = *ret;
                    set_mem_time(name, access_time, miss_penalty);
                }
                break;
            }

            case 1:
                filepath = optarg;
                break;

            default:
                cerr << "用法: " << pro_name << " [OPTION...] <日志文件>" << endl;
                exit(0);
        }
    }

    // cout << "Read file " << filepath << endl;
    cache = new CacheFIFO(w, n, m, cfg);
    int ret = 0;
    if (filepath.empty())
    {
        std::vector<uint32_t> pcs = {
            0x80001234,
            0x80001238,
            0x8000123c,
            0x80001238,
            0x80001234,
        };
        for (auto &pc : pcs)
        {
            cache->find_data(pc);
        }
    }
    else
    {
        ret = parse_binary_file(filepath);
    }
    cache->show_stat();

    return ret;
}
