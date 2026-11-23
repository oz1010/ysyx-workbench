CI_CPU_FILE = $(NPC_HOME)/build/$(STUID).v
CI_TB_SRCS = $(NPC_HOME)/vsrc/iverilog/iv_top.v \
             $(NPC_HOME)/vsrc/iverilog/iv_memsys.v
CI_IVERILOG_FLAGS = -g2012 $(addprefix -D,IN_YOSYS_STA NETLIST CI_STANDALONE) \
                    -s iv_top $(addprefix -I,$(NPC_HOME)/include $(NPC_HOME)/vsrc/core/common)
CI_RTL_VVP = $(IV_GEN_DIR)/$(STUID).vvp
CI_NETLIST_VVP = $(IV_GEN_DIR)/$(STUID)_netlist.vvp
CI_SIM_ARGS = +IMG=$(abspath $(IMG)) +OUTPUT=$(abspath $(RESULT_DIR)) \
              +TRACE=$(if $(filter 1,$(TRACE)),1,0)
CI_VVP = vvp -M$(IV_GEN_DIR) -miv_ps2_input

verilog:
	@$(MAKE) convert2v NETLIST=1 \
		STA_OUTPUT_DIR=$(NPC_HOME)/build/ci \
		STA_TARGET_FILE=$(CI_CPU_FILE)

sim-iverilog: verilog $(IV_PS2_INPUT)
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

.PHONY: verilog sim-iverilog sim-iverilog-netlist
