const std = @import("std");
const core = @import("core");

const Piece = core.Piece;
const Square = core.Square;
const Move = core.Move;
const PieceType = core.types.PieceType;
const Color = core.types.Color;
const CastlingRights = core.types.CastlingRights;

pub const Board = struct {
    pieces: [64]Piece,
    active_color: Color,
    castling_rights: CastlingRights,
    en_passant_target: ?Square,
    halfmove_clock: u16,
    fullmove_number: u16,

    pub fn init() Board {
        var board = Board{
            .pieces = undefined,
            .active_color = .White,
            .castling_rights = .{},
            .en_passant_target = null,
            .halfmove_clock = 0,
            .fullmove_number = 1,
        };

        // Empty squares
        for (0..64) |i| board.pieces[i] = Piece.empty();

        // Pawns
        for (0..8) |i| {
            board.pieces[8 + i] = Piece.init(.White, .Pawn);
            board.pieces[48 + i] = Piece.init(.Black, .Pawn);
        }

        // Back ranks
        const back_rank = [_]PieceType{ .Rook, .Knight, .Bishop, .Queen, .King, .Bishop, .Knight, .Rook };
        for (back_rank, 0..) |piece_type, i| {
            board.pieces[i] = Piece.init(.White, piece_type);
            board.pieces[56 + i] = Piece.init(.Black, piece_type);
        }

        return board;
    }

    pub fn getPiece(self: *const Board, square: Square) Piece {
        return self.pieces[square.toIndex()];
    }

    pub fn setPiece(self: *Board, square: Square, piece: Piece) void {
        self.pieces[square.toIndex()] = piece;
    }

    pub fn findKing(self: *const Board, color: Color) ?Square {
        for (0..64) |i| {
            const piece = self.pieces[i];
            if (!piece.isEmpty() and piece.getType() == .King and piece.getColor() == color) {
                return Square.fromIndex(@intCast(i));
            }
        }
        return null;
    }

    pub fn clone(self: *const Board) Board {
        return self.*;
    }

    pub fn applyMove(self: *Board, move: Move) void {
        const piece = self.getPiece(move.from);
        const piece_type = piece.getType();

        // Handle en passant capture
        if (piece_type == .Pawn and self.en_passant_target != null and move.to == self.en_passant_target.?) {
            const captured_pawn_square = Square.fromCoords(move.from.rank(), move.to.file());
            self.setPiece(captured_pawn_square, Piece.empty());
        }

        // Handle castling
        if (piece_type == .King and @abs(move.to.file() - move.from.file()) == 2) {
            const is_kingside = move.to.file() > move.from.file();
            const rank = move.from.rank();
            const rook_from = Square.fromCoords(rank, if (is_kingside) 7 else 0);
            const rook_to = Square.fromCoords(rank, if (is_kingside) 5 else 3);
            self.setPiece(rook_to, self.getPiece(rook_from));
            self.setPiece(rook_from, Piece.empty());
        }

        // Move piece
        const moving_piece = if (move.promotion) |promo|
            Piece.init(piece.getColor(), promo)
        else
            piece;

        self.setPiece(move.from, Piece.empty());
        self.setPiece(move.to, moving_piece);

        // Update en passant target
        self.en_passant_target = null;
        if (piece_type == .Pawn and @abs(move.to.rank() - move.from.rank()) == 2) {
            self.en_passant_target = Square.fromCoords(
                @divTrunc(move.from.rank() + move.to.rank(), 2),
                move.from.file(),
            );
        }
    }

    pub fn updateCastlingRights(self: *Board, move: Move, captured_piece: Piece) void {
        const piece = self.getPiece(move.to);
        const piece_type = piece.getType();
        const color = piece.getColor();

        // King moved
        if (piece_type == .King) {
            self.castling_rights.remove(color, true);
            self.castling_rights.remove(color, false);
        }

        // Rook moved
        if (piece_type == .Rook) {
            const from_file = move.from.file();
            if (from_file == 0) {
                self.castling_rights.remove(color, false);
            } else if (from_file == 7) {
                self.castling_rights.remove(color, true);
            }
        }

        // Rook captured
        if (!captured_piece.isEmpty() and captured_piece.getType() == .Rook) {
            const to_file = move.to.file();
            const to_rank = move.to.rank();
            const opponent = color.opposite();

            if ((to_rank == 0 and opponent == .White) or (to_rank == 7 and opponent == .Black)) {
                if (to_file == 0) {
                    self.castling_rights.remove(opponent, false);
                } else if (to_file == 7) {
                    self.castling_rights.remove(opponent, true);
                }
            }
        }
    }

    pub fn pathClear(self: *const Board, from: Square, to: Square) bool {
        const rank_step = std.math.sign(to.rank() - from.rank());
        const file_step = std.math.sign(to.file() - from.file());

        var r = from.rank() + rank_step;
        var f = from.file() + file_step;

        while (r != to.rank() or f != to.file()) : ({
            r += rank_step;
            f += file_step;
        }) {
            if (!self.getPiece(Square.fromCoords(r, f)).isEmpty()) return false;
        }
        return true;
    }
};
