const std = @import("std");

const ArenaAllocator = std.heap.ArenaAllocator;
const eql = std.mem.eql;
const assert = std.debug.assert;

const Buffer = @import("../xstd/bytes/buffer.zig").Buffer;

const polyglot = @import("types.zig");

const E = error{NoComment};

test "Basic Usage" {
    // Use your favorite allocator
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var buf = Buffer.init(arena.allocator());
    defer buf.deinit();

    var encoder = polyglot.encoder.init(&buf);

    _ = try encoder.Nil();
    _ = try encoder.Int64(255);
    _ = try encoder.Int32(512);
    _ = try encoder.Uint8(255);
    _ = try encoder.Uint16(23);
    _ = try encoder.Uint32(230);
    _ = try encoder.Uint64(2300);
    _ = try encoder.Error(E.NoComment);
    _ = try encoder.Bool(true);
    _ = try encoder.String("HURAAAA");
    _ = try encoder.Bytes("Array of bytes");
    _ = try encoder.Slice(3, polyglot.Kind.UInt16);
    _ = try encoder.Uint16(1);
    _ = try encoder.Uint16(2);
    _ = try encoder.Uint16(3);
    _ = try encoder.Map(3, polyglot.Kind.String, polyglot.Kind.UInt64);
    _ = try encoder.String("key1");
    _ = try encoder.UInt64(1);
    _ = try encoder.String("key2");
    _ = try encoder.UInt64(2);
    _ = try encoder.String("key3");
    _ = try encoder.UInt64(3);

    const bufBytes = buf.bytes();

    var decoder = polyglot.decoder.init(bufBytes);

    assert(eql(bool, decoder.Nil(), true));
    assert(eql(i64, try decoder.Int64(), 255));
    assert(eql(i32, try decoder.Int32(), 512));
    assert(eql(u8, try decoder.Uint8(), 255));
    assert(eql(u16, try decoder.Uint16(), 23));
    assert(eql(u32, try decoder.Uint32(), 230));
    assert(eql(u64, try decoder.Uint64(), 2300));
    assert(eql(E, try decoder.Error().?, E.NoComment));
    assert(eql(bool, decoder.Bool(), true));
    assert(eql([]const u8, try decoder.String(), "HURAAAA"));
    assert(eql([]const u8, try decoder.Bytes(), "Array of bytes"));
    assert(eql(u8, try decoder.Slice(polyglot.Kind.UInt8), 3));
    assert(eql(u16, try decoder.Uint16(), 1));
    assert(eql(u16, try decoder.Uint16(), 2));
    assert(eql(u16, try decoder.Uint16(), 3));

    assert(eql(u32, try decoder.Map(polyglot.Kind.String, polyglot.Kind.UInt64), 3));
    assert(eql([]const u8, try decoder.String(), "key1"));
    assert(eql(u32, try decoder.Uint64(), 1));
    assert(eql([]const u8, try decoder.String(), "key2"));
    assert(eql(u32, try decoder.Uint64(), 2));
    assert(eql([]const u8, try decoder.String(), "key3"));
    assert(eql(u32, try decoder.Uint64(), 3));
}

// const std = @import("std");
// const Logger = @import("xstd/logger.zig").Logger(.simple, .nanos, "YYYY MMM Do dddd HH:mm:ss.SSS - Qo");

// const Buffer = @import("xstd/bytes/buffer.zig").Buffer;

// const Encoder = @import("polyglot/types.zig").Encoder;
// const Decoder = @import("polyglot/types.zig").Decoder;
// const Kind = @import("polyglot/types.zig").Kind;

// const E = error{ NoComment, WithComment };
// const E1 = error{WithComment};

// pub fn main() !void {
//     std.debug.print("Starting application.\n", .{});

//     var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
//     defer arena.deinit();

//     const allocator = arena.allocator();

//     var buf = Buffer.init(allocator);
//     defer buf.deinit();

//     var encoder = Encoder.init(&buf);

//     _ = try encoder.Nil();
//     _ = try encoder.Int64(255);
//     _ = try encoder.Int32(512);
//     _ = try encoder.Uint8(255);
//     _ = try encoder.Uint16(23);
//     _ = try encoder.Uint32(230);
//     _ = try encoder.Uint64(2300);
//     _ = try encoder.Error(E.NoComment);
//     _ = try encoder.Bool(true);
//     _ = try encoder.String("HURAAAA");
//     _ = try encoder.Bytes("Array of bytes");
//     _ = try encoder.Slice(3, Kind.UInt8);
//     _ = try encoder.Uint8(1);
//     _ = try encoder.Uint8(2);
//     _ = try encoder.Uint8(3);

//     _ = try encoder.Map(3, Kind.String, Kind.UInt64);
//     _ = try encoder.String("key1");
//     _ = try encoder.Uint64(1);
//     _ = try encoder.String("key2");
//     _ = try encoder.Uint64(2);
//     _ = try encoder.String("key3");
//     _ = try encoder.Uint64(3);

//     const bufBytes = buf.bytes();
//     std.debug.print("Buffer - {any}\n", .{bufBytes});

//     var decoder = Decoder.init(bufBytes);
//     std.debug.print("Nil - {any}\n", .{decoder.Nil()});
//     std.debug.print("Int64 - {any}\n", .{try decoder.Int64()});
//     std.debug.print("Int32 - {any}\n", .{try decoder.Int32()});
//     std.debug.print("Uint8 - {any}\n", .{try decoder.Uint8()});
//     std.debug.print("Uint16 - {any}\n", .{try decoder.Uint16()});
//     std.debug.print("Uint32 - {any}\n", .{try decoder.Uint32()});
//     std.debug.print("Uint64 - {any}\n", .{try decoder.Uint64()});
//     std.debug.print("Error - {any}\n", .{try decoder.Error(E)});
//     std.debug.print("Bool - {any}\n", .{try decoder.Bool()});
//     std.debug.print("String - {s}\n", .{try decoder.String()});
//     std.debug.print("Bytes - {s}\n", .{try decoder.Bytes()});
//     std.debug.print("Slice Size- {any}\n", .{try decoder.Slice(Kind.UInt8)});
//     std.debug.print("Slice 1- {}\n", .{try decoder.Uint8()});
//     std.debug.print("Slice 2- {}\n", .{try decoder.Uint8()});
//     std.debug.print("Slice 3- {}\n", .{try decoder.Uint8()});

//     std.debug.print("Slice Size- {any}\n", .{try decoder.Map(Kind.String, Kind.UInt64)});
//     std.debug.print("Map k1- {s}\n", .{try decoder.String()});
//     std.debug.print("Map k1- {any}\n", .{try decoder.Uint64()});
//     std.debug.print("Map k2- {s}\n", .{try decoder.String()});
//     std.debug.print("Map k2- {any}\n", .{try decoder.Uint64()});
//     std.debug.print("Map k3- {s}\n", .{try decoder.String()});
//     std.debug.print("Map k3- {any}\n", .{try decoder.Uint64()});
// }
