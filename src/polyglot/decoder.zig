const std = @import("std");
const decode = @import("decode.zig");
const Kind = @import("types.zig").Kind;

const Self = @This();

buff: []const u8,

pub fn init(bytes: []const u8) Self {
    return Self{ .buff = bytes };
}

pub fn Nil(self: *Self) bool {
    const r = decode.Nil(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Map(self: *Self, key: Kind, value: Kind) !u32 {
    const r = try decode.Map(self.buff, key, value);
    self.buff = r.buff;
    return r.val;
}

pub fn Slice(self: *Self, kind: Kind) !u32 {
    const r = try decode.Slice(self.buff, kind);
    self.buff = r.buff;
    return r.val;
}

pub fn Bytes(self: *Self) ![]const u8 {
    const r = try decode.Bytes(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn String(self: *Self) ![]const u8 {
    const r = try decode.String(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn ErrorAsString(self: *Self) ![]const u8 {
    const r = try decode.Error(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Error(self: *Self, comptime T: type) !?T {
    return stringToError(T, try self.ErrorAsString());
}

pub fn Bool(self: *Self) !bool {
    const r = try decode.Bool(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Uint8(self: *Self) !u8 {
    const r = try decode.Uint8(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Uint16(self: *Self) !u16 {
    const r = try decode.Uint16(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Uint32(self: *Self) !u32 {
    const r = try decode.Uint32(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Uint64(self: *Self) !u64 {
    const r = try decode.Uint64(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Int32(self: *Self) !i32 {
    const r = try decode.Int32(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Int64(self: *Self) !i64 {
    const r = try decode.Int64(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Float32(self: *Self) !f32 {
    const r = try decode.Float32(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Float64(self: *Self) !f64 {
    const r = try decode.Float64(self.buff);
    self.buff = r.buff;
    return r.val;
}

fn stringToError(comptime T: type, str: []const u8) ?T {
    if (@typeInfo(T).ErrorSet.?.len <= 100) {
        const kvs = comptime blk: {
            const ErrorKV = struct { []const u8, T };
            var kvs_array: [@typeInfo(T).ErrorSet.?.len]ErrorKV = undefined;

            inline for (@typeInfo(T).ErrorSet.?, 0..) |errField, i| {
                kvs_array[i] = .{ errField.name, @field(T, errField.name) };
            }

            break :blk kvs_array[0..];
        };
        return std.ComptimeStringMap(T, kvs).get(str);
    } else {
        inline for (@typeInfo(T).ErrorSet.?) |errField| {
            if (std.mem.eql(u8, str, errField.name)) {
                return @field(T, errField.name);
            }
        }
        return null;
    }
}
