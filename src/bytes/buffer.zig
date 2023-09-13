const std = @import("std");
const Queue = std.atomic.Queue;

const assert = std.debug.assert;

pub const Error = error{
    OutOfMemory,
    InvalidRange,
};

pub fn Buffer(comptime threadsafe: bool) type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,

        mu: std.Thread.Mutex = std.Thread.Mutex{},

        ptr: [*]u8,

        cap: usize = 0,
        len: usize = 0,

        pub fn initEmpty(allocator: std.mem.Allocator) Self {
            return Self{
                .ptr = @as([*]u8, @ptrFromInt(0xFFFFFFFF)),
                .allocator = allocator,
                .cap = 0,
                .len = 0,
            };
        }
        pub fn init(allocator: std.mem.Allocator) Error!Self {
            return initWithCapacity(allocator, 1024);
        }
        pub fn initWithCapacity(allocator: std.mem.Allocator, cap: usize) Error!Self {
            var buf = initEmpty(allocator);
            try buf.allocate(cap);
            return buf;
        }

        pub fn deinit(self: *Self) void {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            self.allocator.free(self.ptr[0..self.cap]);
        }

        pub fn allocate(self: *Self, cap: usize) Error!void {
            const l = self.len;

            var slice = try self.allocator.alloc(u8, cap);

            _copy(u8, slice, self.ptr[0..l]);

            self.ptr = slice.ptr;
            self.cap = cap;
        }

        pub fn write(self: *Self, array: []const u8) Error!usize {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            if (self.len + array.len > self.cap) {
                try self.allocate((self.len + array.len) * 2);
            }

            var i: usize = 0;
            while (i < array.len) : (i += 1) {
                self.ptr[self.len + i] = array[i];
            }

            self.len += array.len;

            return array.len;
        }

        fn read(self: *Self, dst: []u8) Error!usize {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            var size = if (self.len < dst.len) self.len else dst.len;
            _copy(u8, dst, self.ptr[0..size]);
            return size;
        }

        pub fn compare(self: *Self, array: []const u8) bool {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            return std.mem.eql(u8, self.ptr[0..self.len], array.ptr[0..array.len]);
        }

        pub fn bytes(self: *Self) []const u8 {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            return self.ptr[0..self.len];
        }

        pub fn clone(self: *Self) Error!Self {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            return self.cloneUsingAllocator(self.allocator);
        }

        pub fn cloneUsingAllocator(self: *Self, allocator: std.mem.Allocator) Error!Self {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            var buf = try initWithCapacity(allocator, self.len);
            _ = try buf.write(self.ptr[0..self.len]);
            return buf;
        }

        pub fn copy(self: *Self) Error!?[]u8 {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            return self.copyUsingAllocator(self.allocator);
        }

        pub fn copyUsingAllocator(self: *Self, allocator: std.mem.Allocator) Error!?[]u8 {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            const s = self.bytes();
            if (allocator.alloc(u8, s.len)) |newStr| {
                std.mem.copy(u8, newStr, s);
                return newStr;
            } else |_| {
                return Error.OutOfMemory;
            }
        }

        pub fn repeat(self: *Self, n: usize) Error!void {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

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

        pub fn isEmpty(self: *Self) bool {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            return self.len == 0;
        }

        pub fn clear(self: *Self) void {
            if (threadsafe) {
                self.mu.lock();
                defer self.mu.unlock();
            }

            for (0..self.len) |i| {
                self.ptr[i] = 0;
            }
            self.len = 0;
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
                return try self.read(m);
            }

            pub fn writer(self: *Self) Writer {
                return .{ .context = self };
            }

            fn appendWrite(self: *Self, m: []const u8) !usize {
                return try self.write(m);
            }
        };
    };
}