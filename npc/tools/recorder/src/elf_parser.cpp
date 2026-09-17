#include "elf_parser.h"

#include <cstring>
#include <fstream>

namespace recorder
{

namespace
{

// ELF32 文件头字段偏移
constexpr size_t EI_CLASS      = 4;
constexpr size_t EI_DATA       = 5;
constexpr size_t EHDR_SIZE     = 52;
constexpr size_t E_PHOFF       = 28;
constexpr size_t E_PHENTSIZE   = 42;
constexpr size_t E_PHNUM       = 44;

// ELF32 程序头字段偏移
constexpr size_t PHDR_SIZE   = 32;
constexpr size_t P_TYPE      = 0;
constexpr size_t P_OFFSET    = 4;
constexpr size_t P_VADDR     = 8;
constexpr size_t P_PADDR     = 12;
constexpr size_t P_FILESZ    = 16;

constexpr uint8_t ELFCLASS32 = 1;
constexpr uint8_t ELFDATA2LSB = 1;
constexpr uint32_t PT_LOAD   = 1;

uint16_t rd16(const uint8_t* p)
{
    return static_cast<uint16_t>(p[0]) | (static_cast<uint16_t>(p[1]) << 8);
}

uint32_t rd32(const uint8_t* p)
{
    return static_cast<uint32_t>(p[0]) | (static_cast<uint32_t>(p[1]) << 8) |
           (static_cast<uint32_t>(p[2]) << 16) | (static_cast<uint32_t>(p[3]) << 24);
}

}  // namespace

int ElfImage::load(const std::string& path, std::string& err)
{
    std::ifstream ifs(path, std::ios::binary | std::ios::ate);
    if (!ifs)
    {
        err = "无法打开ELF文件: " + path;
        return -1;
    }
    std::streamsize size = ifs.tellg();
    if (size < static_cast<std::streamsize>(EHDR_SIZE))
    {
        err = "ELF文件过小: " + path;
        return -1;
    }
    file_.resize(static_cast<size_t>(size));
    ifs.seekg(0, std::ios::beg);
    ifs.read(reinterpret_cast<char*>(file_.data()), size);
    if (!ifs)
    {
        err = "ELF文件读取失败: " + path;
        return -1;
    }

    const uint8_t* ehdr = file_.data();
    if (ehdr[0] != 0x7F || ehdr[1] != 'E' || ehdr[2] != 'L' || ehdr[3] != 'F')
    {
        err = "不是ELF文件: " + path;
        return -1;
    }
    if (ehdr[EI_CLASS] != ELFCLASS32)
    {
        err = "仅支持32位ELF: " + path;
        return -1;
    }
    if (ehdr[EI_DATA] != ELFDATA2LSB)
    {
        err = "仅支持小端ELF: " + path;
        return -1;
    }

    uint32_t phoff     = rd32(ehdr + E_PHOFF);
    uint16_t phentsize = rd16(ehdr + E_PHENTSIZE);
    uint16_t phnum     = rd16(ehdr + E_PHNUM);
    if (phentsize < PHDR_SIZE || phoff + static_cast<uint64_t>(phentsize) * phnum > file_.size())
    {
        err = "ELF程序头无效: " + path;
        return -1;
    }

    segs_.clear();
    for (uint16_t i = 0; i < phnum; ++i)
    {
        const uint8_t* phdr = file_.data() + phoff + i * phentsize;
        if (rd32(phdr + P_TYPE) != PT_LOAD) continue;
        uint32_t vaddr   = rd32(phdr + P_VADDR);
        uint32_t paddr   = rd32(phdr + P_PADDR);
        uint32_t offset  = rd32(phdr + P_OFFSET);
        uint32_t filesz  = rd32(phdr + P_FILESZ);
        if (filesz == 0) continue;
        if (static_cast<uint64_t>(offset) + filesz > file_.size())
        {
            err = "ELF段超出文件范围: " + path;
            return -1;
        }
        // 执行地址与加载地址不同时(如带bootloader的镜像)，两者都建立索引
        segs_.push_back({vaddr, offset, filesz});
        if (paddr != 0 && paddr != vaddr) segs_.push_back({paddr, offset, filesz});
    }
    if (segs_.empty())
    {
        err = "ELF中没有PT_LOAD段: " + path;
        return -1;
    }
    return 0;
}

bool ElfImage::read_inst(uint32_t addr, uint32_t* inst) const
{
    for (const auto& seg : segs_)
    {
        if (addr >= seg.addr && static_cast<uint64_t>(addr) + 4 <=
                                    static_cast<uint64_t>(seg.addr) + seg.filesz)
        {
            const uint8_t* p = file_.data() + seg.offset + (addr - seg.addr);
            *inst = rd32(p);
            return true;
        }
    }
    return false;
}

}  // namespace recorder
