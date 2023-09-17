const std = @import("std");
const builtin = @import("builtin");

const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;

const Type = enum(u2) {
    FIFO = 0,
    LIFO,
};

pub fn CircularLifoList(comptime T: type) type {
    return CircularList(T, .LIFO);
}

pub fn CircularFifoList(comptime T: type) type {
    return CircularList(T, .FIFO);
}

pub fn CircularList(comptime T: type, comptime LType: Type) type {
    return CircularListAligned(T, !builtin.single_threaded, LType, null);
}

pub fn CircularListAligned(comptime T: type, comptime threadsafe: bool, comptime LType: Type, comptime alignment: ?u29) type {
    if (alignment) |a| {
        if (a == @alignOf(T)) {
            return CircularListAligned(T, threadsafe, LType, null);
        }
    }
    return struct {
        const Self = @This();

        const Slice = if (alignment) |a| ([]align(a) T) else []T;

        mu: std.Thread.Mutex = std.Thread.Mutex{},
        items: Slice,

        tail: usize,
        head: usize,
        cap: usize,
        len: usize,

        allocator: Allocator,

        pub fn init(allocator: Allocator, cap: usize) Allocator.Error!Self {
            return Self{
                .items = try allocator.alignedAlloc(T, alignment, cap),
                .tail = 0,
                .head = 0,
                .cap = cap,
                .len = 0,
                .allocator = allocator,
            };
        }

        pub fn deinit(self: Self) void {
            self.allocator.free(self.items.ptr[0..self.cap]);
        }

        pub fn push(self: *Self, item: T) T {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            for (self.items) |it| {
                if (@intFromPtr(&it) == @intFromPtr(&item)) {
                    return item;
                }
            }

            return switch (LType) {
                inline .LIFO => self.pushLifo(item),
                inline .FIFO => self.pushFifo(item),
            };
        }

        inline fn pushLifo(self: *Self, item: T) T {
            var previous: T = self.items[self.tail];

            self.items[self.tail] = item;

            const idx = (self.tail + 1) % self.cap;
            @atomicStore(usize, &self.tail, idx, .Monotonic);

            if (self.len < self.cap) {
                @atomicStore(usize, &self.len, self.len + 1, .Monotonic);
            }

            return previous;
        }

        inline fn pushFifo(self: *Self, item: T) T {
            if (self.len == self.cap and self.tail == self.tail) {
                @atomicStore(usize, &self.head, self.head + 1, .Monotonic);
                if (self.head == self.cap) {
                    @atomicStore(usize, &self.head, 0, .Monotonic);
                }
            }

            return self.pushLifo(item);
        }

        pub fn pop(self: *Self) ?T {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            if (self.len == 0) {
                return null;
            }

            return switch (LType) {
                inline .LIFO => self.popLifo(),
                inline .FIFO => self.popFifo(),
            };
        }

        inline fn popLifo(self: *Self) T {
            var idx = self.head;
            var ptr = &self.head;
            if (idx == 0 and self.tail > 0) {
                idx = self.tail;
                ptr = &self.tail;
            } else if (idx == 0 and self.cap > 0) {
                idx = self.cap;
                ptr = &self.tail;
            }

            idx = (idx - 1) % self.cap;
            @atomicStore(usize, ptr, idx, .Monotonic);

            @atomicStore(usize, &self.len, self.len - 1, .Monotonic);
            return self.items[idx];
        }

        inline fn popFifo(self: *Self) T {
            var idx = self.head;

            const res = self.items[idx];
            idx = (idx + 1) % self.cap;
            @atomicStore(usize, &self.head, idx, .Monotonic);
            @atomicStore(usize, &self.len, self.len - 1, .Monotonic);

            if (self.len == 0 and self.head != self.tail) {
                @atomicStore(usize, &self.tail, 0, .Monotonic);
                @atomicStore(usize, &self.head, 0, .Monotonic);
            }

            return res;
        }

        pub fn read(self: Self, pos: usize) ?T {
            if (pos >= self.items.len or pos >= self.cap) {
                return null;
            }

            return self.items[pos];
        }
    };
}

const testing = std.testing;

test "fifo/push 1 element" {
    var cl = try CircularList(i32, true, .FIFO).init(testing.allocator, 5);
    defer cl.deinit();

    try testing.expectEqual(cl.len, 0);

    _ = cl.push(34);

    try testing.expectEqual(cl.len, 1);

    if (cl.pop()) |x| {
        try testing.expectEqual(x, 34);
    }

    try testing.expectEqual(cl.len, 0);
}

test "fifo/push 5 elements" {
    var cl = try CircularList(i32, true, .FIFO).init(testing.allocator, 5);
    defer cl.deinit();

    try testing.expectEqual(cl.len, 0);

    _ = cl.push(1);
    _ = cl.push(2);
    _ = cl.push(3);
    _ = cl.push(4);
    _ = cl.push(5);

    try testing.expectEqual(cl.len, 5);

    for (1..6) |i| {
        if (cl.pop()) |x| {
            try testing.expectEqual(x, @as(i32, @intCast(i)));
        }
    }

    try testing.expectEqual(cl.len, 0);
}

test "fifo/push 6 elements" {
    var cl = try CircularList(i32, true, .FIFO).init(testing.allocator, 5);
    defer cl.deinit();

    try testing.expectEqual(cl.len, 0);

    _ = cl.push(1);
    _ = cl.push(2);
    _ = cl.push(3);
    _ = cl.push(4);
    _ = cl.push(5);
    _ = cl.push(6);

    try testing.expectEqual(cl.len, 5);

    for (2..7) |i| {
        if (cl.pop()) |x| {
            try testing.expectEqual(x, @as(i32, @intCast(i)));
        }
    }

    try testing.expectEqual(cl.len, 0);
}

test "lifo/push 1 element" {
    var cl = try CircularList(i32, true, .LIFO).init(testing.allocator, 5);
    defer cl.deinit();

    try testing.expectEqual(cl.len, 0);

    _ = cl.push(34);

    try testing.expectEqual(cl.len, 1);

    if (cl.pop()) |x| {
        try testing.expectEqual(x, 34);
    }

    try testing.expectEqual(cl.len, 0);
}

test "lifo/push 5 elements" {
    var cl = try CircularList(i32, true, .LIFO).init(testing.allocator, 5);
    defer cl.deinit();

    try testing.expectEqual(cl.len, 0);

    _ = cl.push(5);
    _ = cl.push(4);
    _ = cl.push(3);
    _ = cl.push(2);
    _ = cl.push(1);

    try testing.expectEqual(cl.len, 5);

    for (1..6) |i| {
        if (cl.pop()) |x| {
            try testing.expectEqual(x, @as(i32, @intCast(i)));
        }
    }

    try testing.expectEqual(cl.len, 0);
}

test "lifo/push 6 elements" {
    var cl = try CircularList(i32, true, .LIFO).init(testing.allocator, 5);
    defer cl.deinit();

    try testing.expectEqual(cl.len, 0);

    _ = cl.push(6);
    _ = cl.push(5);
    _ = cl.push(4);
    _ = cl.push(3);
    _ = cl.push(2);
    _ = cl.push(1);

    try testing.expectEqual(cl.len, 5);

    for (1..6) |i| {
        if (cl.pop()) |x| {
            try testing.expectEqual(x, @as(i32, @intCast(i)));
        }
    }

    try testing.expectEqual(cl.len, 0);
}

// const std = @import("std");
// const debug = std.debug;
// const assert = debug.assert;
// const math = std.math;
// const mem = std.mem;
// const Allocator = mem.Allocator;

// const CircularList = @import("circular_list.zig").CircularList;

// const Package = struct {
//     value: i128,
// };

// fn printList(l: CircularList(i32, true)) void {
//     for (0..l.cap) |i| {
//         if (l.read(i)) |x| {
//             std.debug.print("{}, ", .{x});
//         }
//     }
// }

// pub fn main() !void {
//     std.debug.print("Starting application.\n", .{});

//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();

//     const allocator = arena.allocator();

//     const list = try CircularList(i32, true).initAsFifo(allocator, 5);
//     defer list.deinit();

//     const d = @constCast(&list);
//     d.push(1);
//     d.push(2);
//     d.push(3);
//     d.push(4);

//     printList(list);
//     std.debug.print("\n", .{});

//     if (d.pop()) |x| {
//         std.debug.print("\n======== Pop ======== : {}\n", .{x});

//         printList(list);
//         std.debug.print("\n", .{});
//     }

//     d.push(5);
//     d.push(6);
//     d.push(7);

//     printList(list);
//     std.debug.print("\n", .{});

//     if (d.pop()) |x| {
//         std.debug.print("\n======== Pop ======== : {}\n", .{x});
//         printList(list);
//         std.debug.print("\n", .{});
//     }

//     d.push(8);
//     d.push(9);

//     printList(list);
//     std.debug.print("\n", .{});

//     std.debug.print("\n======== Pop ======== : ", .{});
//     while (d.pop()) |x| {
//         std.debug.print("{},", .{x});
//     }
//     std.debug.print("\n", .{});

//     d.push(10);
//     d.push(11);
//     d.push(12);
//     d.push(13);
//     d.push(14);

//     printList(list);
//     std.debug.print("\n", .{});

//     std.debug.print("\n======== Pop ======== : ", .{});
//     while (d.pop()) |x| {
//         std.debug.print("{},", .{x});
//     }

//     std.debug.print("\n", .{});
// }
