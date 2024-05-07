TOOLCHAIN	:=	riscv64-linux-gnu-
CC			:=	${TOOLCHAIN}gcc
OBJDUMP		:=	${TOOLCHAIN}objdump
OBJCOPY		:=	${TOOLCHAIN}objcopy
BUILD_DIR	?= $(NEMU_HOME)/build/risc32

TAGET		:= $(BUILD_DIR)/prog
BINARY		:= ${TAGET}.bin

all: ${BUILD_DIR} ${BINARY}

${BUILD_DIR}:
	@mkdir -p $@

# ${CC} -ffreestanding -nostdlib -static -Wl,-Ttext=0 -O2 -o $@ $<
${TAGET}: a.c
	@${CC} -march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -static -Wl,-Ttext=0 -O2 -o $@ $<

# ${OBJDUMP} -M no-aliases -d $<
objdump: ${TAGET}
	@${OBJDUMP} -M no-aliases -d $<

# riscv64-linux-gnu-objcopy -O binary -S build/bin/prog prog.bin
${BINARY}: ${TAGET}
	@${OBJCOPY} -O binary -S $^ $@

clean:
	@-rm -f ${TAGET} ${BINARY}
