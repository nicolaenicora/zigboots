const std = @import("std");
const xstd = @import("xstd");
const polyglot = @import("polyglot");

const Logger = xstd.log.Logger(.simple, .nanos, "YYYY MMM Do dddd HH:mm:ss.SSS - Qo");

const Buffer = xstd.bytes.Buffer;

const Encoder = polyglot.Encoder;
const Decoder = polyglot.Decoder;
const Kind = polyglot.Kind;

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
    const assert = std.debug.assert;
    const eql = std.mem.eql;

    assert(decoder.Nil());
    assert(try decoder.Int64() == 255);
    assert(try decoder.Int32() == 512);
    assert(try decoder.Uint8() == 255);
    assert(try decoder.Uint16() == 23);
    assert(try decoder.Uint32() == 230);
    assert(try decoder.Uint64() == 2300);

    const err: ?E = try decoder.Error(E);
    assert(err.? == E.NoComment);

    assert(try decoder.Bool());
    assert(eql(u8, try decoder.String(), "HURAAAA"));
    assert(eql(u8, try decoder.Bytes(), "Array of bytes"));
    assert(try decoder.Slice(Kind.UInt8) == 3);
    assert(try decoder.Uint8() == 1);
    assert(try decoder.Uint8() == 2);
    assert(try decoder.Uint8() == 3);

    assert(try decoder.Map(Kind.String, Kind.UInt64) == 3);
    assert(eql(u8, try decoder.String(), "key1"));
    assert(try decoder.Uint64() == 1);
    assert(eql(u8, try decoder.String(), "key2"));
    assert(try decoder.Uint64() == 2);
    assert(eql(u8, try decoder.String(), "key3"));
    assert(try decoder.Uint64() == 3);
}
