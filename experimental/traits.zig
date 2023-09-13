/// Generic iterator interface. Call next to get the next element or
/// null if the iterator's exhausted. Call reset to start iteration
/// over from the beginning.
pub fn Iterator(comptime T: type, comptime Self: type) type {
    return struct {
        self_concrete: *Self,

        nextFn: *const fn (self: *Self) ?T,
        resetFn: *const fn (self: *Self) void,

        pub fn next(self: @This()) ?T {
            return self.nextFn(self.self_concrete);
        }

        pub fn reset(self: @This()) ?T {
            return self.resetFn(self.self_concrete);
        }
    };
}
