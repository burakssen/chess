const std = @import("std");
const raylib = @import("raylib");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Fetch raylib dependency
    const raylib_dep = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib_artifact = raylib_dep.artifact("raylib");

    const chess_mod = b.createModule(.{
        .root_source_file = b.path("src/chess/chess.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });

    const game_mod = b.createModule(.{
        .root_source_file = b.path("src/game/game.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "chess", .module = chess_mod },
        },
    });

    game_mod.linkLibrary(raylib_artifact);
    game_mod.addIncludePath(raylib_dep.path("src"));

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "game", .module = game_mod },
        },
    });

    // Check if we're targeting Emscripten
    if (target.result.os.tag == .emscripten) {
        // For Emscripten, we need to create a static library (WASM)
        const wasm = b.addLibrary(.{
            .name = "chess",
            .root_module = exe_mod,
        });

        const emsdk = b.dependency("emsdk", .{});
        game_mod.addSystemIncludePath(emsdk.path("upstream/emscripten/cache/sysroot/include"));

        wasm.linkLibrary(raylib_artifact);

        // Get emcc flags and settings
        const emcc_flags = raylib.emsdk.emccDefaultFlags(b.allocator, .{
            .optimize = optimize,
            .asyncify = true,
        });

        var emcc_settings = raylib.emsdk.emccDefaultSettings(b.allocator, .{
            .optimize = optimize,
        });

        try emcc_settings.put("STACK_SIZE", "1500KB");
        try emcc_settings.put("EXPORTED_FUNCTIONS", "[_main, _GetScreenWidth, _GetScreenHeight]");

        // Create the emcc step to compile to HTML
        const emcc_step = raylib.emsdk.emccStep(b, raylib_artifact, wasm, .{
            .optimize = optimize,
            .flags = emcc_flags,
            .settings = emcc_settings,
            .shell_file_path = b.path("index.html"),
            .install_dir = .{ .custom = "web" },
            .preload_paths = &.{
                .{ .src_path = b.path("assets").getPath(b), .virtual_path = "assets" },
            },
        });

        b.getInstallStep().dependOn(emcc_step);

        // Run step for Emscripten (opens in browser)
        const run_step = b.step("run", "Run the web build");
        const emrun_step = raylib.emsdk.emrunStep(
            b,
            b.getInstallPath(.{ .custom = "web" }, "index.html"),
            &.{"--no_browser"},
        );
        emrun_step.dependOn(emcc_step);
        run_step.dependOn(emrun_step);
    } else {
        // Native build (desktop)
        const exe = b.addExecutable(.{
            .name = "chess",
            .root_module = exe_mod,
        });

        exe.linkLibrary(raylib_artifact);

        b.installArtifact(exe);

        const run_step = b.step("run", "Run the app");
        const run_cmd = b.addRunArtifact(exe);
        run_step.dependOn(&run_cmd.step);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }
    }

    // Tests (only for native builds)
    if (target.result.os.tag != .emscripten) {
        const exe_tests = b.addTest(.{
            .root_module = exe_mod,
        });

        exe_tests.linkLibrary(raylib_artifact);

        const run_exe_tests = b.addRunArtifact(exe_tests);
        const test_step = b.step("test", "Run tests");
        test_step.dependOn(&run_exe_tests.step);
    }
}
