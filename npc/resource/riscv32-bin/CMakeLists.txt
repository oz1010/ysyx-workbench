cmake_minimum_required(VERSION 3.15)

project(prog C)
set(C_STANDARD 17)

set(TOOLCHAIN riscv64-linux-gnu-)
set(CMAKE_C_COMPILER ${TOOLCHAIN}gcc)
set(OBJDUMP ${TOOLCHAIN}objdump)
set(OBJCOPY ${TOOLCHAIN}objcopy)
set(CMAKE_C_FLAGS "-march=rv32i -mabi=ilp32 -ffreestanding -nostdlib -static -Wl,-Ttext=0 -O2")

file(GLOB_RECURSE MAIN_SRC "*.c")

set(TARGET ${PROJECT_NAME})
add_executable(${TARGET}
    ${MAIN_SRC}
)
include_directories(${TARGET} public
    .
)
set(TARGET_HEX ${PROJECT_NAME}.hex)
add_custom_command(TARGET ${TARGET} POST_BUILD
    COMMAND ${OBJDUMP} -M no-aliases -d ${EXECUTABLE_OUTPUT_PATH}/${TARGET} > ${EXECUTABLE_OUTPUT_PATH}/${TARGET_HEX}
    COMMENT "Generate ${EXECUTABLE_OUTPUT_PATH}/${TARGET_HEX}"
)
set(TARGET_BIN ${PROJECT_NAME}.bin)
add_custom_command(TARGET ${TARGET} POST_BUILD
    COMMAND ${OBJCOPY} -O binary -S ${EXECUTABLE_OUTPUT_PATH}/${TARGET} ${EXECUTABLE_OUTPUT_PATH}/${TARGET_BIN}
    COMMENT "Generate ${EXECUTABLE_OUTPUT_PATH}/${TARGET_BIN}"
    # ${TOOLCHAIN_PATH}/bin/arm-none-eabi-objcopy -O binary -S ${EXECUTABLE_OUTPUT_PATH}/${MAIN_TARGET} ${EXECUTABLE_OUTPUT_PATH}/${MAIN_BIN_TARGET}
)

