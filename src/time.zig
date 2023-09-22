const std = @import("std");
const strings = @import("bytes/strings.zig");

pub const Measure = enum(u2) { seconds = 0, millis = 1, micros = 2, nanos = 3 };

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

    pub fn string(self: Month) []const u8 {
        return switch (self) {
            .January => "January",
            .February => "February",
            .March => "March",
            .April => "April",
            .May => "May",
            .June => "June",
            .July => "July",
            .August => "August",
            .September => "September",
            .October => "October",
            .November => "November",
            .December => "December",
        };
    }

    pub fn shortString(self: Month) []const u8 {
        return switch (self) {
            .January => "Jan",
            .February => "Feb",
            .March => "Mar",
            .April => "Apr",
            .May => "May",
            .June => "Jun",
            .July => "Jul",
            .August => "Aug",
            .September => "Sep",
            .October => "Oct",
            .November => "Nov",
            .December => "Dec",
        };
    }
};
pub const Weekday = enum(u3) {
    Monday = 1,
    Tuesday,
    Wednesday,
    Thursday,
    Friday,
    Saturday,
    Sunday,

    pub fn string(self: Weekday) []const u8 {
        return switch (self) {
            .Sunday => "Sunday",
            .Monday => "Monday",
            .Tuesday => "Tuesday",
            .Wednesday => "Wednesday",
            .Thursday => "Thursday",
            .Friday => "Friday",
            .Saturday => "Saturday",
        };
    }

    pub fn shortString(self: Weekday) []const u8 {
        return switch (self) {
            .Sunday => "Sun",
            .Monday => "Mon",
            .Tuesday => "Tue",
            .Wednesday => "Wed",
            .Thursday => "Thu",
            .Friday => "Fri",
            .Saturday => "Sat",
        };
    }

    pub fn shorterString(self: Weekday) []const u8 {
        return switch (self) {
            .Sunday => "Su",
            .Monday => "Mo",
            .Tuesday => "Tu",
            .Wednesday => "We",
            .Thursday => "Th",
            .Friday => "Fr",
            .Saturday => "Sa",
        };
    }
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

        year: u12 = 0,
        month: u4 = 0,
        yday: u9 = 0,
        wday: u3 = 0,
        day: u5 = 0,
        hour: u6 = 0,
        min: u6 = 0,
        sec: u6 = 0,

        milli: u10 = 0,
        micro: u10 = 0,
        nano: u10 = 0,

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
                    @atomicStore(u10, @constCast(&self.milli), @as(u10, @intCast(milli)), .Monotonic);

                    break :blk @divTrunc(self.value, std.time.ms_per_s);
                },
                inline .micros => blk: {
                    const micro = @rem(self.value, std.time.ns_per_us);
                    @atomicStore(u10, @constCast(&self.micro), @as(u10, @intCast(micro)), .Monotonic);

                    var milli = @rem(self.value, std.time.us_per_s);
                    milli = @divTrunc(milli, std.time.ns_per_us);
                    @atomicStore(u10, @constCast(&self.milli), @as(u10, @intCast(milli)), .Monotonic);

                    break :blk @divTrunc(self.value, std.time.us_per_s);
                },
                inline .nanos => blk: {
                    const nano = @rem(self.value, std.time.ns_per_us);
                    @atomicStore(u10, @constCast(&self.nano), @as(u10, @intCast(nano)), .Monotonic);

                    var micro = @rem(self.value, std.time.ns_per_ms);
                    micro = @divTrunc(micro, std.time.ns_per_us);
                    @atomicStore(u10, @constCast(&self.micro), @as(u10, @intCast(micro)), .Monotonic);

                    var milli = @rem(self.value, std.time.ns_per_s);
                    milli = @divTrunc(milli, std.time.ns_per_ms);
                    @atomicStore(u10, @constCast(&self.milli), @as(u10, @intCast(milli)), .Monotonic);

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

                    @atomicStore(u12, @constCast(&self.year), @as(u12, @intCast(year)), .Monotonic);
                    @atomicStore(u4, @constCast(&self.month), @as(u4, @intCast(month)), .Monotonic);
                    @atomicStore(u9, @constCast(&self.yday), @as(u9, @intCast(d)), .Monotonic);
                    @atomicStore(u5, @constCast(&self.day), @as(u5, @intCast(day)), .Monotonic);
                    @atomicStore(u6, @constCast(&self.hour), @as(u6, @intCast(hour)), .Monotonic);
                    @atomicStore(u6, @constCast(&self.min), @as(u6, @intCast(min)), .Monotonic);
                    @atomicStore(u6, @constCast(&self.sec), @as(u6, @intCast(sec)), .Monotonic);
                    @atomicStore(u3, @constCast(&self.wday), @as(u3, @intCast(weekday(self.year, self.month, self.day))), .Monotonic);

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

            @atomicStore(u12, @constCast(&self.year), @as(u12, @intCast(year)), .Monotonic);
            @atomicStore(u4, @constCast(&self.month), @as(u4, @intCast(month)), .Monotonic);
            @atomicStore(u9, @constCast(&self.yday), @as(u9, @intCast(d)), .Monotonic);
            @atomicStore(u5, @constCast(&self.day), @as(u5, @intCast(day)), .Monotonic);
            @atomicStore(u6, @constCast(&self.hour), @as(u6, @intCast(hour)), .Monotonic);
            @atomicStore(u6, @constCast(&self.min), @as(u6, @intCast(min)), .Monotonic);
            @atomicStore(u6, @constCast(&self.sec), @as(u6, @intCast(sec)), .Monotonic);
            @atomicStore(u3, @constCast(&self.wday), @as(u3, @intCast(weekday(self.year, self.month, self.day))), .Monotonic);

            return self;
        }

        // format returns a date string
        pub fn format(self: Self, pattern: []const u8, dst: []const u8) !usize {
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
                    const l1 = j == 1;
                    const l2 = j == 2 and in(2, slice);
                    const l3 = j == 3 and in(3, slice);
                    const l4 = j == 4 and in(4, slice);
                    if (l1 or l2 or l3 or l4) {
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
                } else if (std.mem.eql(u8, token, "MMMM")) {
                    const m = @as(Month, @enumFromInt(self.month));
                    try sb.appendf("{s}", .{m.string()});
                } else if (std.mem.eql(u8, token, "MMM")) {
                    const m = @as(Month, @enumFromInt(self.month));
                    try sb.appendf("{s}", .{m.shortString()});
                } else if (std.mem.eql(u8, token, "Mo")) {
                    if (self.month == 1) {
                        try sb.appendf("{d}st", .{self.month});
                    } else if (self.month == 2) {
                        try sb.appendf("{d}nd", .{self.month});
                    } else if (self.month == 3) {
                        try sb.appendf("{d}rd", .{self.month});
                    } else {
                        try sb.appendf("{d}th", .{self.month});
                    }
                } else if (std.mem.eql(u8, token, "DD")) {
                    if (self.day < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.day});
                } else if (std.mem.eql(u8, token, "DDDD")) {
                    try sb.appendf("{d}", .{self.yday});
                } else if (std.mem.eql(u8, token, "DDDo")) {
                    try sb.appendf("{d}", .{self.yday});
                    const rem = @rem(self.yday, daysBefore[self.month]);
                    if (rem == 1) {
                        try sb.append("st");
                    } else if (rem == 2) {
                        try sb.append("nd");
                    } else if (rem == 3) {
                        try sb.append("rd");
                    } else {
                        try sb.append("th");
                    }
                } else if (std.mem.eql(u8, token, "Do")) {
                    try sb.appendf("{d}", .{self.day});
                    const rem = @rem(self.day, 30);
                    if (rem == 1) {
                        try sb.append("st");
                    } else if (rem == 2) {
                        try sb.append("nd");
                    } else if (rem == 3) {
                        try sb.append("rd");
                    } else {
                        try sb.append("th");
                    }
                } else if (std.mem.eql(u8, token, "HH")) {
                    if (self.hour < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.hour});
                } else if (std.mem.eql(u8, token, "kk")) {
                    if (self.hour < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.hour});
                } else if (std.mem.eql(u8, token, "k")) {
                    try sb.appendf("{d}", .{self.hour});
                } else if (std.mem.eql(u8, token, "hh")) {
                    const h = @rem(self.hour, 12);
                    try sb.appendf("{d}", .{h});
                } else if (std.mem.eql(u8, token, "h")) {
                    const h = @rem(self.hour, 12);
                    if (h < 10) {
                        try sb.append("0");
                        try sb.appendf("0{d}", .{h});
                    } else {
                        try sb.appendf("{d}", .{h});
                    }
                } else if (std.mem.eql(u8, token, "mm")) {
                    if (self.min < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.min});
                } else if (std.mem.eql(u8, token, "ss")) {
                    if (self.sec < 10) {
                        try sb.append("0");
                    }
                    try sb.appendf("{d}", .{self.sec});
                } else if (@intFromEnum(self.measure) >= @intFromEnum(Measure.millis) and std.mem.eql(u8, token, "SSS")) {
                    const items = [_]u10{ self.milli, self.micro, self.nano };
                    for (items) |item| {
                        if (item > 0) {
                            var buffer: [3]u8 = undefined;
                            if (item < 10) {
                                _ = try std.fmt.bufPrint(&buffer, "00{d}", .{item});
                            } else if (item < 100) {
                                _ = try std.fmt.bufPrint(&buffer, "0{d}", .{item});
                            } else {
                                _ = try std.fmt.bufPrint(&buffer, "{d}", .{item});
                            }
                            try sb.append(buffer[0..3]);
                        }
                    }
                } else if (std.mem.eql(u8, token, "a")) {
                    if (self.hour <= 11) {
                        try sb.append("AM");
                    } else {
                        try sb.append("PM");
                    }
                } else if (std.mem.eql(u8, token, "c")) {
                    try sb.appendf("{d}", .{self.wday});
                } else if (std.mem.eql(u8, token, "dd")) {
                    const wd = @as(Weekday, @enumFromInt(self.wday));
                    try sb.appendf("{s}", .{wd.shorterString()});
                } else if (std.mem.eql(u8, token, "ddd")) {
                    const wd = @as(Weekday, @enumFromInt(self.wday));
                    try sb.appendf("{s}", .{wd.shortString()});
                } else if (std.mem.eql(u8, token, "dddd")) {
                    const wd = @as(Weekday, @enumFromInt(self.wday));
                    try sb.appendf("{s}", .{wd.string()});
                } else if (std.mem.eql(u8, token, "ZZ")) {
                    try sb.append("ZZ(N/A)");
                } else if (std.mem.eql(u8, token, "ZZZ")) {
                    try sb.append("ZZZ(N/A)");
                } else if (std.mem.eql(u8, token, "NN")) {
                    try sb.append("NN(N/A)");
                } else if (std.mem.eql(u8, token, "wo")) {
                    try sb.append("wo(N/A)");
                } else if (std.mem.eql(u8, token, "ww")) {
                    try sb.append("ww(N/A)");
                } else if (std.mem.eql(u8, token, "QQ")) {
                    try sb.append("QQ(N/A)");
                } else if (std.mem.eql(u8, token, "QO")) {
                    try sb.append("QO(N/A)");
                } else {
                    try sb.append(token);
                }
            }

            return try sb.bytesInto(dst);
        }
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

const tokens_2 = [_][]const u8{ "MM", "Mo", "DD", "Do", "YY", "ss", "kk", "NN", "mm", "hh", "HH", "ZZ", "dd", "Qo", "QQ", "wo", "ww" };
const tokens_3 = [_][]const u8{ "MMM", "DDD", "ZZZ", "ddd", "SSS" };
const tokens_4 = [_][]const u8{ "MMMM", "DDDD", "DDDo", "dddd", "YYYY" };

fn in(comptime tokentype: u4, elem: []const u8) bool {
    for (switch (tokentype) {
        inline 2 => tokens_2,
        inline 3 => tokens_3,
        inline 4 => tokens_4,
        inline 5...15, 0...1 => [_][]const u8{},
    }) |item| {
        if (std.mem.eql(u8, item, elem)) {
            return true;
        }
    }
    return false;
}

const weekday_t = [_]u8{ 0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4 };
fn weekday(y: u12, m: u4, d: u5) u16 {
    // Sakomotho's algorithm is explained here:
    // https://stackoverflow.com/a/6385934
    var sy = y;
    if (m < 3) {
        sy = sy - 1;
    }
    const t1 = @divTrunc(sy, 4);
    const t2 = @divTrunc(sy, 100);
    const t3 = @divTrunc(sy, 400);

    const i = @as(usize, @intCast(m));
    return @rem((sy + t1 - t2 + t3 + weekday_t[i - 1] + d - 1), 7) + 1;
}

test "format - YYYY-MM-DD HH:mm" {
    const t = Time(.seconds).now();
    const f = t.format();

    const b = try strings.formatf(90, "{}-{}-{} {}:{}", .{ t.year, t.month, t.day, t.hour, t.min });

    try std.testing.expectEqual(f, b);
}
