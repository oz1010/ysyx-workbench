#include <proc.h>
#include <elf.h>

#ifdef __LP64__
#define Elf_Ehdr Elf64_Ehdr
#define Elf_Phdr Elf64_Phdr
#else
#define Elf_Ehdr Elf32_Ehdr
#define Elf_Phdr Elf32_Phdr
#endif

uint8_t *proc_addr = (uint8_t *)0x83000000;
#define ELF_HEADER_SIZE 52

static const char *elf_type_to_str(Elf64_Half e_type)
{
    const char *str = "UNKNOWN";
    switch (e_type)
    {
    case ET_NONE:
        str = "NONE (No file type)";
        break;
    case ET_REL:
        str = "REL (Relocatable file)";
        break;
    case ET_EXEC:
        str = "EXEC (Executable file)";
        break;
    case ET_DYN:
        str = "DYN (Shared object file)";
        break;
    case ET_CORE:
        str = "CORE (Core file)";
        break;
    case ET_NUM:
        str = "NUM (Number of defined types)";
        break;
    case ET_LOOS:
        str = "LOOS (OS-specific range start)";
        break;
    case ET_HIOS:
        str = "HIOS (OS-specific range end)";
        break;
    case ET_LOPROC:
        str = "LOPROC (Processor-specific range start)";
        break;
    case ET_HIPROC:
        str = "HIPROC (Processor-specific range end)";
        break;
    default:
        break;
    }

    return str;
}

/*
ELF文件加载器
$ readelf -l build/dummy-riscv32e

Elf file type is EXEC (Executable file)
Entry point 0x830003f4
There are 4 program headers, starting at offset 52

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  RISCV_ATTRIBUT 0x005c9b 0x00000000 0x00000000 0x0001f 0x00000 R   0x1
  LOAD           0x000000 0x83000000 0x83000000 0x053d4 0x053d4 R E 0x1000
  LOAD           0x0053d8 0x830063d8 0x830063d8 0x00898 0x008d4 RW  0x1000
  GNU_STACK      0x000000 0x00000000 0x00000000 0x00000 0x00000 RW  0x10
*/
static uintptr_t loader(PCB *pcb, const char *filename)
{
    uint8_t *elf_addr = proc_addr;
    Elf_Ehdr *elf_header = (Elf_Ehdr *)elf_addr;
    int ret = 0;

    if (ELF_HEADER_SIZE != ramdisk_read(elf_header, 0, ELF_HEADER_SIZE))
    {
        ERROR("Loader elf failed");
        return nullptr;
    }

    /* 检查 ELF magic bytes */
    uint8_t elf_ident[4] = {ELFMAG};
    if ((ret = memcmp(elf_header->e_ident, elf_ident, sizeof(elf_ident))) != 0)
    {
        ERROR("Not an ELF file - it has the wrong magic bytes at the start");
        return nullptr;
    }
    // DEBUG("%#12x %% \"%c\"", elf_addr, 'T');
    // DEBUG("e_machine %d", (elf_header->e_machine)); // EM_RISCV
    DEBUG("Elf file type is %s", elf_type_to_str(elf_header->e_type));
    DEBUG("Entry point %p", elf_header->e_entry);
    DEBUG("There are %d program headers, starting at offset %d", elf_header->e_phnum, elf_header->e_phoff);

    /* 解析Program Headers */
    elf_addr += elf_header->e_phoff;
    Elf_Phdr *elf_prog_headers = (Elf_Phdr *)elf_addr;
    ramdisk_read(elf_prog_headers, ELF_HEADER_SIZE, sizeof(Elf_Phdr) * elf_header->e_phnum);
    for (Elf32_Half idx = 0; idx < elf_header->e_phnum; ++idx)
    {
        Elf_Phdr *h = &elf_prog_headers[idx];
        DEBUG("%#x %#x %#x %#x %#x %#x %#x %#x", h->p_type, h->p_offset, h->p_vaddr, h->p_paddr, h->p_filesz, h->p_memsz, h->p_flags, h->p_align);
    }

    TODO();
    return nullptr;
}

void naive_uload(PCB *pcb, const char *filename)
{
    uintptr_t entry = loader(pcb, filename);
    assert(entry != nullptr);
    Log("Jump to entry = %p", entry);
    ((void (*)())entry)();
}
