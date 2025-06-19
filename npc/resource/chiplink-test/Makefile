NAME			= chiplink_test
SRCS			= start.S test_init.c main.c
LINKER_FILE		= ${AM_HOME}/scripts/platform/npc/linker_sram.ld
INC_PATH		+= ${AM_HOME}/am/src
INC_PATH		+= ${AM_HOME}/am/src
INC_PATH		+= ${NPC_HOME}/include
INC_PATH		+= include

CFLAGS 			+= -DMAINARGS=\"$(mainargs)\"

include			${AM_HOME}/Makefile
