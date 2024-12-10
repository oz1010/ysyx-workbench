.DEFAULT_GOAL = app

# Add necessary options if the target is a shared library
ifeq ($(SHARE),1)
SO = -so
CFLAGS  += -fPIC -fvisibility=hidden
LDFLAGS += -shared -fPIC
endif

WORK_DIR  = $(shell pwd)
BUILD_DIR = $(WORK_DIR)/build

INC_PATH := $(WORK_DIR)/../common/include $(WORK_DIR)/include $(INC_PATH)
OBJ_DIR  = $(BUILD_DIR)/obj-$(NAME)$(SO)
BINARY   = $(BUILD_DIR)/$(NAME)$(SO)

# Compilation flags
ifeq ($(CC),clang)
CXX := clang++
else
CXX := g++
endif
LD := $(CXX)
INCLUDES = $(addprefix -I, $(INC_PATH))
# CFLAGS  := -O2 -MMD -Wall -Werror $(INCLUDES) $(CFLAGS)
# LDFLAGS := -O2 $(LDFLAGS)
CFLAGS  := -g -MMD -Wall $(INCLUDES) $(CFLAGS)
LDFLAGS := -g $(LDFLAGS)

VERILATOR_CFLAGS += $(INCLUDES)

OBJS =
OBJS += $(SRCS:%.cpp=$(OBJ_DIR)/%.o)
OBJS += $(CCSRC:%.cc=$(OBJ_DIR)/%.o)
OBJS += $(CSRC:%.c=$(OBJ_DIR)/%.o)

# Compilation patterns
$(OBJ_DIR)/%.o: %.c
	@echo + CC $<
	@mkdir -p $(dir $@)
	@$(CC) $(CFLAGS) -E -MF /dev/null $< | clang-format > $@.i
	@$(CC) $(CFLAGS) -c -o $@ $<
	$(call call_fixdep, $(@:.o=.d), $@)

$(OBJ_DIR)/%.o: %.cc
	@echo + CX $<
	@mkdir -p $(dir $@)
	@$(CXX) $(CFLAGS) $(CXXFLAGS) -c -o $@ $<
	$(call call_fixdep, $(@:.o=.d), $@)

$(OBJ_DIR)/%.o: %.cpp
	@echo + CXX $<
	@mkdir -p $(dir $@)
	@$(CXX) $(CFLAGS) $(CXXFLAGS) -c -o $@ $<
	$(call call_fixdep, $(@:.o=.d), $@)

$(IMG):
	@$(MAKE) -C $(NPC_HOME)/resource/riscv32-bin

$(VOBJS): $(VSRCS)
	@echo + CV $<
	@mkdir -p $(dir $@)
	@$(VERILATOR) $(VERILATOR_CFLAGS) \
		$(addprefix -CFLAGS , $(VCXXFLAGS)) \
		$(addprefix -LDFLAGS , $(VLDFLAGS)) \
		$^

# Depencies
-include $(OBJS:.o=.d)

# Some convenient rules

.PHONY: app clean

app: $(BINARY) $(IMG)

$(BINARY):: $(VOBJS) $(OBJS) $(ARCHIVES)
	@echo + LD $@
	@$(LD) -o $@ $(OBJS) $(LDFLAGS) $(ARCHIVES) $(LIBS)

clean:
	-rm -rf $(VGEN_DIR) $(BUILD_DIR)
