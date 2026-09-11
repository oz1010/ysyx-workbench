#include "recorder.h"

#include <cstdio>
#include <fstream>

#include "elf_parser.h"
#include "inst_decode.h"
#include "stream_reader.h"

namespace recorder
{

namespace
{

/**
 * 镜像路径后缀判断：.bin替换为.elf，.elf直接使用，其他格式报错
 */
std::string resolve_elf_path(const std::string& image_path, std::string& err)
{
    size_t slash = image_path.find_last_of("/\\");
    size_t dot   = image_path.find_last_of('.');
    if (dot == std::string::npos || (slash != std::string::npos && dot < slash))
    {
        err = "不支持的镜像格式(无后缀): " + image_path;
        return "";
    }
    std::string suffix = image_path.substr(dot + 1);
    std::string elf_path;
    if (suffix == "bin")
    {
        elf_path = image_path.substr(0, dot) + ".elf";
    }
    else if (suffix == "elf")
    {
        elf_path = image_path;
    }
    else
    {
        err = "不支持的镜像格式(." + suffix + "): " + image_path;
        return "";
    }

    std::ifstream ifs(elf_path, std::ios::binary);
    if (!ifs)
    {
        err = "镜像文件不存在: " + elf_path;
        return "";
    }
    return elf_path;
}

}  // namespace

Recorder::Recorder()  = default;
Recorder::~Recorder() = default;

const file_desc_t& Recorder::desc() const { return desc_; }
const std::string& Recorder::elf_path() const { return elf_path_; }
uint64_t           Recorder::bytes_consumed() const
{
    return reader_ ? reader_->tell() : 0;
}
uint64_t Recorder::file_size() const { return file_size_; }
const char* Recorder::error() const { return error_.c_str(); }

int Recorder::init(const std::string& filepath, size_t page_size)
{
    reader_ = new StreamReader();
    elf_    = new ElfImage();

    std::string err;
    if (reader_->open(filepath, page_size, err) != 0)
    {
        error_ = err;
        return -1;
    }

    std::ifstream ifs(filepath, std::ios::binary | std::ios::ate);
    file_size_ = ifs ? static_cast<uint64_t>(ifs.tellg()) : 0;

    if (parse_descript() != 0) return -1;

    elf_path_ = resolve_elf_path(desc_.image_path, err);
    if (elf_path_.empty())
    {
        error_ = err;
        return -1;
    }
    if (elf_->load(elf_path_, err) != 0)
    {
        error_ = err;
        return -1;
    }
    return 0;
}

int Recorder::parse_descript()
{
    struct raw_descript
    {
        uint32_t magic;
        uint32_t version;
        uint32_t config;
        uint32_t image_path_len;
    } raw;

    if (!reader_->read_bytes(&raw, sizeof(raw)))
    {
        error_ = "文件过小，缺少文件描述部分";
        return -1;
    }
    if (raw.magic != DESCRIPT_MAGIC)
    {
        char buf[64];
        snprintf(buf, sizeof(buf), "文件魔术字不匹配: 0x%08X", raw.magic);
        error_ = buf;
        return -1;
    }
    if ((raw.version >> 16) != DESCRIPT_VERSION_MAJOR)
    {
        char buf[64];
        snprintf(buf, sizeof(buf), "文件主版本不兼容: 0x%08X", raw.version);
        error_ = buf;
        return -1;
    }

    desc_.magic       = raw.magic;
    desc_.version     = raw.version;
    desc_.config      = raw.config;
    desc_.max_tick    = 0;
    desc_.image_path.clear();

    // max_tick字段自v1.0.2起追加在image_path_len之后，旧版本文件无此字段
    if ((raw.version & 0xFFFF) >= 0x0002)
    {
        uint64_t max_tick;
        if (!reader_->read_bytes(&max_tick, sizeof(max_tick)))
        {
            error_ = "文件过小，缺少max_tick字段";
            return -1;
        }
        desc_.max_tick = max_tick;
    }

    if (raw.image_path_len > 0)
    {
        std::string path(raw.image_path_len, '\0');
        if (!reader_->read_bytes(path.data(), raw.image_path_len))
        {
            error_ = "镜像路径不完整";
            return -1;
        }
        while (!path.empty() && path.back() == '\0') path.pop_back();
        desc_.image_path = path;
    }
    if (desc_.image_path.empty())
    {
        error_ = "文件描述中镜像路径为空";
        return -1;
    }
    return 0;
}

int Recorder::next(rc_decode_item_t* item)
{
    if (!reader_)
    {
        error_ = "recorder未初始化";
        return -1;
    }
    if (!item)
    {
        error_ = "记录项指针为空";
        return -1;
    }
    return decode_record(item);
}

int Recorder::decode_record(rc_decode_item_t* item)
{
    // 记录边界处无数据表示全部解析完毕
    if (!reader_->require(1)) return 0;

    const uint64_t record_offset = reader_->tell();
    const uint8_t  header        = reader_->read_u8();

    const bool discont_pc    = header & RC_BIN_FLAG_DISCONT_PC;
    const bool same_duration = header & RC_BIN_FLAG_SAME_DURATION;
    item->icache_miss        = header & RC_BIN_FLAG_ICACHE_MISS;
    item->dcache_miss        = header & RC_BIN_FLAG_DCACHE_MISS;
    const uint8_t tiny_delta = header >> RC_BIN_IF_DELTA_SHIFT;

    // PC（不连续时从Payload读取ZigZag+ULEB128编码的Delta）
    if (discont_pc)
    {
        uint64_t zigzag = 0;
        if (!reader_->read_uleb128(&zigzag))
        {
            error_ = "PC Delta缺失或数据不完整(offset=" + std::to_string(record_offset) + ")";
            return -1;
        }
        const int64_t pc_delta =
            static_cast<int64_t>(zigzag >> 1) ^ -static_cast<int64_t>(zigzag & 1);
        item->pc = static_cast<uint32_t>(static_cast<int64_t>(last_pc_) + pc_delta);
    }
    else
    {
        item->pc = static_cast<uint32_t>(last_pc_ + 4);
    }

    // IF起始tick增量（Header[7:4]为15时从Payload读取ULEB128）
    uint64_t delta_if_begin = tiny_delta;
    if (tiny_delta == RC_BIN_IF_DELTA_MAX)
    {
        if (!reader_->read_uleb128(&delta_if_begin))
        {
            error_ = "IF起始tick增量缺失或数据不完整(offset=" +
                     std::to_string(record_offset) + ")";
            return -1;
        }
    }
    item->if_begin = last_if_begin_ + delta_if_begin;

    // 各阶段持续时间（与上一条一致时省略）
    if (same_duration)
    {
        for (int i = 0; i < STAGE_COUNT; ++i)
        {
            item->durations[i] = last_durations_[i];
        }
    }
    else
    {
        for (int i = 0; i < STAGE_COUNT; ++i)
        {
            uint64_t duration = 0;
            if (!reader_->read_uleb128(&duration) || duration > UINT32_MAX)
            {
                error_ = "阶段持续时间缺失或数据不完整(offset=" +
                         std::to_string(record_offset) + ")";
                return -1;
            }
            item->durations[i]   = static_cast<uint32_t>(duration);
            last_durations_[i]   = item->durations[i];
        }
    }

    // 更新增量解码上下文
    last_pc_       = item->pc;
    last_if_begin_ = item->if_begin;

    // 展开各阶段起止tick
    uint64_t tick = item->if_begin;
    for (int i = 0; i < STAGE_COUNT; ++i)
    {
        item->stage_ticks[i][0] = tick;
        tick += item->durations[i];
        item->stage_ticks[i][1] = tick;
    }

    // 从ELF中查询指令字并计算指令码
    item->index      = record_cnt_++;
    item->inst       = 0;
    item->inst_found = elf_->read_inst(item->pc, &item->inst);
    item->inst_code  = item->inst_found ? decode_inst_code(item->inst) : INST_INVALID_CODE;
    return 1;
}

}  // namespace recorder
