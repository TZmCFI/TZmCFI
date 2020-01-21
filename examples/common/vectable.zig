/// A comptime type for constructing an exception vector table for a Cortex-M
/// processor.
pub fn VecTable(comptime num_irqs: usize, comptime nameProvider: var) type {
    return extern struct {
        stack: ?extern fn () void,
        handlers: [num_irqs + 16]?extern fn () void,

        const Self = @This();

        pub fn new() Self {
            @setEvalBranchQuota(10000);
            comptime {
                var self: Self = undefined;
                self.stack = null;

                var i = 1;
                while (i < num_irqs + 16) : (i += 1) {
                    const name = nameProvider(i) orelse getDefaultName(i);
                    self.handlers[i - 1] = unhandled(name);
                }

                return self;
            }
        }

        // FIXME: `sp` is actually a pointer to non-code data, but Zig won't let us
        //        create a pointer to such entities (e.g., `extern var stack: u8`) in a constant
        //        context. (Hence the use of a function pointer)
        pub fn setInitStackPtr(self: Self, sp: ?extern fn () void) Self {
            var this = self;
            this.stack = sp;
            return this;
        }

        pub fn setExcHandler(self: Self, exc_number: usize, handler: ?extern fn () void) Self {
            var this = self;
            this.handlers[exc_number - 1] = handler;
            return this;
        }

        /// Register a TZmCFI-optimized exception handler.
        ///
        /// When using TZmCFI's exception trampolines, the performance of
        /// exception handlers can be improved by using an alternate calling
        /// convention in which exception handlers return directly to the
        /// exception return trampoline.
        ///
        /// This method creates a wrapper method to use this calling convention,
        /// and passes it to `setExcHandler`. It automatically changes it back
        /// to the default calling convention if the build option `HAS_TZMCFI_SES`
        /// is disabled.
        pub fn setTcExcHandler(self: Self, exc_number: usize, comptime handler: extern fn () void) Self {
            return self.setExcHandler(
                exc_number,
                struct {
                    fn _() callconv(.C) void {
                        @setTcExcHandler(@import("build_options").HAS_TZMCFI_SES);
                        @call(.{ .modifier = .always_inline }, handler, .{});
                    }
                }._,
            );
        }
    };
}

fn getDefaultName(comptime exc_number: usize) []const u8 {
    if (exc_number < 16) {
        return "???[" ++ intToStr(exc_number) ++ "]";
    } else {
        return "IRQ[" ++ intToStr(exc_number - 16) ++ "]";
    }
}

/// Create an "unhandled exception" handler.
fn unhandled(comptime name: []const u8) extern fn () void {
    const ns = struct {
        fn handler() callconv(.C) void {
            @panic("unhandled exception: " ++ name);
        }
    };
    return ns.handler;
}

fn intToStr(comptime i: var) []const u8 {
    comptime {
        if (i < 0) {
            @compileError("negative numbers are not supported (yet)");
        } else if (i == 0) {
            return "0";
        } else {
            var str: []const u8 = "";
            var ii = i;
            while (ii > 0) {
                str = [1]u8{'0' + ii % 10} ++ str;
                ii /= 10;
            }
            return str;
        }
    }
}
