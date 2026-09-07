# muldivremtest 形式化验证工程
# 参考：test/verification/verilog/sub
# 执行 make verify 即可看到验证结果

NPC_HOME := $(abspath ../../../..)
DEPTH  ?= 45
FVW    ?= 8
CPU_NUM ?= 2

VERIFY_NAME := verify
BUILD_PATH  ?= build
GEN_VERIFY_SBY ?= $(BUILD_PATH)/verify.sby

all: verify

verify: $(GEN_VERIFY_SBY)
	sby -f $(GEN_VERIFY_SBY) -j $(CPU_NUM)

$(GEN_VERIFY_SBY): verify.sby FORCE
	mkdir -p $(dir $@)
	sed -e 's|@NPC_HOME@|$(NPC_HOME)|g' \
	    -e 's|@DEPTH@|$(DEPTH)|g' \
	    -e 's|@FVW@|$(FVW)|g' \
	    $< > $@

FORCE:

.PHONY: all verify clean FORCE

clean:
	@rm -rf $(VERIFY_NAME) $(VERIFY_NAME)_bmc $(VERIFY_NAME)_cover $(BUILD_PATH)
