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

using namespace std;

#define show_progress(POS, SIZE)                                                           \
    do                                                                                     \
    {                                                                                      \
        cout << ((POS) == 0 ? "\n" : "\r") << "解析文件进度: " << fixed << setprecision(2) \
             << (100.0 * (POS) / (SIZE)) << "% (" << (POS) << "/" << (SIZE) << ")";        \
        cout.flush();                                                                      \
    } while (0)

ICache *cache;

int parse_binary_file(std::string filepath)
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
    size_t pos = 0, last_idx = 0, show_mix_size = 1024 * 1024;

    show_progress(pos, size);

    try
    {
        while (pos <= (buffer.size() - 4))
        {
            if (pos - last_idx >= show_mix_size)
            {
                show_progress(pos, size);
                last_idx = pos;
            }
            uint32_t pc = *reinterpret_cast<uint32_t *>(&buffer[pos]);
            cache->find_data(pc);
            pos += 4;
        }
    }
    catch (const std::exception &e)
    {
        std::cerr << e.what() << '\n';
        return -1;
    }

    show_progress(pos, size);

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

    const struct option table[] = {
        {"help", no_argument, NULL, 'h'},
        {"time", required_argument, NULL, 't'},
        {"cache", required_argument, NULL, 'c'},
        {0, 0, NULL, 0},
    };
    int opt;
    uint32_t w = 1, n = 1, m = 2;
    while ((opt = getopt_long(argc, argv, "-ht:c:", table, NULL)) != -1)
    {
        switch (opt)
        {
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
    cache = new CacheFIFO(w, n, m);
    int ret = parse_binary_file(filepath);
    cache->show_stat();

    return ret;
}
