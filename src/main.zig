const std = @import("std");
const Logger = @import("xstd/logger.zig").Logger(.simple, .nanos, "YYYY MMM Do dddd HH:mm:ss.SSS - Qo");

const Buffer = @import("xstd/bytes/buffer.zig").Buffer;

const frpc = @import("frpc/types.zig");

const E = error{NoComment};

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var buf = Buffer.init(allocator);
    defer buf.deinit();

    const encode = frpc.encode;

    try encode.bool(&buf, false);
    try encode.float32(&buf, std.math.floatMax(f32));
    try encode.err(&buf, E, E.NoComment);

    std.debug.print("Buffer - {any}\n", .{buf.bytes()});
}
