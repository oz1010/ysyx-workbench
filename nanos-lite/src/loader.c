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

static uintptr_t loader(PCB *pcb, const char *filename)
{
    uint8_t *elf_addr = proc_addr;
    Elf_Ehdr *elf_header = (Elf_Ehdr *)elf_addr;
    elf_addr += ELF_HEADER_SIZE;
    int ret = 0;

    if (ELF_HEADER_SIZE != ramdisk_read(elf_header, 0, ELF_HEADER_SIZE))
    {
        FATAL("Loader elf failed");
        return nullptr;
    }

    /* 检查 ELF magic bytes */
    uint32_t elf_ident[2] = {0x464c457f, 0x10101};
    if ((ret=memcmp(elf_header->e_ident, elf_ident, sizeof(elf_ident))) != 0)
    {
        ERROR("Not an ELF file - it has the wrong magic bytes at the start");
        return nullptr;
    }

    /**
     * ref. readelf -l build/ramdisk.img
     */
    // DEBUG("%#12x %% \"%c\"", elf_addr, 'T');
    DEBUG("Elf file type is EXEC (Executable file)");
    DEBUG("Entry point %p", elf_header->e_entry);
    DEBUG("There are %d program headers, starting at offset %d", elf_header->e_phnum, ELF_HEADER_SIZE);

    TODO();
    return nullptr;
}

void naive_uload(PCB *pcb, const char *filename)
{
    uintptr_t entry = loader(pcb, filename);
    assert(entry!=nullptr);
    Log("Jump to entry = %p", entry);
    ((void (*)())entry)();
}
