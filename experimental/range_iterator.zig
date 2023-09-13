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

pub fn Range(comptime T: type) type {
    return struct {
        const Self = @This();

        allocator: Allocator,
        next_val: T,
        start: T,
        step: T,
        end: T,

        iterator: Iterator(T, Self),

        /// Return the next element in the range, or null if the range
        /// has been exhausted.
        pub fn next(self: *Self) ?T {
            // const self = @fieldParentPtr(Self, "iterator", iterator);

            std.debug.print("next received self pointer {*}\n", .{self});
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
        pub fn init(allocator: Allocator, start: T, end: T, step: T) !*Self {
            if (step == 0) {
                return error.ZeroStepSize;
            }

            var range_ptr = try allocator.create(Self);
            range_ptr.* = Self{ .allocator = allocator, .next_val = start, .start = start, .end = end, .step = step, .iterator = Iterator(T, Self){ .nextFn = next, .target_self = range_ptr } };
            return range_ptr;
        }
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const alloc = arena.allocator();

    var range = try Range(u32).init(alloc, 0, 10, 1);
    std.debug.print("range ptr received {*}\n", .{range});
    const iter = &(range.iterator);
    var correct: u32 = 0;
    while (iter.next()) |n| {
        try testing.expectEqual(correct, n);
        correct += 1;
    }
}
