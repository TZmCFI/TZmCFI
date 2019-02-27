
AS = arm-none-eabi-gcc -x assembler-with-cpp -c
CC = arm-none-eabi-gcc
CXX = arm-none-eabi-g++
LD = arm-none-eabi-g++
AR = arm-none-eabi-ar
HEX = arm-none-eabi-objcopy -O ihex
BIN = arm-none-eabi-objcopy -O binary -S
SZ = arm-none-eabi-size

TZMCFI_PATCH = $(APPDIR)/../../target/debug/tzmcfi_patch
TZMCFI_MKIMPLIB = $(APPDIR)/../../target/debug/tzmcfi_mkimplib

MCU := -mthumb -mfloat-abi=soft -msoft-float -march=armv8-m.main

ifeq "$(CMSIS_PATH)" ""
$(error You must specify CMSIS_PATH to the directory where CMSIS 5 is located.)
endif

INCLUDES := $(INCLUDES) -I$(CMSIS_PATH)/CMSIS/Core/Include
INCLUDES := $(INCLUDES) -I$(CMSIS_PATH)/Device/ARM/ARMCM33/Include

CFLAGS := $(MCU)
CFLAGS := $(CFLAGS) -ffunction-sections -fdata-sections
CFLAGS := $(CFLAGS) -Os -g -Wall
CFLAGS := $(CFLAGS) $(INCLUDES)

# We live in a modern era. Pre-C++17 specifications ended with feudalism.
CXXFLAGS := $(CFLAGS) -std=gnu++17 -fno-exceptions

ASFLAGS := $(MCU) -Wall -fdata-sections -ffunction-sections
