NAME			= test_nvboard
SRCS			= main.c
SRCS			+= $(shell find ./test -name "*.c")
LINKER_FILE		= ${AM_HOME}/scripts/platform/npc/linker_flash_psram_ssbl.ld
INC_PATH		+= ${AM_HOME}/am/src
INC_PATH		+= ${NPC_HOME}/include
INC_PATH		+= include

CFLAGS 			+= -DMAINARGS=\"$(mainargs)\"

include			${AM_HOME}/Makefile
