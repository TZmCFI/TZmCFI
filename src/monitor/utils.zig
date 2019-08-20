const swap = @import("std").mem.swap;

/// Reverse elements between `start` (inclusive) and `end` (exclusive).
pub fn reverse(comptime T: type, start: [*]T, end: [*]T) void {
    var p1 = start;
    var p2 = end - 1;

    while (@ptrToInt(p1) < @ptrToInt(p2)) {
        swap(T, &p1[0], &p2[0]);

        p1 += 1;
        p2 -= 1;
    }
}
