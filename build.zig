const std = @import("std");
const raylib = @import("raylib");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // --- Dependencies ---
    const raylib_dep = b.dependency("raylib", .{ .target = target, .optimize = optimize });
    const raylib_artifact = raylib_dep.artifact("raylib");

    // --- Modules ---
    const core = b.createModule(.{
        .root_source_file = b.path("src/core/core.zig"),
        .target = target,
        .optimize = optimize,
    });

    const engine = b.createModule(.{
        .root_source_file = b.path("src/engine/engine.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "core", .module = core }},
    });

    const ai = b.createModule(.{
        .root_source_file = b.path("src/ai/ai.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "engine", .module = engine },
        },
    });

    const ui = b.createModule(.{
        .root_source_file = b.path("src/ui/ui.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "engine", .module = engine },
        },
    });

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "core", .module = core },
            .{ .name = "engine", .module = engine },
            .{ .name = "ai", .module = ai },
            .{ .name = "ui", .module = ui },
        },
    });

    // Link Raylib
    for (&[_]*std.Build.Module{ ui, exe_mod }) |mod| {
        mod.linkLibrary(raylib_artifact);
        mod.addIncludePath(raylib_dep.path("src"));
    }

    // --- Emscripten Build (WASM) ---
    if (target.result.os.tag == .emscripten) {
        const wasm = b.addLibrary(.{ .name = "chess", .root_module = exe_mod });
        wasm.linkLibrary(raylib_artifact);
        wasm.addIncludePath(raylib_dep.path("src"));

        // Emscripten flags & settings
        const emcc_flags = raylib.emsdk.emccDefaultFlags(b.allocator, .{
            .optimize = optimize,
            .asyncify = true,
        });

        var emcc_settings = raylib.emsdk.emccDefaultSettings(b.allocator, .{
            .optimize = optimize,
        });
        try emcc_settings.put("STACK_SIZE", "1500KB");
        try emcc_settings.put("EXPORTED_FUNCTIONS", "[_main, _GetScreenWidth, _GetScreenHeight]");

        // Compile to HTML
        const emcc_step = raylib.emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .shell_file_path = b.path("index.html"),
            .install_dir = .{ .custom = "web" },
            .preload_paths = &.{
                .{ .src_path = b.path("assets").getPath(b), .virtual_path = "assets" },
                .{ .src_path = b.path("assets/default").getPath(b), .virtual_path = "assets/default" },
                .{ .src_path = b.path("assets/bubblegum").getPath(b), .virtual_path = "assets/bubblegum" },
                .{ .src_path = b.path("assets/neon").getPath(b), .virtual_path = "assets/neon" },
            },
        });
        b.getInstallStep().dependOn(emcc_step);

        return;
    }

    // --- Native Build (Desktop) ---
    const exe = b.addExecutable(.{
        .name = "chess",
        .root_module = exe_mod,
    });
    exe.linkLibrary(raylib_artifact);
    b.installArtifact(exe);

    const run = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| run_cmd.addArgs(args);

    // --- Tests ---
    const tests = b.addTest(.{ .root_module = exe_mod });
    tests.linkLibrary(raylib_artifact);

    const run_tests = b.addRunArtifact(tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_tests.step);
}
