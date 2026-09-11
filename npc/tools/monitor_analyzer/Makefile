NAME			?= mon_analyzer
BUILD			:= build
INC_PATH 		?= $(NPC_HOME)/include
RECORDER		:= $(NPC_HOME)/tools/recorder
INC_PATH		+= $(RECORDER)/include
SRCS			+= main.cpp
CXXFLAGS		+= -std=c++17
ARCHIVES		+= $(RECORDER)/build/librecorder.a

include $(NPC_HOME)/scripts/build.mk

$(RECORDER)/build/librecorder.a:
	@$(MAKE) -C $(RECORDER)
