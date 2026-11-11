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
THREADS ?= $(shell nproc)

# Chisel gen directory
CHISEL_GEN_DIR_NAME = $(patsubst "%",%,$(CONFIG_CHISEL_DIR_NAME))
CHISEL_GEN_OUT = build
CHISEL_GEN_MODE = normal
ifneq ($(filter sta sta-area,$(MAKECMDGOALS)),)
	CHISEL_GEN_OUT = build-sta
	CHISEL_GEN_MODE = synthesis
endif
ifeq ($(IVSIM),1)
	CHISEL_GEN_OUT = build-sta
	CHISEL_GEN_MODE = synthesis
endif
CHISEL_BUILD = ./vsrc/chisel-gen/$(CHISEL_GEN_OUT)/$(CHISEL_GEN_DIR_NAME)

# VSRCS-y += ./vsrc/ysyxSoC/build/ysyxSoCFull.v
VSRCS-y += ./vsrc/ysyxSoC/build/ysyxSoCFull_axi.v
VSRCS-y += ./vsrc/core/ysyx_23060295.v
VDIRS_CORE-y							+= ./vsrc/core/common
VDIRS_CORE-y							+= ./vsrc/device
VDIRS_CORE-$(CONFIG_ISA_RISCV_SINGLE)	+= ./vsrc/core/single
VDIRS_CORE-$(CONFIG_ISA_RISCV_MULTIPLE)	+= ./vsrc/core/multiple
VDIRS_CORE-$(CONFIG_ISA_RISCV_PIPELINE)	+= ./vsrc/core/pipeline
VDIRS_CORE-$(CONFIG_ISA_RISCV_PIPELINE_CHISEL)	+= $(CHISEL_BUILD)
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
# REF_STA_FILES							+= $(shell find -L $(REF_STA_DIRS) -maxdepth 1 -name *.v)
REF_STA_FILES							+= $(foreach d, $(REF_STA_DIRS), \
												$(wildcard $(d)/*.v) \
												$(wildcard $(d)/*.sv) \
											)
STA_SRC_FILES							?= $(addprefix $(WORK_DIR)/,$(REF_STA_FILES))
STA_INCLUDE_DIR							+= $(NPC_HOME)/include
STA_INCLUDE_DIR							+= $(NPC_HOME)/vsrc/core/common
STA_OUTPUT_DIR							?= $(WORK_DIR)/build/yosys
GEN_STA_FILE							?= $(STA_OUTPUT_DIR)/$(VMOD_NAME).v
GEN_STUDEN_FILE							?= $(STA_OUTPUT_DIR)/ysyx_23060295.v
# 最终综合目标分析文件，也可以是一个列表
# STA_TARGET_FILE							?= $(STA_SRC_FILES)
# STA_TARGET_FILE							?= $(GEN_STA_FILE)
STA_TARGET_FILE							?= $(GEN_STUDEN_FILE)
STA_TARGET_TOP							?= ysyx_23060295

# iverilog gen directory
IV_GEN_DIR								= $(WORK_DIR)/build/iverilog
IV_TOP_NAME 							= iv_top
IV_TARGET								= $(IV_GEN_DIR)/$(IV_TOP_NAME).vvp
IV_PS2_INPUT							= $(IV_GEN_DIR)/iv_ps2_input.vpi
IV_PS2_INPUT_SRC						= $(WORK_DIR)/vsrc/iverilog/iv_ps2_input.c
IV_DIRS-y								+= ./vsrc/iverilog
IV_DIRS-y								+= $(VDIRS_CORE-y)
IV_VSRCS-y 								+= $(foreach d, $(IV_DIRS-y), \
												$(wildcard $(d)/*.v) \
												$(wildcard $(d)/*.sv) \
											)
IV_INC_PATH	+= $(WORK_DIR)/include
IV_INC_PATH	+= $(VDIRS_CORE-y)

# VSRCS-y		+= $(shell find -L $(VDIRS-y) -maxdepth 1 -name *.v)
VSRCS-y		+= $(foreach d, $(VDIRS-y), \
					$(wildcard $(d)/*.v) \
					$(wildcard $(d)/*.sv) \
				)
VSRCS-y     += $(shell find -L ./vsrc -name *.cpp)
VSRCS       += $(addprefix $(WORK_DIR)/,$(VSRCS-y))
INC_PATH    += $(VGEN_DIR)
INC_PATH    += $(VDIRS-y)
INC_PATH    += $(WORK_DIR)/./vsrc/ysyxSoC/perip/uart16550/rtl
INC_PATH    += $(WORK_DIR)/./vsrc/ysyxSoC/perip/spi/rtl
LDFLAGS     += -L$(VGEN_DIR) -lV$(VMOD_NAME) -lverilated -lreadline  -pthread -lpthread -latomic

# TRACE=1 make run -j, enable Verilator waveform tracing (FST preferred)
ifeq ($(TRACE),1)
NPC_ARGS += --trace_hw=true
endif

VERILATOR_CFLAGS += --trace
# 自动开启VM_TRACE_FST
VERILATOR_CFLAGS += --trace-fst
# FST tracing uses zlib for compression and gzip-backed sections.
# Keep this in LIBS so -lz is placed after static Verilator archives.
LIBS += -lz

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
VERILATOR_CFLAGS += -MMD -O3 --x-assign fast --x-initial fast --noassert
VERILATOR_CFLAGS += -cc --build -j --top-module $(VMOD_NAME) --Mdir $(VGEN_DIR)
VERILATOR_CFLAGS += --timescale "1ns/1ns" --no-timing
VERILATOR_CFLAGS += --autoflush
VERILATOR_CFLAGS += -y $(WORK_DIR)/vsrc/core
VERILATOR_CFLAGS += -Wno-UNOPTFLAT # 忽略仿真无法优化的组合逻辑环路
VERILATOR_CFLAGS += -Wno-PINMISSING # 忽略未连接的引脚
# # 使用多线程运行仿真
# VERILATOR_CFLAGS += --threads $(THREADS)

VERILATOR_CFLAGS += $(INCLUDES)

ifeq ($(CONFIG_ISA_RISCV_PIPELINE_CHISEL), y)
compile_chisel:
	@echo "\033[42m--- Compile Chisel in $(CHISEL_GEN_DIR_NAME) ---\033[0m"
	@make verilog \
		GEN_DIR_NAME=$(CHISEL_GEN_DIR_NAME) \
		GEN_OUT=$(CHISEL_GEN_OUT) \
		GEN_MODE=$(CHISEL_GEN_MODE) \
		-C vsrc/chisel-gen
else
compile_chisel:
	@echo "\033[42m--- Skip Compile Chisel ---\033[0m"
endif

ARCHIVES_DEPENDS = $(VSRCS) $(WORK_DIR)/include/generated/autoconf.vh
$(VGEN_DIR)/libV$(VMOD_NAME).a: $(ARCHIVES_DEPENDS) compile_chisel
	@echo "\033[42m--- Generate $@ ---\033[0m"
	@mkdir -p $(dir $@)
	@$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -CFLAGS , $(VCXXFLAGS)) \
		$(addprefix -LDFLAGS , $(VLDFLAGS)) \
		$(ARCHIVES_DEPENDS)

$(IV_TARGET) : $(IV_VSRCS-y) $(WORK_DIR)/include/generated/autoconf.vh $(WORK_DIR)/vsrc/core/common/riscv32e_defines.v compile_chisel
	@mkdir -p $(dir $@)
	@iverilog -g2012 -DIN_YOSYS_STA -s $(IV_TOP_NAME) $(addprefix -I,$(IV_INC_PATH)) -o $@ $(IV_VSRCS-y)

$(IV_PS2_INPUT): $(IV_PS2_INPUT_SRC)
	@mkdir -p $(dir $@)
	@cd $(IV_GEN_DIR) && iverilog-vpi --name=iv_ps2_input $(IV_PS2_INPUT_SRC)

# verilator支持的版本：
#          +1364-1995ext+<ext>        Use Verilog 1995 with file extension <ext>
#          +1364-2001ext+<ext>        Use Verilog 2001 with file extension <ext>
#          +1364-2005ext+<ext>        Use Verilog 2005 with file extension <ext>
#          +1800-2005ext+<ext>        Use SystemVerilog 2005 with file extension <ext>
#          +1800-2009ext+<ext>        Use SystemVerilog 2009 with file extension <ext>
#          +1800-2012ext+<ext>        Use SystemVerilog 2012 with file extension <ext>
#          +1800-2017ext+<ext>        Use SystemVerilog 2017 with file extension <ext>
#          +1800-2023ext+<ext>        Use SystemVerilog 2023 with file extension <ext>
# 但yosys前端目前最高为Verilog-2005，原版可以支持到sv-2023
convert2v: $(STA_TARGET_FILE)
$(GEN_STA_FILE): $(STA_SRC_FILES) compile_chisel
	@echo convert to $@
	@mkdir -p $(dir $@)
	@$(VERILATOR) -Wall --Wno-fatal -sv --bbox-unsup --bbox-sys -E \
		--no-public-params --no-timing --no-assert \
		+1800-2005ext+ \
		$(addprefix +incdir+, $(STA_INCLUDE_DIR)) \
		+define+IN_YOSYS_STA \
		$(STA_SRC_FILES) > $@
$(STA_TARGET_FILE): $(GEN_STA_FILE)
	@echo convert to $@
	@mkdir -p $(dir $@)
	@python3 $(WORK_DIR)/scripts/rename_ysyx_verilog.py

sta: $(STA_TARGET_FILE) compile_chisel
	@echo start yosys-sta
	@make -C $(YOSYS_STA_HOME) sta \
		DESIGN=$(STA_TARGET_TOP) SDC_FILE=$(NPC_HOME)/vsrc/yosys/$(VMOD_NAME).sdc \
		CLK_FREQ_MHZ=6000 CLK_PORT_NAME=clock O=$(STA_OUTPUT_DIR) \
		OUTPUT_DIR=$(STA_OUTPUT_DIR) \
		VERILOG_INCLUDE_DIRS="$(STA_INCLUDE_DIR)" \
		RTL_FILES="$(STA_TARGET_FILE)"

# 层级化面积统计: 不 flatten, stat 按模块分别报告面积, 用于定位流水线各模块占比
# YOSYS_PDK		?= nangate45
# YOSYS_STA_LIB	?= $(YOSYS_STA_HOME)/pdk/$(YOSYS_PDK)/lib/Nangate45_typ.lib
YOSYS_PDK		?= icsprout55
YOSYS_STA_LIB	?= $(YOSYS_STA_HOME)/pdk/icsprout55/IP/STD_cell/ics55_LLSC_H7C_V1p10C100/ics55_LLSC_H7CL/liberty/ics55_LLSC_H7CL_typ_tt_1p2_25_nldm.lib

sta-area: $(STA_TARGET_FILE) | $(WORK_DIR)/scripts/yosys_area_hier.tcl compile_chisel
	@echo start yosys-area-hier
	@mkdir -p $(STA_OUTPUT_DIR)/area-hier
	@yosys -l $(STA_OUTPUT_DIR)/area-hier/yosys.log -p \
		"tcl $(WORK_DIR)/scripts/yosys_area_hier.tcl $(STA_TARGET_TOP) $(YOSYS_STA_LIB) \
			\"$(abspath $(STA_TARGET_FILE))\" $(STA_OUTPUT_DIR)/area-hier/stat_hier.txt \
			\"$(abspath $(STA_INCLUDE_DIR))\""
	@python3 $(WORK_DIR)/scripts/area_hier_report.py \
		$(STA_OUTPUT_DIR)/area-hier/stat_hier.txt \
		--csv $(STA_OUTPUT_DIR)/area-hier/area_hier.csv

.PHONY: sta sta-area convert2v
