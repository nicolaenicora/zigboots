const std = @import("std");
const strings = @import("bytes/strings.zig");

pub const Measure = enum(u2) { seconds = 0, millis, micros, nanos };

pub const Month = enum(u4) {
    January = 1,
    February,
    March,
    April,
    May,
    June,
    July,
    August,
    September,
    October,
    November,
    December,
};
pub const Weekday = enum(u3) {
    Sunday = 0,
    Monday,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
};

pub fn now() Time {
    return Time(.seconds).now();
}

pub fn unixMilli() Time {
    return Time(.millis).now();
}

pub fn unixMicros() Time {
    return Time(.micros).now();
}

pub fn unixNanos() Time {
    return Time(.nanos).now();
}

pub fn Time(comptime measure: Measure) type {
    return struct {
        const Self = @This();

        measure: Measure = measure,
        value: i128,

        year: u16 = 0,
        month: u16 = 0,
        day: u16 = 0,
        hour: u16 = 0,
        min: u16 = 0,
        sec: u16 = 0,

        milli: u16 = 0,
        micro: u32 = 0,
        nano: u32 = 0,

        pub fn now() Self {
            const t = @constCast(&Self{ .value = switch (measure) {
                inline .seconds => std.time.timestamp(),
                inline .millis => std.time.milliTimestamp(),
                inline .micros => std.time.microTimestamp(),
                inline .nanos => std.time.nanoTimestamp(),
            } }).parse();
            return t.*;
        }

        fn parse(self: *Self) *Self {
            var seconds = switch (measure) {
                inline .seconds => self.value,
                inline .millis => blk: {
                    const milli = @rem(self.value, std.time.ms_per_s);
                    @atomicStore(u16, @constCast(&self.milli), @as(u16, @intCast(milli)), .Monotonic);

                    break :blk @divTrunc(self.value, std.time.ms_per_s);
                },
                inline .micros => blk: {
                    const micro = @rem(self.value, std.time.us_per_s);
                    @atomicStore(u32, @constCast(&self.micro), @as(u32, @intCast(micro)), .Monotonic);

                    const milli = @divTrunc(micro, std.time.ms_per_s);
                    @atomicStore(u16, @constCast(&self.milli), @as(u16, @intCast(milli)), .Monotonic);

                    break :blk @divTrunc(self.value, std.time.us_per_s);
                },
                inline .nanos => blk: {
                    const nano = @rem(self.value, std.time.ns_per_s);
                    @atomicStore(u32, @constCast(&self.nano), @as(u32, @intCast(nano)), .Monotonic);

                    const micro = @divTrunc(nano, std.time.ms_per_s);
                    @atomicStore(u32, @constCast(&self.micro), @as(u32, @intCast(micro)), .Monotonic);

                    const milli = @divTrunc(micro, std.time.ms_per_s);
                    @atomicStore(u16, @constCast(&self.milli), @as(u16, @intCast(milli)), .Monotonic);

                    break :blk @divTrunc(self.value, std.time.ns_per_s);
                },
            };

            // Split into time and day.
            var d = @divFloor(seconds, std.time.s_per_day);

            // Account for 400 year cycles.
            var n = @divFloor(d, days_per_400_years);
            var y = 400 * n;
            d -= days_per_400_years * n;

            // Cut off 100-year cycles.
            // The last cycle has one extra leap year, so on the last day
            // of that year, day / daysPer100Years will be 4 instead of 3.
            // Cut it back down to 3 by subtracting n>>2.
            n = @divFloor(d, days_per_100_years);
            n -= n >> 2;
            y += 100 * n;
            d -= days_per_100_years * n;

            // Cut off 4-year cycles.
            // The last cycle has a missing leap year, which does not
            // affect the computation.
            n = @divFloor(d, days_per_4_years);
            y += 4 * n;
            d -= days_per_4_years * n;

            // Cut off years within a 4-year cycle.
            // The last year is a leap year, so on the last day of that year,
            // day / 365 will be 4 instead of 3. Cut it back down to 3
            // by subtracting n>>2.
            n = @divFloor(d, days_per_year);
            n -= n >> 2;
            y += n;
            d -= days_per_year * n;

            var sec = @rem(seconds, std.time.s_per_day);
            var hour = @divFloor(sec, std.time.s_per_hour);
            sec -= hour * std.time.s_per_hour;
            var min = @divFloor(sec, std.time.s_per_min);
            sec -= min * std.time.s_per_min;

            var year = y + absolute_zero_year;

            var day = d;
            // Estimate month on assumption that every month has 31 days.
            // The estimate may be too low by at most one month, so adjust.
            var month = @divFloor(day, 31);
            if (isLeap(year)) {
                // Leap year
                if (day > 31 + 29 - 1) {
                    day -= 1;
                }
                if (day == 31 + 29 - 1) {
                    day -= 1;
                    // Leap day.
                    month = 2; // February
                    day = 29;

                    @atomicStore(u16, @constCast(&self.year), @as(u16, @intCast(year)), .Monotonic);
                    @atomicStore(u16, @constCast(&self.month), @as(u16, @intCast(month)), .Monotonic);
                    @atomicStore(u16, @constCast(&self.day), @as(u16, @intCast(day)), .Monotonic);
                    @atomicStore(u16, @constCast(&self.hour), @as(u16, @intCast(hour)), .Monotonic);
                    @atomicStore(u16, @constCast(&self.min), @as(u16, @intCast(min)), .Monotonic);
                    @atomicStore(u16, @constCast(&self.sec), @as(u16, @intCast(sec)), .Monotonic);

                    return self;
                }
            }

            const i = @as(usize, @intCast(month));
            var begin = daysBefore[i];
            var end = daysBefore[i + 1];

            if (day >= end) {
                month += 1;
                begin = end;
            }

            month += 1; // because January is 1
            day = day - begin + 1;

            @atomicStore(u16, @constCast(&self.year), @as(u16, @intCast(year)), .Monotonic);
            @atomicStore(u16, @constCast(&self.month), @as(u16, @intCast(month)), .Monotonic);
            @atomicStore(u16, @constCast(&self.day), @as(u16, @intCast(day)), .Monotonic);
            @atomicStore(u16, @constCast(&self.hour), @as(u16, @intCast(hour)), .Monotonic);
            @atomicStore(u16, @constCast(&self.min), @as(u16, @intCast(min)), .Monotonic);
            @atomicStore(u16, @constCast(&self.sec), @as(u16, @intCast(sec)), .Monotonic);

            return self;
        }

        // format returns a date string
        fn custom_format(self: Self, pattern: []const u8, dst: []const u8) !void {
            var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
            defer arena.deinit();

            var tokens = std.fifo.LinearFifo([]const u8, .Dynamic).init(arena.allocator());
            defer tokens.deinit();

            var i: usize = 0;
            while (i < pattern.len) {
                var j: usize = 4;
                while (j > 0) : (j -= 1) {
                    if (i > pattern.len - j) {
                        continue;
                    }

                    const slice = pattern.ptr[i .. i + j];
                    if (j == 1 or (j == 2 and in2(slice)) or (j == 3 and in3(slice)) or (j == 4 and in4(slice))) {
                        const token = pattern.ptr[i .. i + j];
                        try tokens.writeItem(token);
                        i += (j - 1);
                        break;
                    }
                }
                i += 1;
            }

            var sb = try strings.StringBuilder.initWithCapacity(arena.allocator(), pattern.len);
            defer sb.deinit();

            while (tokens.readItem()) |token| {
                if (std.mem.eql(u8, token, "YYYY")) {
                    try sb.appendf("{d}", .{self.year});
                } else if (std.mem.eql(u8, token, "MM")) {
                    if (self.month < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.month});
                } else if (std.mem.eql(u8, token, "DD")) {
                    if (self.day < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.day});
                } else if (std.mem.eql(u8, token, "HH")) {
                    if (self.hour < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.hour});
                } else if (std.mem.eql(u8, token, "mm")) {
                    if (self.min < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.min});
                } else {
                    try sb.append(token);
                }
            }
            std.mem.copyBackwards(u8, @constCast(dst), sb.bytes());
        }

        // format returns a date string in "YYYY-MM-DD HH:mm" format (24h).
        pub fn format(self: Self) ![]u8 {
            var buffer: [16]u8 = undefined;
            try self.custom_format("YYYY-MM-DD HH:mm", &buffer);
            return &buffer;
        }

        // // format_ss returns a date string in "YYYY-MM-DD HH:mm:ss" format (24h).
        // pub fn format_ss(self: *Self) []u8 {
        //     return '${t.year:04d}-${t.month:02d}-${t.day:02d} ${t.hour:02d}:${t.minute:02d}:${t.second:02d}'
        // }

        // // format_ss_milli returns a date string in "YYYY-MM-DD HH:mm:ss.123" format (24h).
        // pub fn format_ss_milli(self: *Self) []u8 {
        //     return '${t.year:04d}-${t.month:02d}-${t.day:02d} ${t.hour:02d}:${t.minute:02d}:${t.second:02d}.${(t.microsecond / 1000):03d}'
        // }

        // // format_rfc3339 returns a date string in "YYYY-MM-DDTHH:mm:ss.123Z" format (24 hours, see https://www.rfc-editor.org/rfc/rfc3339.html)
        // // RFC3339 is an Internet profile, based on the ISO 8601 standard for for representation of dates and times using the Gregorian calendar.
        // // It is intended to improve consistency and interoperability, when representing and using date and time in Internet protocols.
        // pub fn format_rfc3339(self: *Self) []u8 {
        //     u := t.local_to_utc()
        //     return '${u.year:04d}-${u.month:02d}-${u.day:02d}T${u.hour:02d}:${u.minute:02d}:${u.second:02d}.${(u.microsecond / 1000):03d}Z'
        // }

        // // format_ss_micro returns a date string in "YYYY-MM-DD HH:mm:ss.123456" format (24h).
        // pub fn format_ss_micro(self: *Self) []u8 {
        //     return '${t.year:04d}-${t.month:02d}-${t.day:02d} ${t.hour:02d}:${t.minute:02d}:${t.second:02d}.${t.microsecond:06d}'
        // }

        // // hhmm returns a date string in "HH:mm" format (24h).
        // pub fn hhmm(self: *Self) []u8 {
        //     return '${t.hour:02d}:${t.minute:02d}'
        // }

        // // hhmmss returns a date string in "HH:mm:ss" format (24h).
        // pub fn hhmmss(self: *Self) []u8 {
        //     return '${t.hour:02d}:${t.minute:02d}:${t.second:02d}'
        // }

        // // hhmm12 returns a date string in "hh:mm" format (12h).
        // pub fn hhmm12(self: *Self) []u8 {
        //     return t.get_fmt_time_str(.hhmm12)
        // }

        // // ymmdd returns a date string in "YYYY-MM-DD" format.
        // pub fn ymmdd(self: *Self) []u8 {
        //     return t.get_fmt_date_str(.hyphen, .yyyymmdd)
        // }

        // // ddmmy returns a date string in "DD.MM.YYYY" format.
        // pub fn ddmmy(self: *Self) []u8 {
        //     return t.get_fmt_date_str(.dot, .ddmmyyyy)
        // }

        // // md returns a date string in "MMM D" format.
        // pub fn md(self: *Self) []u8 {
        //     return t.get_fmt_date_str(.space, .mmmd)
        // }
    };
}

inline fn isLeap(year: i128) bool {
    return @rem(year, 4) == 0 and (@rem(year, 100) != 0 or @rem(year, 400) == 0);
}

const absolute_zero_year = 1970;
const days_per_year = 365;
const days_per_400_years = days_per_year * 400 + 97;
const days_per_100_years = days_per_year * 100 + 24;
const days_per_4_years = days_per_year * 4 + 1;

// daysBefore[m] counts the number of days in a non-leap year
// before month m begins. There is an entry for m=12, counting
// the number of days before January of next year (365).
const daysBefore = [13]u32{
    0,
    31,
    31 + 28,
    31 + 28 + 31,
    31 + 28 + 31 + 30,
    31 + 28 + 31 + 30 + 31,
    31 + 28 + 31 + 30 + 31 + 30,
    31 + 28 + 31 + 30 + 31 + 30 + 31,
    31 + 28 + 31 + 30 + 31 + 30 + 31 + 31,
    31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30,
    31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31,
    31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30,
    31 + 28 + 31 + 30 + 31 + 30 + 31 + 31 + 30 + 31 + 30 + 31,
};

const tokens_2 = [16][]const u8{ "MM", "DD", "Do", "YY", "ss", "kk", "NN", "mm", "hh", "HH", "ZZ", "dd", "Qo", "QQ", "wo", "ww" };
const tokens_3 = [4][]const u8{ "MMM", "DDD", "ZZZ", "ddd" };
const tokens_4 = [5][]const u8{ "MMMM", "DDDD", "DDDo", "dddd", "YYYY" };

fn in2(elem: []const u8) bool {
    for (tokens_2) |item| {
        if (std.mem.eql(u8, item, elem)) {
            return true;
        }
    }
    return false;
}
fn in3(elem: []const u8) bool {
    for (tokens_3) |item| {
        if (std.mem.eql(u8, item, elem)) {
            return true;
        }
    }
    return false;
}
fn in4(elem: []const u8) bool {
    for (tokens_4) |item| {
        if (std.mem.eql(u8, item, elem)) {
            return true;
        }
    }
    return false;
}

test "format - YYYY-MM-DD HH:mm" {
    const t = Time(.seconds).now();
    const f = t.format();

    const b = try strings.formatf(90, "{}-{}-{} {}:{}", .{ t.year, t.month, t.day, t.hour, t.min });

    try std.testing.expectEqual(f, b);
}
