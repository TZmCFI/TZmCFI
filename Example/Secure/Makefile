
APPDIR := .
MONITORDIR := $(APPDIR)/../../SecureMonitor
TARGET := SecureMonitor

include $(APPDIR)/../Common.mak

LDSCRIPT := $(APPDIR)/An521.ld

LDFLAGS := $(MCU) -T$(LDSCRIPT) -lc -lm -Wl,-Map=$(TARGET).map,--cref -Wl,--gc-sections

default:        all
all:            $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).implib.o

.PHONY:	default all clean

OBJS := Main.o Startup.o

vpath %.cpp $(MONITORDIR)
OBJS += Assert.o Exception.o LinearAllocator.o Thread.o SecureAPI.o
CXXFLAGS += -I$(APPDIR)/../../Headers

# Enable CMSE features
CXXFLAGS += -mcmse

# Export these symbols to an application running in the Non-Secure mode
CMSE_SYMS := \
	-s TCReset						\
	-s TCCreateThread				\
	-s TCLockdown					\
	-s TCActivateThread     		\
	-s __TCPrivateEnterInterrupt    \
	-s __TCPrivateLeaveInterrupt

clean:
	rm -rf $(OBJS) $(TARGET).elf $(TARGET).hex $(TARGET).bin $(TARGET).map

$(TARGET).elf $(TARGET).implib.o:   $(OBJS) $(LDSCRIPT)
	$(CC) $(OBJS) $(LDFLAGS) -o $@
	$(TZMCFI_MKIMPLIB) $(CMSE_SYMS) $@ | \
		$(AS) - -o $(TARGET).implib.o $(ASFLAGS)
	$(SZ) $@

$(TARGET).hex:	 $(TARGET).elf
	$(HEX) $< $@

$(TARGET).bin:	 $(TARGET).elf
	$(BIN) $< $@

