const std = @import("std");
const Board = @import("board.zig").Board;
const Rules = @import("rules.zig").Rules;
const core = @import("core");
const Square = core.Square;
const Move = core.Move;
const PieceType = core.types.PieceType;
const Color = core.types.Color;

pub const MoveGenerator = struct {
    buffer: [256]Move,
    count: usize,

    pub fn init() MoveGenerator {
        return .{
            .buffer = undefined,
            .count = 0,
        };
    }

    pub fn generateLegalMoves(self: *MoveGenerator, board: *const Board) []const Move {
        self.count = 0;

        for (0..64) |i| {
            const from_sq = Square.fromIndex(@intCast(i));
            const piece = board.getPiece(from_sq);
            if (piece.isEmpty() or piece.getColor() != board.active_color) continue;

            _ = self.generateMovesForPiece(board, from_sq);
        }

        return self.buffer[0..self.count];
    }

    pub fn generateMovesForPiece(self: *MoveGenerator, board: *const Board, square: Square) []const Move {
        const start_count = self.count;

        const piece = board.getPiece(square);
        if (piece.isEmpty() or piece.getColor() != board.active_color) {
            return self.buffer[start_count..self.count];
        }

        const piece_type = piece.getType();
        const color = piece.getColor();

        for (0..64) |i| {
            const to_sq = Square.fromIndex(@intCast(i));

            // Handle pawn promotions
            if (piece_type == .Pawn) {
                const promo_rank: i8 = if (color == .White) 7 else 0;
                if (to_sq.rank() == promo_rank) {
                    const promo_types = [_]PieceType{ .Queen, .Rook, .Bishop, .Knight };
                    for (promo_types) |promo_type| {
                        const move = Move.withPromotion(square, to_sq, promo_type);
                        if (Rules.isMoveLegal(board, move)) {
                            self.addMove(move);
                        }
                    }
                    continue;
                }
            }

            // Regular move
            const move = Move.init(square, to_sq);
            if (Rules.isMoveLegal(board, move)) {
                self.addMove(move);
            }
        }

        return self.buffer[start_count..self.count];
    }

    fn addMove(self: *MoveGenerator, move: Move) void {
        if (self.count < self.buffer.len) {
            self.buffer[self.count] = move;
            self.count += 1;
        }
    }

    pub fn reset(self: *MoveGenerator) void {
        self.count = 0;
    }
};
