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

pub fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        step: T,
        start: T,
        end: T,

        pub fn range_iterator(self: Self) RangeIterator {
            return RangeIterator.init(self);
        }
        /// Initialize. Returns error if step size is invalid.
        pub fn init(start: T, end: T, step: T) !Self {
            if (step == 0) {
                return error.ZeroStepSize;
            }

            return Self{ .start = start, .end = end, .step = step };
        }

        const RangeIterator = struct {
            const SelfRangeIterator = @This();

            target_self: Self,
            iterator: Iterator(T),

            next_val: T,

            pub fn next(iter: *Iterator(T)) ?T {
                const self = @fieldParentPtr(SelfRangeIterator, "iterator", iter);

                const rv = self.next_val;
                if (self.target_self.step < 0 and rv <= self.target_self.end) {
                    return null;
                } else if (rv >= self.target_self.end) {
                    return null;
                }

                self.next_val += self.target_self.step;
                return rv;
            }

            pub fn init(source: Self) SelfRangeIterator {
                return SelfRangeIterator{ .target_self = source, .next_val = source.start, .iterator = Iterator(T){ .nextFn = next } };
            }
        };
    };
}

pub fn main() !void {
    const range = try Range(i32).init(-2, 10, 1);
    const rangeIter = range.range_iterator();
    const iter = @constCast(&rangeIter.iterator);

    std.debug.print("optained iterator pointer {}\n", .{rangeIter});
    var correct: i32 = -2;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 1;
    }
}
