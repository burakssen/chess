const std = @import("std");
const Board = @import("board.zig").Board;
const Rules = @import("rules.zig").Rules;
const MoveGenerator = @import("move_gen.zig").MoveGenerator;
const core = @import("core");

const Move = core.Move;
const Square = core.Square;
const Color = core.types.Color;
const GameStatus = core.types.GameStatus;

pub const ChessGame = struct {
    allocator: std.mem.Allocator,
    board: Board,
    move_gen: MoveGenerator,
    move_history: std.ArrayList(Move),
    status: GameStatus,

    pub fn init(allocator: std.mem.Allocator) !ChessGame {
        return .{
            .allocator = allocator,
            .board = Board.init(),
            .move_gen = MoveGenerator.init(),
            .move_history = try .initCapacity(allocator, 512),
            .status = .ongoing,
        };
    }

    pub fn deinit(self: *ChessGame) void {
        self.move_history.deinit(self.allocator);
    }

    pub fn makeMove(self: *ChessGame, move: Move) !void {
        if (!Rules.isMoveLegal(&self.board, move)) return error.IllegalMove;

        const captured_piece = self.board.getPiece(move.to);

        self.board.applyMove(move);
        self.board.updateCastlingRights(move, captured_piece);

        try self.move_history.append(self.allocator, move);

        // Switch active color
        self.board.active_color = self.board.active_color.opposite();
        if (self.board.active_color == .White) {
            self.board.fullmove_number += 1;
        }

        self.updateGameStatus();
    }

    pub fn getLegalMoves(self: *ChessGame) []const Move {
        return self.move_gen.generateLegalMoves(&self.board);
    }

    pub fn getLegalMovesForPiece(self: *ChessGame, square: Square) []const Move {
        return self.move_gen.generateMovesForPiece(&self.board, square);
    }

    pub fn isInCheck(self: *const ChessGame) bool {
        return Rules.isInCheck(&self.board, self.board.active_color);
    }

    fn updateGameStatus(self: *ChessGame) void {
        const legal_moves = self.getLegalMoves();

        if (legal_moves.len == 0) {
            self.status = if (self.isInCheck()) .checkmate else .stalemate;
        } else {
            self.status = .ongoing;
        }
    }

    pub fn reset(self: *ChessGame) !void {
        self.deinit();
        self.* = try ChessGame.init(self.allocator);
    }
};
