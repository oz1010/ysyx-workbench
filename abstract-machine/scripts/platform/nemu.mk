AM_SRCS := platform/nemu/trm.c \
           platform/nemu/ioe/ioe.c \
           platform/nemu/ioe/timer.c \
           platform/nemu/ioe/input.c \
           platform/nemu/ioe/gpu.c \
           platform/nemu/ioe/audio.c \
           platform/nemu/ioe/disk.c \
           platform/nemu/mpe.c

LINKER_FILE ?= $(AM_HOME)/scripts/platform/nemu/linker_flash_sram.ld

CFLAGS    += -fdata-sections -ffunction-sections
LDFLAGS   += -T $(LINKER_FILE)
            #  --defsym=_pmem_start=0x20000000 --defsym=_entry_offset=0x0
LDFLAGS   += --gc-sections
NEMUFLAGS += -l $(shell dirname $(IMAGE).elf)/nemu-log.txt
# 默认NEMU切换为批处理模式，查看函数sdb_mainloop实现
NEMUFLAGS += -b

# Generate bin with flag
# BINARY_FLG	:= -S --set-section-flags .bss=alloc,contents -O binary
BINARY_FLG	:= -O binary
BINARY_FLG	+= -S
# # 指定contents属性会使.bss保留内容0，造成生成文件过大。适合加载bin文件后不初始化.bss的场景
# BINARY_FLG	+= --set-section-flags .bss=alloc,contents
# # 只复制特定段到bin中
# BINARY_FLG     += -j .data.extra -j .bss.extra -j .bootloader -j .bin_header -j .text -j .data -j .rodata -j .init -j .fini -j .vectors -j .isr_vector

CFLAGS += -I$(AM_HOME)/am/src/platform/nemu/include

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
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) run ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin

gdb: insert-arg
	$(MAKE) -C $(NEMU_HOME) ISA=$(ISA) gdb ARGS="$(NEMUFLAGS)" IMG=$(IMAGE).bin

.PHONY: insert-arg
