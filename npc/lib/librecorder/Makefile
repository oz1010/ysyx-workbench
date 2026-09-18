# 核心解析算法编译为静态库librecorder.a，输出到$(NPC_HOME)/build/lib/
# recorder可执行文件（tools/recorder）与mon_analyzer（tools/monitor_analyzer）链接该库

NPC_HOME	?= $(abspath $(CURDIR)/../..)
BUILD		:= $(NPC_HOME)/build/lib
OBJ_DIR		:= $(NPC_HOME)/build/obj-librecorder
LIB			:= $(BUILD)/librecorder.a

LIB_SRCS	:= $(wildcard src/*.cpp)
LIB_OBJS	:= $(patsubst src/%.cpp,$(OBJ_DIR)/%.o,$(LIB_SRCS))

CXX			?= g++
CXXFLAGS	+= -O2 -std=c++17 -MMD -Wall -Werror -Iinclude -I$(NPC_HOME)/include

all: $(LIB)

$(LIB): $(LIB_OBJS)
	@mkdir -p $(dir $@)
	@echo + AR $@
	@ar rcs $@ $(LIB_OBJS)

$(OBJ_DIR)/%.o: src/%.cpp
	@echo + CXX $<
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	-rm -rf $(OBJ_DIR) $(LIB)

-include $(LIB_OBJS:.o=.d)

.PHONY: all clean
