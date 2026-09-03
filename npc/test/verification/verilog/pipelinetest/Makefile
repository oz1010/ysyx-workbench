# 流水线NPC形式化验证（验证要求见 https://ysyx.oscc.cc/docs/2607/b/4.html#%E6%B5%81%E6%B0%B4%E7%BA%BF%E5%A4%84%E7%90%86%E5%99%A8%E7%9A%84%E6%B5%8B%E8%AF%95%E9%AA%8C%E8%AF%81）
# 执行 make verify 即可看到验证结果
# DEPTH 指定BMC深度，默认15（约覆盖1条指令从取指到完成，含访存延迟），
# CVR_DEPTH 指定覆盖检查的BMC深度（ecall/mret/csr等需要更深的轨迹），
# 更大的深度可用 make verify DEPTH=30 CVR_DEPTH=30 覆盖（遍历更长的指令序列，求解时间显著增加）
# 每日写代码测试：make verify （使用默认 DEPTH=13 CVR_DEPTH=20 快速验证 10^5+ 场景）
# 彻底回归：make verify DEPTH=25 CVR_DEPTH=30 运行时间约几小时
NPC_HOME := $(abspath ../../../..)
DEPTH ?= 13
CVR_DEPTH ?= 20
SOLVER    ?= yices  # 可选：yices, z3, boolector
CPU_NUM   ?= 4 # 当前后台有2个任务，同时使用2个求解器

VERIFY_NAME := verify
BUILD_PATH ?= build
GEN_VERIFY_SBY ?= $(BUILD_PATH)/verify.sby

all: verify

# 
verify: $(GEN_VERIFY_SBY)
	sby -f $(GEN_VERIFY_SBY) -j $(CPU_NUM)

# verify.sby由模板生成，注入NPC_HOME绝对路径与BMC深度
$(GEN_VERIFY_SBY): verify.sby FORCE
	mkdir -p $(dir $@)
	sed -e 's|@NPC_HOME@|$(NPC_HOME)|g' \
		-e 's|@DEPTH@|$(DEPTH)|g' \
		-e 's|@CVR_DEPTH@|$(CVR_DEPTH)|g' \
		-e 's|@SOLVER@|$(SOLVER)|g' \
		$< > $@

FORCE:

clean:
	rm -rf $(VERIFY_NAME) $(VERIFY_NAME)_* $(BUILD_PATH)

.PHONY: all verify clean FORCE
