#ifndef __RECORDER_H__
#define __RECORDER_H__

#include <cstddef>
#include <cstdint>
#include <string>

#include "recorder_types.h"

namespace recorder
{

// record格式的公共类型定义已提取到 include/recorder_types.h，
// 这里引入以保持 recorder:: 限定名可用
using ::STAGE_INDEX_IFU;
using ::STAGE_INDEX_IDU;
using ::STAGE_INDEX_EXU;
using ::STAGE_INDEX_LSU;
using ::STAGE_INDEX_WBU;
using ::STAGE_COUNT;
using ::INST_INVALID_CODE;
using ::rc_decode_item_t;

/**
 * 文件魔术字与版本号，见 recorder_types.h 中 HW_MONITOR_DESCRIPT_xxx
 */
constexpr uint32_t DESCRIPT_MAGIC         = RC_BIN_DESCRIPT_MAGIC;
constexpr uint32_t DESCRIPT_VERSION       = RC_BIN_DESCRIPT_VERSION;
constexpr uint32_t DESCRIPT_VERSION_MAJOR = RC_BIN_DESCRIPT_VERSION_MAJOR;

/**
 * record 文件描述部分，对应 rc_bin_descript_t + 镜像路径字符串
 */
struct file_desc_t
{
    uint32_t    magic;
    uint32_t    version;
    uint32_t    config;        // bit0: icache_enable, bit1: dcache_enable
    uint64_t    max_tick;      // 最大tick值（指令执行完时的tick值），v1.0.2起有效，旧版本为0
    std::string image_path;    // 描述信息中的仿真镜像路径
};

/**
 * 按 vsrc/core/pipeline/inst_decode.v 的解码规则，由指令字计算 inst_code
 * 返回值与 riscv32e_defines.v 中 INST_xxx 定义一致，无法识别返回 INST_INVALID_CODE
 */
uint16_t decode_inst_code(uint32_t inst);

class StreamReader;
class ElfImage;

class Recorder
{
public:
    Recorder();
    ~Recorder();

    Recorder(const Recorder&)            = delete;
    Recorder& operator=(const Recorder&) = delete;

    /**
     * 初始化：打开record文件，流式解析文件描述部分；
     * 根据描述中的镜像路径加载ELF（.bin尝试替换为.elf后缀，.elf直接解析，其他格式报错）
     * @param filepath record文件路径
     * @param page_size 流式读取的页大小，默认4096
     * @return 0成功，-1失败（错误信息见error()）
     */
    int init(const std::string& filepath, size_t page_size = 4096);

    /**
     * 流式解析下一条记录，每次仅解析出一个记录项
     * @return 1: 成功, 0: 全部解析完毕, -1: 出错（错误信息见error()）
     */
    int next(rc_decode_item_t* item);

    const file_desc_t& desc() const;      // 文件描述
    const std::string& elf_path() const;  // 实际解析的ELF路径
    uint64_t bytes_consumed() const;      // 已消费的文件偏移
    uint64_t file_size() const;           // record文件总大小
    const char* error() const;            // 错误信息

private:
    int parse_descript();
    int decode_record(rc_decode_item_t* item);

    StreamReader* reader_;
    ElfImage*     elf_;
    file_desc_t   desc_;
    std::string   elf_path_;
    std::string   error_;
    uint64_t      file_size_  = 0;
    uint64_t      record_cnt_ = 0;
    // 增量解码上下文，与 rc_encode_ctx_t 对应
    uint64_t last_pc_        = 0;
    uint64_t last_if_begin_  = 0;
    uint32_t last_durations_[STAGE_COUNT] = {0};
};

}  // namespace recorder

#endif
