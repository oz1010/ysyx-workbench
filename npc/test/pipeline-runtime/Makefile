NPC := $(NPC_HOME)
BUILD := $(NPC)/build/pipeline-runtime
GEN := $(NPC)/vsrc/chisel-gen/build/pipeline-manual

.PHONY: all ifu runtime generate
all: ifu runtime

generate:
	$(MAKE) -C $(NPC)/vsrc/chisel-gen verilog GEN_DIR_NAME=pipeline-manual

ifu: generate
	@mkdir -p $(BUILD)
	verilator --cc --exe --build -j 2 --top-module Ifu \
		--Mdir $(BUILD)/ifu $(GEN)/Ifu.v $(CURDIR)/ifu.cpp
	$(BUILD)/ifu/VIfu

runtime:
	$(MAKE) -C $(NPC) app -j
	python3 -I $(CURDIR)/runtime.py
