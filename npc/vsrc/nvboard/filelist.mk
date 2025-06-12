ifdef CONFIG_HAS_NVBOARD

NV_GEN_DIR 		= build/nvboard
NXDC_FILES 		?= $(NPC_HOME)/vsrc/nvboard/pins/ysyxSoCFull.nxdc
NXDC_GEN_CPP 	?= $(NV_GEN_DIR)/auto_bind.cpp

VSRCS-$(CONFIG_HAS_NVBOARD)		+= $(NXDC_GEN_CPP)

# NVBoard check
ifeq ($(wildcard $(NVBOARD_HOME)/scripts/auto_pin_bind.py),)
    $(error NVBOARD_HOME=$(NVBOARD_HOME) is not a NVBoard repo)
endif

include $(NVBOARD_HOME)/scripts/nvboard.mk

# 引脚绑定关系C++文件生成规则
$(NPC_HOME)/$(NXDC_GEN_CPP): $(NXDC_FILES)
	@echo + CNXDC $<
	@mkdir -p $(dir $@)
	@python3 $(NVBOARD_HOME)/scripts/auto_pin_bind.py $^ $@

endif

