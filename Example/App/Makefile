
APPDIR := .
TARGET := NonSecureExample

include $(APPDIR)/../Common.mak

LDSCRIPT := $(APPDIR)/An521.ld

LDFLAGS := $(MCU) -T$(LDSCRIPT) -lc -lm -Wl,-Map=$(TARGET).map,--cref -Wl,--gc-sections

default:        all
all:            $(TARGET).elf $(TARGET).hex $(TARGET).bin

.PHONY:	default all clean

COBJS := Main.o Pl011Driver.o LibcStub.o
ASMOBJS := Startup.o

OBJS = $(COBJS) $(ASMOBJS)

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

$(TARGET).elf:   $(PATCH_TIMESTAMP_FILE) $(LDSCRIPT)
	$(CC) $(PATCHED_FILES) $(LDFLAGS) -o $@
	$(SZ) $@

$(TARGET).hex:	 $(TARGET).elf
	$(HEX) $< $@

$(TARGET).bin:	 $(TARGET).elf
	$(BIN) $< $@

%.s: %.c
	$(CC) $(CXXFLAGS) $^ -o $@ -S

%.s: %.cpp
	$(CXX) $(CXXFLAGS) $^ -o $@ -S
