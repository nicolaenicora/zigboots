const std = @import("std");
const Allocator = std.mem.Allocator;
const Stack = std.atomic.Stack;
const Error = @import("../bytes/buffer.zig").Error;

pub const Context = struct { allocator: std.mem.Allocator };

pub fn Interface(comptime T: type) type {
    return struct {
        const Self = @This();

        popFn: *const fn (self: *Self) Error!T,
        pushFn: *const fn (self: *Self, data: T) void,

        // __ptr: ?*const usize = null,

        pub fn pop(self: *Self) Error!T {
            return self.popFn(self);
        }

        pub fn push(self: *Self, data: T) void {
            self.pushFn(self, data);
        }

        // pub fn __set_origin_ptr(self: *Self, ptr: usize) void {
        //     self.__ptr = &ptr;
        // }
        // pub fn __get_origin_ptr(self: *Self) usize {
        //     return self.__ptr.?.*;
        // }
    };
}

pub fn Pool(comptime T: type, comptime createItemFn: *const fn (context: Context) Error!T) type {
    return struct {
        const Self = @This();

        queue: Stack(T),

        ctx: Context,

        pool: Interface(T),

        first: bool = false,

        pub fn init(ctx: Context) Self {
            // const p = Self{ .queue = Stack(T).init(), .ctx = ctx, .pool = Interface(T){ .popFn = retrieve, .pushFn = store } };
            // p.pool.__set_origin_ptr(@intFromPtr(&p));
            return Self{ .queue = Stack(T).init(), .ctx = ctx, .pool = Interface(T){ .popFn = retrieve, .pushFn = store } };
        }

        pub fn interface(self: Self) Interface(T) {
            return self.pool;
        }

        pub fn retrieve(pool: *Interface(T)) Error!T {
            // const self = @as(*Pool(T, createItemFn), @ptrFromInt(pool.__get_origin_ptr()));
            const self = @fieldParentPtr(Self, "pool", pool);

            const v = @atomicLoad(bool, &self.first, .Monotonic);
            @atomicStore(bool, &self.first, true, .Monotonic);

            if (!v) {
                self.queue.root = null;
            }

            if (self.queue.pop()) |n| {
                return n.data;
            }

            return try createItemFn(self.ctx);
        }

        pub fn store(pool: *Interface(T), data: T) void {
            // const self = @as(*Pool(T, createItemFn), @ptrFromInt(pool.__get_origin_ptr()));
            const self = @fieldParentPtr(Self, "pool", pool);

            var n = Stack(T).Node{
                .data = data,
                .next = null,
            };

            self.queue.push(&n);
        }
    };
}
