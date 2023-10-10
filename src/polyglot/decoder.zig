const std = @import("std");
const decode = @import("decode.zig");

const Self = @This();

buff: []const u8,

pub fn init(bytes: []const u8) Self {
    return Self{ .buff = bytes };
}

pub fn Nil(self: *Self) !bool {
    const r = try decode.Nil(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Map(self: *Self) !u32 {
    const r = try decode.Map(self.buff);
    self.buff = r.buff;
    return r.val;
}

pub fn Slice(self: *Self) !u32 {
    const r = try decode.Slice(self.buff);
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

pub fn Error(self: *Self) ![]const u8 {
    const r = try decode.Error(self.buff);
    self.buff = r.buff;
    return r.val;
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
