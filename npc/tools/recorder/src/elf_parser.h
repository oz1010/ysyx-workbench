#ifndef __ELF_PARSER_H__
#define __ELF_PARSER_H__

#include <cstdint>
#include <string>
#include <vector>

namespace recorder
{

/**
 * 精简ELF32解析器：加载PT_LOAD段并支持按地址读取指令字
 */
class ElfImage
{
public:
    /**
     * 加载并解析ELF文件
     * @return 0成功，-1失败（错误信息填充到err）
     */
    int load(const std::string& path, std::string& err);

    /**
     * 读取addr处的4字节小端指令字
     * @return true: 读取成功
     */
    bool read_inst(uint32_t addr, uint32_t* inst) const;

private:
    std::vector<uint8_t> file_;
    struct segment
    {
        uint32_t addr;    // 索引地址(p_vaddr与p_paddr均建立索引)
        uint32_t offset;  // 文件内偏移
        uint32_t filesz;  // 文件内长度
    };
    std::vector<segment> segs_;
};

}  // namespace recorder

#endif
