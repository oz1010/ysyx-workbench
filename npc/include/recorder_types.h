#ifndef __RECORDER_TYPES_H__
#define __RECORDER_TYPES_H__

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/**
 * 流水阶段索引，与 vsrc/core/common/riscv32e_defines.v 中 STAGE_INDEX_xxx 一致
 */
enum
{
    STAGE_INDEX_IFU,
    STAGE_INDEX_IDU,
    STAGE_INDEX_EXU,
    STAGE_INDEX_LSU,
    STAGE_INDEX_WBU,

    STAGE_COUNT
};

/**
 * 文件魔术字与版本号
 *   - 魔术字固定为：'PMRD' (Perf Monitor Record Data)
 *   - 版本号xx.x.x，高位占用2字节，1.2.3对应值为0x00010203
 *     用于检测数据格式是否兼容，前两位版本一致数据格式必须兼容
 *     初始版本号为1.0.0
 *     1.0.2: rc_bin_descript_t 末尾新增 max_tick 字段
 */
#define RC_BIN_DESCRIPT_MAGIC 0x504D5244u
#define RC_BIN_DESCRIPT_VERSION 0x00010002u
#define RC_BIN_DESCRIPT_VERSION_MAJOR (RC_BIN_DESCRIPT_VERSION >> 16)

/**
 * 二进制描述数据
 */
typedef struct
{
    /**
     * 文件魔术字
     * 固定为：'PMRD' (Perf Monitor Record Data)
     */
    uint32_t magic;

    /**
     * xx.x.x，高位占用2字节，1.2.3对应值为0x00010203
     * 用于检测数据格式是否兼容，前两位版本一致数据格式必须兼容
     * 初始版本号为1.0.0
     */
    uint32_t version;

    /**
     * 当前配置项
     */
    union
    {
        struct
        {
            uint32_t icache_enable : 1;
            uint32_t dcache_enable : 1;
            uint32_t reserve : 30;
        };
        uint32_t raw;
    } config;

    /**
     * 仿真镜像绝对路径信息，这里保存字符串长度包含\0
     * 描述信息后紧跟指定长度的字符串
     */
    uint32_t image_path_len;

    /**
     * 最大tick值，即每个指令执行完时的tick值
     * 仿真退出前强制回写更新，仅v1.0.2及以上版本有效
     */
    uint64_t max_tick;
} rc_bin_descript_t;

typedef union
{
    struct
    {
        uint32_t stage : 4;   // 阶段编号，枚举STAGE_INDEX_xxx
        uint32_t is_end : 1;  // 阶段结束标识
    };
    int raw;
} rc_mid_t;

// record条目Header标志位及IF起始tick增量字段定义
#define RC_BIN_FLAG_DISCONT_PC (1 << 0)
#define RC_BIN_FLAG_SAME_DURATION (1 << 1)
#define RC_BIN_FLAG_ICACHE_MISS (1 << 2)
#define RC_BIN_FLAG_DCACHE_MISS (1 << 3)
#define RC_BIN_IF_DELTA_MASK (0xF0)
#define RC_BIN_IF_DELTA_SHIFT 4
#define RC_BIN_IF_DELTA_MAX (0x0F)

// 编码上下文
typedef struct
{
    uint64_t last_pc;
    uint64_t last_if_begin;
    uint64_t last_update_tick;
    // 缓存上一次各流水阶段的持续时间 (共 5 个阶段，end - begin)
    uint32_t last_durations[STAGE_COUNT];
    int is_first_record;
} rc_encode_ctx_t;

/**
 * 无效指令码，与 riscv32e_defines.v 中 INST_INVALID 一致
 */
enum
{
    INST_INVALID_CODE = 0xFFFF
};

/**
 * 单条解析记录项
 */
typedef struct
{
    uint64_t index;      // 记录序号，从0开始
    uint32_t pc;         // 指令PC
    uint32_t inst;       // ELF中pc处的指令字，未找到时为0
    uint16_t inst_code;  // inst 对应的指令码，未找到时为INST_INVALID_CODE
    bool inst_found;     // ELF中是否找到pc对应的指令
    bool icache_miss;    // 取指发生I-Cache Miss
    bool dcache_miss;    // 访存发生D-Cache Miss
    uint64_t if_begin;   // IF阶段起始tick
    uint32_t durations[STAGE_COUNT];       // 各阶段持续时间(end - begin)
    uint64_t stage_ticks[STAGE_COUNT][2];  // 各阶段起始/结束tick
} rc_decode_item_t;

#ifdef __cplusplus
}
#endif

#endif
