const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;

const CircularLifoList = @import("list/circular.zig").CircularLifoList;
const CircularFifoList = @import("list/circular.zig").CircularFifoList;

const Package = struct {
    value: i128,
};

fn printList(l: CircularLifoList(i32)) void {
    for (0..l.cap) |i| {
        if (l.read(i)) |x| {
            std.debug.print("{}, ", .{x});
        }
    }
}

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var d = try CircularLifoList(i32).init(allocator, 5);
    defer d.deinit();

    _ = d.push(1);
    _ = d.push(2);
    _ = d.push(3);
    _ = d.push(4);

    printList(d);
    std.debug.print("\n", .{});

    if (d.pop()) |x| {
        std.debug.print("\n======== Pop ======== : {}\n", .{x});

        printList(d);
        std.debug.print("\n", .{});
    }

    _ = d.push(5);
    _ = d.push(6);
    _ = d.push(7);

    printList(d);
    std.debug.print("\n", .{});

    if (d.pop()) |x| {
        std.debug.print("\n======== Pop ======== : {}\n", .{x});
        printList(d);
        std.debug.print("\n", .{});
    }

    _ = d.push(8);
    _ = d.push(9);

    printList(d);
    std.debug.print("\n", .{});

    std.debug.print("\n======== Pop ======== : ", .{});
    while (d.pop()) |x| {
        std.debug.print("{},", .{x});
    }
    std.debug.print("\n", .{});

    _ = d.push(11);
    _ = d.push(12);
    _ = d.push(13);
    _ = d.push(14);
    _ = d.push(15);
    _ = d.push(16);
    _ = d.push(17);
    _ = d.push(18);

    printList(d);
    std.debug.print("\n", .{});

    try d.resize(10);
    std.debug.print("Resized to 10 =>", .{});

    _ = d.push(18);
    _ = d.push(19);
    _ = d.push(20);
    _ = d.push(21);
    _ = d.push(22);
    _ = d.push(23);
    _ = d.push(24);

    printList(d);
    std.debug.print("\n", .{});

    try d.resize(5);
    std.debug.print("Resized to 5 =>", .{});

    printList(d);
    std.debug.print("\n", .{});

    std.debug.print("\n======== Pop ======== : ", .{});
    while (d.pop()) |x| {
        std.debug.print("{},", .{x});
    }

    std.debug.print("\n", .{});
}
