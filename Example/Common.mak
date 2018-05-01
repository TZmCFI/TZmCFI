
AS = arm-none-eabi-gcc -x assembler-with-cpp -c
CC = arm-none-eabi-gcc
CXX = arm-none-eabi-g++
LD = arm-none-eabi-g++
AR = arm-none-eabi-ar
HEX = arm-none-eabi-objcopy -O ihex
BIN = arm-none-eabi-objcopy -O binary -S
SZ = arm-none-eabi-size

MCU := -mcpu=cortex-m33 -mthumb

CFLAGS := $(MCU)
CFLAGS := $(CFLAGS) -ffunction-sections -fdata-sections
CFLAGS := $(CFLAGS) -Os -g -Wall

# We live in a modern era. Pre-C++17 specifications ended with feudalism.
CXXFLAGS := $(CFLAGS) -std=c++17 -fno-exceptions

ASFLAGS := $(MCU) -Wall -fdata-sections -ffunction-sections
