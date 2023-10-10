pub const DecodingError = error{ InvalidSlice, InvalidMap, InvalidBytes, InvalidString, InvalidError, InvalidBool, InvalidUint8, InvalidUint16, InvalidUint32, InvalidUint64, InvalidInt32, InvalidInt64, InvalidFloat32, InvalidFloat64 };
const std = @import("std");
const Buffer = @import("../xstd/bytes/buffer.zig").Buffer;

const Kind = @import("common.zig").Kind;
const continuation = @import("common.zig").continuation;

const VarIntLen16 = 3;
const VarIntLen32 = 5;
const VarIntLen64 = 10;

pub fn Result(comptime V: type) type {
    return struct {
        buff: []const u8,
        val: V,
    };
}

pub fn Nil(b: []const u8) Result(bool) {
    if (b.len > 0) {
        if (b[0] == Kind.Nil.code()) {
            return .{ .buff = b[1..], .val = true };
        }
    }
    return .{ b, false };
}

pub fn Map(b: []const u8, key: Kind, value: Kind) !Result(u32) {
    if (b.len > 2) {
        if (b[0] == Kind.Map.code() and b[1] == key.code() and b[2] == value.code()) {
            return try Uint32(b[3..]);
        }
    }
    return DecodingError.InvalidMap;
}

pub fn Slice(b: []const u8, kind: Kind) !Result(u32) {
    if (b.len > 1) {
        if (b[0] == Kind.Slice.code() and b[1] == kind.code()) {
            return try Uint32(b[2..]);
        }
    }
    return DecodingError.InvalidSlice;
}

pub fn Bytes(b: []const u8) !Result([]const u8) {
    if (b.len > 0) {
        if (b[0] == Kind.Bytes.code()) {
            const values = try Uint32(b[1..]);
            const buf: []const u8 = values[0];
            const size: usize = values[1];

            if (buf.len > size - 1) {
                return .{ .buff = buf[size..], .val = buf[0..size] };
            }
        }
    }
    return DecodingError.InvalidBytes;
}

fn String(b: []const u8) !Result([]const u8) {
    if (b.len > 0) {
        if (b[0] == Kind.String.code()) {
            const values = try Uint32(b[1..]);
            const buf: []const u8 = values[0];
            const size: usize = values[1];

            if (buf.len > size - 1) {
                return .{ .buff = buf[size..], .val = buf[0..size] };
            }
        }
    }
    return DecodingError.InvalidString;
}

pub fn Error(b: []const u8) !Result([]const u8) {
    if (b.len > 0) {
        if (b[0] == Kind.Error.code()) {
            return String(b[1..]);
        }
    }
    return DecodingError.InvalidError;
}

pub fn Bool(b: []const u8) !Result(bool) {
    if (b.len > 1) {
        if (b[0] == Kind.Bool.code()) {
            return .{ .buff = b[2..], .val = if (b[1] == 1) true else false };
        }
    }
    return DecodingError.InvalidBool;
}

pub fn Uint8(b: []const u8) !Result(u8) {
    if (b.len > 1) {
        if (b[0] == Kind.UInt8.code()) {
            return .{ .buff = b[2..], .val = b[1] };
        }
    }
    return DecodingError.InvalidUint8;
}

pub fn Uint16(b: []const u8) !Result(u16) {
    return try uint(b, u4, u16, Kind.UInt16, VarIntLen16, DecodingError.InvalidUint16);
}
pub fn Uint32(b: []const u8) !Result(u32) {
    return try uint(b, u5, u32, Kind.UInt32, VarIntLen32, DecodingError.InvalidUint32);
}
pub fn Uint64(b: []const u8) !Result(u64) {
    return try uint(b, u6, u64, Kind.UInt64, VarIntLen64, DecodingError.InvalidUint64);
}
fn uint(b: []const u8, comptime T: type, comptime R: type, kind: Kind, varIntLen: u8, err: DecodingError) !Result(R) {
    if (b.len > 1 and b[0] == kind.code()) {
        var x: R = 0;
        var s: T = 0;
        for (1..varIntLen + 1) |i| {
            const cb = b[i];
            // Check if msb is set signifying a continuation byte
            if (cb < continuation) {
                if (i > varIntLen and cb > 1) {
                    return err;
                }
                // End of varint, add the last bits and advance the buffer
                const bits = @as(T, @intCast(s));
                const n = @as(R, @intCast(cb));
                return .{ .buff = b[i + 1 ..], .val = x | n << bits };
            }
            // Add the lower 7 bits to the result and continue to the next byte
            const bits = @as(T, @intCast(s));
            const n = @as(R, @intCast(cb & (continuation - 1)));
            x |= n << bits;
            s += 7;
        }
    }
    return err;
}

pub fn Int32(b: []const u8) !Result(i32) {
    return int(b, u5, u32, i32, Kind.Int32, VarIntLen32, DecodingError.InvalidInt32);
}
pub fn Int64(b: []const u8) !Result(i64) {
    return int(b, u6, u64, i64, Kind.Int64, VarIntLen64, DecodingError.InvalidInt64);
}
fn int(b: []const u8, comptime T1: type, comptime T2: type, comptime R: type, kind: Kind, varIntLen: u8, err: DecodingError) !Result(R) {
    if (b.len > 1 and b[0] == kind.code()) {
        var ux: T2 = 0;
        var s: T1 = 0;
        for (1..varIntLen + 1) |i| {
            const cb = b[i];
            // Check if msb is set signifying a continuation byte
            if (cb < continuation) {
                if (i > varIntLen and cb > 1) {
                    return err;
                }
                // End of varint, add the last bits
                const bits = @as(T1, @intCast(s));
                const n = @as(T2, @intCast(cb));

                ux |= n << bits;
                // Separate value and sign
                var x = @as(R, @intCast(ux >> 1));
                // If sign bit is set, negate the number
                if ((ux & 1) != 0) {
                    x = -(x + 1);
                }
                return .{ .buff = b[i + 1 ..], .val = x };
            }
            const bits = @as(T1, @intCast(s));
            const n = @as(T2, @intCast(cb & (continuation - 1)));
            ux |= n << bits;
            s += 7;
        }
    }
    return err;
}

pub fn Float32(b: []const u8) !Result(f32) {
    if (b.len > 4) {
        if (b[0] == Kind.Float32.code()) {
            const b4 = @as(u32, @intCast(b[4]));
            const b3 = @as(u32, @intCast(b[3])) << 8;
            const b2 = @as(u32, @intCast(b[2])) << 16;
            const b1 = @as(u32, @intCast(b[1])) << 24;
            return .{ .buff = b[5..], .val = @as(f32, @bitCast(b4 | b3 | b2 | b1)) };
        }
    }
    return DecodingError.InvalidFloat32;
}

pub fn Float64(b: []const u8) !Result(f64) {
    if (b.len > 8) {
        if (b[0] == Kind.Float64.code()) {
            const b8 = @as(u64, @intCast(b[8]));
            const b7 = @as(u64, @intCast(b[7])) << 8;
            const b6 = @as(u64, @intCast(b[6])) << 16;
            const b5 = @as(u64, @intCast(b[5])) << 24;
            const b4 = @as(u64, @intCast(b[4])) << 32;
            const b3 = @as(u64, @intCast(b[3])) << 40;
            const b2 = @as(u64, @intCast(b[2])) << 48;
            const b1 = @as(u64, @intCast(b[1])) << 56;
            return .{ .buff = b[9..], .val = @as(f64, @bitCast(b8 | b7 | b6 | b5 | b4 | b3 | b2 | b1)) };
        }
    }
    return DecodingError.InvalidFloat32;
}
