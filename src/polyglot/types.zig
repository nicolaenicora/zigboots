pub const encode = @import("encode.zig");
pub const decode = @import("decode.zig");
pub const decoder = @import("decoder.zig");
pub const encoder = @import("encoder.zig");

pub const Kind = enum(u8) {
    Nil = 0,
    Slice,
    Map,
    Any,
    Bytes,
    String,
    Error,
    Bool,
    UInt8,
    UInt16,
    UInt32,
    UInt64,
    Int32,
    Int64,
    Float32,
    Float64,

    pub fn code(self: Kind) u8 {
        return @as(u8, @intCast(@intFromEnum(self)));
    }
};
pub const continuation = 0x80;
