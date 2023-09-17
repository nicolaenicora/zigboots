const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = std.atomic.Stack;
const Error = @import("../bytes/buffer.zig").Error;
const CircularLifoList = @import("../list/circular.zig").CircularLifoList;

const PoolError = error{
    NoCapacity,
};

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        create: *const fn (allocator: std.mem.Allocator) T,

        allocator: std.mem.Allocator,
        queue: CircularLifoList(usize),

        counter: usize = 0,

        pub fn initWithCapacity(allocator: std.mem.Allocator, createFn: *const fn (allocator: std.mem.Allocator) T, cap: usize) !Self {
            return Self{ .allocator = allocator, .queue = try CircularLifoList(usize).init(allocator, cap), .create = createFn };
        }

        pub fn init(allocator: std.mem.Allocator, createFn: *const fn (allocator: std.mem.Allocator) T) !Self {
            return initWithCapacity(allocator, createFn, std.math.maxInt(u16));
        }

        pub fn pop(self: *Self) Error!T {
            if (self.queue.pop()) |n| {
                _ = @atomicRmw(usize, &self.counter, .Sub, 1, .Monotonic);

                return @as(*T, @ptrFromInt(n)).*;
            }

            return self.create(self.allocator);
        }

        pub fn push(self: *Self, data: *const T) PoolError!void {
            if (self.counter == self.queue.cap) {
                return PoolError.NoCapacity;
            }
            _ = @atomicRmw(usize, &self.counter, .Add, 1, .Monotonic);
            _ = self.queue.push(@as(usize, @intFromPtr(data)));
        }
    };
}
