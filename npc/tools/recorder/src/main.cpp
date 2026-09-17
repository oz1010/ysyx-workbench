// recorder可执行文件：将二进制record文件解析为文本
// 用法: recorder <path_to_bin> [-o path_to_text] [--offset ps_num]

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <ostream>
#include <string>

#include "inst_decode.h"
#include "recorder.h"

namespace
{

constexpr const char* STAGE_NAMES[recorder::STAGE_COUNT] = {"IF", "ID", "EX", "LS", "WB"};

struct options_t
{
    std::string bin_path;
    std::string out_path;
    bool        has_offset = false;
    uint64_t    ps_num     = 0;
};

void usage(const char* prog)
{
    std::fprintf(stderr,
                 "用法: %s <path_to_bin> [-o path_to_text] [--offset ps_num]\n"
                 "  将二进制record文件解析为文本，默认输出到stdout\n"
                 "  -o path     输出到指定文件（默认stdout）\n"
                 "  --offset n  时间输出为皮秒，值为 2*tick+n（默认输出tick值）\n",
                 prog);
}

bool parse_u64(const char* s, uint64_t* val)
{
    if (!s || !*s) return false;
    char* end = nullptr;
    unsigned long long v = std::strtoull(s, &end, 0);
    if (end == s || *end != '\0') return false;
    *val = static_cast<uint64_t>(v);
    return true;
}

int parse_args(int argc, char** argv, options_t* opt)
{
    if (argc < 2)
    {
        usage(argv[0]);
        return -1;
    }
    opt->bin_path = argv[1];
    for (int i = 2; i < argc; ++i)
    {
        if (std::strcmp(argv[i], "-o") == 0)
        {
            if (++i >= argc)
            {
                std::fprintf(stderr, "错误: -o缺少输出文件路径\n");
                return -1;
            }
            opt->out_path = argv[i];
        }
        else if (std::strcmp(argv[i], "--offset") == 0)
        {
            if (++i >= argc || !parse_u64(argv[i], &opt->ps_num))
            {
                std::fprintf(stderr, "错误: --offset缺少有效的皮秒偏移数值\n");
                return -1;
            }
            opt->has_offset = true;
        }
        else
        {
            std::fprintf(stderr, "错误: 无法识别的参数: %s\n", argv[i]);
            usage(argv[0]);
            return -1;
        }
    }
    return 0;
}

void print_desc(std::ostream& os, const recorder::file_desc_t& desc,
                const std::string& elf_path, bool has_offset, uint64_t ps_num)
{
    os << "魔术字: 0x" << std::hex << desc.magic << std::dec << "\n";
    os << "版本号: 0x" << std::hex << desc.version << std::dec << " (主版本"
       << (desc.version >> 16) << ", 次版本" << (desc.version & 0xFFFF) << ")\n";
    os << "配置: 0x" << std::hex << desc.config << std::dec
       << " (I-Cache: " << ((desc.config & 0x1) ? "使能" : "关闭")
       << ", D-Cache: " << ((desc.config & 0x2) ? "使能" : "关闭") << ")\n";
    os << "镜像路径: " << desc.image_path << "\n";
    os << "ELF路径: " << elf_path << "\n";
    os << "时间单位: " << (has_offset ? "皮秒 (2*tick+" + std::to_string(ps_num) + ")"
                                  : std::string("tick"))
       << "\n";
    if (has_offset)
        os << "最大时间: " << 2 * desc.max_tick + ps_num << " ps\n";
    else
        os << "最大时间: " << desc.max_tick << "\n";
    os << '\n';
}

void print_records(std::ostream& os, recorder::Recorder* re, bool has_offset, uint64_t ps_num)
{
    using ull = unsigned long long;
    auto time_val = [&](uint64_t tick) -> ull {
        return has_offset ? 2 * tick + ps_num : tick;
    };

    // 列间3空格分隔；时间列宽度取最大时间的位数，每阶段列宽 = 2*时间宽度+1（起始-结束）
    uint64_t max_time = time_val(re->desc().max_tick);
    int w_time = 1;
    for (uint64_t t = max_time; t >= 10; t /= 10) ++w_time;

    const int SEP = 3;
    const int W_INDEX = 3 + SEP, W_PC = 10 + SEP, W_INST = 7 + SEP, W_CACHE = 3 + SEP;
    const int W_STAGE = 2 * w_time + 1 + SEP;

    os << std::left << std::setw(W_INDEX) << "No."
       << std::setw(W_PC) << "PC" << std::setw(W_INST) << "INST" << std::setw(W_CACHE) << "I D";
    for (int i = 0; i < recorder::STAGE_COUNT; ++i)
    {
        os << std::setw(W_STAGE) << STAGE_NAMES[i];
    }
    os << "\n";

    recorder::rc_decode_item_t item = {};
    while (true)
    {
        int code = re->next(&item);
        if (code == 0) break;
        if (code < 0)
        {
            std::fprintf(stderr, "错误: 解析记录#%llu失败: %s\n",
                         static_cast<unsigned long long>(item.index), re->error());
            return;
        }

        char pc_buf[16];
        std::snprintf(pc_buf, sizeof(pc_buf), "0x%08X", item.pc);
        os << std::left << std::setw(W_INDEX) << static_cast<ull>(item.index)
           << std::setw(W_PC) << pc_buf
           << std::setw(W_INST) << recorder::inst_code_name(item.inst_code)
           << std::setw(W_CACHE) << std::to_string(item.icache_miss) + " " +
                  std::to_string(item.dcache_miss)
           << std::right << std::setfill('0');
        for (int i = 0; i < recorder::STAGE_COUNT; ++i)
        {
            os << std::setw(w_time) << time_val(item.stage_ticks[i][0]) << "-"
               << std::setw(w_time) << time_val(item.stage_ticks[i][1])
               << std::string(SEP, ' ');
        }
        os << std::left << std::setfill(' ') << "\n";
    }
}

}  // namespace

int main(int argc, char** argv)
{
    options_t opt;
    if (parse_args(argc, argv, &opt) != 0) return 1;

    recorder::Recorder re;
    if (re.init(opt.bin_path) != 0)
    {
        std::fprintf(stderr, "错误: %s\n", re.error());
        return 1;
    }

    std::ofstream ofs;
    std::ostream* os = &std::cout;
    if (!opt.out_path.empty())
    {
        ofs.open(opt.out_path);
        if (!ofs)
        {
            std::fprintf(stderr, "错误: 无法打开输出文件: %s\n", opt.out_path.c_str());
            return 1;
        }
        os = &ofs;
    }

    print_desc(*os, re.desc(), re.elf_path(), opt.has_offset, opt.ps_num);
    print_records(*os, &re, opt.has_offset, opt.ps_num);
    return 0;
}
