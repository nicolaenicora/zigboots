const std = @import("std");
const Atomic = std.atomic.Atomic;
const order = std.builtin.AtomicOrder;

pub fn AtomicBox(comptime T: anytype) type {
    return struct {
        const Self = @This();

        v: *const Atomic(T),

        pub fn init(d: T) Self {
            var v = Atomic(T).init(d);
            return Self{ .v = &v };
        }

        pub fn atomic(self: Self) *Atomic(T) {
            return @constCast(self.v);
        }

        pub fn loadUnchecked(self: Self) T {
            return self.v.value;
        }

        pub fn storeUnchecked(self: Self, value: T) void {
            const ref = @as(*Atomic(T), @constCast(self.v));
            ref.value = value;
        }

        pub inline fn load(self: Self) T {
            const r = self.v.load(order.Monotonic);
            return r;
        }

        pub fn loadAsRef(self: Self) *const T {
            const r = self.v.load(order.Monotonic);
            return &r;
        }

        pub inline fn store(self: Self, value: T) void {
            const ref = @as(*Atomic(T), @constCast(self.v));
            ref.store(value, order.Monotonic);
        }

        pub inline fn swap(self: Self, value: T) struct {
            old: T,
            new: T,
        } {
            const ref = @as(*Atomic(T), @constCast(self.v));
            const v = ref.swap(value, order.SeqCst);
            return .{
                .old = v,
                .new = value,
            };
        }

        pub inline fn compareAndSwap(self: Self, new_value: T) bool {
            const ref = @as(*Atomic(T), @constCast(self.v));
            const result = ref.compareAndSwap(self.load(), new_value, order.Monotonic, order.Monotonic);
            return if (result) |_| false else true;
        }

        pub inline fn tryCompareAndSwap(self: Self, new_value: T) bool {
            const ref = @as(*Atomic(T), @constCast(self.v));
            const result = ref.tryCompareAndSwap(self.load(), new_value, order.Monotonic, order.Monotonic);
            return if (result) |_| false else true;
        }
    };
}

const testing = std.testing;

test "itself" {
    const box = AtomicBox(i32).init(23);

    var ref = box.atomic();

    var value = ref.load(order.SeqCst);
    try testing.expectEqual(value, 23);

    _ = ref.fetchAdd(1, order.SeqCst);
    var newValue = ref.load(order.SeqCst);
    try testing.expectEqual(newValue, 24);
}

test "load" {
    const box = AtomicBox(i32).init(23);

    try testing.expectEqual(box.load(), 23);
}

test "loadAsRef" {
    const box = AtomicBox(i32).init(23);

    try testing.expectEqual(box.loadAsRef().*, 23);
}

test "store" {
    const box = AtomicBox(i32).init(23);

    try testing.expectEqual(box.load(), 23);

    box.store(64);
    try testing.expectEqual(box.load(), 64);
}

test "store usize" {
    const box = AtomicBox(usize).init(23);

    try testing.expectEqual(box.load(), 23);

    box.store(64);
    try testing.expectEqual(box.load(), 64);
}

test "swap" {
    const box = AtomicBox(i32).init(23);

    try testing.expectEqual(box.load(), 23);

    const result = box.swap(64);
    try testing.expectEqual(box.load(), 64);
    try testing.expectEqual(result, .{ .old = 23, .new = 64 });
}

test "compareAndSwap" {
    const box = AtomicBox(i32).init(23);

    var result = box.compareAndSwap(64);
    if (result) {
        try testing.expectEqual(box.load(), 64);
    } else {
        unreachable;
    }
}

test "trCompareAndSwap" {
    const box = AtomicBox(i32).init(23);

    var result = box.tryCompareAndSwap(64);
    if (result) {
        try testing.expectEqual(box.load(), 64);
    } else {
        unreachable;
    }
}

test "loadUnchecked" {
    const box = AtomicBox(i32).init(23);

    try testing.expectEqual(box.loadUnchecked(), 23);
}

test "storeUnchecked" {
    const box = AtomicBox(i32).init(23);

    box.storeUnchecked(64);

    try testing.expectEqual(box.load(), 64);
}
