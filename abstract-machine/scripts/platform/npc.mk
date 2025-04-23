AM_SRCS := platform/npc/trm.c \
           platform/npc/ioe/ioe.c \
           platform/npc/ioe/timer.c \
           platform/npc/ioe/input.c \
           platform/npc/ioe/gpu.c \
           platform/npc/ioe/audio.c \
           platform/npc/ioe/disk.c \
           platform/npc/mpe.c

CFLAGS    += -fdata-sections -ffunction-sections
LDFLAGS   += -T $(AM_HOME)/scripts/linker.ld \
             --defsym=_pmem_start=0x20000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections -e _start
NPCFLAGS += -l $(shell dirname $(IMAGE).elf)/npc-log.txt
# 默认NPC切换为批处理模式，查看函数sdb_mainloop实现
NPCFLAGS += -b

# Generate bin with flag
# BINARY_FLG	:= -S --set-section-flags .bss=alloc,contents -O binary
BINARY_FLG	:= -O binary
BINARY_FLG	+= -S
BINARY_FLG	+= -j .bin_header -j .text -j .data -j .rodata -j .init -j .fini -j .vectors -j .isr_vector

CFLAGS += -DMAINARGS=\"$(mainargs)\"
CFLAGS += -I$(AM_HOME)/am/src/platform/npc/include
.PHONY: $(AM_HOME)/am/src/platform/npc/trm.c

image: $(IMAGE).elf
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) $(BINARY_FLG) $(IMAGE).elf $(IMAGE).bin

run: image
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) run ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin

gdb: image
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) gdb ARGS="$(NPCFLAGS)" IMG=$(IMAGE).bin
