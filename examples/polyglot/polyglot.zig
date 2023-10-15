const std = @import("std");
const xstd = @import("xstd");

const Buffer = xstd.bytes.Buffer;

const Encoder = @import("polyglot").Encoder;
const Decoder = @import("polyglot").Decoder;
const Kind = @import("polyglot").Kind;

const E = error{ NoComment, WithComment };
const E1 = error{WithComment};

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var buf = Buffer.init(allocator);
    defer buf.deinit();

    var encoder = Encoder.init(&buf);

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
    _ = try encoder.Slice(3, Kind.UInt8);
    _ = try encoder.Uint8(1);
    _ = try encoder.Uint8(2);
    _ = try encoder.Uint8(3);

    _ = try encoder.Map(3, Kind.String, Kind.UInt64);
    _ = try encoder.String("key1");
    _ = try encoder.Uint64(1);
    _ = try encoder.String("key2");
    _ = try encoder.Uint64(2);
    _ = try encoder.String("key3");
    _ = try encoder.Uint64(3);

    const bufBytes = buf.bytes();
    std.debug.print("Buffer - {any}\n", .{bufBytes});

    var decoder = Decoder.init(bufBytes);
    std.debug.print("Nil - {any}\n", .{decoder.Nil()});
    std.debug.print("Int64 - {any}\n", .{try decoder.Int64()});
    std.debug.print("Int32 - {any}\n", .{try decoder.Int32()});
    std.debug.print("Uint8 - {any}\n", .{try decoder.Uint8()});
    std.debug.print("Uint16 - {any}\n", .{try decoder.Uint16()});
    std.debug.print("Uint32 - {any}\n", .{try decoder.Uint32()});
    std.debug.print("Uint64 - {any}\n", .{try decoder.Uint64()});
    std.debug.print("Error - {any}\n", .{try decoder.Error(E)});
    std.debug.print("Bool - {any}\n", .{try decoder.Bool()});
    std.debug.print("String - {s}\n", .{try decoder.String()});
    std.debug.print("Bytes - {s}\n", .{try decoder.Bytes()});
    std.debug.print("Slice Size- {any}\n", .{try decoder.Slice(Kind.UInt8)});
    std.debug.print("Slice 1- {}\n", .{try decoder.Uint8()});
    std.debug.print("Slice 2- {}\n", .{try decoder.Uint8()});
    std.debug.print("Slice 3- {}\n", .{try decoder.Uint8()});

    std.debug.print("Slice Size- {any}\n", .{try decoder.Map(Kind.String, Kind.UInt64)});
    std.debug.print("Map k1- {s}\n", .{try decoder.String()});
    std.debug.print("Map k1- {any}\n", .{try decoder.Uint64()});
    std.debug.print("Map k2- {s}\n", .{try decoder.String()});
    std.debug.print("Map k2- {any}\n", .{try decoder.Uint64()});
    std.debug.print("Map k3- {s}\n", .{try decoder.String()});
    std.debug.print("Map k3- {any}\n", .{try decoder.Uint64()});
}
