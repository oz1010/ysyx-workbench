#***************************************************************************************
# Copyright (c) 2014-2022 Zihao Yu, Nanjing University
#
# NPC is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#**************************************************************************************/
WORK_DIR    = $(shell pwd)
VGEN_DIR    = $(WORK_DIR)/build/vgen
# VMOD_NAME	= ysyx_23060295
VMOD_NAME	= top
TVERILATOR  = verilator

TVSRCS-y += ./vsrc/test/core/top.v
# VDIRS-y									+= ./vsrc/core/common
# VDIRS-y									+= ./vsrc/device
# VDIRS-$(CONFIG_ISA_RISCV_MULTIPLE)		+= ./vsrc/core/multiple
# VDIRS-$(CONFIG_ISA_RISCV_SINGLE)		+= ./vsrc/core/single
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/amba
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/bitrev
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/flash
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/gpio
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/ps2
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/psram
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/psram/efabless
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/sdram
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/sdram/core_sdram_axi4
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/spi
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/uart16550
# VDIRS-y									+= $(NPC_HOME)/../ysyxSoC/perip/vga
# TVSRCS-y		+= $(shell find -L $(NPC_HOME)/../ysyxSoC/perip -name *.v)

TVCSR_CPPS   = $(shell find -L ./vsrc/test -name *.cpp)
TVSRCS-y		+= $(shell find -L $(VDIRS-y) -maxdepth 1 -name *.v)
TVSRCS-y     += $(TVCSR_CPPS)
TVSRCS       += $(addprefix $(WORK_DIR)/,$(TVSRCS-y))
INC_PATH    += $(VGEN_DIR)
INC_PATH    += $(VDIRS-y)
INC_PATH    += $(NPC_HOME)/../ysyxSoC/perip/uart16550/rtl
INC_PATH    += $(NPC_HOME)/../ysyxSoC/perip/spi/rtl
LDFLAGS     += -L$(VGEN_DIR) -lV$(VMOD_NAME) -lverilated -lreadline  -pthread -lpthread -latomic

# TRACE=1 make run -j , code define VM_TRACE_VCD
ifdef TRACE
TVERILATOR_CFLAGS += --trace
endif

# 多个目标会触发多次构建规则，这里选择其中一个即可
TVOBJS = $(VGEN_DIR)/libV$(VMOD_NAME).a
# VOBJS += $(VGEN_DIR)/V$(VMOD_NAME)_ALL.a $(VGEN_DIR)/libV$(VMOD_NAME).a $(VGEN_DIR)/libverilated.a
ifeq ($(TVSRCS),)
    $(error "verilator need *.v files to build")
endif
# # TVCXXFLAGS += $(shell llvm-config --cxxflags) -fPIE
# TVCXXFLAGS += -I/usr/lib/llvm-14/include -fno-exceptions -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -fPIE
# VLDFLAGS += $(shell llvm-config --libs)
# TVERILATOR_CFLAGS += -MMD --build -cc
# TVERILATOR_CFLAGS += -O3 --x-assign fast --x-initial fast --noassert
TVCXX_OPT += $(if $(CONFIG_CC_OPT),$(call remove_quote,$(CONFIG_CC_OPT)),-O0)
TVCXXFLAGS += $(if $(CONFIG_CC_DEBUG),-O0 -ggdb3,$(TVCXX_OPT))
TVCXXFLAGS += $(addprefix -I,$(INC_PATH))
TVCXXFLAGS += -DTOP_NAME="\"$(VMOD_NAME)\""
TVCXXFLAGS += -DTOP_FILE=V$(VMOD_NAME).h
TVCXXFLAGS += -D__GUEST_ISA__=$(GUEST_ISA)
TVERILATOR_CFLAGS += -cc --build -j --top-module $(VMOD_NAME) --Mdir $(VGEN_DIR)
TVERILATOR_CFLAGS += --timescale "1ns/1ns" --no-timing
TVERILATOR_CFLAGS += --autoflush
TVERILATOR_CFLAGS += -y $(WORK_DIR)/vsrc/core
