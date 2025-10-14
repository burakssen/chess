const std = @import("std");

const rl = @cImport({
    @cInclude("raylib.h");
});

const Chess = @import("chess");
const PieceTextures = @import("piece_textures.zig");
const Piece = Chess.Piece;
const Square = Chess.types.Square;
const Move = Chess.types.Move;
const types = @import("types.zig");
const GameStatus = types.GameStatus;

const ChessState = @This();

chess: Chess,
textures: PieceTextures,
selected_square: ?Square,
dragging_piece: ?struct {
    piece: Piece,
    from: Square,
    mouse_offset: rl.Vector2,
},
legal_moves: std.array_list.Managed(Move),
allocator: std.mem.Allocator,
game_status: GameStatus,

pub fn init(allocator: std.mem.Allocator) !ChessState {
    return ChessState{
        .chess = Chess.init(allocator),
        .textures = try PieceTextures.init(allocator),
        .selected_square = null,
        .dragging_piece = null,
        .legal_moves = std.array_list.Managed(Move).init(allocator),
        .allocator = allocator,
        .game_status = .ongoing,
    };
}

pub fn deinit(self: *ChessState) void {
    self.chess.deinit();
    self.textures.deinit();
    self.legal_moves.deinit();
}

pub fn reset(self: *ChessState) !void {
    self.chess.deinit();
    self.chess = Chess.init(self.allocator);
    self.selected_square = null;
    self.dragging_piece = null;
    self.legal_moves.clearRetainingCapacity();
    self.game_status = .ongoing;
}
