const std = @import("std");
const Logger = @import("xstd/logger.zig").Logger(.simple, .nanos, "YYYY MMM Do dddd HH:mm:ss.SSS - Qo");

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});
}
