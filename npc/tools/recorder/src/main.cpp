// recorder可执行文件：将二进制record文件解析为文本
// 用法: recorder <path_to_bin> [-o path_to_text] [--offset ps_num]

#include <algorithm>
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
    bool        has_offset  = false;
    uint64_t    ps_num      = 0;
    bool        icache      = false;
    bool        dcache      = false;
    bool        time_detail = false;
};

void usage(const char* prog)
{
    std::fprintf(stderr,
                 "用法: %s <path_to_bin> [-o path_to_text] [--offset ps_num] [--cache] [--time_detail]\n"
                 "  将二进制record文件解析为文本，默认输出到stdout\n"
                 "  -o path         输出到指定文件（默认stdout）\n"
                 "  --offset n      时间输出为皮秒，值为 2*tick+n（默认输出tick值）\n"
                 "  --cache         同时使能--icache和--dcache\n"
                 "  --icache        打印ICACHE列（I-Cache Miss及存储名称，无存储数据时为none）\n"
                 "  --dcache        打印DCACHE列（D-Cache Miss及存储名称，无存储数据时为none）\n"
                 "  --time_detail   打印IF ID EX LS WB各阶段时间详细列\n",
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
        else if (std::strcmp(argv[i], "--cache") == 0)
        {
            opt->icache = true;
            opt->dcache = true;
        }
        else if (std::strcmp(argv[i], "--icache") == 0)
        {
            opt->icache = true;
        }
        else if (std::strcmp(argv[i], "--dcache") == 0)
        {
            opt->dcache = true;
        }
        else if (std::strcmp(argv[i], "--time_detail") == 0)
        {
            opt->time_detail = true;
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
    os << "版本号: " << (desc.version >> 16) << "." << ((desc.version >> 8) & 0xFF) << "."
       << (desc.version & 0xFF) << "\n";
    os << "配置: 0x" << std::hex << desc.config << std::dec
       << " (I-Cache: " << ((desc.config & 0x1) ? "使能" : "关闭")
       << ", D-Cache: " << ((desc.config & 0x2) ? "使能" : "关闭") << ")\n";
    os << "镜像路径: " << desc.image_path << "\n";
    os << "ELF路径: " << elf_path << "\n";
    os << "存储列表: ";
    for (size_t i = 0; i < desc.storages.size(); ++i)
    {
        os << (i == 0 ? "" : " ") << desc.storages[i];
    }
    os << "\n";
    os << "时间单位: " << (has_offset ? "皮秒 (2*tick+" + std::to_string(ps_num) + ")"
                                  : std::string("tick"))
       << "\n";
    if (has_offset)
    {
        os << "最大时间: " << 2 * desc.max_tick + ps_num << " ps\n";
        os << "最大阶段时间: " << 2 * desc.max_duration << " ps\n";
    }
    else
    {
        os << "最大时间: " << desc.max_tick << "\n";
        os << "最大阶段时间: " << desc.max_duration << "\n";
    }
    os << '\n';
}

void print_records(std::ostream& os, recorder::Recorder* re, bool has_offset, uint64_t ps_num,
                   bool icache, bool dcache, bool time_detail)
{
    using ull = unsigned long long;
    auto time_val = [&](uint64_t tick) -> ull {
        return has_offset ? 2 * tick + ps_num : tick;
    };
    // 持续时间为绝对时间的差值，换算时只需乘2，不含offset
    auto dur_val = [&](uint64_t dur) -> ull {
        return has_offset ? 2 * dur : dur;
    };

    // 列间3空格分隔；时间列宽度取最大时间的位数，每阶段列宽 = 2*时间宽度+1（起始-结束）
    uint64_t max_time = time_val(re->desc().max_tick);
    int w_time = 1;
    for (uint64_t t = max_time; t >= 10; t /= 10) ++w_time;

    // DURATION列：各阶段持续时间以'-'连接，每段宽度取最大阶段时间的位数
    uint64_t max_dur = dur_val(re->desc().max_duration);
    int w_dur = 1;
    for (uint64_t t = max_dur; t >= 10; t /= 10) ++w_dur;

    const int SEP = 3;
    const int W_INDEX = 3 + SEP, W_PC = 10 + SEP, W_INST = 7 + SEP;
    const int W_STAGE = 2 * w_time + 1 + SEP;
    const int W_DUR = recorder::STAGE_COUNT * w_dur + (recorder::STAGE_COUNT - 1) + SEP;

    // ICACHE/DCACHE列：各为'标志 存储名称'，名称宽度取存储名称的最大长度（无存储数据时为none）
    const auto& storages = re->desc().storages;
    const int storage_bits = rc_storage_index_bits(static_cast<int>(storages.size()));
    const uint32_t storage_mask =
        storage_bits >= 32 ? UINT32_MAX : ((1u << storage_bits) - 1);
    size_t max_storage_len = std::strlen("none");
    for (const auto& s : storages) max_storage_len = std::max(max_storage_len, s.size());
    const int W_CACHE = 2 + static_cast<int>(max_storage_len) + SEP;

    os << std::left << std::setw(W_INDEX) << "No."
       << std::setw(W_PC) << "PC" << std::setw(W_INST) << "INST"
       << std::setw(W_DUR) << "DURATION";
    if (icache)
    {
        os << std::setw(W_CACHE) << "ICACHE";
    }
    if (dcache)
    {
        os << std::setw(W_CACHE) << "DCACHE";
    }
    if (time_detail)
    {
        for (int i = 0; i < recorder::STAGE_COUNT; ++i)
        {
            os << std::setw(W_STAGE) << STAGE_NAMES[i];
        }
    }
    os << "\n";

    recorder::rc_decode_item_t item = {};
    uint64_t                   valid_cnt = 0;  // 有效指令编号，不含被flush的无效记录
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

        // 无效记录（被flush的指令，各阶段数据不完整）和寄存器写记录不参与正常打印
        if (!item.valid) continue;
        if (item.rec_type == RC_BIN_TYPE_REG) continue;

        const uint64_t no = valid_cnt++;

        char pc_buf[16];
        std::snprintf(pc_buf, sizeof(pc_buf), "0x%08X", item.pc);
        os << std::left << std::setw(W_INDEX) << static_cast<ull>(no)
           << std::setw(W_PC) << pc_buf
           << std::setw(W_INST) << recorder::inst_code_name(item.inst_code)
           << std::right << std::setfill('0');
        for (int i = 0; i < recorder::STAGE_COUNT; ++i)
        {
            os << std::setw(w_dur) << dur_val(item.durations[i]);
            if (i + 1 < recorder::STAGE_COUNT) os << "-";
        }
        os << std::string(SEP, ' ');
        // CACHE列：先打印是否命中，再打印对应的存储名称（名称按最大长度对齐）；
        // 存储索引为全1（无存储数据）或超出存储列表范围时显示为none
        auto storage_name = [&storages, storage_mask](uint32_t idx) -> std::string {
            if (idx == storage_mask || idx >= storages.size()) return "none";
            return storages[idx];
        };
        if (icache)
        {
            os << std::left << std::setfill(' ')
               << item.icache_stat << ' '
               << std::setw(static_cast<int>(max_storage_len)) << storage_name(item.storage_index)
               << std::string(SEP, ' ');
        }
        if (dcache)
        {
            os << std::left << std::setfill(' ')
               << item.dcache_stat << ' '
               << std::setw(static_cast<int>(max_storage_len)) << storage_name(item.data_storage_index)
               << std::string(SEP, ' ');
        }
        os << std::right << std::setfill('0');
        if (time_detail)
        {
            for (int i = 0; i < recorder::STAGE_COUNT; ++i)
            {
                os << std::setw(w_time) << time_val(item.stage_ticks[i][0]) << "-"
                   << std::setw(w_time) << time_val(item.stage_ticks[i][1])
                   << std::string(SEP, ' ');
            }
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
    print_records(*os, &re, opt.has_offset, opt.ps_num, opt.icache, opt.dcache, opt.time_detail);
    return 0;
}
