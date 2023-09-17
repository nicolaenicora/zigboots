const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const math = std.math;
const mem = std.mem;
const Allocator = mem.Allocator;
const AllocatorError = mem.Allocator.Error;

const LoggerBuilder = @import("logger.zig").LoggerBuilder;
const Level = @import("logger.zig").Level;

const Error = @import("bytes/buffer.zig").Error;
const Utf8BufferPool = @import("bytes/utf8_buffer.zig").Utf8BufferPool;
const Utf8Buffer = @import("bytes/utf8_buffer.zig").Utf8Buffer;

const Pool = @import("bytes/pool.zig").Pool;

pub fn NewUtf8Buffer(allocator: std.mem.Allocator) Error!Utf8Buffer(false) {
    return try Utf8Buffer(false).initWithCapacity(allocator, 250);
}

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // var utf8BufferPool = Utf8BufferPool(true).init(allocator);
    // var sb = try utf8BufferPool.pop();
    // defer sb.deinit();

    var utf8BufferPool = try Pool(Utf8Buffer(false)).init(allocator, NewUtf8Buffer);
    var sb = try utf8BufferPool.pop();

    try sb.append("SB------");
    // try sb.append("A");
    // try sb.append("\u{5360}");
    // try sb.append("💯");
    // try sb.append("Hell");

    // const d = sb.rawLength();
    // std.debug.print("{any}\n", .{d});

    // std.debug.print("{s}\n", .{sb.bytes()});

    // try sb.pushAt("🔥", 1);

    // if (sb.at(1)) |v| {
    //     std.debug.print("{s}\n", .{v});
    // }

    // std.debug.print("{s}\n", .{sb.bytes()});

    // if (sb.compare("A🔥\u{5360}💯Hell")) {
    //     std.debug.print("--->Huraa te same.<---\n", .{});
    // }

    // try sb.removeFrom(sb.rawLength() - 1);

    utf8BufferPool.push(sb);

    sb = try utf8BufferPool.pop();
    try sb.append("-Second Round SB");
    std.debug.print("{s}\n", .{sb.bytes()});

    var sb2 = try utf8BufferPool.pop();
    try sb2.append("SB2------");
    try sb2.append("-Second Round SB2");
    std.debug.print("{s}\n", .{sb2.bytes()});

    utf8BufferPool.push(sb);
    utf8BufferPool.push(sb2);

    sb2 = try utf8BufferPool.pop();
    try sb2.append("Finally");
    std.debug.print("{s}\n", .{sb2.bytes()});

    sb = try utf8BufferPool.pop();
    try sb.append("Finally");
    std.debug.print("{s}\n", .{sb.bytes()});

    utf8BufferPool.push(sb);
    utf8BufferPool.push(sb2);

    sb = try utf8BufferPool.pop();
    try sb.append("Finally");
    std.debug.print("{s}\n", .{sb.bytes()});

    sb2 = try utf8BufferPool.pop();
    try sb2.append("Finally");
    std.debug.print("{s}\n", .{sb2.bytes()});

    var sb3 = try utf8BufferPool.pop();
    try sb3.append("SB3------");
    try sb3.append("New Finally");
    std.debug.print("{s}\n", .{sb3.bytes()});

    utf8BufferPool.push(sb);
    utf8BufferPool.push(sb2);
    utf8BufferPool.push(sb3);
    utf8BufferPool.push(sb3);

    std.debug.print("=============================\n", .{});
    sb3 = try utf8BufferPool.pop();
    std.debug.print("{s}\n", .{sb3.bytes()});
    sb3 = try utf8BufferPool.pop();
    std.debug.print("{s}\n", .{sb3.bytes()});
    sb2 = try utf8BufferPool.pop();
    std.debug.print("{s}\n", .{sb2.bytes()});
    sb = try utf8BufferPool.pop();
    std.debug.print("{s}\n", .{sb.bytes()});
}
