const std = @import("std");
const assert = std.debug.assert;

/// String Builder
/// A variable length collection of characters
const Self = @This();

/// The allocator used for managing the buffer
allocator: std.mem.Allocator,

/// The internal  buffer
ptr: [*]u8,

/// The total size of the String
cap: usize = 0,
len: usize = 0,

/// Errors that may occur when using String
pub const Error = error{
    OutOfMemory,
    InvalidRange,
};

pub fn initAsEmpty(allocator: std.mem.Allocator) Self {
    return .{
        .ptr = @as([*]u8, @ptrFromInt(0xDEADBEEF)),
        .allocator = allocator,
        .cap = 0,
    };
}
pub fn init(allocator: std.mem.Allocator) Error!Self {
    return initWithCapacity(allocator, 1024);
}
pub fn initWithCapacity(allocator: std.mem.Allocator, cap: usize) Error!Self {
    var buf = initAsEmpty(allocator);
    try buf.allocate(cap);
    return buf;
}

/// Deallocates the internal buffer
pub fn deinit(self: *Self) void {
    self.allocator.free(self.ptr[0..self.cap]);
}

/// Returns the size of the internal buffer
pub fn capacity(self: Self) usize {
    return self.cap;
}

/// Allocates space for the internal buffer
fn allocate(self: *Self, cap: usize) Error!void {
    var slice = try self.allocator.alloc(u8, cap);

    _copy(u8, slice, self.ptr[0..self.len]);

    self.ptr = slice.ptr;
    self.cap = cap;
}

pub fn append(self: *Self, array: []const u8) Error!void {
    try self.pushAt(array, self.len);
}

pub fn pushAt(self: *Self, array: []const u8, index: usize) Error!void {
    // Make sure buffer has enough space
    if (self.len + array.len > self.cap) {
        try self.allocate((self.len + array.len) * 2);
    }

    // If the index is >= len, then simply push to the end.
    // If not, then copy contents over and insert literal.
    if (index == self.len) {
        var i: usize = 0;
        while (i < array.len) : (i += 1) {
            self.ptr[self.len + i] = array[i];
        }
    } else {
        if (self.utf8Position(index, true)) |k| {
            // Move existing contents over
            var i: usize = self.len - 1;
            while (i >= k) : (i -= 1) {
                if (i + array.len < self.cap) {
                    self.ptr[i + array.len] = self.ptr[i];
                }

                if (i == 0) break;
            }

            i = 0;
            while (i < array.len) : (i += 1) {
                self.ptr[index + i] = array[i];
            }
        }
    }

    self.len += array.len;
}

pub fn pop(self: *Self) ?[]const u8 {
    if (self.len == 0) return null;

    var i: usize = 0;
    while (i < self.len) {
        const size = utf8Size(self.ptr[i]);
        if (i + size >= self.len) break;
        i += size;
    }

    const ret = self.ptr[i..self.len];
    self.len -= (self.len - i);
    return ret;
}

pub fn compare(self: Self, literal: []const u8) bool {
    return std.mem.eql(u8, self.ptr[0..self.len], literal.ptr[0..literal.len]);
}

pub fn bytes(self: Self) []const u8 {
    return self.ptr[0..self.len];
}

pub fn at(self: *Self, index: usize) ?[]const u8 {
    if (self.utf8Position(index, true)) |i| {
        const size = utf8Size(self.ptr[i]);
        return self.ptr[i..(i + size)];
    }
    return null;
}

pub fn length(self: Self) usize {
    var l: usize = 0;
    var i: usize = 0;

    while (i < self.len) {
        i += utf8Size(self.ptr[i]);
        l += 1;
    }

    return l;
}

/// Finds the first occurrence of the string literal
pub fn find(self: *Self, literal: []const u8) ?usize {
    const index = std.mem.indexOf(u8, self.ptr[0..self.len], literal);
    if (index) |i| {
        return self.utf8Position(i, false);
    }
    return null;
}

/// Removes a character at the specified index
pub fn removeFrom(self: *Self, index: usize) Error!void {
    try self.removeRange(index, index + 1);
}

/// Removes a range of character from the String
/// Start (inclusive) - End (Exclusive)
pub fn removeRange(self: *Self, start: usize, end: usize) Error!void {
    if (end < start or end > self.len) return Error.InvalidRange;

    const rStart = self.utf8Position(start, true).?;
    const rEnd = self.utf8Position(end, true).?;
    const difference = rEnd - rStart;

    var i: usize = rEnd;
    while (i < self.len) : (i += 1) {
        self.ptr[i - difference] = self.ptr[i];
    }

    self.len -= difference;
}

/// Trims all characters at the start.
pub fn trimStart(self: *Self, cut: []const u8) void {
    var i: usize = 0;
    while (i < self.len) : (i += 1) {
        const size = utf8Size(self.ptr[i]);
        if (size > 1 or !in(self.ptr[i], cut)) break;
    }

    if (self.utf8Position(i, false)) |k| {
        self.removeRange(0, k) catch {};
    }
}
fn in(byte: u8, arr: []const u8) bool {
    var i: usize = 0;
    while (i < arr.len) : (i += 1) {
        if (arr[i] == byte) return true;
    }

    return false;
}

/// Trims all characters at the end.
pub fn trimEnd(self: *Self, cut: []const u8) void {
    self.reverse();
    self.trimStart(cut);
    self.reverse();
}

/// Trims all characters from both ends
pub fn trim(self: *Self, cut: []const u8) void {
    self.trimStart(cut);
    self.trimEnd(cut);
}

/// Copies this String into a new one
/// User is responsible for managing the new clone sharing the same allocator
pub fn clone(self: Self) Error!Self {
    return self.cloneUsingAllocator(self.allocator);
}
pub fn cloneUsingAllocator(self: Self, allocator: std.mem.Allocator) Error!Self {
    var buf = try initWithCapacity(allocator, self.len);
    try buf.append(self.bytes());
    return buf;
}

fn copyTo(self: Self, dst: []u8) Error!usize {
    var size = if (self.len <= dst.len) self.len else dst.len;
    _copy(u8, dst, self.ptr[0..size]);
    return size;
}

/// Returns an owned slice
pub fn copy(self: Self) Error!?[]u8 {
    return self.copyUsingAllocator(self.allocator);
}

/// Returns an owned slice
pub fn copyUsingAllocator(self: Self, allocator: std.mem.Allocator) Error!?[]u8 {
    const s = self.bytes();
    if (allocator.alloc(u8, s.len)) |newStr| {
        std.mem.copy(u8, newStr, s);
        return newStr;
    } else |_| {
        return Error.OutOfMemory;
    }
}

pub fn reverse(self: *Self) void {
    var i: usize = 0;
    while (i < self.len) {
        const size = utf8Size(self.ptr[i]);
        if (size > 1) std.mem.reverse(u8, self.ptr[i..(i + size)]);
        i += size;
    }

    std.mem.reverse(u8, self.ptr[0..self.len]);
}

pub fn repeat(self: *Self, n: usize) Error!void {
    try self.allocate(self.cap * (n + 1));

    var i: usize = 1;
    while (i <= n) : (i += 1) {
        var j: usize = 0;
        while (j < self.len) : (j += 1) {
            self.ptr[((i * self.len) + j)] = self.ptr[j];
        }
    }

    self.len *= (n + 1);
}

pub inline fn isEmpty(self: Self) bool {
    return self.len == 0;
}

pub fn split(self: *const Self, delimiters: []const u8, index: usize) ?[]const u8 {
    var i: usize = 0;
    var block: usize = 0;
    var start: usize = 0;

    while (i < self.len) {
        const size = utf8Size(self.ptr[i]);
        if (size == delimiters.len) {
            if (std.mem.eql(u8, delimiters, self.ptr[i..(i + size)])) {
                if (block == index) return self.ptr[start..i];
                start = i + size;
                block += 1;
            }
        }

        i += size;
    }

    if (i >= self.len - 1 and block == index) {
        return self.ptr[start..self.len];
    }

    return null;
}

pub fn splitAndCopy(self: *const Self, delimiters: []const u8, index: usize) Error!?Self {
    if (self.split(delimiters, index)) |block| {
        var s = initAsEmpty(self.allocator);
        try s.append(block);
        return s;
    }

    return null;
}

/// Clears the contents of the String but leaves the capacity
pub fn clear(self: *Self) void {
    for (0..self.len) |i| {
        self.ptr[i] = 0;
    }
    self.len = 0;
}

/// Converts all (ASCII) uppercase letters to lowercase
pub fn toLowercase(self: *Self) void {
    var i: usize = 0;
    while (i < self.len) {
        const size = utf8Size(self.ptr[i]);
        if (size == 1) self.ptr[i] = std.ascii.toLower(self.ptr[i]);
        i += size;
    }
}

/// Converts all (ASCII) uppercase letters to lowercase
pub fn toUppercase(self: *Self) void {
    var i: usize = 0;
    while (i < self.len) {
        const size = utf8Size(self.ptr[i]);
        if (size == 1) self.ptr[i] = std.ascii.toUpper(self.ptr[i]);
        i += size;
    }
}

pub fn substract(self: *Self, start: usize, end: usize) Error!Self {
    var result = initAsEmpty(self.allocator);

    if (self.utf8Position(start, true)) |rStart| {
        if (self.utf8Position(end, true)) |rEnd| {
            if (rEnd < rStart or rEnd > self.len)
                return Error.InvalidRange;
            try result.append(self.ptr[rStart..rEnd]);
        }
    }

    return result;
}

fn utf8Position(self: *Self, index: usize, real: bool) ?usize {
    var i: usize = 0;
    var j: usize = 0;
    while (i < self.cap) {
        if (real) {
            if (j == index) return i;
        } else {
            if (i == index) return j;
        }
        i += utf8Size(self.ptr[i]);
        j += 1;
    }

    if (real) {
        if (j == index) return i;
    } else {
        if (i == index) return j;
    }

    return null;
}

fn _copy(comptime Type: type, dest: []Type, src: []const Type) void {
    assert(dest.len >= src.len);

    if (@intFromPtr(src.ptr) == @intFromPtr(dest.ptr) or src.len == 0) return;

    const input: []const u8 = std.mem.sliceAsBytes(src);
    const output: []u8 = std.mem.sliceAsBytes(dest);

    assert(input.len > 0);
    assert(output.len > 0);

    const is_input_or_output_overlaping = (@intFromPtr(input.ptr) < @intFromPtr(output.ptr) and
        @intFromPtr(input.ptr) + input.len > @intFromPtr(output.ptr)) or
        (@intFromPtr(output.ptr) < @intFromPtr(input.ptr) and
        @intFromPtr(output.ptr) + output.len > @intFromPtr(input.ptr));

    if (is_input_or_output_overlaping) {
        @memcpy(output, input);
    } else {
        std.mem.copyBackwards(u8, output, input);
    }
}

// Reader and Writer functionality.
pub usingnamespace struct {
    pub const Writer = std.io.Writer(*Self, Error, appendWrite);
    pub const Reader = std.io.Reader(*Self, Error, readFn);

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }

    fn readFn(self: *Self, m: []u8) !usize {
        return try self.copyTo(m);
    }

    pub fn writer(self: *Self) Writer {
        return .{ .context = self };
    }

    fn appendWrite(self: *Self, m: []const u8) !usize {
        try self.append(m);
        return m.len;
    }
};

// Iterator support
pub usingnamespace struct {
    pub const Iterator = struct {
        sb: *const Self,
        index: usize,

        pub fn next(it: *Iterator) ?[]const u8 {
            if (it.index == it.sb.cap) return null;
            var i = it.index;
            it.index += utf8Size(it.sb.ptr[i]);
            return it.sb.ptr[i..it.index];
        }
    };

    pub fn iterator(self: *const Self) Iterator {
        return Iterator{
            .sb = self,
            .index = 0,
        };
    }
};

/// Checks if byte is part of UTF-8 character
inline fn isUTF8Byte(byte: u8) bool {
    return ((byte & 0x80) > 0) and (((byte << 1) & 0x80) == 0);
}

/// Returns the UTF-8 character's size
inline fn utf8Size(byte: u8) u3 {
    return std.unicode.utf8ByteSequenceLength(byte) catch {
        return 1;
    };
}

const ArenaAllocator = std.heap.ArenaAllocator;
const eql = std.mem.eql;

test "Basic Usage" {
    // Use your favorite allocator
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Create your String
    var buffer = try Self.init(arena.allocator());
    defer buffer.deinit();

    // Use functions provided
    try buffer.append("🔥 Hello!");
    _ = buffer.pop();
    try buffer.append(", World 🔥");

    // Success!
    assert(buffer.compare("🔥 Hello, World 🔥"));
}

test "String Tests" {
    // Allocator for the String
    const page_allocator = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_allocator);
    defer arena.deinit();

    // This is how we create the String
    var buffer = try Self.init(arena.allocator());
    defer buffer.deinit();

    // allocate & capacity
    try buffer.allocate(16);
    assert(buffer.capacity() == 16);
    assert(buffer.len == 0);

    // truncate
    buffer.clear();
    assert(buffer.capacity() == buffer.cap);
    assert(buffer.len == 0);

    // append
    try buffer.append("A");
    try buffer.append("\u{5360}");
    try buffer.append("💯");
    try buffer.append("Hello🔥");

    assert(buffer.len == 17);

    // pop & length
    assert(buffer.length() == 9);
    assert(eql(u8, buffer.pop().?, "🔥"));
    assert(buffer.length() == 8);
    assert(eql(u8, buffer.pop().?, "o"));
    assert(buffer.length() == 7);

    // str & cmp
    assert(buffer.compare("A\u{5360}💯Hell"));
    assert(buffer.compare(buffer.bytes()));

    // charAt
    assert(eql(u8, buffer.at(2).?, "💯"));
    assert(eql(u8, buffer.at(1).?, "\u{5360}"));
    assert(eql(u8, buffer.at(0).?, "A"));

    // insert
    try buffer.pushAt("🔥", 1);
    assert(eql(u8, buffer.at(1).?, "🔥"));
    assert(buffer.compare("A🔥\u{5360}💯Hell"));

    // find
    assert(buffer.find("🔥").? == 1);
    assert(buffer.find("💯").? == 3);
    assert(buffer.find("Hell").? == 4);

    // remove & removeRange
    try buffer.removeRange(0, 3);
    assert(buffer.compare("💯Hell"));
    try buffer.removeFrom(buffer.len - 1);
    assert(buffer.compare("💯Hel"));

    const whitelist = [_]u8{ ' ', '\t', '\n', '\r' };

    // trimStart
    try buffer.pushAt("      ", 0);
    buffer.trimStart(whitelist[0..]);
    assert(buffer.compare("💯Hel"));

    // trimEnd
    _ = try buffer.append("lo💯\n      ");
    buffer.trimEnd(whitelist[0..]);
    assert(buffer.compare("💯Hello💯"));

    // clone
    var testStr = try buffer.clone();
    defer testStr.deinit();
    assert(testStr.compare(buffer.bytes()));

    // reverse
    buffer.reverse();
    assert(buffer.compare("💯olleH💯"));
    buffer.reverse();
    assert(buffer.compare("💯Hello💯"));

    // repeat
    try buffer.repeat(2);
    assert(buffer.compare("💯Hello💯💯Hello💯💯Hello💯"));

    // isEmpty
    assert(!buffer.isEmpty());

    // split
    assert(eql(u8, buffer.split("💯", 0).?, ""));
    assert(eql(u8, buffer.split("💯", 1).?, "Hello"));
    assert(eql(u8, buffer.split("💯", 2).?, ""));
    assert(eql(u8, buffer.split("💯", 3).?, "Hello"));
    assert(eql(u8, buffer.split("💯", 5).?, "Hello"));
    assert(eql(u8, buffer.split("💯", 6).?, ""));

    var splitStr = try Self.init(arena.allocator());
    defer splitStr.deinit();

    try splitStr.append("variable='value'");
    assert(eql(u8, splitStr.split("=", 0).?, "variable"));
    assert(eql(u8, splitStr.split("=", 1).?, "'value'"));

    // splitToString
    var newSplit = try splitStr.splitAndCopy("=", 0);
    assert(newSplit != null);
    defer newSplit.?.deinit();

    assert(eql(u8, newSplit.?.bytes(), "variable"));

    // toLowercase & toUppercase
    buffer.toUppercase();
    assert(buffer.compare("💯HELLO💯💯HELLO💯💯HELLO💯"));
    buffer.toLowercase();
    assert(buffer.compare("💯hello💯💯hello💯💯hello💯"));

    // substr
    var subStr = try buffer.substract(0, 7);
    defer subStr.deinit();
    assert(subStr.compare("💯hello💯"));

    // clear
    buffer.clear();
    const cap = buffer.cap;
    assert(buffer.len == 0);
    assert(buffer.cap == cap);

    // writer
    const writer = buffer.writer();
    const len = try writer.write("This is a Test!");
    assert(len == 15);

    // owned
    const mySlice = try buffer.copy();
    assert(eql(u8, mySlice.?, "This is a Test!"));
    arena.allocator().free(mySlice.?);

    // Iterator
    var i: usize = 0;
    var iter = buffer.iterator();
    while (iter.next()) |ch| {
        if (i == 0) {
            assert(eql(u8, "T", ch));
        }
        i += 1;
    }

    assert(i == buffer.cap);
}
