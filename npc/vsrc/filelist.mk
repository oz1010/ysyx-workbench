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
VMOD_NAME	= ysyxSoCFull
# VMOD_NAME	= top
VERILATOR   = verilator

# VSRCS-y += ./vsrc/ysyxSoC/build/ysyxSoCFull.v
VSRCS-y += ./vsrc/ysyxSoC/build/ysyxSoCFull_axi.v
VSRCS-y += ./vsrc/core/ysyx_23060295.v
VDIRS_CORE-y							+= ./vsrc/core/common
VDIRS_CORE-y							+= ./vsrc/device
VDIRS_CORE-$(CONFIG_ISA_RISCV_SINGLE)	+= ./vsrc/core/single
VDIRS_CORE-$(CONFIG_ISA_RISCV_MULTIPLE)	+= ./vsrc/core/multiple
VDIRS_CORE-$(CONFIG_ISA_RISCV_PIPELINE)	+= ./vsrc/core/pipeline
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/amba
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/bitrev
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/flash
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/gpio
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/ps2
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/psram
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/psram/efabless
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/sdram
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/sdram/core_sdram_axi4
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/spi
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/uart16550
VDIRS_YSYXSOC-y							+= ./vsrc/ysyxSoC/perip/vga
VDIRS-y 								+= $(VDIRS_CORE-y)
VDIRS-y 								+= $(VDIRS_YSYXSOC-y)
# VSRCS-y		+= $(shell find -L ./vsrc/ysyxSoC/perip -name *.v)

REF_STA_FILES							+= ./vsrc/yosys/$(VMOD_NAME).v
REF_STA_FILES							+= ./vsrc/core/ysyx_23060295.v
REF_STA_DIRS							+= $(VDIRS_CORE-y)
REF_STA_FILES							+= $(shell find -L $(REF_STA_DIRS) -maxdepth 1 -name *.v)
STA_FILES								?= $(addprefix $(WORK_DIR)/,$(REF_STA_FILES))
STA_INCLUDE_DIR							+= $(NPC_HOME)/include
STA_INCLUDE_DIR							+= $(NPC_HOME)/vsrc/core/common
STA_OUTPUT_DIR							?= $(WORK_DIR)/build/yosys
GEN_STA_FILE							?= $(STA_OUTPUT_DIR)/$(VMOD_NAME).v

VSRCS-y		+= $(shell find -L $(VDIRS-y) -maxdepth 1 -name *.v)
VSRCS-y     += $(shell find -L ./vsrc -name *.cpp)
VSRCS       += $(addprefix $(WORK_DIR)/,$(VSRCS-y))
INC_PATH    += $(VGEN_DIR)
INC_PATH    += $(VDIRS-y)
INC_PATH    += $(WORK_DIR)/./vsrc/ysyxSoC/perip/uart16550/rtl
INC_PATH    += $(WORK_DIR)/./vsrc/ysyxSoC/perip/spi/rtl
LDFLAGS     += -L$(VGEN_DIR) -lV$(VMOD_NAME) -lverilated -lreadline  -pthread -lpthread -latomic

# TRACE=1 make run -j , code define VM_TRACE_VCD
ifdef TRACE
VERILATOR_CFLAGS += --trace
endif

# 多个目标会触发多次构建规则，这里选择其中一个即可
# VOBJS += $(VGEN_DIR)/libV$(VMOD_NAME).a
# VOBJS += $(VGEN_DIR)/V$(VMOD_NAME)_ALL.a $(VGEN_DIR)/libV$(VMOD_NAME).a $(VGEN_DIR)/libverilated.a
ARCHIVES    += $(VGEN_DIR)/libV$(VMOD_NAME).a
ifeq ($(VSRCS),)
    $(error "verilator need *.v files to build")
endif
# # VCXXFLAGS += $(shell llvm-config --cxxflags) -fPIE
# VCXXFLAGS += -I/usr/lib/llvm-14/include -fno-exceptions -D_GNU_SOURCE -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS -fPIE
# VLDFLAGS += $(shell llvm-config --libs)
# VERILATOR_CFLAGS += -MMD --build -cc
# VERILATOR_CFLAGS += -O3 --x-assign fast --x-initial fast --noassert
VCXX_OPT += $(if $(CONFIG_CC_OPT),$(call remove_quote,$(CONFIG_CC_OPT)),-O0)
VCXXFLAGS += $(if $(CONFIG_CC_DEBUG),-O0 -ggdb3,$(VCXX_OPT))
VCXXFLAGS += $(addprefix -I,$(INC_PATH))
VCXXFLAGS += -DTOP_NAME="\"$(VMOD_NAME)\""
VCXXFLAGS += -DTOP_FILE=V$(VMOD_NAME).h
VCXXFLAGS += -D__GUEST_ISA__=$(GUEST_ISA)
VERILATOR_CFLAGS += -cc --build -j --top-module $(VMOD_NAME) --Mdir $(VGEN_DIR)
VERILATOR_CFLAGS += --timescale "1ns/1ns" --no-timing
VERILATOR_CFLAGS += --autoflush
VERILATOR_CFLAGS += -y $(WORK_DIR)/vsrc/core

VERILATOR_CFLAGS += $(INCLUDES)

$(VGEN_DIR)/libV$(VMOD_NAME).a: $(VSRCS)
	@echo + CV $<
	@mkdir -p $(dir $@)
	@$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -CFLAGS , $(VCXXFLAGS)) \
		$(addprefix -LDFLAGS , $(VLDFLAGS)) \
		$^

convert2v: $(GEN_STA_FILE)
$(GEN_STA_FILE): $(STA_FILES)
	@echo start convert2v
	@mkdir -p $(dir $@)
	$(VERILATOR) -Wall --Wno-fatal -sv --bbox-unsup --bbox-sys -E \
		--no-public-params --no-timing --no-assert \
		+1800-2005ext+ \
		$(addprefix +incdir+, $(STA_INCLUDE_DIR)) \
		+define+IN_YOSYS_STA \
		$^ > $@

# sta: $(GEN_STA_FILE)
sta: $(STA_FILES)
	@echo start yosys-sta
	make -C $(YOSYS_STA_HOME) sta \
		DESIGN=$(VMOD_NAME) SDC_FILE=$(NPC_HOME)/vsrc/yosys/$(VMOD_NAME).sdc \
		CLK_FREQ_MHZ=6000 CLK_PORT_NAME=clk OUTPUT_DIR=$(STA_OUTPUT_DIR) \
		VERILOG_INCLUDE_DIRS="$(STA_INCLUDE_DIR)" \
		RTL_FILES="$^"

.PHONY: sta convert2v
