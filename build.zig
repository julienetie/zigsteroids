const std = @import("std");
const rl = @import("raylib-zig/build.zig");

pub fn build(b: *std.Build) !void {
    // target options
    const target = b.standardTargetOptions(.{});
    // optimization level from the standard build options
    const optimize = b.standardOptimizeOption(.{});
    // raylib modules
    const raylib = rl.getModule(b, "raylib-zig");
    const raylib_math = rl.math.getModule(b, "raylib-zig");

    // Creates a new executable with the following properties
    // - name: NAme of executable
    // - root_source_file: Main source file location
    // - optimize: optimization level
    // - target: target options
    const exe = b.addExecutable(.{ .name = "lsr", .root_source_file = .{ .path = "src/main.zig" }, .optimize = optimize, .target = target });

    // Links raylib lib to executable
    rl.link(b, exe, target, optimize);
    exe.addModule("raylib", raylib);
    exe.addmodule("raylib-math", raylib_math);

    // Creates run artifacto for executable allowing it to be run after the build
    const run_cmd = b.addRunArtifact(exe);
    // Defines a build step named run
    const run_step = b.step("run", "run");
    // Sets the run step to depend on the run command step. Ensuring the executable is run after being built
    run_step.dependOn(&run_cmd.step);

    // Installs the executable as a build artifact, making it available for use after the buiild process completes
    b.installArtifact(exe);
}
