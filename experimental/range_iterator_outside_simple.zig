const std = @import("std");
const testing = std.testing;

pub fn Iterator(comptime T: type) type {
    return struct {
        nextFn: *const fn (self: *Iterator(T)) ?T,

        pub fn next(self: *Iterator(T)) ?T {
            return self.nextFn(self);
        }
    };
}

pub fn RangeIterator(comptime T: type, comptime Target: type) type {
    return struct {
        const Self = @This();

        target_self: Target,
        iterator: Iterator(T),

        next_val: T,

        pub fn next(iterator: *Iterator(T)) ?T {
            const self = @fieldParentPtr(Self, "iterator", iterator);

            const rv = self.next_val;
            if (self.target_self.step < 0) {
                if (rv <= self.target_self.end) {
                    return null;
                }
            } else {
                if (rv >= self.target_self.end) {
                    return null;
                }
            }

            self.next_val += self.target_self.step;

            return rv;
        }

        pub fn init(source: Target) Self {
            return Self{ .target_self = source, .next_val = source.start, .iterator = Iterator(T){ .nextFn = next } };
        }
    };
}

pub fn Range(comptime T: type) type {
    return extern struct {
        const Self = @This();

        step: T,
        start: T,
        end: T,

        pub fn range_iterator(self: Self) RangeIterator(T, Self) {
            return RangeIterator(T, Self).init(self);
        }

        pub fn init(start: T, end: T, step: T) Self {
            return Self{ .start = start, .end = end, .step = step };
        }
    };
}

pub fn main() !void {
    const range = Range(i32).init(-2, 10, 1);
    const rangeIter = range.range_iterator();
    const iter = @constCast(&rangeIter.iterator);

    std.debug.print("Range after getting the iterator {}\n", .{rangeIter});

    var correct: i32 = -2;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 1;
    }
}
