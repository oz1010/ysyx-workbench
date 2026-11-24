LINKER_FILE ?= ${AM_HOME}/scripts/platform/npc/linker_flash_sram_sdram_ssbl.ld
NPC_RUN_TARGET = run

include $(AM_HOME)/scripts/riscv32e-npc.mk
