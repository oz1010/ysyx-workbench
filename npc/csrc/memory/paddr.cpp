
#include <stdint.h>
#include "memory/host.h"
#include "memory/paddr.h"
#include "common.h"
#include "device/mmio.h"
#include "cpu/cpu-exec.h"

uint8_t raw_memory[CONFIG_MSIZE] = {0};
char def_img_file[] = "npc/build/test/addi/case.bin";
char *cfg_img_file = NULL;

uint8_t* guest_to_host(paddr_t paddr) { return raw_memory + paddr - CONFIG_MBASE; }
paddr_t host_to_guest(uint8_t *haddr) { return haddr - raw_memory + CONFIG_MBASE; }

static word_t pmem_read(paddr_t addr, int len) {
  word_t ret = host_read(guest_to_host(addr), len);
  return ret;
}

static void pmem_write(paddr_t addr, int len, word_t data) {
  host_write(guest_to_host(addr), len, data);
}

static void out_of_bound(paddr_t addr) {
  panic("address = " FMT_PADDR " is out of bound of pmem [" FMT_PADDR ", " FMT_PADDR "] at pc = " FMT_WORD,
      addr, PMEM_LEFT, PMEM_RIGHT, cpu.pc);
}

void load_memory(const char* fpath)
{
	char file_path[1024] = {0};

	if (fpath[0]!='/')
	{
		const char* npc_home = getenv("NPC_HOME");
		Assert(npc_home, "Miss set NPC_HOME");
		strcat(&file_path[strlen(file_path)], npc_home);
		strcat(&file_path[strlen(file_path)], "/../");
		strcat(&file_path[strlen(file_path)], fpath);
	}
	else
	{
		strcat(&file_path[strlen(file_path)], fpath);
	}

	LOG_INFO("Load memory from file %s", file_path);
	size_t membytes = CONFIG_MSIZE*sizeof(raw_memory[0]);
	unsigned char* pmemstart = (unsigned char*)&raw_memory[0];
	unsigned char* pmemend = pmemstart + membytes;
	FILE* fd = fopen(file_path, "rb");
	Assert(fd, "open file:%s failed", file_path);

	size_t readsize = fread(pmemstart, 1, membytes, fd);
	LOG_INFO("Load memory from file total size %lu", readsize);
}

void init_memory()
{
    IFDEF(CONFIG_MEM_RANDOM, memset(pmem, rand(), CONFIG_MSIZE));
    LOG_INFO("physical memory area [" FMT_PADDR ", " FMT_PADDR "]", PMEM_LEFT, PMEM_RIGHT);

    load_memory(cfg_img_file ? cfg_img_file : def_img_file);
}

int read_memory(paddr_t addr, int len, void *data)
{
    const uint32_t idx = addr - CONFIG_MBASE;
	
	if (idx>(ARRAY_SIZE(raw_memory)-len)) {
		LOG_ERROR("addr:%#.8x is out of range", addr);
		return -1;
	}

    memcpy(data, &raw_memory[idx], len);
    return 0;
}

int write_memory(paddr_t addr, int len, void *data)
{
    const uint32_t idx = addr - CONFIG_MBASE;
	
	if (addr>(ARRAY_SIZE(raw_memory)-len)) {
		LOG_ERROR("addr:%#.8x is out of range", addr);
		return -1;
	}

    memcpy(&raw_memory[idx], data, len);
    return 0;
}

word_t paddr_read(paddr_t addr, int len) {
	if (likely(in_pmem(addr))) return pmem_read(addr, len);
	IFDEF(CONFIG_DEVICE, return mmio_read(addr, len));
	out_of_bound(addr);
	return 0;
}

void paddr_write(paddr_t addr, int len, word_t data) {
  if (likely(in_pmem(addr))) { pmem_write(addr, len, data); return; }
  IFDEF(CONFIG_DEVICE, mmio_write(addr, len, data); return);
  out_of_bound(addr);
}
