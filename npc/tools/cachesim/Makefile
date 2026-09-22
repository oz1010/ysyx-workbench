NAME			?= cachesim
BUILD			:= build
INC_PATH 		?= $(NPC_HOME)/include
RECORDER		:= $(NPC_HOME)/lib/librecorder
INC_PATH		+= $(RECORDER)/include
SRCS			+= main.cpp mem.cpp util.cpp
CXXFLAGS		+= -std=c++17
# CXXFLAGS		+= -g -O0
ARCHIVES		+= $(NPC_HOME)/build/lib/librecorder.a

include $(NPC_HOME)/scripts/build.mk

$(NPC_HOME)/build/lib/librecorder.a:
	@$(MAKE) -C $(RECORDER)
