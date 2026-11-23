MILL ?= mill
export COURSIER_REPOSITORIES ?= https://repo1.maven.org/maven2
# chisel 7.15.0 发布对应的 firtool 版本（环境里的 1.105.0 太旧，无法解析新版 FIRRTL）
# export CHISEL_FIRTOOL_PATH = /root/tools/firtool-1.158.0/bin
GEN_OUT ?= build
GEN_DIR_NAME ?= pipeline-manual
GEN_MODE ?= normal
GEN_TARGET = $(GEN_OUT)/$(GEN_DIR_NAME)
TARGET_PIPELINE_DIR = $(NPC_HOME)/vsrc/core/pipeline-chisel

# 自动检测有效目标：src/ 下定义了 riscv32e_core 顶层类的子目录
PIPELINES := $(sort $(patsubst src/%/,%,$(dir $(shell grep -rl --include='*.scala' 'class riscv32e_core' src/))))

# 所有目录共用的源文件 + 生成器自身：任一变化都需要重新生成
COMMON_SRCS := $(wildcard src/common/*.scala src/common/*.v src/common/*.sv)
GEN_SRCS    := $(wildcard src/generator/*.scala) build.mill

.PHONY: all verilog copy_to_npc clean $(PIPELINES)

all: verilog

# verilog 依赖具体生成目录；目录已是最新时不重复跑生成器
verilog: $(GEN_TARGET)

# 目录别名：make pipeline-manual 等价于 make build/pipeline-manual
$(PIPELINES): %: $(GEN_OUT)/%

# build/<名字> 只依赖 src/<名字> 与 src/common 下的源文件，
# 改哪个目录就只重编哪个目录（wildcard 在二次展开时按目标收集依赖）
.SECONDEXPANSION:
$(GEN_OUT)/%: $$(wildcard src/$$*/*.scala src/$$*/*.v src/$$*/*.sv) $(COMMON_SRCS) $(GEN_SRCS)
	@$(MILL) -i chisel.runMain Generate $(GEN_OUT) $* $(GEN_MODE)
# 目标是目录：重写其中 .v 不会更新目录 mtime，显式 touch 使其新于源文件，避免下次重复重建
	@touch "$@"

# 无效目标直接报错并列出有效目标
%::
	@echo "Error: '$@' 不是有效目标，有效目标: $(PIPELINES)" >&2
	@exit 2

# copy_to_npc: verilog $(TARGET_PIPELINE_DIR)

# $(TARGET_PIPELINE_DIR): $(GEN_TARGET)
# 	@-rm -rf $(TARGET_PIPELINE_DIR)
# 	@cp -r $(GEN_TARGET) $(TARGET_PIPELINE_DIR)
# 	@echo "[\033[32mDONE\033[0m] Copy to $(TARGET_PIPELINE_DIR)"

clean:
	@rm -rf build build-sta $(GEN_OUT)
