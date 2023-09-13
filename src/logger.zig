const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;

const StringBuilder = @import("bytes/strings.zig").StringBuilder;

pub const Level = enum {
    Trace,
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
    Panic,
    No,
    Disabled,

    pub fn String(self: Level) []const u8 {
        return switch (self) {
            .Trace => "Trace",
            .Debug => "Debug",
            .Info => "Info",
            .Warn => "Warn",
            .Error => "Error",
            .Fatal => "Fatal",
            .Panic => "Panic",
            .No => "No",
            .Disabled => "Disabled",
        };
    }
    pub fn ParseString(val: []const u8) Level {
        const lVal = @constCast(val);
        if (std.mem.eql(u8, "Trace", lVal)) return .Trace;
        if (std.mem.eql(u8, "Debug", lVal)) return .Debug;
        if (std.mem.eql(u8, "Info", lVal)) return .Info;
        if (std.mem.eql(u8, "Warn", lVal)) return .Warn;
        if (std.mem.eql(u8, "Error", lVal)) return .Error;
        if (std.mem.eql(u8, "Fatal", lVal)) return .Fatal;
        if (std.mem.eql(u8, "Panic", lVal)) return .Panic;
        if (std.mem.eql(u8, "No", lVal)) return .No;
        if (std.mem.eql(u8, "Disabled", lVal)) return .Disabled;
        return .Disabled;
    }
};

pub fn LoggerBuilder() type {
    return struct {
        const Self = @This();

        allocator: std.mem.Allocator,
        writer: std.fs.File.Writer,
        level: Level,

        pub fn init(allocator: std.mem.Allocator) Self {
            return Self{ .allocator = allocator, .level = .Info, .writer = std.io.getStdOut().writer() };
        }

        pub fn withWriter(self: *Self, w: std.fs.File.Writer) Self {
            @atomicStore(std.fs.File.Writer, &self.writer, w, .Monotonic);
            return self;
        }

        pub fn withLevel(self: *Self, l: Level) Self {
            @atomicStore(Level, &self.level, l, .SeqCst);
            return self;
        }

        pub fn build(self: *Self) Logger {
            return Logger{ .allocator = self.allocator, .writer = self.writer, .level = self.level };
        }
    };
}

pub const Logger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    level: Level,

    pub fn Trace(self: *Self) Entry {
        return Entry.init(self, .Trace);
    }
    pub fn Debug(self: *Self) Entry {
        return Entry.init(self, .Debug);
    }
    pub fn Info(self: *Self) Entry {
        return Entry.init(self, .Info);
    }
    pub fn Warn(self: *Self) Entry {
        return Entry.init(self, .Warn);
    }
    pub fn Error(self: *Self) Entry {
        return Entry.init(self, .Error);
    }
    pub fn Fatal(self: *Self) Entry {
        return Entry.init(self, .Fatal);
    }
    pub fn Panic(self: *Self) Entry {
        return Entry.init(self, .Panic);
    }
};

pub const Entry = struct {
    const Self = @This();

    logger: Logger,
    oplevel: Level,
    str: StringBuilder(false),

    fn init(
        logger: *Logger,
        oplevel: Level,
    ) Self {
        return &Entry{ .logger = logger, .oplevel = oplevel, .str = StringBuilder(false).init(logger.allocator) };
    }

    pub fn Str(self: *const Self, key: []const u8, value: []const u8) *const Self {
        _ = value;
        _ = key;
        return self;
    }

    pub fn Int32(self: *const Self, key: []const u8, value: i32) *const Self {
        _ = value;
        _ = key;
        return self;
    }

    pub fn Error(self: *const Self, err: error{}) *const Self {
        _ = err;
        return self;
    }

    pub fn Msg(self: *const Self, key: []const u8) *const Self {
        _ = key;
        return self;
    }
};
