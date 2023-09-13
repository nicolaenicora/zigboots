const std = @import("std");
const Allocator = std.mem.Allocator;
const Order = std.math.Order;

const Iterator = @import("traits.zig").Iterator;

pub fn Entry(comptime K: type, comptime V: type) type {
    return struct {
        const Self = @This();

        key: K,
        value: V,
    };
}

pub fn SkipList(
    comptime K: type,
    comptime V: type,
    comptime Context: type,
) type {
    return struct {
        const SelfSkipList = @This();

        first: ?*Node = null,
        len: usize,
        allocator: Allocator,
        ctx: Context,

        iterator: Iterator(K, SkipList(K, V, Context)),

        pub const Node = struct {
            const SelfNode = @This();
            next: ?*Node = null,
            prev: ?*Node = null,
            up: ?*Node = null,
            down: ?*Node = null,
            key: K,
            data: ?V,
            /// Insert a new node after the current one.
            ///
            /// Arguments:
            ///     new_node: Pointer to the new node to insert.
            pub fn insertAfter(self: *SelfNode, new_node: *Node) void {
                new_node.next = self.next;
                self.next = new_node;
            }
            /// Remove a node from the list.
            ///
            /// Arguments:
            ///     node: Pointer to the node to be removed.
            /// Returns:
            ///     node removed
            pub fn removeNext(self: *SelfNode) ?*Node {
                const next_node = self.next orelse return null;
                self.next = next_node.next;
                return next_node;
            }
            /// Iterate over the singly-linked list from this node, until the final node is found.
            /// This operation is O(N).
            pub fn findLast(self: *SelfNode) *Node {
                var it = self;
                while (true) {
                    it = it.next orelse return it;
                }
            }
            /// Iterate over each next node, returning the count of all nodes except the starting one.
            /// This operation is O(N).
            pub fn countChildren(self: *const SelfNode) usize {
                var count: usize = 0;
                var it: ?*const Node = self.next;
                while (it) |n| : (it = n.next) {
                    count += 1;
                }
                return count;
            }
            /// Reverse the list starting from this node in-place.
            /// This operation is O(N).
            pub fn reverse(indirect: *?*Node) void {
                if (indirect.* == null) {
                    return;
                }
                var current: *Node = indirect.*.?;
                while (current.next) |it| {
                    current.next = it.next;
                    it.next = indirect.*;
                    indirect.* = it;
                }
            }
        };

        /// Initialize and return a priority queue.
        pub fn init(allocator: Allocator) SelfSkipList {
            return initContext(allocator, undefined);
        }

        pub fn initContext(allocator: Allocator, ctx: Context) SelfSkipList {
            return SelfSkipList{ .len = 0, .allocator = allocator, .ctx = ctx, .iter = Iterator(K){
                .nextFn = next,
                .resetFn = reset,
            } };
        }

        /// Free memory used by the queue.
        pub fn deinit(self: SelfSkipList) void {
            self.allocator.free(self.items);
        }

        pub fn dd(self: SelfSkipList) []const u8 {
            return self.ctx.store();
        }

        /// Return the next element in the range
        pub fn next(it: *Iterator(K)) ?K {
            const self = @fieldParentPtr(SelfSkipList, "iter", it);
            _ = self;

            return null;
        }

        /// Reset the range back to its start.
        pub fn reset(it: *Iterator(K)) void {
            const self = @fieldParentPtr(SelfSkipList, "iter", it);
            _ = self;
        }
    };
}

pub fn main() !void {
    std.debug.print("Starting application.\n", .{});

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    const SimpleContext = struct {
        pub fn store(self: @This()) []const u8 {
            _ = self;
            return "DDDDD";
        }
    };

    const d = SkipList(u32, []const u32, SimpleContext).init(allocator);

    std.debug.print("Context Store {s}.\n", .{d.dd()});
}
