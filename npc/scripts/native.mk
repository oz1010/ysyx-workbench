#***************************************************************************************
# Copyright (c) 2014-2022 Zihao Yu, Nanjing University
#
# NEMU is licensed under Mulan PSL v2.
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

-include $(NPC_HOME)/../Makefile
include $(NPC_HOME)/scripts/build.mk

include $(NPC_HOME)/tools/difftest.mk

compile_git:
	$(call git_commit, "compile NPC")
$(BINARY):: compile_git

# Some convenient rules

override ARGS ?= --log=$(BUILD_DIR)/npc-log.txt
override ARGS += $(ARGS_DIFF)
override ARGS += -b

ifeq ($(CONFIG_PERF_MONITOR), y)
ANALYZER += analyzer
ifeq ($(CONFIG_PERF_MONITOR_BIN_DATA), y)
override PERF_FILE ?= $(BUILD_DIR)/npc-monitor.bin
# PERF_MONITOR_SH=$(NPC_HOME)/scripts/monitor_analyzer_bin.py $(PERF_FILE)
PERF_MONITOR_SH=$(NPC_HOME)/tools/monitor_analyzer/build/mon_analyzer $(PERF_FILE)
else
override PERF_FILE ?= $(BUILD_DIR)/npc-monitor.txt
PERF_MONITOR_SH=$(NPC_HOME)/scripts/monitor_analyzer.py $(PERF_FILE)
endif
endif
override ARGS += --perf=$(PERF_FILE)

# Command to execute NPC
NPC_EXEC := $(BINARY) $(ARGS) $(IMG)

run-env: $(BINARY) $(IMG) $(DIFF_REF_SO) $(ANALYZER)

run: run-env
	$(call git_commit, "run NPC")
	$(NPC_EXEC)
	$(PERF_MONITOR_SH)

gdb: run-env
	$(call git_commit, "gdb NNPC")
	gdb -s $(BINARY) --args $(NPC_EXEC)

test:
	@make clean -C test/vsrc
	@make test -C test/vsrc

analyzer:
	@make -C tools/monitor_analyzer

clean-tools = $(dir $(shell find ./tools -maxdepth 2 -mindepth 2 -name "Makefile"))
$(clean-tools):
	$(MAKE) -s -C $@ clean
clean-tools: $(clean-tools)
clean-all: clean distclean clean-tools

.PHONY: run gdb run-env clean-tools clean-all $(clean-tools) test analyzer
