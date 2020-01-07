// LPC Flexcomm device driver

pub const Flexcomm = struct {
    base: usize,

    const Self = @This();

    /// Peripheral Select and Flexcomm Interface ID register
    pub fn regPselid(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xff8);
    }
    
    pub const PSELID_PERSEL_USART = 0x1;

    /// USART Configuration register. Basic USART configuration settings that 
    /// typically are not changed during operation.
    pub fn regUsartCfg(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x000);
    }

    pub const USART_CFG_ENABLE: u32 = 1 << 0;
    pub const USART_CFG_DATALEN_8BIT: u32 = 0x1 << 2;

    /// USART Baud Rate Generator register. 16-bit integer baud rate divisor value.
    pub fn regUsartBrg(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0x020);
    }

    /// FIFO configuration and enable register.
    pub fn regFifoCfg(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xe00);
    }

    pub const FIFO_CFG_ENABLETX: u32 = 1 << 0;
    pub const FIFO_CFG_ENABLERX: u32 = 1 << 1;

    /// FIFO status register.
    pub fn regFifoStat(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xe04);
    }

    pub const FIFO_STAT_TXNOTFULL: u32 = 1 << 5;

    /// FIFO trigger settings for interrupt and DMA request.
    pub fn regFifoTrig(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xe08);
    }

    /// FIFO write data.
    pub fn regFifoWr(self: Self) *volatile u32 {
        return @intToPtr(*volatile u32, self.base + 0xe20);
    }

    pub fn tryWrite(self: Self, data: u8) bool {
        if ((self.regFifoStat().* & FIFO_STAT_TXNOTFULL) == 0) {
            return false;
        }

        self.regFifoWr().* = data;
        return true;
    }

    pub fn write(self: Self, data: u8) void {
        while (!self.tryWrite(data)) {}
    }

    pub fn writeSlice(self: Self, data: []const u8) void {
        for (data) |b| {
            self.write(b);
        }
    }
};
