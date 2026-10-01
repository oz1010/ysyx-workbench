include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/npc.mk

ifeq ($(shell $(CC) -dumpfullversion),13.3.0)
RISCV_MARCH	:= rv32e_zicsr_zifencei
else
RISCV_MARCH	:= rv32e_zicsr
endif

CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS += -march=$(RISCV_MARCH) -mabi=ilp32e  # overwrite
LDFLAGS       += -melf32lriscv                    # overwrite

# 当用户包含了start.S，SKIP_AM_START为true，则不包含默认start.S
ifeq ($(SKIP_AM_START),false)
    AM_SRCS += riscv/npc/start.S
endif
AM_SRCS += riscv/npc/cte.c \
           riscv/npc/trap.S \
           riscv/npc/vme.c
# 公共乘除法库头文件
AM_SRCS += riscv/npc/libgcc/div.S \
           riscv/npc/libgcc/muldi3.S \
           riscv/npc/libgcc/multi3.c \
           riscv/npc/libgcc/ashldi3.c \
           riscv/npc/libgcc/unused.c

