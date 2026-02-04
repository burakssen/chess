const std = @import("std");
const board = @import("board.zig");
const Board = board.Board;
const UndoInfo = board.UndoInfo;
const Rules = @import("rules.zig").Rules;
const MoveGenerator = @import("move_gen.zig").MoveGenerator;
const core = @import("core");

const Move = core.Move;
const Square = core.Square;
const Color = core.types.Color;
const GameStatus = core.types.GameStatus;

/// Game mode configuration
pub const GameMode = enum {
    human_vs_human,
    human_vs_computer,
    computer_vs_human,
    computer_vs_computer,
};

pub const ChessGame = struct {
    allocator: std.mem.Allocator,
    board: Board,
    move_gen: MoveGenerator,
    move_history: std.ArrayList(Move),
    undo_history: std.ArrayList(UndoInfo),
    status: GameStatus,
    game_mode: GameMode,
    human_color: Color,

    pub fn init(allocator: std.mem.Allocator) !ChessGame {
        return initWithMode(allocator, .human_vs_human, .White);
    }

    pub fn initWithMode(allocator: std.mem.Allocator, mode: GameMode, human_color: Color) !ChessGame {
        return .{
            .allocator = allocator,
            .board = Board.init(),
            .move_gen = MoveGenerator.init(),
            .move_history = try .initCapacity(allocator, 512),
            .undo_history = try .initCapacity(allocator, 512),
            .status = .ongoing,
            .game_mode = mode,
            .human_color = human_color,
        };
    }

    pub fn deinit(self: *ChessGame) void {
        self.move_history.deinit(self.allocator);
        self.undo_history.deinit(self.allocator);
    }

    /// Returns true if the current player is a computer
    pub fn isComputerTurn(self: *const ChessGame) bool {
        return switch (self.game_mode) {
            .human_vs_human => false,
            .human_vs_computer => self.board.active_color != self.human_color,
            .computer_vs_human => self.board.active_color != self.human_color,
            .computer_vs_computer => true,
        };
    }

    /// Returns true if the current player is human
    pub fn isHumanTurn(self: *const ChessGame) bool {
        return !self.isComputerTurn();
    }

    pub fn makeMove(self: *ChessGame, move: Move) !void {
        if (!Rules.isMoveLegal(&self.board, move)) return error.IllegalMove;

        const undo_info = self.board.makeMove(move);
        try self.move_history.append(self.allocator, move);
        try self.undo_history.append(self.allocator, undo_info);

        self.updateGameStatus();
    }

    pub fn undoMove(self: *ChessGame) void {
        if (self.move_history.items.len == 0) return;

        const move = self.move_history.pop().?;
        const undo = self.undo_history.pop().?;
        self.board.unmakeMove(move, undo);

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
        const mode = self.game_mode;
        const human_color = self.human_color;
        self.deinit();
        self.* = try ChessGame.initWithMode(self.allocator, mode, human_color);
    }

    pub fn setGameMode(self: *ChessGame, mode: GameMode, human_color: Color) void {
        self.game_mode = mode;
        self.human_color = human_color;
    }
};
