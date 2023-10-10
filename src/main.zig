const std = @import("std");
const Logger = @import("xstd/logger.zig").Logger(.simple, .nanos, "YYYY MMM Do dddd HH:mm:ss.SSS - Qo");

const Buffer = @import("xstd/bytes/buffer.zig").Buffer;

const polyglot = @import("polyglot/types.zig");

const E = error{NoComment};

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var buf = Buffer.init(allocator);
    defer buf.deinit();

    var encoder = polyglot.encoder.init(&buf);

    _ = try encoder.Int64(255);
    _ = try encoder.Uint16(23);
    _ = try encoder.Error(E, E.NoComment);

    const bufBytes = buf.bytes();
    std.debug.print("Buffer - {any}\n", .{bufBytes});

    var decoder = polyglot.decoder.init(bufBytes);
    std.debug.print("Result - {any}\n", .{try decoder.Int64()});
    std.debug.print("Result - {any}\n", .{try decoder.Uint16()});
    std.debug.print("Result - {s}\n", .{try decoder.Error()});
}
