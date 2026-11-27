AM_SRCS := platform/npc/trm.c \
           platform/npc/ioe/ioe.c \
           platform/npc/ioe/timer.c \
           platform/npc/ioe/input.c \
           platform/npc/ioe/gpu.c \
           platform/npc/ioe/audio.c \
           platform/npc/ioe/disk.c \
           platform/npc/mpe.c

LINKER_FILE ?= ${AM_HOME}/scripts/platform/npc/linker_psram.ld
NPC_RUN_TARGET ?= sim-verilator

CFLAGS    += -fdata-sections -ffunction-sections
LDFLAGS   += -T $(LINKER_FILE)
            #  --defsym=_pmem_start=0x20000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections
# 默认NPC切换为批处理模式，查看函数sdb_mainloop实现

# Generate bin with flag
# BINARY_FLG	:= -S --set-section-flags .bss=alloc,contents -O binary
BINARY_FLG	:= -O binary
BINARY_FLG	+= -S
# # 指定contents属性会使.bss保留内容0，造成生成文件过大。适合加载bin文件后不初始化.bss的场景
# BINARY_FLG	+= --set-section-flags .bss=alloc,contents
# # 只复制特定段到bin中
# BINARY_FLG     += -j .data.extra -j .bss.extra -j .bootloader -j .bin_header -j .text -j .data -j .rodata -j .init -j .fini -j .vectors -j .isr_vector
RESULT_DIR := $(shell dirname $(IMAGE).elf)

CFLAGS += -I$(AM_HOME)/am/src/platform/npc/include

MAINARGS_MAX_LEN = 64
MAINARGS_PLACEHOLDER = The insert-arg rule in Makefile will insert mainargs here.
CFLAGS += -DMAINARGS_MAX_LEN=$(MAINARGS_MAX_LEN) -DMAINARGS_PLACEHOLDER=\""$(MAINARGS_PLACEHOLDER)"\"

insert-arg: image
	@python3 $(AM_HOME)/tools/insert-arg.py $(IMAGE).bin $(MAINARGS_MAX_LEN) "$(MAINARGS_PLACEHOLDER)" "$(mainargs)"

$(IMAGE).elf: $(LINKER_FILE)

image: $(IMAGE).elf
	@$(OBJDUMP) -d $(IMAGE).elf > $(IMAGE).txt
	@echo + OBJCOPY "->" $(IMAGE_REL).bin
	@$(OBJCOPY) $(BINARY_FLG) $(IMAGE).elf $(IMAGE).bin

run: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) RESULT_DIR=$(RESULT_DIR) $(NPC_RUN_TARGET) IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NPC_HOME) ISA=$(ISA) RESULT_DIR=$(RESULT_DIR) gdb IMG=$(IMAGE).bin

.PHONY: insert-arg
