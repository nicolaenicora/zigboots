const std = @import("std");
const encode = @import("encode.zig");
const Kind = @import("common.zig").Kind;

const Buffer = @import("../xstd/bytes/buffer.zig").Buffer;

const Self = @This();

buff: *Buffer,

pub fn init(b: *Buffer) Self {
    return Self{ .buff = b };
}

pub fn Nil(self: *Self) !*Self {
    try encode.Nil(self.buff);
    return self;
}

pub fn Map(self: *Self, size: u32, key: Kind, value: Kind) !*Self {
    try encode.Map(self.buff, size, key, value);
    return self;
}

pub fn Slice(self: *Self, kind: Kind) !*Self {
    try encode.Slice(self.buff, kind);
    return self;
}

pub fn Bytes(self: *Self, value: []const u8) !*Self {
    try encode.Bytes(self.buff, value);
    return self;
}

pub fn String(self: *Self, value: []const u8) !*Self {
    try encode.String(self.buff, value);
    return self;
}

pub fn Error(self: *Self, comptime V: type, value: V) !*Self {
    try encode.Error(self.buff, V, value);
    return self;
}

pub fn Bool(self: *Self, value: bool) !*Self {
    try encode.Bool(self.buff, value);
    return self;
}

pub fn Uint8(self: *Self, value: u8) !*Self {
    try encode.Uint8(self.buff, value);
    return self;
}

pub fn Uint16(self: *Self, value: u16) !*Self {
    try encode.Uint16(self.buff, value);
    return self;
}

pub fn Uint32(self: *Self, value: u32) !*Self {
    try encode.Uint32(self.buff, value);
    return self;
}

pub fn Uint64(self: *Self, value: u64) !*Self {
    try encode.Uint64(self.buff, value);
    return self;
}

pub fn Int32(self: *Self, value: i32) !*Self {
    try encode.Int32(self.buff, value);
    return self;
}

pub fn Int64(self: *Self, value: i64) !*Self {
    try encode.Int64(self.buff, value);
    return self;
}

pub fn Float32(self: *Self, value: f32) !*Self {
    try encode.Float32(self.buff, value);
    return self;
}

pub fn Float64(self: *Self, value: f64) !*Self {
    try encode.Float64(self.buff, value);
    return self;
}
