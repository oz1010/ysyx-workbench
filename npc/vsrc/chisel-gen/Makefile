MILL ?= /root/tools/mill/bin/mill
export COURSIER_REPOSITORIES ?= https://repo1.maven.org/maven2
OUT ?= build

.PHONY: all verilog clean

all: verilog

verilog:
	@$(MILL) -i chisel.runMain Generate $(OUT)

clean:
	@rm -rf "$(OUT)"
