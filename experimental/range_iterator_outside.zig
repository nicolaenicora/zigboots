const std = @import("std");
const testing = std.testing;

const Allocator = std.mem.Allocator;
/// Generic iterator interface. Call next to get the next element or
/// null if the iterator's exhausted. Call reset to start iteration
/// over from the beginning.
pub fn Iterator(comptime T: type, comptime TargetSelf: type) type {
    return struct {
        const Self = @This();

        target_self: *TargetSelf,
        nextFn: *const fn (self: *TargetSelf) ?T,

        pub fn next(self: Self) ?T {
            std.debug.print("target_self {*}\n", .{self.target_self});
            return self.nextFn(self.target_self);
        }
    };
}

pub fn RangeIterator(comptime T: type) type {
    return struct {
        const SelfRangeIterator = @This();

        target_self: *Range(T),
        iterator: Iterator(T, SelfRangeIterator),

        next_val: T,

        /// Return the next element in the range, or null if the range
        /// has been exhausted.
        pub fn next(self: *SelfRangeIterator) ?T {
            // const self = @fieldParentPtr(Self, "iterator", iterator);

            std.debug.print("next received self pointer {*}\n", .{self});
            const rv = self.next_val;
            if (self.target_self.*.step < 0 and rv <= self.target_self.*.end) {
                return null;
            } else if (rv >= self.target_self.*.end) {
                return null;
            }

            self.next_val += self.target_self.*.step;
            return rv;
        }

        /// Initialize. Returns error if step size is invalid.
        pub fn init(source: *Range(T)) !*SelfRangeIterator {
            var range_ptr = try source.allocator.create(SelfRangeIterator);
            range_ptr.* = SelfRangeIterator{ .target_self = source, .next_val = source.*.start, .iterator = Iterator(T, SelfRangeIterator){ .nextFn = next, .target_self = range_ptr } };
            std.debug.print("iterator instantiated pointer {*}\n", .{range_ptr});
            return range_ptr;
        }
    };
}

pub fn Range(comptime T: type) type {
    return struct {
        allocator: Allocator,

        step: T,
        start: T,
        end: T,

        pub fn iterator(self: *Range(T)) !*RangeIterator(T) {
            return RangeIterator(T).init(self);
        }
        /// Initialize. Returns error if step size is invalid.
        pub fn init(allocator: Allocator, start: T, end: T, step: T) !Range(T) {
            if (step == 0) {
                return error.ZeroStepSize;
            }

            return Range(T){ .allocator = allocator, .start = start, .end = end, .step = step };
        }
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    const start: i32 = -2;
    var range = try Range(i32).init(alloc, start, 10, 1);
    const iter = try range.iterator();
    std.debug.print("optained iterator pointer {*}\n", .{iter});
    var correct: i32 = start;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 1;
    }
}
