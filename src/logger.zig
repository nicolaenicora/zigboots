const std = @import("std");
const time = std.time;
const mem = std.mem;
const Allocator = mem.Allocator;
const StringHashMap = std.StringHashMap;

const StringBuilder = @import("bytes/strings.zig").StringBuilder;

pub const Format = enum(u8) {
    Simple = 0,
    Json,
};

pub const Level = enum(u8) {
    Trace = 0,
    Debug,
    Info,
    Warn,
    Error,
    Fatal,
    Disabled,

    pub fn String(self: Level) []const u8 {
        return switch (self) {
            .Trace => "TRACE",
            .Debug => "DEBUG",
            .Info => "INFO",
            .Warn => "WARN",
            .Error => "ERROR",
            .Fatal => "FATAL",
            .Disabled => "DISABLED",
        };
    }
    pub fn ParseString(val: []const u8) !Level {
        var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
        defer arena.deinit();

        var sb = StringBuilder.init(arena.allocator());
        defer sb.deinit();

        try sb.append(val);
        sb.toUppercase();

        const lVal = sb.bytes();
        if (std.mem.eql(u8, "TRACE", lVal)) return .Trace;
        if (std.mem.eql(u8, "DEBUG", lVal)) return .Debug;
        if (std.mem.eql(u8, "INFO", lVal)) return .Info;
        if (std.mem.eql(u8, "WARN", lVal)) return .Warn;
        if (std.mem.eql(u8, "ERROR", lVal)) return .Error;
        if (std.mem.eql(u8, "FATAL", lVal)) return .Fatal;
        if (std.mem.eql(u8, "DISABLED", lVal)) return .Disabled;
        return .Disabled;
    }
};

pub const Logger = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    writer: std.fs.File.Writer,
    level: Level,
    format: Format,

    pub fn init(allocator: std.mem.Allocator, l: Level, f: Format) Self {
        return Self{ .allocator = allocator, .level = l, .format = f, .writer = std.io.getStdOut().writer() };
    }

    pub fn Trace(self: Self) Entry {
        const op = Level.Trace;
        if (@intFromEnum(self.level) > @intFromEnum(op)) {
            return Entry.initEmpty();
        }
        return Entry.init(self, op);
    }
    pub fn Debug(self: Self) Entry {
        const op = Level.Debug;
        if (@intFromEnum(self.level) > @intFromEnum(op)) {
            return Entry.initEmpty();
        }
        return Entry.init(self, op);
    }
    pub fn Info(self: Self) Entry {
        const op = Level.Info;
        if (@intFromEnum(self.level) > @intFromEnum(op)) {
            return Entry.initEmpty();
        }
        return Entry.init(self, op);
    }
    pub fn Warn(self: Self) Entry {
        const op = Level.Warn;
        if (@intFromEnum(self.level) > @intFromEnum(op)) {
            return Entry.initEmpty();
        }
        return Entry.init(self, op);
    }
    pub fn Error(self: Self) Entry {
        const op = Level.Error;
        if (@intFromEnum(self.level) > @intFromEnum(op)) {
            return Entry.initEmpty();
        }
        return Entry.init(self, op);
    }
    pub fn Fatal(self: Self) Entry {
        const op = Level.Fatal;
        if (@intFromEnum(self.level) > @intFromEnum(op)) {
            return Entry.initEmpty();
        }
        return Entry.init(self, op);
    }
};

pub const Entry = struct {
    const Self = @This();

    logger: ?Logger = null,
    opLevel: Level,

    elems: ?StringHashMap([]const u8) = null,

    fn initEmpty() Self {
        return Entry{ .opLevel = .Disabled };
    }

    fn init(
        logger: Logger,
        opLevel: Level,
    ) Self {
        return Entry{ .logger = logger, .opLevel = opLevel, .elems = StringHashMap([]const u8).init(logger.allocator) };
    }

    pub fn deinit(self: *Self) void {
        if (self.elems) |*hash| {
            var iter = hash.iterator();
            while (iter.next()) |entry| {
                self.logger.?.allocator.free(entry.value_ptr.*);
            }

            hash.deinit();
        }
    }

    pub fn Attr(self: *Self, key: []const u8, comptime V: type, value: V) *Self {
        if (self.elems) |*hash| {
            var str = StringBuilder.init(self.logger.?.allocator);

            switch (@TypeOf(value)) {
                []const u8 => str.appendf("{s}", .{value}) catch {},
                else => str.appendf("{}", .{value}) catch {},
            }

            if (str.find(" ")) |_| {
                switch (self.logger.?.format) {
                    .Simple => {
                        str.appendAt("\u{0022}", 0) catch {};
                        str.append("\u{0022}") catch {};
                    },
                    .Json => {},
                }
            }

            str.shrink() catch {};

            hash.put(key, str.bytes()) catch {};
        }

        return self;
    }

    pub fn Error(self: *Self, value: error{}) *Self {
        return self.Attr("error", error{}, value);
    }

    pub fn Msg(self: *Self, message: []const u8) void {
        switch (self.logger.?.format) {
            .Simple => self.simpleMsg(message),
            .Json => self.jsonMsg(message),
        }
    }

    inline fn jsonMsg(self: *Self, message: []const u8) void {
        if (self.elems) |*hash| {
            defer self.deinit();

            var str = StringBuilder.init(self.logger.?.allocator);
            defer str.deinit();

            str.append("{") catch {};

            str.appendf("\u{0022}{s}\u{0022}: \u{0022}{any}\u{0022}", .{ "timestamp", time.microTimestamp() }) catch {};
            str.appendf(", \u{0022}{s}\u{0022}: \u{0022}{s}\u{0022}", .{ "level", self.opLevel.String() }) catch {};
            if (message.len > 0) {
                str.appendf(", \u{0022}{s}\u{0022}: \u{0022}{s}\u{0022}", .{ "message", self.opLevel.String() }) catch {};
            }

            var iter = hash.iterator();
            while (iter.next()) |entry| {
                str.appendf(", \u{0022}{s}\u{0022}: \u{0022}{s}\u{0022}", .{ entry.key_ptr.*, entry.value_ptr.* }) catch {};
            }

            str.append("}\n") catch {};

            str.shrink() catch {};

            const result = str.bytes();

            _ = self.logger.?.writer.write(result) catch {};
        }
    }

    inline fn simpleMsg(self: *Self, message: []const u8) void {
        if (self.elems) |*hash| {
            defer self.deinit();

            var str = StringBuilder.init(self.logger.?.allocator);
            defer str.deinit();

            str.appendf("{any} {s}", .{ time.microTimestamp(), self.opLevel.String() }) catch {};
            if (message.len > 0) {
                str.appendf(" {s}", .{message}) catch {};
            }
            str.append(" ") catch {};

            var iter = hash.iterator();
            while (iter.next()) |entry| {
                str.appendf("{s}={s} ", .{ entry.key_ptr.*, entry.value_ptr.* }) catch {};
            }
            str.removeEnd(1) catch {};

            str.append("\n") catch {};

            str.shrink() catch {};

            const result = str.bytes();

            _ = self.logger.?.writer.write(result) catch {};
        }
    }

    pub fn Send(self: *Self) void {
        self.Msg("");
    }
};
