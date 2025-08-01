const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // Standard target options allow the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});
    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});
    // It's also possible to define more custom flags to toggle optional features
    // of this build script using `b.option()`. All defined flags (including
    // target and optimize options) will be listed when running `zig build --help`
    // in this directory.
    //
    // Define the colors and vectors modules
    const ansi_module = b.addModule("ansi", .{
        .root_source_file = b.path("src/graphics/ansi.zig"),
        .target = target,
    });

    const vectors_module = b.addModule("vectors", .{
        .root_source_file = b.path("src/graphics/vectors.zig"),
        .target = target,
    });

    const quaternions_module = b.addModule("quaternions", .{
        .root_source_file = b.path("src/graphics/quaternions.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "vectors", .module = vectors_module },
        },
    });

    const projection_module = b.addModule("projection", .{
        .root_source_file = b.path("src/graphics/projection.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "vectors", .module = vectors_module },
        },
    });
    // Define the polygon module with dependencies on colors and vectors
    const polygon_module = b.addModule("polygon", .{
        .root_source_file = b.path("src/graphics/polygon.zig"),
        .target = target,
        .imports = &.{
            .{ .name = "ansi", .module = ansi_module },
            .{ .name = "vectors", .module = vectors_module },
            .{ .name = "quaternions", .module = quaternions_module },
            .{ .name = "projection", .module = projection_module },
        },
    });

    // Define other modules (chars, quaternions, projection) if needed
    const chars_module = b.addModule("chars", .{
        .root_source_file = b.path("src/graphics/chars.zig"),
        .target = target,
    });

    // Define the _3t module (assuming mod is defined elsewhere, e.g., for the package itself)
    const mod = b.addModule("_3t", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
    });

    // Create the executable
    const exe = b.addExecutable(.{
        .name = "_3t",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "_3t", .module = mod },
                .{ .name = "ansi", .module = ansi_module },
                .{ .name = "vectors", .module = vectors_module },
                .{ .name = "polygon", .module = polygon_module },
                .{ .name = "chars", .module = chars_module },
                .{ .name = "quaternions", .module = quaternions_module },
                .{ .name = "projection", .module = projection_module },
            },
        }),
    });

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    // This creates a RunArtifact step in the build graph. A RunArtifact step
    // invokes an executable compiled by Zig. Steps will only be executed by the
    // runner if invoked directly by the user (in the case of top level steps)
    // or if another step depends on it, so it's up to you to define when and
    // how this Run step will be executed. In our case we want to run it when
    // the user runs `zig build run`, so we create a dependency link.
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    // By making the run step depend on the default step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // Creates an executable that will run `test` blocks from the provided module.
    // Here `mod` needs to define a target, which is why earlier we made sure to
    // set the releative field.
    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    // A run step that will run the test executable.
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Creates an executable that will run `test` blocks from the executable's
    // root module. Note that test executables only test one module at a time,
    // hence why we have to create two separate ones.
    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    // A run step that will run the second test executable.
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // A top level step for running all tests. dependOn can be called multiple
    // times and since the two run steps do not depend on one another, this will
    // make the two of them run in parallel.
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);

    // Just like flags, top level steps are also listed in the `--help` menu.
    //
    // The Zig build system is entirely implemented in userland, which means
    // that it cannot hook into private compiler APIs. All compilation work
    // orchestrated by the build system will result in other Zig compiler
    // subcommands being invoked with the right flags defined. You can observe
    // these invocations when one fails (or you pass a flag to increase
    // verbosity) to validate assumptions and diagnose problems.
    //
    // Lastly, the Zig build system is relatively simple and self-contained,
    // and reading its source code will allow you to master it.
}
