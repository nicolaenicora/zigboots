const std = @import("std");
const builtin = @import("builtin");

pub const StringBuilder = @import("utf8_buffer.zig").Utf8Buffer(!builtin.single_threaded);
