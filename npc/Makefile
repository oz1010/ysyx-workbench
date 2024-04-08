VERILATOR_FLAGS	:= --build -j 0 -cc --exe -x-assign fast -Wall

C_SRC	:=	$(shell ls csrc/*.cpp)
V_SRC	:=  $(shell ls vsrc/*.v)
OBJ_DIR	:=	obj_dir
TARGET	:=  obj_dir/Vtop
#TARGET_ARGS	:= +trace

.PHONY: run clean

ifdef TRACE
VERILATOR_FLAGS += --trace
endif

all: ${TARGET}

run: ${TARGET}
	@rm -rf logs
	@${TARGET} ${TARGET_ARGS}

${TARGET}: ${V_SRC} ${C_SRC}
	#@verilator --build -j 0 -cc --exe -x-assign fast -Wall --trace $^
	@verilator ${VERILATOR_FLAGS} $^

sim:
	$(call git_commit, "sim RTL") # DO NOT REMOVE THIS LINE!!!
	@echo "Write this Makefile by your self."

include ../Makefile

clean:
	@rm -rf logs
	@rm -rf ${OBJ_DIR}

