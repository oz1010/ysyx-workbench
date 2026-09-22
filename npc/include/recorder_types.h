/**
 * ====================================================================================
 *                         记录数据二进制格式说明
 * ====================================================================================
 *
 * 1. 文件格式
 *
 * 记录文件整体格式为：
 *   - 描述头部 rc_bin_descript_t，固定长度
 *   - 字符串列表项 'KEY\0VALUE0\0...VALUEn\0\n'，record_offset-描述头部大小
 *   - 各种类型记录项
 * 
 * 记录项格式为：
 *   - 记录头部Header，固定1字节，Bit[7:6]固定为记录类型
 *   - 记录负载Payload，根据记录类型来确定
 * 
 * 记录类型：
 *   - 0 (RC_BIN_TYPE_INST): 指令记录
 *   - 1 (RC_BIN_TYPE_REG) : 寄存器记录
 *
 * 2. 指令记录
 *
 * Header (1 Byte):
 *    +-------------------------------+-------+-------+---------------+--------------+
 *    | Bit [7:6]        |  Bit [5:4] | Bit 3 | Bit 2 | Bit 1         | Bit 0        |
 *    +-------------------------------+-------+-------+---------------+--------------+
 *    | RC_BIN_TYPE_INST |  RESERVE   | RESERVE|CACHE_DATA| INST_VALID | DISCONT_PC  |
 *    +-------------------------------+-------+-------+---------------+--------------+
 *    - Bit 0 (DISCONT_PC)    : 1 表示 PC 不连续 (PC != last_pc + 4)，Payload 中存在 PC Delta。
 *    - Bit 1 (INST_VALID)    : 1 表示有效指令；0 表示同批次被flush的未完成指令。
 *    - Bit 2 (CACHE_DATA)    : 1 表示 Payload 中存在缓存统计数据。
 *    - Bit 3                 : 保留，未使用（v2.4.0起原D_MISS标识删除）。
 *
 * Payload (字段按以下顺序出现):
 *    - [PC Delta]          : (ZigZag + ULEB128)仅在 Bit 0 (DISCONT_PC) == 1 时存在。
 *    - <ΔIF_begin>         : (ULEB128)         固定存在，IF阶段起始tick相对上一条指令记录的增量。
 *    - <Storage Index>     : (ULEB128)         固定存在，存储索引值，具体格式见后面；
 *    - <Stage Durations>   : (ULEB128 ARRAY)   固定存在，依次为IF ID EX LS WB各阶段的持续时间。
 *    - [Cache Data]        : (1 Byte)          仅在 Bit 2 (CACHE_DATA) == 1 时存在，
 *                                              缓存统计数据：Bit[1:0]为icache状态，Bit[3:2]为dcache状态，
 *                                              取值0=无 1=命中 2=未命中；缓存统计只针对读，写为0（无）。
 * 
 * 存储索引值：低bit位为指令存储索引，高bit位为数据存储索引，各占用的bit位数由
 * 存储体列表数决定（3个存储体占2bit，9个存储体占4bit），索引值取自HW_CPU_STAT_ICACHE_MEM_INDEX，
 * 即描述信息中STORAGE列表的索引；无存储数据时对应bit位默认为全1，解析时显示为none。
 * 
 * 无效记录（由指令记录Header INST_VALID位标识）:
 *    指令完成WBU阶段时，同批次被flush的未完成指令也会按时间顺序写入文件。
 *    这类记录部分阶段数据缺失，缺失阶段的持续时间编码为0，解析时根据Header的
 * INST_VALID位判断记录有效性；无效记录可用于计算flush流水线占用的时间，正常打印时屏蔽。
 *
 * 3. 寄存器写记录
 *
 * Header (1 Byte):
 *    +-------------------+----------------------------------+-----------+
 *    | Bit [7:6]         | Bit [5:1]                        | Bit 0     |
 *    +-------------------+----------------------------------+-----------+
 *    | RC_BIN_TYPE_REG   | RESERVE                          | 0=GPR     |
 *    |                   |                                  | 1=CSR     |
 *    +-------------------+----------------------------------+-----------+
 *
 * Payload (字段按以下顺序出现):
 *    - [Index]             : (ULEB128)         必然存在，写地址：GPR为寄存器索引(0-31)，
 * CSR为CSR地址。
 *    - [Data]              : (ULEB128)         必然存在，寄存器写数据。
 *
 * ====================================================================================
 */

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
 */
#define RC_BIN_DESCRIPT_MAGIC 0x504D5244u
#define RC_BIN_DESCRIPT_VERSION 0x00020500u
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
     * 记录数据在文件中的偏移，即描述信息与全部字符串数据之后的文件偏移。
     * 描述信息之后紧跟行式字符串数据，每行格式为'KEY\0VALUE0\0...VALUEn\0\n'，
     * 一行内KEY后跟多个\0结尾的VALUE（列表形式），用\n标识一行结束：
     *   - 'IMG\0<image_path>\0\n'      仿真镜像绝对路径
     *   - 'STORAGE\0<name>\0...\0\n'   存储体名称列表，顺序固定，Storage Index的
     *                                  低bit位指令存储索引即为该列表的索引
     */
    uint64_t record_offset;

    /**
     * 最大tick值，即每个指令执行完时的tick值
     * 仿真退出前强制回写更新
     */
    uint64_t max_tick;

    /**
     * 各流水阶段持续时间的最大值（stage_end - stage_begin的最大值）
     * 记录每条指令各阶段持续时间时更新
     */
    uint64_t max_duration;

    /**
     * 总取指数
     * 记录仿真时取指单元所有指令数，退出前强制回写更新
     */
    uint64_t total_inst;
} rc_bin_descript_t;

typedef union
{
    struct
    {
        uint32_t stage : 4;    // 阶段编号，枚举STAGE_INDEX_xxx
        uint32_t is_end : 1;   // 阶段结束标识
        uint32_t kind : 2;     // WBU进入时的寄存器写数据类型：0无 1=CSR写 2=GPR写（CSR两个写通道共用1）
        uint32_t wen : 1;      // 寄存器写使能
        uint32_t waddr : 13;   // 寄存器写地址：GPR为5位索引，CSR为12位地址（高位补0）
        uint32_t reserve : 11; // 保留
    };
    int raw;
} rc_mid_t;

/**
 * 记录类型，存储于记录Header字节的高2位
 *   v2.1.0新增寄存器写记录：WBU进入时采集的1组GPR写和2组CSR写数据，
 *   紧随所属指令记录之后写入，流内顺序为[指令记录][寄存器记录]*，
 *   不携带pc，其pc即前一条指令记录的pc
 *   v2.3.0起寄存器记录Header bit0表示GPR/CSR（0=GPR 1=CSR），bits[5:1]保留，
 *   原bits[4:3] CSR写通道索引已删除
 *   v2.4.0起指令记录Header bit2改为CACHE_DATA（是否存在缓存统计数据），bit3不再使用，
 *   原bits[3:2] I_MISS/D_MISS标识删除；Payload末尾新增Cache Data字节：
 *   Bit[1:0]为icache状态、Bit[3:2]为dcache状态（0=无 1=命中 2=未命中），
 *   缓存统计只针对读，写为无；数据由icache/dcache经IFU/LSU流水随PC关联传递
 */
#define RC_BIN_TYPE_INST 0x0  // 指令记录
#define RC_BIN_TYPE_REG  0x1  // 寄存器写记录
#define RC_BIN_TYPE_SHIFT 6
#define RC_BIN_TYPE_MASK  0x3

// 寄存器写记录Header低6位定义（仅记录类型为RC_BIN_TYPE_REG时有效）
#define RC_BIN_REG_GPR (0 << 0)  // bit0: 0=GPR 1=CSR（v2.3.0起由bit5移至bit0）
#define RC_BIN_REG_CSR (1 << 0)
#define RC_BIN_REG_RESERVE 0x3E  // bits[5:1]: 保留（v2.3.0起，原CSR写通道索引bits[4:3]已删除）

// record条目Header标志位定义（仅记录类型为RC_BIN_TYPE_INST时有效）
#define RC_BIN_FLAG_DISCONT_PC (1 << 0)
#define RC_BIN_FLAG_INST_VALID (1 << 1)
#define RC_BIN_FLAG_CACHE_DATA (1 << 2)  // bit2: 1表示Payload中存在缓存统计数据
                                         // bit3: 保留未使用（v2.4.0起原D_MISS标识删除）

/**
 * 缓存访问状态编码（2bit），Cache Data字节中Bit[1:0]为icache，Bit[3:2]为dcache
 * 缓存统计只针对读，写或无读访问时为NONE
 */
enum
{
    RC_BIN_CACHE_STAT_NONE = 0,  // 无缓存统计数据（写或无读访问）
    RC_BIN_CACHE_STAT_HIT  = 1,  // 命中
    RC_BIN_CACHE_STAT_MISS = 2   // 未命中
};

/**
 * 存储索引占用的bit位数，由存储体列表数量决定
 * 如3个存储体占2bit，9个存储体占4bit
 */
static inline int rc_storage_index_bits(int storage_count)
{
    int bits = 0;
    while ((1 << bits) < storage_count)
    {
        bits++;
    }
    return bits;
}

// 编码上下文
typedef struct
{
    uint64_t last_pc;
    uint64_t last_if_begin;
    uint64_t last_update_tick;
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
    uint8_t  rec_type;   // 记录类型，枚举RC_BIN_TYPE_xxx：0=指令记录 1=寄存器写记录
    uint64_t index;      // 记录序号，从0开始
    uint32_t pc;         // 指令PC
    uint32_t inst;       // ELF中pc处的指令字，未找到时为0
    uint16_t inst_code;  // inst 对应的指令码，未找到时为INST_INVALID_CODE
    bool inst_found;     // ELF中是否找到pc对应的指令
    uint32_t icache_stat; // 取指I-Cache访问状态：0无 1命中 2未命中
    uint32_t dcache_stat; // 访存D-Cache访问状态：0无 1命中 2未命中（写为0）
    uint32_t storage_index;      // 指令存储索引（Storage Index低bit位，即STORAGE列表索引；全1表示无存储数据）
    uint32_t data_storage_index; // 数据存储索引（Storage Index高bit位；全1表示无存储数据）
    uint64_t if_begin;   // IF阶段起始tick
    uint32_t durations[STAGE_COUNT];       // 各阶段持续时间(end - begin)
    uint64_t stage_ticks[STAGE_COUNT][2];  // 各阶段起始/结束tick
    bool valid;  // 记录是否有效，取自Header的INST_VALID位；被flush的指令为无效记录

    /* 寄存器写记录字段（rec_type==RC_BIN_TYPE_REG时有效） */
    uint32_t reg_pc;     // 写回对应的指令PC（即前一条指令记录的pc）
    bool     reg_is_csr; // 0=GPR写 1=CSR写（v2.3.0起取自Header bit0）
    uint32_t reg_index;  // 写地址：GPR为寄存器索引(0-31)，CSR为CSR地址
    uint32_t reg_data;   // 写数据
} rc_decode_item_t;

#ifdef __cplusplus
}
#endif

#endif
