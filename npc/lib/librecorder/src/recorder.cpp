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
        uint64_t record_offset;
        uint64_t max_tick;
        uint64_t max_duration;
        uint64_t total_inst;
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

    desc_.magic        = raw.magic;
    desc_.version      = raw.version;
    desc_.config       = raw.config;
    desc_.max_tick     = raw.max_tick;
    desc_.max_duration = raw.max_duration;
    desc_.total_inst   = raw.total_inst;
    desc_.image_path.clear();
    desc_.storages.clear();

    // 描述信息后为行式字符串数据，每行格式为'KEY\0VALUE0\0...VALUEn\0\n'，
    // 一行内KEY后跟多个\0结尾的VALUE（列表形式），用\n标识一行结束；
    // record_offset指示记录数据的文件偏移
    const uint64_t record_offset = raw.record_offset;
    if (record_offset < sizeof(raw))
    {
        error_ = "record_offset字段无效";
        return -1;
    }
    while (reader_->tell() < record_offset)
    {
        std::string key;
        if (!reader_->read_cstr(&key))
        {
            error_ = "字符串数据不完整";
            return -1;
        }

        std::vector<std::string> values;
        while (true)
        {
            uint8_t peek = 0;
            if (!reader_->peek_u8(&peek))
            {
                error_ = "字符串数据不完整";
                return -1;
            }
            if (peek == '\n')
            {
                reader_->read_u8();  // 消费行结束符
                break;
            }
            std::string value;
            if (!reader_->read_cstr(&value))
            {
                error_ = "字符串数据不完整";
                return -1;
            }
            values.push_back(value);
        }

        if (key == "IMG")
        {
            desc_.image_path = values.empty() ? "" : values.front();
        }
        else if (key == "STORAGE")
        {
            desc_.storages = values;
        }
        else
        {
            error_ = "未知的字符串KEY: " + key;
            return -1;
        }
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
    const uint8_t  rec_type      = (header >> RC_BIN_TYPE_SHIFT) & RC_BIN_TYPE_MASK;

    // 寄存器写记录（v2.1.0新增，v2.2.0起不携带PC，v2.3.0起Header bit0为GPR/CSR、
    // bits[5:1]保留，CSR写通道索引已删除）：Payload为写索引index + 写数据data，
    // 对应的pc即前一条指令记录的pc（last_pc_）
    if (rec_type == RC_BIN_TYPE_REG)
    {
        uint64_t reg_index = 0, reg_data = 0;
        if (!reader_->read_uleb128(&reg_index) || !reader_->read_uleb128(&reg_data))
        {
            error_ = "寄存器写记录Payload缺失或数据不完整(offset=" +
                     std::to_string(record_offset) + ")";
            return -1;
        }
        item->rec_type   = RC_BIN_TYPE_REG;
        item->reg_pc     = static_cast<uint32_t>(last_pc_);
        item->reg_is_csr = (header & RC_BIN_REG_CSR) != 0;
        item->reg_index  = static_cast<uint32_t>(reg_index);
        item->reg_data   = static_cast<uint32_t>(reg_data);
        item->storage_index      = 0;
        item->data_storage_index = 0;
        item->valid      = false;  // 非指令记录，不参与指令统计
        item->icache_stat = RC_BIN_CACHE_STAT_NONE;
        item->dcache_stat = RC_BIN_CACHE_STAT_NONE;
        return 1;
    }

    // 指令记录：初始化寄存器写记录字段为默认值
    item->rec_type   = RC_BIN_TYPE_INST;
    item->reg_pc     = 0;
    item->reg_is_csr = false;
    item->reg_index  = 0;
    item->reg_data   = 0;
    item->icache_stat = RC_BIN_CACHE_STAT_NONE;
    item->dcache_stat = RC_BIN_CACHE_STAT_NONE;

    const bool discont_pc    = header & RC_BIN_FLAG_DISCONT_PC;
    const bool inst_valid    = header & RC_BIN_FLAG_INST_VALID;
    const bool cache_data    = header & RC_BIN_FLAG_CACHE_DATA;

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

    // IF起始tick增量（必然存在，ULEB128编码）
    uint64_t delta_if_begin = 0;
    if (!reader_->read_uleb128(&delta_if_begin))
    {
        error_ = "IF起始tick增量缺失或数据不完整(offset=" +
                 std::to_string(record_offset) + ")";
        return -1;
    }
    item->if_begin = last_if_begin_ + delta_if_begin;

    // Storage Index（必然存在，ULEB128编码）：低bit位为指令存储索引，
    // 高bit位为数据存储索引，bit位数由存储体列表数决定
    uint64_t storage_index = 0;
    if (!reader_->read_uleb128(&storage_index))
    {
        error_ = "Storage Index缺失或数据不完整(offset=" + std::to_string(record_offset) + ")";
        return -1;
    }
    const int     storage_bits = rc_storage_index_bits(static_cast<int>(desc_.storages.size()));
    const uint64_t storage_mask =
        storage_bits >= 32 ? ~0ull : ((1ull << storage_bits) - 1);
    item->storage_index      = static_cast<uint32_t>(storage_index & storage_mask);
    item->data_storage_index = static_cast<uint32_t>((storage_index >> storage_bits) & storage_mask);

    // 各阶段持续时间（固定写入）
    for (int i = 0; i < STAGE_COUNT; ++i)
    {
        uint64_t duration = 0;
        if (!reader_->read_uleb128(&duration) || duration > UINT32_MAX)
        {
            error_ = "阶段持续时间缺失或数据不完整(offset=" +
                     std::to_string(record_offset) + ")";
            return -1;
        }
        item->durations[i] = static_cast<uint32_t>(duration);
    }

    // 缓存统计数据（1 Byte，仅Header CACHE_DATA位为1时存在）：
    // Bit[1:0]为icache状态，Bit[3:2]为dcache状态，0=无 1=命中 2=未命中
    if (cache_data)
    {
        if (!reader_->require(1))
        {
            error_ = "缓存统计数据缺失或数据不完整(offset=" +
                     std::to_string(record_offset) + ")";
            return -1;
        }
        const uint8_t stat = reader_->read_u8();
        item->icache_stat = stat & 0x3;
        item->dcache_stat = (stat >> 2) & 0x3;
    }

    // 更新增量解码上下文
    last_pc_       = item->pc;
    last_if_begin_ = item->if_begin;

    // 记录有效性由Header的INST_VALID位标识：被flush的指令存在缺失阶段，
    // 为无效记录，可用于计算flush流水线占用的时间
    item->valid = inst_valid;

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
