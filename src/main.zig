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

    try encode.Int64(&buf, 255);
    try encode.UInt16(&buf, 23);

    const bufBytes = buf.bytes();
    std.debug.print("Buffer - {any}\n", .{bufBytes});

    const decode = frpc.decode;
    const r1 = try decode.Int64(bufBytes);
    std.debug.print("Result - {any}\n", .{r1});

    const r2 = try decode.UInt16(r1.buff);
    std.debug.print("Result - {any}\n", .{r2});
}
