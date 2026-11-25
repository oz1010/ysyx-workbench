CI_CPU_FILE := $(CPU_VERILOG)
CI_CPU_PREPROC = $(NPC_HOME)/build/ci/$(STUID).pre.v
CI_TB_SRCS = $(NPC_HOME)/vsrc/iverilog/iv_top.v \
             $(NPC_HOME)/vsrc/iverilog/iv_memsys.v
CI_IVERILOG_FLAGS = -g2012 $(addprefix -D,IN_YOSYS_STA NETLIST CI_STANDALONE) \
                    -s iv_top $(addprefix -I,$(NPC_HOME)/include $(NPC_HOME)/vsrc/core/common)
CI_RTL_VVP = $(IV_GEN_DIR)/$(STUID).vvp
CI_NETLIST_VVP = $(IV_GEN_DIR)/$(STUID)_netlist.vvp
CI_VERILATOR_DIR = $(NPC_HOME)/build/verilator-standalone
CI_VERILATOR_BINARY = $(CI_VERILATOR_DIR)/Viv_top
CI_VERILATOR_FLAGS = --binary --timing -sv -Wno-fatal --top-module iv_top \
                     --Mdir $(CI_VERILATOR_DIR) -Wno-UNOPTFLAT -Wno-PINMISSING \
                     $(addprefix -D,IN_YOSYS_STA NETLIST CI_STANDALONE) \
                     $(addprefix -I,$(NPC_HOME)/include $(NPC_HOME)/vsrc/core/common)
CI_SIM_ARGS = +IMG=$(abspath $(IMG)) +OUTPUT=$(abspath $(RESULT_DIR)) \
              +TRACE=$(if $(filter 1,$(TRACE)),1,0)
CI_VVP = vvp -M$(IV_GEN_DIR) -miv_ps2_input
CI_AMTEST_DIR ?= $(abspath $(NPC_HOME)/../am-kernels/tests/am-tests)
CI_AMTEST_ARCH ?= riscv32e-npc
CI_AMTEST_IMG = $(CI_AMTEST_DIR)/build/amtest-$(CI_AMTEST_ARCH).bin

verilog: $(CI_CPU_FILE)

$(CI_CPU_FILE): $(CPU_RTL_FILES) $(NPC_HOME)/include/generated/autoconf.vh \
                $(NPC_HOME)/scripts/rename_ysyx_verilog.py \
                $(NPC_HOME)/vsrc/filelist.mk $(NPC_HOME)/scripts/ci.mk
	@echo "Generating $@"
	@mkdir -p $(dir $@) $(dir $(CI_CPU_PREPROC))
	@$(VERILATOR) -Wall --Wno-fatal -sv --bbox-unsup --bbox-sys -E \
		--no-public-params --no-timing --no-assert \
		+1800-2005ext+ \
		$(addprefix +incdir+,$(STA_INCLUDE_DIR)) \
		+define+IN_YOSYS_STA +define+NETLIST \
		$(CPU_RTL_FILES) > $(CI_CPU_PREPROC)
	@python3 $(NPC_HOME)/scripts/rename_ysyx_verilog.py \
		$(CI_CPU_PREPROC) -o $@ --top $(STUID) --conditional-reset-pc

$(YSYXSOC_VERILOG):
	@$(MAKE) -C $(YSYXSOC_HOME) STUID=$(STUID) verilog

sim-verilator: $(CI_CPU_FILE)
	@test -f "$(IMG)" || { echo "IMG=$(IMG) does not exist"; exit 1; }
	@mkdir -p $(CI_VERILATOR_DIR) $(RESULT_DIR)
	@$(VERILATOR) $(CI_VERILATOR_FLAGS) -o $(CI_VERILATOR_BINARY) $(CI_CPU_FILE) $(CI_TB_SRCS) $(IV_PS2_INPUT_SRC)
	$(CI_VERILATOR_BINARY) $(CI_SIM_ARGS)

amtest-image:
	$(MAKE) -C $(CI_AMTEST_DIR) ARCH=$(CI_AMTEST_ARCH) mainargs="$(mainargs)" image

ifneq ($(mainargs),)
ifeq ($(abspath $(IMG)),$(abspath $(CI_AMTEST_IMG)))
sim-iverilog: amtest-image
endif
endif

sim-iverilog: $(CI_CPU_FILE) $(IV_PS2_INPUT)
	@test -f "$(IMG)" || { echo "IMG=$(IMG) does not exist"; exit 1; }
	@mkdir -p $(IV_GEN_DIR) $(RESULT_DIR)
	@iverilog $(CI_IVERILOG_FLAGS) -o $(CI_RTL_VVP) $(CI_CPU_FILE) $(CI_TB_SRCS)
	$(CI_VVP) $(CI_RTL_VVP) $(CI_SIM_ARGS)

sim-iverilog-netlist: $(IV_PS2_INPUT)
	@test -f "$(IMG)" || { echo "IMG=$(IMG) does not exist"; exit 1; }
	@test -f "$(NETLIST)" || { echo "NETLIST=$(NETLIST) does not exist"; exit 1; }
	@test -f "$(CELLS)" || { echo "CELLS=$(CELLS) does not exist"; exit 1; }
	@mkdir -p $(IV_GEN_DIR) $(RESULT_DIR)
	@iverilog $(CI_IVERILOG_FLAGS) -Dfunctional -o $(CI_NETLIST_VVP) $(NETLIST) $(CELLS) $(CI_TB_SRCS)
	$(CI_VVP) $(CI_NETLIST_VVP) $(CI_SIM_ARGS)

.PHONY: verilog amtest-image sim-verilator sim-iverilog sim-iverilog-netlist
