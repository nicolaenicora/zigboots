const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = std.atomic.Stack;
const Error = @import("../bytes/buffer.zig").Error;
const CircularLifoList = @import("../list/circular.zig").CircularLifoList;

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        create: *const fn (allocator: std.mem.Allocator) T,

        allocator: std.mem.Allocator,
        queue: CircularLifoList(usize),

        pub fn init(allocator: std.mem.Allocator, createFn: *const fn (allocator: std.mem.Allocator) T) !Self {
            return Self{ .allocator = allocator, .queue = try CircularLifoList(usize).init(allocator, 100), .create = createFn };
        }

        pub fn pop(self: *Self) Error!T {
            if (self.queue.pop()) |n| {
                return @as(*T, @ptrFromInt(n)).*;
            }

            return self.create(self.allocator);
        }

        pub fn push(self: *Self, data: *const T) void {
            _ = self.queue.push(@as(usize, @intFromPtr(data)));
        }
    };
}
