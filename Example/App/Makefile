
APPDIR := .
TARGET := NonSecureExample

include $(APPDIR)/../Common.mak

LDSCRIPT := $(APPDIR)/An521.ld

LDFLAGS := $(MCU) -T$(LDSCRIPT) -lc -lm -Wl,-Map=$(TARGET).map,--cref -Wl,--gc-sections

default:        all
all:            $(TARGET).elf $(TARGET).hex $(TARGET).bin

.PHONY:	default all clean

OBJS := Main.o Pl011Driver.o Startup.o LibcStub.o

clean:
	rm -rf $(OBJS) $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).map

$(TARGET).elf:   $(OBJS) $(LDSCRIPT)
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	$(SZ) $@

$(TARGET).hex:	 $(TARGET).elf
	$(HEX) $< $@

$(TARGET).bin:	 $(TARGET).elf
	$(BIN) $< $@

