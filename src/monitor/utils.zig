const swap = @import("std").mem.swap;

/// Reverse elements between `start` (inclusive) and `end` (exclusive).
pub inline fn reverse(comptime T: type, start: [*]T, end: [*]T) void {
    var p1 = start;
    var p2 = end - 1;

    while (@ptrToInt(p1) < @ptrToInt(p2)) {
        swap_noalias(T, &p1[0], &p2[0]);

        p1 += 1;
        p2 -= 1;
    }
}

inline fn swap_noalias(comptime T: type, noalias x: *T, noalias y: *T) void {
    if (@sizeOf(T) == 16 and @alignOf(T) >= 4) {
        var x1: usize = undefined;
        var x2: usize = undefined;
        var x3: usize = undefined;
        var x4: usize = undefined;
        var y1: usize = undefined;
        var y2: usize = undefined;
        var y3: usize = undefined;
        var y4: usize = undefined;
        asm volatile (
            \\ ldm %[x], {r2, r3, r4, r5}
            \\ ldm %[y], {r6, r8, r10, r11}
            \\ stm %[y], {r2, r3, r4, r5}
            \\ stm %[x], {r6, r8, r10, r11}
            :
            : [x] "r" (x),
              [y] "r" (y)
            : "memory", "r2", "r3", "r4", "r5", "r6", "r11", "r8", "r10"
        );
    } else {
        swap(T, x, y);
    }
}
