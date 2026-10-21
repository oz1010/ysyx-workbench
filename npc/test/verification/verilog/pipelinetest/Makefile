# Standalone Chisel pipeline formal harness; no RTL generation or source edits.
PROJECT_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
.DEFAULT_GOAL := verify
PYTHON ?= python3
YOSYS ?= yosys
SBY ?= sby
N ?= 5
DEPTH ?= 40
CVR_DEPTH ?= 120
MAX_CYCLES ?= 96
MAX_WAIT ?= 2
MEM_BYTES ?= 16
SOLVER ?= boolector
CPU_NUM ?= 4
SELFTEST_DEPTH ?= 16
BUILD_PATH ?= build
BUILD_DIR := $(abspath $(if $(filter /%,$(BUILD_PATH)),$(BUILD_PATH),$(PROJECT_DIR)/$(BUILD_PATH)))
TASKS ?= alu_bmc alu_progress alu_cvr
SELFTEST_TASKS ?=

configure:
	$(PYTHON) $(PROJECT_DIR)/configure.py --build $(BUILD_DIR) --n $(N) \
		--depth $(DEPTH) --cover-depth $(CVR_DEPTH) --max-cycles $(MAX_CYCLES) \
		--max-wait $(MAX_WAIT) --mem-bytes $(MEM_BYTES) --solver $(SOLVER) \
		--selftest-depth $(SELFTEST_DEPTH)

all: verify
verify: configure
	cd $(PROJECT_DIR) && $(SBY) -f -j $(CPU_NUM) $(BUILD_DIR)/verify.sby $(TASKS)

bmc: TASKS = alu_bmc
progress: TASKS = alu_progress
cover: TASKS = alu_cvr
mem: TASKS = mem_bmc mem_progress mem_cvr
stall: TASKS = stall_bmc stall_progress stall_cvr
bmc progress cover mem stall: verify

# Read/elaborate/check all cores, monitors and protocol models, without a solver.
check: configure
	cd $(PROJECT_DIR) && $(YOSYS) -Q -T -l $(BUILD_DIR)/elaborate.log -s $(BUILD_DIR)/elaborate.ys

# Includes expected-failure mutations; ERROR/UNKNOWN are not acceptable results.
selftest: configure
	cd $(PROJECT_DIR) && $(SBY) -f -j $(CPU_NUM) $(BUILD_DIR)/selftest.sby $(SELFTEST_TASKS)

report:
	$(PYTHON) $(PROJECT_DIR)/report.py --build $(BUILD_DIR)

help:
	@printf '%s\n' 'make check       Elaborate complete harness (Slang required)' \
	 'make verify      ALU safety + bounded progress + coverage' \
	 'make bmc|progress|cover|mem|stall' \
	 'make selftest    DUT-independent scoreboard regression' \
	 'make report      Summarize existing task status files' \
	 'make verify TASKS="mem_bmc stall_cvr" N=5 SOLVER=boolector' \
	 'N DEPTH CVR_DEPTH MAX_CYCLES MAX_WAIT MEM_BYTES CPU_NUM BUILD_PATH are configurable'

clean:
	$(PYTHON) -c 'from pathlib import Path; import shutil; p=Path("$(BUILD_DIR)").resolve(); root=Path("$(PROJECT_DIR)").resolve(); assert p != root and root in p.parents, "refuse to clean outside project"; shutil.rmtree(p) if p.exists() else None'
	@rm -rf __pycache__

.PHONY: all configure verify bmc progress cover mem stall check selftest report help clean
