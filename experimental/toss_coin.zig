const std = @import("std");

const Toss = enum {
    Tail,
    Head,
};

pub fn toss_coin_in_zig() Toss {
    var rng = std.rand.RomuTrio.init(@as(u64, @intCast(std.time.microTimestamp())));
    const rand = rng.random().float(f32);

    // std.debug.print("Random: {d}\n", .{rand});

    if (rand < 0.45) {
        return Toss.Head;
    } else {
        return Toss.Tail;
    }
}

pub fn main() !void {
    blk: while (true) {
        const coin = toss_coin_in_zig();
        switch (coin) {
            .Tail => std.debug.print("Tail.\n", .{}),
            .Head => {
                std.debug.print("Head.\n", .{});
                break :blk;
            },
        }
    }
}
