MILL ?= /root/tools/mill/bin/mill
export COURSIER_REPOSITORIES ?= https://repo1.maven.org/maven2
# chisel 7.15.0 发布对应的 firtool 版本（环境里的 1.105.0 太旧，无法解析新版 FIRRTL）
export CHISEL_FIRTOOL_PATH = /root/tools/firtool-1.158.0/bin
OUT ?= build

.PHONY: all copy_to_npc verilog clean

all: verilog

verilog:
	@$(MILL) -i chisel.runMain Generate $(OUT)

copy_to_npc: verilog
	@cp -r $(OUT)/pipeline-chisel $(NPC_HOME)/vsrc/core/

clean:
	@rm -rf "$(OUT)"
