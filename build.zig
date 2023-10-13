const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zigboots",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // const zap = b.dependency("zap", .{
    //     .target = target,
    //     .optimize = optimize,
    // });

    // exe.addModule("zap", zap.module("zap"));
    // exe.linkLibrary(zap.artifact("facil.io"));

    //exe.linkLibrary(duck.artifact("duckdb"));
    //exe.installLibraryHeaders(duck.artifact("duckdb"));

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    var test_step = b.step("test-suite", "Run unit tests");
    {
        var dir = try std.fs.cwd().openDir(".", .{});

        const walker = try dir.openIterableDir("src", .{ .access_sub_paths = true });
        var iter = try walker.walk(b.allocator);

        const allowed_exts = [_][]const u8{".zig"};
        while (try iter.next()) |entry| {
            const ext = std.fs.path.extension(entry.basename);
            const include_file = for (allowed_exts) |e| {
                if (std.mem.eql(u8, ext, e))
                    break true;
            } else false;
            if (include_file) {
                // we have to clone the path as walker.next() or walker.deinit() will override/kill it

                var buff: [1024]u8 = undefined;
                const testPath = try std.fmt.bufPrint(&buff, "src/{s}", .{entry.path});
                //std.debug.print("Testing: {s}\n", .{testPath});

                test_step.dependOn(&b.addRunArtifact(b.addTest(.{
                    .root_source_file = .{ .path = testPath },
                    .target = target,
                    .optimize = optimize,
                })).step);
            }
        }
    }
}
