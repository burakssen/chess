const std = @import("std");
const Board = @import("board.zig").Board;
const core = @import("core");
const Piece = core.Piece;
const Square = core.Square;
const Move = core.Move;
const Color = core.types.Color;
const PieceType = core.types.PieceType;

pub const Rules = struct {
    pub fn isMovePseudoLegal(board: *const Board, move: Move) bool {
        const piece = board.getPiece(move.from);
        if (piece.isEmpty() or piece.getColor() != board.active_color) return false;

        const target = board.getPiece(move.to);
        if (!target.isEmpty() and target.getColor() == piece.getColor()) return false;

        return isPieceMoveLegal(board, piece, move);
    }

    fn isPieceMoveLegal(board: *const Board, piece: Piece, move: Move) bool {
        const fr = move.from.rank();
        const ff = move.from.file();
        const tr = move.to.rank();
        const tf = move.to.file();
        const rd = tr - fr;
        const fd = tf - ff;

        return switch (piece.getType()) {
            .Pawn => isPawnMoveLegal(board, piece, move, fr, ff, tr, tf, rd, fd),
            .Knight => (@abs(rd) == 1 and @abs(fd) == 2) or (@abs(rd) == 2 and @abs(fd) == 1),
            .Bishop => @abs(rd) == @abs(fd) and board.pathClear(move.from, move.to),
            .Rook => (rd == 0 or fd == 0) and board.pathClear(move.from, move.to),
            .Queen => (rd == 0 or fd == 0 or @abs(rd) == @abs(fd)) and board.pathClear(move.from, move.to),
            .King => isKingMoveLegal(board, piece, move, fr, ff, tr, tf, rd, fd),
            else => false,
        };
    }

    fn isPawnMoveLegal(
        board: *const Board,
        piece: Piece,
        move: Move,
        fr: i8,
        ff: i8,
        tr: i8,
        _: i8, // to file
        rd: i8,
        fd: i8,
    ) bool {
        const dir: i8 = if (piece.getColor() == .White) 1 else -1;
        const start_rank: i8 = if (piece.getColor() == .White) 1 else 6;
        const promo_rank: i8 = if (piece.getColor() == .White) 7 else 0;
        const target = board.getPiece(move.to);

        // Check promotion validity
        if (tr == promo_rank) {
            if (move.promotion == null) return false;
            const promo_type = move.promotion.?;
            if (promo_type == .Pawn or promo_type == .King) return false;
        } else {
            if (move.promotion != null) return false;
        }

        // Forward moves
        if (fd == 0) {
            if (rd == dir and target.isEmpty()) return true;
            if (rd == 2 * dir and target.isEmpty() and fr == start_rank) {
                const mid = Square.fromCoords(fr + dir, ff);
                return board.getPiece(mid).isEmpty();
            }
        }

        // Captures
        if (@abs(fd) == 1 and rd == dir) {
            if (!target.isEmpty() and target.getColor() != piece.getColor()) return true;
            if (board.en_passant_target) |ep| if (ep == move.to) return true;
        }

        return false;
    }

    fn isKingMoveLegal(
        board: *const Board,
        piece: Piece,
        move: Move,
        fr: i8,
        ff: i8,
        tr: i8,
        tf: i8,
        rd: i8,
        fd: i8,
    ) bool {
        // Normal king move
        if (@abs(rd) <= 1 and @abs(fd) <= 1) return true;

        // Castling
        if (fr == tr and @abs(fd) == 2) {
            if (!board.pathClear(move.from, move.to)) return false;

            const is_kingside = tf > ff;
            const between_files: []const i8 = if (is_kingside) &.{ 5, 6 } else &.{ 1, 2, 3 };

            // Check if squares are empty and not attacked
            for (between_files) |f| {
                const sq = Square.fromCoords(fr, f);
                if (!board.getPiece(sq).isEmpty()) return false;
                if (isSquareAttacked(board, sq, piece.getColor().opposite())) return false;
            }

            return board.castling_rights.canCastle(piece.getColor(), is_kingside);
        }

        return false;
    }

    pub fn isSquareAttacked(board: *const Board, square: Square, by_color: Color) bool {
        for (0..64) |i| {
            const from_sq = Square.fromIndex(@intCast(i));
            const piece = board.getPiece(from_sq);
            if (piece.isEmpty() or piece.getColor() != by_color) continue;

            // Create temporary board with attacker's perspective
            var temp_board = board.*;
            temp_board.active_color = by_color;

            const move = Move.init(from_sq, square);
            if (isMovePseudoLegal(&temp_board, move)) return true;
        }
        return false;
    }

    pub fn isMoveLegal(board: *const Board, move: Move) bool {
        if (!isMovePseudoLegal(board, move)) return false;

        // Make move on temporary board
        var temp_board = board.clone();
        temp_board.applyMove(move);

        // Check if our king is in check after the move
        const our_king = temp_board.findKing(board.active_color) orelse return false;
        return !isSquareAttacked(&temp_board, our_king, board.active_color.opposite());
    }

    pub fn isInCheck(board: *const Board, color: Color) bool {
        const king_square = board.findKing(color) orelse return false;
        return isSquareAttacked(board, king_square, color.opposite());
    }
};
