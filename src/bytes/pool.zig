const std = @import("std");
const Allocator = std.mem.Allocator;
const Queue = std.atomic.Queue;
const Error = @import("../bytes/buffer.zig").Error;
const CircularLifoList = @import("../list/circular.zig").CircularLifoList;

pub fn Pool(comptime T: type) type {
    return struct {
        const Self = @This();

        create: *const fn (allocator: std.mem.Allocator) Error!T,

        allocator: std.mem.Allocator,
        queue: CircularLifoList(T),

        pub fn init(allocator: std.mem.Allocator, createFn: *const fn (allocator: std.mem.Allocator) Error!T) !Self {
            return Self{ .allocator = allocator, .queue = try CircularLifoList(T).init(allocator, 500), .create = createFn };
        }

        pub fn pop(self: *Self) Error!T {
            if (self.queue.pop()) |n| {
                return n;
            }

            return try self.create(self.allocator);
        }

        pub fn push(self: *Self, data: T) void {
            var d = self.queue.push(data);
            const l = d.rawLength();
            _ = l;
        }
    };
}
