# 核心解析算法编译为静态库librecorder.a，recorder可执行文件用于将record文件解析为文本

BUILD		:= build
OBJ_DIR		:= $(BUILD)/obj
LIB			:= $(BUILD)/librecorder.a
BIN			:= $(BUILD)/recorder

LIB_SRCS	:= $(filter-out src/main.cpp,$(wildcard src/*.cpp))
LIB_OBJS	:= $(patsubst src/%.cpp,$(OBJ_DIR)/%.o,$(LIB_SRCS))
MAIN_OBJ	:= $(OBJ_DIR)/main.o

CXX			?= g++
CXXFLAGS	+= -O2 -std=c++17 -MMD -Wall -Werror -Iinclude -I../../include

all: $(LIB) $(BIN)

$(LIB): $(LIB_OBJS)
	@mkdir -p $(dir $@)
	@echo + AR $@
	@ar rcs $@ $(LIB_OBJS)

$(BIN): $(MAIN_OBJ) $(LIB)
	@echo + LD $@
	@$(CXX) $(CXXFLAGS) -o $@ $(MAIN_OBJ) $(LIB)

$(OBJ_DIR)/%.o: src/%.cpp
	@echo + CXX $<
	@mkdir -p $(dir $@)
	@$(CXX) $(CXXFLAGS) -c -o $@ $<

clean:
	-rm -rf $(BUILD)

-include $(LIB_OBJS:.o=.d) $(MAIN_OBJ:.o=.d)

.PHONY: all clean
