const std = @import("std");

pub const Board = @import("board.zig");
pub const Piece = @import("piece.zig");
pub const types = @import("types.zig");

const Move = types.Move;
const Square = types.Square;

pub const Chess = @This();

board: Board,
move_history: std.array_list.Managed(Move),
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Chess {
    return .{
        .board = Board.init(),
        .move_history = std.array_list.Managed(Move).init(allocator),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Chess) void {
    self.move_history.deinit();
}

pub fn makeMove(self: *Chess, move: Move) !void {
    try self.board.makeMove(move);
    try self.move_history.append(move);
}

pub fn undoMove(self: *Chess) !void {
    // Implementation needed: store board state history
    _ = self.move_history.pop();
}
