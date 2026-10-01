include $(AM_HOME)/scripts/isa/riscv.mk
include $(AM_HOME)/scripts/platform/nemu.mk

ifeq ($(shell $(CC) -dumpfullversion),13.3.0)
RISCV_MARCH	:= rv32im_zicsr_zifencei
else
RISCV_MARCH	:= rv32im_zicsr
endif

CFLAGS  += -DISA_H=\"riscv/riscv.h\"
COMMON_CFLAGS += -march=$(RISCV_MARCH) -mabi=ilp32   # overwrite
LDFLAGS       += -melf32lriscv                     # overwrite

AM_SRCS += riscv/nemu/start.S \
           riscv/nemu/cte.c \
           riscv/nemu/trap.S \
           riscv/nemu/vme.c
