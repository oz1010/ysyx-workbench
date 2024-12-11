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
VMOD_NAME	= top
VERILATOR   = verilator

VCSR_CPPS   = $(shell find -L vsrc -name *.cpp)
VCSR_VS     = $(shell find -L vsrc -name *.v)
VSRCS-y     += $(VCSR_VS) $(VCSR_CPPS)
VSRCS       += $(addprefix $(WORK_DIR)/,$(VSRCS-y))
INC_PATH    += $(VGEN_DIR)
LDFLAGS     += -L$(VGEN_DIR) -lV$(VMOD_NAME) -lverilated -lreadline  -pthread -lpthread -latomic

# 多个目标会触发多次构建规则，这里选择其中一个即可
VOBJS = $(VGEN_DIR)/libV$(VMOD_NAME).a
# VOBJS += $(VGEN_DIR)/V$(VMOD_NAME)_ALL.a $(VGEN_DIR)/libV$(VMOD_NAME).a $(VGEN_DIR)/libverilated.a
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
VCXXFLAGS += -DTOP_NAME="\"V$(VMOD_NAME)\""
VERILATOR_CFLAGS += -cc --build -j --top-module $(VMOD_NAME) --Mdir $(VGEN_DIR)
