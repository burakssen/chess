const std = @import("std");
const builtin = @import("builtin");
const Game = @import("game");

pub fn main() !void {
    var wasm_buffer: [1024 * 1024 * 1]u8 = undefined;

    var fba = std.heap.FixedBufferAllocator.init(&wasm_buffer);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = switch (builtin.os.tag) {
        .emscripten => fba.allocator(),
        else => gpa.allocator(),
    };

    defer _ = if (builtin.os.tag != .emscripten) gpa.deinit();

    var game = try Game.init(allocator);
    defer game.deinit();

    try game.run();
}
