
APPDIR := .
TARGET := NonSecureExample
TRAMPOLINEDIR := $(APPDIR)/../../NonSecure
TZMCFI_HEADERS_DIR := $(APPDIR)/../../Headers
RTOSDIR := $(APPDIR)/../FreeRTOS

# Path to the secure import library
MONITOR_IMPLIB := ../Secure/SecureMonitor.implib.o

INCLUDES := $(INCLUDES) -I$(APPDIR)
INCLUDES := $(INCLUDES) -I$(TZMCFI_HEADERS_DIR)
INCLUDES := $(INCLUDES) -I$(RTOSDIR)/include
INCLUDES := $(INCLUDES) -I$(RTOSDIR)/portable/GCC/ARM_CM33/secure
INCLUDES := $(INCLUDES) -I$(RTOSDIR)/portable/GCC/ARM_CM33/non_secure

include $(APPDIR)/../Common.mak

LDSCRIPT := $(APPDIR)/An521.ld

LDFLAGS := $(MCU) -T$(LDSCRIPT) -lc -lm -Wl,-Map=$(TARGET).map,--cref -Wl,--gc-sections

default:        all
all:            $(TARGET).elf $(TARGET).hex $(TARGET).bin

.PHONY:	default all clean

COBJS := \
	Main.o \
	Pl011Driver.o \
	LibcStub.o \
	OSHooks.o \
	$(RTOSDIR)/croutine.o \
	$(RTOSDIR)/event_groups.o \
	$(RTOSDIR)/list.o \
	$(RTOSDIR)/queue.o \
	$(RTOSDIR)/stream_buffer.o \
	$(RTOSDIR)/tasks.o \
	$(RTOSDIR)/timers.o \
	$(RTOSDIR)/portable/GCC/ARM_CM33/non_secure/port.o \
	$(RTOSDIR)/portable/GCC/ARM_CM33/non_secure/portasm.o \
	$(RTOSDIR)/portable/MemMang/heap_4.o \
	$(RTOSDIR)/portable/Common/mpu_wrappers.o
ASMOBJS := Startup.o

OBJS = $(COBJS) $(ASMOBJS)

# TZmCFI trampolines
vpath %.s $(TRAMPOLINEDIR)
TRAMPOLINEOBJS := ExceptionTrampolines.o

# Link the secure import library
LDFLAGS += $(MONITOR_IMPLIB)

clean:
	rm -rf $(OBJS) $(COBJS:.o=.s) $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).map

# Patching pipeline for inline CFI
PATCHDIR := $(APPDIR)/CfiPatch.Artifacts
PATCH_TIMESTAMP_FILE = $(PATCHDIR)/timestamp
PATCHED_FILES = $(patsubst %.o,$(PATCHDIR)/%.s,$(COBJS) $(ASMOBJS))

$(PATCH_TIMESTAMP_FILE): $(COBJS:.o=.s)
	rm -Rf $(PATCHDIR)
	mkdir -p $(PATCHDIR)
	cp $(COBJS:.o=.s) $(ASMOBJS:.o=.s) $(PATCHDIR)
	$(TZMCFI_PATCH) $(PATCHED_FILES)
	touch $(PATCH_TIMESTAMP_FILE)

# $(TARGET).elf:   $(PATCH_TIMESTAMP_FILE) $(TRAMPOLINEOBJS) $(LDSCRIPT)
# 	$(CC) $(PATCHED_FILES) $(TRAMPOLINEOBJS) $(LDFLAGS) -o $@
# 	$(SZ) $@

# Here's how to compile without patching:
$(TARGET).elf:   $(COBJS) $(ASMOBJS) $(TRAMPOLINEOBJS) $(LDSCRIPT) $(MONITOR_IMPLIB)
	$(CC) $(COBJS) $(ASMOBJS) $(TRAMPOLINEOBJS) $(LDFLAGS) -o $@
	$(SZ) $@

$(TARGET).hex:	 $(TARGET).elf
	$(HEX) $< $@

$(TARGET).bin:	 $(TARGET).elf
	$(BIN) $< $@

%.s: %.c
	$(CC) $(CXXFLAGS) $^ -o $@ -S

%.s: %.cpp
	$(CXX) $(CXXFLAGS) $^ -o $@ -S
