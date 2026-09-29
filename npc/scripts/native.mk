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
RESULT_DIR ?= $(BUILD_DIR)
override ARGS ?= --output=$(RESULT_DIR) --log=npc-log.txt
override ARGS += $(ARGS_DIFF)
override ARGS += -b
override ARGS += $(NPC_ARGS)

ifeq ($(CONFIG_PERF_MONITOR), y)
ANALYZER += analyzer
RECORDER += recorder
ifeq ($(CONFIG_PERF_MONITOR_BIN_DATA), y)
override PERF_NAME ?= npc-monitor.bin
PERF_MONITOR_SH=$(NPC_HOME)/tools/monitor_analyzer/build/mon_analyzer $(RESULT_DIR)/$(PERF_NAME)
else
override PERF_NAME ?= npc-monitor.txt
PERF_MONITOR_SH=$(NPC_HOME)/scripts/monitor_analyzer.py $(RESULT_DIR)/$(PERF_NAME)
endif
endif
override ARGS += --perf=$(PERF_NAME)

# Command to execute NPC
NPC_EXEC := $(BINARY) $(ARGS) $(IMG)

run-env: $(BINARY) $(IMG) $(DIFF_REF_SO) $(ANALYZER) $(RECORDER)

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

branchsim:
	@make -C tools/branchsim

recorder:
	@make -C tools/recorder

cachesim:
	@make -C tools/cachesim

run_cachesim: cachesim
	$(NPC_HOME)/tools/cachesim/build/cachesim $(mainargs)

clean-tools = $(dir $(shell find ./tools -maxdepth 2 -mindepth 2 -name "Makefile"))
$(clean-tools):
	$(MAKE) -s -C $@ clean
clean-tools: $(clean-tools)
clean-all: clean distclean clean-tools

.PHONY: run gdb run-env clean-tools clean-all $(clean-tools) test analyzer branchsim cachesim recorder
