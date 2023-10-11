const std = @import("std");
const Buffer = @import("../xstd/bytes/buffer.zig").Buffer;

const Kind = @import("types.zig").Kind;
const continuation = @import("types.zig").continuation;

pub const EncodingError = error{NotError};

pub fn Nil(
    b: *Buffer,
) !void {
    var result = [1]u8{Kind.Nil.code()};
    _ = try b.write(result[0..]);
}

pub fn Map(b: *Buffer, size: usize, key: Kind, value: Kind) !void {
    var result = [3]u8{ Kind.Map.code(), key.code(), value.code() };
    _ = try b.write(result[0..]);
    try Uint32(b, @as(u32, @intCast(size)));
}

pub fn Slice(b: *Buffer, size: usize, kind: Kind) !void {
    var result = [2]u8{ Kind.Slice.code(), kind.code() };
    _ = try b.write(result[0..]);
    try Uint32(b, @as(u32, @intCast(size)));
}

pub fn Bytes(b: *Buffer, value: []const u8) !void {
    var result = [1]u8{Kind.Bytes.code()};
    _ = try b.write(result[0..]);
    try Uint32(b, @as(u32, @intCast(value.len)));
    _ = try b.write(value[0..]);
}

pub fn String(b: *Buffer, value: []const u8) !void {
    var result = [1]u8{Kind.String.code()};
    _ = try b.write(result[0..]);

    try Uint32(b, @as(u32, @intCast(value.len)));

    _ = try b.write(value);
}

pub fn Error(b: *Buffer, value: anyerror) !void {
    var result = [1]u8{Kind.Error.code()};
    _ = try b.write(result[0..]);

    try String(b, @errorName(value));
}

pub fn Bool(b: *Buffer, value: bool) !void {
    var result = [2]u8{ Kind.Bool.code(), if (value) 1 else 0 };
    _ = try b.write(result[0..]);
}

pub fn Uint8(b: *Buffer, value: u8) !void {
    var result = [2]u8{ Kind.UInt8.code(), value };
    _ = try b.write(result[0..]);
}

pub fn Uint16(b: *Buffer, value: u16) !void {
    var result = [6]u8{ Kind.UInt16.code(), 0x00, 0x00, 0x00, 0x00, 0x00 };
    var pos: usize = 1;
    var val = value;
    while (val >= continuation) {
        result[pos] = @as(u8, @truncate(val | continuation));
        val >>= 7;
        pos += 1;
    }
    result[pos] = @as(u8, @intCast(val));
    pos += 1;

    _ = try b.write(result[0..pos]);
}

pub fn Uint32(b: *Buffer, value: u32) !void {
    var result = [6]u8{ Kind.UInt32.code(), 0x00, 0x00, 0x00, 0x00, 0x00 };
    var pos: usize = 1;
    var val = value;
    while (val >= continuation) {
        result[pos] = @as(u8, @truncate(val | continuation));
        val >>= 7;
        pos += 1;
    }
    result[pos] = @as(u8, @intCast(val));
    pos += 1;

    _ = try b.write(result[0..pos]);
}

pub fn Uint64(b: *Buffer, value: u64) !void {
    var result = [9]u8{ Kind.UInt64.code(), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    var pos: usize = 1;
    var val = value;
    while (val >= continuation) {
        result[pos] = @as(u8, @truncate(val | continuation));
        val >>= 7;
        pos += 1;
    }
    result[pos] = @as(u8, @intCast(val));
    pos += 1;

    _ = try b.write(result[0..pos]);
}

pub fn Int32(b: *Buffer, value: i32) !void {
    var val = @as(u32, @bitCast(value)) << 1;
    if (value < 0) {
        val = ~val;
    }

    var result = [6]u8{ Kind.Int32.code(), 0x00, 0x00, 0x00, 0x00, 0x00 };
    var pos: usize = 1;
    while (val >= continuation) {
        result[pos] = @as(u8, @truncate(val | continuation));
        val >>= 7;
        pos += 1;
    }
    result[pos] = @as(u8, @intCast(val));
    pos += 1;

    _ = try b.write(result[0..pos]);
}

pub fn Int64(b: *Buffer, value: i64) !void {
    var val = @as(u64, @bitCast(value)) << 1;
    if (value < 0) {
        val = ~val;
    }

    var result = [11]u8{ Kind.Int64.code(), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
    var pos: usize = 1;
    while (val >= continuation) {
        result[pos] = @as(u8, @truncate(val | continuation));
        val >>= 7;
        pos += 1;
    }
    result[pos] = @as(u8, @intCast(val));
    pos += 1;

    _ = try b.write(result[0..pos]);
}

pub fn Float32(b: *Buffer, value: f32) !void {
    const val = @as(u32, @bitCast(value));
    const b24 = @as(u8, @truncate(val >> 24));
    const b16 = @as(u8, @truncate(val >> 16));
    const b8 = @as(u8, @truncate(val >> 8));
    const b0 = @as(u8, @truncate(val));
    const result = [5]u8{ Kind.Float32.code(), b24, b16, b8, b0 };
    _ = try b.write(result[0..]);
}

pub fn Float64(b: *Buffer, value: f64) !void {
    const val = @as(u64, @bitCast(value));
    const b56 = @as(u8, @truncate(val >> 56));
    const b48 = @as(u8, @truncate(val >> 48));
    const b40 = @as(u8, @truncate(val >> 40));
    const b32 = @as(u8, @truncate(val >> 32));
    const b24 = @as(u8, @truncate(val >> 24));
    const b16 = @as(u8, @truncate(val >> 16));
    const b8 = @as(u8, @truncate(val >> 8));
    const b0 = @as(u8, @truncate(val));
    const result = [9]u8{ Kind.Float64.code(), b56, b48, b40, b32, b24, b16, b8, b0 };

    _ = try b.write(result[0..]);
}
