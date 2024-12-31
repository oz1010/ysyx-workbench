TOOLCHAIN	:=	riscv64-linux-gnu-
CC			:=	${TOOLCHAIN}gcc
OBJDUMP		:=	${TOOLCHAIN}objdump
OBJCOPY		:=	${TOOLCHAIN}objcopy
BUILD_DIR	?=	$(NPC_HOME)/build/riscv32-bin

TAGET		:= $(BUILD_DIR)/prog
BINARY		:= ${TAGET}.bin
OBJ_TARGET  := ${TAGET}.hex

all: ${BINARY} ${OBJ_TARGET}

# ${CC} -ffreestanding -nostdlib -static -Wl,-Ttext=0 -O2 -o $@ $<
${TAGET}: a.c
	@mkdir -p $(dir $@)
	@${CC} -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -static -Wl,-Ttext=0 -O2 -g -o $@ $<

# ${OBJDUMP} -M no-aliases -d $<
${OBJ_TARGET}: ${TAGET}
	@${OBJDUMP} -M no-aliases -d $< >$@

# riscv64-linux-gnu-objcopy -O binary -S build/bin/prog prog.bin
${BINARY}: ${TAGET}
	@${OBJCOPY} -O binary -S $^ $@

clean:
	@-rm -f ${TAGET} ${BINARY}

.PHONY: clean
