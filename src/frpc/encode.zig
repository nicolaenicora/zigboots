const std = @import("std");
const Buffer = @import("../xstd/bytes/buffer.zig").Buffer;

const continuation = 0x80;

const Kind = enum(u8) { Nil = 0, Slice, Map, Any, Bytes, String, Error, Bool, UInt8, UInt16, UInt32, UInt64, Int32, Int64, Float32, Float64 };

pub fn @"null"(
    b: *Buffer,
) !void {
    var result = [1]u8{@as(u8, @intCast(@intFromEnum(Kind.Nil)))};
    _ = try b.write(result[0..]);
}

pub fn map(b: *Buffer, size: usize, key: Kind, value: Kind) !void {
    var result = [3]u8{ @as(u8, @intCast(@intFromEnum(Kind.Map))), @as(u8, @intCast(@intFromEnum(key))), @as(u8, @intCast(@intFromEnum(value))) };
    _ = try b.write(result[0..]);
    try uint32(b, size);
}

pub fn slice(b: *Buffer, size: usize, kind: Kind) !void {
    var result = [2]u8{ @as(u8, @intCast(@intFromEnum(Kind.Slice))), @as(u8, @intCast(@intFromEnum(kind))) };
    _ = try b.write(result[0..]);
    try uint32(b, size);
}

pub fn bytes(b: *Buffer, value: []const u8) !void {
    var result = [1]u8{@as(u8, @intCast(@intFromEnum(Kind.Bytes)))};
    _ = try b.write(result[0..]);
    try uint32(b, value.len);
    _ = try b.write(value[0..]);
}

pub fn string(b: *Buffer, value: []const u8) !void {
    var result = [1]u8{@as(u8, @intCast(@intFromEnum(Kind.String)))};
    _ = try b.write(result[0..]);

    try uint32(b, @as(u32, @intCast(value.len)));

    _ = try b.write(value);
}

pub fn err(b: *Buffer, comptime V: type, value: V) !void {
    var result = [1]u8{@intCast(@intFromEnum(Kind.Error))};
    _ = try b.write(result[0..]);

    var str_buf: [5000]u8 = undefined;
    const buf = try std.fmt.bufPrint(&str_buf, "{any}", .{value});
    try string(b, buf[0..]);
}

pub fn @"bool"(b: *Buffer, value: bool) !void {
    var result = [2]u8{ @as(u8, @intCast(@intFromEnum(Kind.Bool))), if (value) 1 else 0 };
    _ = try b.write(result[0..]);
}

pub fn uint8(b: *Buffer, value: u8) !void {
    var result = [2]u8{ @as(u8, @intCast(@intFromEnum(Kind.Uint8))), value };
    _ = try b.write(result[0..]);
}

pub fn uint16(b: *Buffer, value: u16) !void {
    var result = [6]u8{ @as(u8, @intCast(@intFromEnum(Kind.UInt16))), 0x00, 0x00, 0x00, 0x00, 0x00 };
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

pub fn uint32(b: *Buffer, value: u32) !void {
    var result = [6]u8{ @as(u8, @intCast(@intFromEnum(Kind.UInt32))), 0x00, 0x00, 0x00, 0x00, 0x00 };
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

pub fn uint64(b: *Buffer, value: u64) !void {
    var result = [9]u8{ @as(u8, @intCast(@intFromEnum(Kind.UInt64))), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
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

pub fn int32(b: *Buffer, value: i32) !void {
    var val = @as(u32, @bitCast(value)) << 1;
    if (value < 0) {
        val = ~val;
    }

    var result = [6]u8{ @as(u8, @intCast(@intFromEnum(Kind.Int32))), 0x00, 0x00, 0x00, 0x00, 0x00 };
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

pub fn int64(b: *Buffer, value: i64) !void {
    var val = @as(u64, @bitCast(value)) << 1;
    if (value < 0) {
        val = ~val;
    }

    var result = [11]u8{ @as(u8, @intCast(@intFromEnum(Kind.Int64))), 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00 };
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

pub fn float32(b: *Buffer, value: f32) !void {
    const val = @as(u32, @bitCast(value));
    const b24 = @as(u8, @truncate(val >> 24));
    const b16 = @as(u8, @truncate(val >> 16));
    const b8 = @as(u8, @truncate(val >> 8));
    const b0 = @as(u8, @truncate(val));
    const result = [5]u8{ @as(u8, @intCast(@intFromEnum(Kind.Float32))), b24, b16, b8, b0 };
    _ = try b.write(result[0..]);
}

pub fn float64(b: *Buffer, value: f64) !void {
    const val = @as(u64, @bitCast(value));
    const b56 = @as(u8, @truncate(val >> 56));
    const b48 = @as(u8, @truncate(val >> 48));
    const b40 = @as(u8, @truncate(val >> 40));
    const b32 = @as(u8, @truncate(val >> 32));
    const b24 = @as(u8, @truncate(val >> 24));
    const b16 = @as(u8, @truncate(val >> 16));
    const b8 = @as(u8, @truncate(val >> 8));
    const b0 = @as(u8, @truncate(val));
    const result = [9]u8{ @as(u8, @intCast(@intFromEnum(Kind.Float32))), b56, b48, b40, b32, b24, b16, b8, b0 };

    _ = try b.write(result[0..]);
}
