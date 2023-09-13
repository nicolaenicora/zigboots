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

const pool = @import("bytes/pool.zig");

pub fn NewUtf8Buffer(ctx: pool.Context) Error!Utf8Buffer(false) {
    return try Utf8Buffer(false).initWithCapacity(ctx.allocator, 250);
}

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // var utf8BufferPool = Utf8BufferPool(true).init(allocator);
    // var sb = try utf8BufferPool.pop();
    // defer sb.deinit();

    const ctx = pool.Context{ .allocator = allocator };
    var utf8BufferPool = pool.Pool(Utf8Buffer(false), NewUtf8Buffer).init(ctx).interface();
    var sb = try utf8BufferPool.pop();

    try sb.append("A");
    try sb.append("\u{5360}");
    try sb.append("💯");
    try sb.append("Hell");

    const d = sb.rawLength();
    std.debug.print("{any}\n", .{d});

    std.debug.print("{s}\n", .{sb.bytes()});

    try sb.pushAt("🔥", 1);

    if (sb.at(1)) |v| {
        std.debug.print("{s}\n", .{v});
    }

    std.debug.print("{s}\n", .{sb.bytes()});

    if (sb.compare("A🔥\u{5360}💯Hell")) {
        std.debug.print("--->Huraa te same.<---\n", .{});
    }

    try sb.removeFrom(sb.rawLength() - 1);

    utf8BufferPool.push(sb);

    sb = try utf8BufferPool.pop();

    try sb.append("-Second Round");
    std.debug.print("{s}\n", .{sb.bytes()});

    utf8BufferPool.push(sb);
}
