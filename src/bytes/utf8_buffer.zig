const std = @import("std");
const Stack = std.atomic.Stack;

const Error = @import("buffer.zig").Error;
const Buffer = @import("buffer.zig").Buffer;

const assert = std.debug.assert;

pub fn Utf8BufferPool(comptime threadsafe: bool) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        queue: Stack(Utf8Buffer(threadsafe)),

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .queue = Stack(Utf8Buffer(threadsafe)).init(), .allocator = allocator };
        }

        pub fn pop(self: *Self) Error!Utf8Buffer(threadsafe) {
            if (self.queue.pop()) |n| {
                return n.data;
            }

            return try Utf8Buffer(threadsafe).init(self.allocator);
        }

        pub fn push(self: *Self, data: Utf8Buffer(threadsafe)) void {
            var n = Stack(Utf8Buffer(threadsafe)).Node{
                .data = data,
                .next = null,
            };
            self.queue.push(&n);
        }
    };
}

pub fn Utf8Buffer(comptime threadsafe: bool) type {
    return struct {
        const Self = @This();

        buffer: Buffer(threadsafe),

        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return Self{ .buffer = try Buffer(threadsafe).init(allocator) };
        }

        pub fn initWithCapacity(allocator: std.mem.Allocator, cap: usize) Error!Self {
            var buf = try Buffer(threadsafe).initWithCapacity(allocator, cap);
            return Self{ .buffer = buf };
        }

        pub fn deinit(self: *Self) void {
            self.buffer.deinit();
        }

        pub fn copy(self: *Self) Error!?[]u8 {
            return try self.buffer.copy();
        }

        pub fn clear(self: *Self) void {
            self.buffer.clear();
        }
        pub fn capacity(self: *Self) usize {
            const buffer = self.buffer;

            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            return buffer.cap;
        }

        pub fn bytes(self: *Self) []const u8 {
            return self.buffer.bytes();
        }

        pub inline fn isEmpty(self: *Self) bool {
            const buffer = self.buffer;

            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            return buffer.len == 0;
        }

        pub fn append(self: *Self, array: []const u8) Error!void {
            try self.pushAt(array, self.buffer.len);
        }

        pub fn pushAt(self: *Self, array: []const u8, index: usize) Error!void {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            // Make sure buffer has enough space
            if (self.buffer.len + array.len > self.buffer.cap) {
                try self.buffer.allocate((self.buffer.len + array.len) * 2);
            }

            // If the index is >= len, then simply push to the end.
            // If not, then copy contents over and insert the given array.
            if (index == self.buffer.len) {
                var i: usize = 0;
                while (i < array.len) : (i += 1) {
                    self.buffer.ptr[self.buffer.len + i] = array[i];
                }
            } else {
                if (self.utf8Position(index, true)) |k| {
                    // Move existing contents over
                    var i: usize = self.buffer.len - 1;
                    while (i >= k) : (i -= 1) {
                        if (i + array.len < self.buffer.cap) {
                            self.buffer.ptr[i + array.len] = self.buffer.ptr[i];
                        }

                        if (i == 0) break;
                    }

                    i = 0;
                    while (i < array.len) : (i += 1) {
                        self.buffer.ptr[index + i] = array[i];
                    }
                }
            }

            @atomicStore(usize, &self.buffer.len, self.buffer.len + array.len, .Monotonic);
        }

        pub fn pop(self: *Self) ?[]const u8 {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            if (self.buffer.len == 0) return null;

            var i: usize = 0;
            while (i < self.buffer.len) {
                const size = utf8Size(self.buffer.ptr[i]);
                if (i + size >= self.buffer.len) break;
                i += size;
            }

            const ret = self.buffer.ptr[i..self.buffer.len];
            self.buffer.len -= (self.buffer.len - i);
            return ret;
        }

        pub fn at(self: *Self, index: usize) ?[]const u8 {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            if (self.utf8Position(index, true)) |i| {
                const size = utf8Size(self.buffer.ptr[i]);
                return self.buffer.ptr[i..(i + size)];
            }
            return null;
        }

        pub fn rawLength(self: *Self) usize {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            return self.buffer.len;
        }

        pub fn length(self: *Self) usize {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            var l: usize = 0;
            var i: usize = 0;

            while (i < self.buffer.len) {
                i += utf8Size(self.buffer.ptr[i]);
                l += 1;
            }

            return l;
        }

        pub fn find(self: *Self, array: []const u8) ?usize {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            const index = std.mem.indexOf(u8, self.buffer.ptr[0..self.buffer.len], array);
            if (index) |i| {
                return self.utf8Position(i, false);
            }
            return null;
        }

        pub fn compare(self: *Self, array: []const u8) bool {
            return self.buffer.compare(array);
        }

        pub fn clone(self: *Self) Error!Self {
            return Self{ .buffer = try self.buffer.clone() };
        }

        pub fn repeat(self: *Self, n: usize) Error!void {
            try self.buffer.repeat(n);
        }

        pub fn removeFrom(self: *Self, index: usize) Error!void {
            try self.removeRange(index, index + 1);
        }

        pub fn removeRange(self: *Self, start: usize, end: usize) Error!void {
            if (end < start or end > self.buffer.len) return Error.InvalidRange;

            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            const rStart = self.utf8Position(start, true).?;
            const rEnd = self.utf8Position(end, true).?;
            const difference = rEnd - rStart;

            var i: usize = rEnd;
            while (i < self.buffer.len) : (i += 1) {
                self.buffer.ptr[i - difference] = self.buffer.ptr[i];
            }

            self.buffer.len -= difference;
        }

        pub fn trimStart(self: *Self, cut: []const u8) void {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            var i: usize = 0;
            while (i < self.buffer.len) : (i += 1) {
                const size = utf8Size(self.buffer.ptr[i]);
                if (size > 1 or !in(self.buffer.ptr[i], cut)) break;
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
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            self.reverse();
            self.trimStart(cut);
            self.reverse();
        }

        pub fn trim(self: *Self, cut: []const u8) void {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            self.trimStart(cut);
            self.trimEnd(cut);
        }

        pub fn reverse(self: *Self) void {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            var i: usize = 0;
            while (i < self.buffer.len) {
                const size = utf8Size(self.buffer.ptr[i]);
                if (size > 1) std.mem.reverse(u8, self.buffer.ptr[i..(i + size)]);
                i += size;
            }

            std.mem.reverse(u8, self.buffer.ptr[0..self.buffer.len]);
        }

        pub fn split(self: *Self, delimiters: []const u8, index: usize) ?[]const u8 {
            var i: usize = 0;
            var block: usize = 0;
            var start: usize = 0;

            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            while (i < self.buffer.len) {
                const size = utf8Size(self.buffer.ptr[i]);
                if (size == delimiters.len) {
                    if (std.mem.eql(u8, delimiters, self.buffer.ptr[i..(i + size)])) {
                        if (block == index) return self.buffer.ptr[start..i];
                        start = i + size;
                        block += 1;
                    }
                }

                i += size;
            }

            if (i >= self.buffer.len - 1 and block == index) {
                return self.buffer.ptr[start..self.buffer.len];
            }

            return null;
        }

        pub fn splitAsCopy(self: *Self, delimiters: []const u8, index: usize) Error!?Self {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            if (self.split(delimiters, index)) |block| {
                var s = Self{ .buffer = Buffer(threadsafe).initEmpty(self.buffer.allocator) };
                try s.append(block);
                return s;
            }

            return null;
        }

        pub fn toLowercase(self: *Self) void {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            var i: usize = 0;
            while (i < self.buffer.len) {
                const size = utf8Size(self.buffer.ptr[i]);
                if (size == 1) self.buffer.ptr[i] = std.ascii.toLower(self.buffer.ptr[i]);
                i += size;
            }
        }

        pub fn toUppercase(self: *Self) void {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            var i: usize = 0;
            while (i < self.buffer.len) {
                const size = utf8Size(self.buffer.ptr[i]);
                if (size == 1) self.buffer.ptr[i] = std.ascii.toUpper(self.buffer.ptr[i]);
                i += size;
            }
        }

        pub fn substract(self: *Self, start: usize, end: usize) Error!Self {
            if (threadsafe) {
                self.buffer.mu.lock();
                defer self.buffer.mu.unlock();
            }

            var result = Self{ .buffer = Buffer(threadsafe).initEmpty(self.buffer.allocator) };

            if (self.utf8Position(start, true)) |rStart| {
                if (self.utf8Position(end, true)) |rEnd| {
                    if (rEnd < rStart or rEnd > self.buffer.len)
                        return Error.InvalidRange;
                    try result.append(self.buffer.ptr[rStart..rEnd]);
                }
            }

            return result;
        }

        fn utf8Position(self: *Self, index: usize, real: bool) ?usize {
            var i: usize = 0;
            var j: usize = 0;
            while (i < self.buffer.cap) {
                if (real) {
                    if (j == index) return i;
                } else {
                    if (i == index) return j;
                }
                i += utf8Size(self.buffer.ptr[i]);
                j += 1;
            }

            if (real) {
                if (j == index) return i;
            } else {
                if (i == index) return j;
            }

            return null;
        }

        // Reader and Writer functionality.
        pub usingnamespace struct {
            pub const Writer = std.io.Writer(*Self, Error, appendWrite);
            pub const Reader = std.io.Reader(*Self, Error, readFn);

            pub fn reader(self: *Self) Reader {
                return .{ .context = self };
            }

            fn readFn(self: *Self, m: []u8) !usize {
                return try self.buffer.read(m);
            }

            pub fn writer(self: *Self) Writer {
                return .{ .context = self };
            }

            fn appendWrite(self: *Self, m: []const u8) !usize {
                return try self.buffer.write(m);
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

        // Iterator support
        pub usingnamespace struct {
            pub const Iterator = struct {
                sb: *Self,
                index: usize,

                pub fn next(it: *Iterator) ?[]const u8 {
                    if (it.index == it.sb.buffer.cap) return null;
                    var i = it.index;
                    it.index += utf8Size(it.sb.buffer.ptr[i]);
                    return it.sb.buffer.ptr[i..it.index];
                }
            };

            pub fn iterator(self: *Self) Iterator {
                return Iterator{
                    .sb = self,
                    .index = 0,
                };
            }
        };
    };
}

const ArenaAllocator = std.heap.ArenaAllocator;
const eql = std.mem.eql;

test "Basic Usage" {
    // Use your favorite allocator
    var arena = ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var buffer = try Utf8Buffer(true).init(arena.allocator());
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

    var buffer = try Utf8Buffer(true).init(arena.allocator());
    defer buffer.deinit();

    // truncate
    buffer.clear();
    assert(buffer.capacity() == 1024);
    assert(buffer.rawLength() == 0);

    // append
    try buffer.append("A");
    try buffer.append("\u{5360}");
    try buffer.append("💯");
    try buffer.append("Hello🔥");

    assert(buffer.rawLength() == 17);

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
    try buffer.removeFrom(buffer.rawLength() - 1);
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

    var splitStr = try Utf8Buffer(true).init(arena.allocator());
    defer splitStr.deinit();

    try splitStr.append("variable='value'");
    assert(eql(u8, splitStr.split("=", 0).?, "variable"));
    assert(eql(u8, splitStr.split("=", 1).?, "'value'"));

    // splitToString
    var newSplit = try splitStr.splitAsCopy("=", 0);
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
    const cap = buffer.capacity();
    assert(buffer.rawLength() == 0);
    assert(buffer.capacity() == cap);

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

    assert(i == buffer.capacity());
}