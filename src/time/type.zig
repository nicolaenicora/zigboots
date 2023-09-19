const std = @import("std");

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
        month: Month = .January,
        day: Weekday = .Sunday,
        hour: u5 = 0,
        min: u6 = 0,
        sec: u6 = 0,

        milli: u16 = 0,
        micro: u32 = 0,
        nano: u32 = 0,

        pub fn now() Self {
            var t = @constCast(&Self{ .value = switch (measure) {
                inline .seconds => std.time.timestamp(),
                inline .millis => std.time.milliTimestamp(),
                inline .micros => std.time.microTimestamp(),
                inline .nanos => std.time.nanoTimestamp(),
            } }).parse();
            return t.*;
        }

        fn parse(self: *Self) *Self {
            const seconds = switch (measure) {
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
            // d := abs / secondsPerDay
            var d = @divFloor(seconds, std.time.s_per_day);

            // Account for 400 year cycles.
            // n := d / daysPer400Years
            var n = @divFloor(d, days_per_400_years);
            var y = 400 * n;
            d -= days_per_400_years * n;

            // Cut off 100-year cycles.
            // The last cycle has one extra leap year, so on the last day
            // of that year, day / daysPer100Years will be 4 instead of 3.
            // Cut it back down to 3 by subtracting n>>2.
            // n = d / daysPer100Years
            n = @divFloor(d, days_per_100_years);
            n -= n >> 2;
            y += 100 * n;
            d -= days_per_100_years * n;

            // Cut off 4-year cycles.
            // The last cycle has a missing leap year, which does not
            // affect the computation.
            // n = d / daysPer4Years
            n = @divFloor(d, days_per_4_years);
            y += 4 * n;
            d -= days_per_4_years * n;

            // Cut off years within a 4-year cycle.
            // The last year is a leap year, so on the last day of that year,
            // day / 365 will be 4 instead of 3. Cut it back down to 3
            // by subtracting n>>2.
            n = @divFloor(d, 365);
            n -= n >> 2;
            y += n;
            d -= 365 * n;

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
                    @atomicStore(Month, @constCast(&self.month), @as(Month, @enumFromInt(month)), .Monotonic);
                    @atomicStore(Weekday, @constCast(&self.day), @as(Weekday, @enumFromInt(day)), .Monotonic);
                    @atomicStore(u5, @constCast(&self.hour), @as(u5, @intCast(hour)), .Monotonic);
                    @atomicStore(u6, @constCast(&self.min), @as(u6, @intCast(min)), .Monotonic);
                    @atomicStore(u6, @constCast(&self.sec), @as(u6, @intCast(sec)), .Monotonic);

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
            @atomicStore(Month, @constCast(&self.month), @as(Month, @enumFromInt(month)), .Monotonic);
            @atomicStore(Weekday, @constCast(&self.day), @as(Weekday, @enumFromInt(day)), .Monotonic);
            @atomicStore(u5, @constCast(&self.hour), @as(u5, @intCast(hour)), .Monotonic);
            @atomicStore(u6, @constCast(&self.min), @as(u6, @intCast(min)), .Monotonic);
            @atomicStore(u6, @constCast(&self.sec), @as(u6, @intCast(sec)), .Monotonic);

            return self;
        }
    };
}

inline fn isLeap(year: i128) bool {
    return @rem(year, 4) == 0 and (@rem(year, 100) != 0 or @rem(year, 400) == 0);
}

const absolute_zero_year = 1970;
const days_per_400_years = 365 * 400 + 97;
const days_per_100_years = 365 * 100 + 24;
const days_per_4_years = 365 * 4 + 1;

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

fn daysIn(m: Month, year: u32) u32 {
    if (m == .February and isLeap(year)) {
        return 29;
    }
    return daysBefore[m] - daysBefore[m - 1];
}
