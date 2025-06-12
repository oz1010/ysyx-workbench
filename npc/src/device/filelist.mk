#***************************************************************************************
# Copyright (c) 2014-2022 Zihao Yu, Nanjing University
#
# NEMU is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#**************************************************************************************/

# DIRS-y += src/device/io
# SRCS-$(CONFIG_DEVICE) += src/device/device.cpp src/device/alarm.cpp src/device/intr.cpp
# SRCS-$(CONFIG_HAS_SERIAL) += src/device/serial.cpp
# SRCS-$(CONFIG_HAS_TIMER) += src/device/timer.cpp
# SRCS-$(CONFIG_HAS_KEYBOARD) += src/device/keyboard.cpp
# SRCS-$(CONFIG_HAS_VGA) += src/device/vga.cpp
# SRCS-$(CONFIG_HAS_AUDIO) += src/device/audio.cpp
# SRCS-$(CONFIG_HAS_DISK) += src/device/disk.cpp
# SRCS-$(CONFIG_HAS_SDCARD) += src/device/sdcard.cpp

# SRCS-BLACKLIST-$(CONFIG_TARGET_AM) += src/device/alarm.cpp

# SRCS-$(CONFIG_DEVICE) += src/device/vdev.cpp
# DIRS-y += src/device/vdev
SRCS-y							+= src/device/vdev/vdev.cpp
SRCS-$(CONFIG_HAS_CLINT)		+= src/device/vdev/clint.cpp
SRCS-$(CONFIG_HAS_UART)			+= src/device/vdev/uart16550.cpp
SRCS-$(CONFIG_HAS_SPI_MASTER)	+= src/device/vdev/spi_master.cpp
SRCS-$(CONFIG_HAS_GPIO)			+= src/device/vdev/gpio.cpp

ifdef CONFIG_DEVICE
ifndef CONFIG_TARGET_AM
LIBS += $(shell sdl2-config --libs)
endif
endif
