const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
/// Generic iterator interface. Call next to get the next element or
/// null if the iterator's exhausted. Call reset to start iteration
/// over from the beginning.
pub fn Iterator(comptime T: type) type {
    return struct {
        const Self = @This();

        nextFn: *const fn (self: *Self) ?T,

        pub fn next(self: *Self) ?T {
            return self.nextFn(self);
        }
    };
}

pub fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        next_val: T,
        start: T,
        step: T,
        end: T,

        iterator: Iterator(T),

        /// Return the next element in the range, or null if the range
        /// has been exhausted.
        pub fn next(iterator: *Iterator(T)) ?T {
            const self = @fieldParentPtr(Self, "iterator", iterator);

            const rv = self.next_val;
            if (self.step < 0) {
                if (rv <= self.end) {
                    return null;
                }
            } else {
                if (rv >= self.end) {
                    return null;
                }
            }

            self.next_val += self.step;
            return rv;
        }

        /// Initialize. Returns error if step size is invalid.
        pub fn init(start: T, end: T, step: T) !Self {
            if (step == 0) {
                return error.ZeroStepSize;
            }

            return Self{ .next_val = start, .start = start, .end = end, .step = step, .iterator = Iterator(T){ .nextFn = next } };
        }
    };
}

pub fn main() !void {
    var range = try Range(u32).init(0, 10, 1);
    const iter = &(range.iterator);
    var correct: u32 = 0;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 1;
    }
}
