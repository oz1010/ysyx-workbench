TOPNAME = top
NXDC_FILES = constr/top.nxdc
INC_PATH ?=

VERILATOR = verilator
VERILATOR_CFLAGS += -MMD --build -cc \
					-O3 --x-assign fast --x-initial fast --noassert

BUILD_DIR = ./build
OBJ_DIR = $(BUILD_DIR)/obj_dir
BIN = $(BUILD_DIR)/$(TOPNAME)

default: $(BIN)

$(shell mkdir -p $(BUILD_DIR))

# # constraint file
# SRC_AUTO_BIND = $(abspath $(BUILD_DIR)/auto_bind.cpp)
# $(SRC_AUTO_BIND): $(NXDC_FILES)
# 	python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

# project source
VSRCS = $(shell find $(abspath ./vsrc) -name "*.v")
CSRCS = $(shell find $(abspath ./csrc) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
# CSRCS += $(SRC_AUTO_BIND)

# # rules for NVBoard
# include $(NVBOARD_HOME)/scripts/nvboard.mk

# rules for verilator
INCFLAGS = $(addprefix -I, $(INC_PATH))
CXXFLAGS += $(INCFLAGS) -DTOP_NAME="\"V$(TOPNAME)\""

# open trace with 'make TRACE=1'
ifdef TRACE
VERILATOR_CFLAGS += --trace
#CXXFLAGS += -DTRACE=1
endif

# $(BIN): $(VSRCS) $(CSRCS) $(NVBOARD_ARCHIVE)
$(BIN): $(VSRCS) $(CSRCS)
	@rm -rf $(OBJ_DIR)
	$(VERILATOR) $(VERILATOR_CFLAGS) \
		--top-module $(TOPNAME) $^ \
		$(addprefix -CFLAGS , $(CXXFLAGS)) $(addprefix -LDFLAGS , $(LDFLAGS)) \
		--Mdir $(OBJ_DIR) --exe -o $(abspath $(BIN))

all: default

run: $(BIN)
	@$^ 

clean:
	rm -rf $(BUILD_DIR) 

.PHONY: default all clean run



# VERILATOR_FLAGS := --build -j 0 -cc --exe -x-assign fast -Wall --trace

# C_SRC   	:=	$(shell ls csrc/*.cpp)
# V_SRC   	:=	$(shell ls vsrc/*.v)
# OBJ_DIR 	:=  obj_dir
# TARGET  	:=  obj_dir/Vtop
# TARGET_ARGS	:= +trace

# .PHONY: run clean

# all:
# 	@echo "Write this Makefile by your self."

# run: ${TARGET}
# 	@rm -rf logs
# 	@${TARGET} ${TARGET_ARGS}

# ${TARGET}: ${V_SRC} ${C_SRC}
# 	#@verilator --build -j 0 -cc --exe -x-assign fast -Wall --trace $^
# 	@verilator ${VERILATOR_FLAGS} $^

# sim:
# 	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
# 	@echo "Write this Makefile by your self."

# # include ../Makefile

# clean:
# 	@rm -rf logs
# 	@rm -rf ${OBJ_DIR}
