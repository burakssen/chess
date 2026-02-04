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
        self.reset();

        for (0..64) |i| {
            const from_sq = Square.fromIndex(@intCast(i));
            const piece = board.getPiece(from_sq);
            if (piece.isEmpty() or piece.getColor() != board.active_color) continue;

            _ = self.generateMovesForPieceInternal(board, from_sq);
        }

        return self.buffer[0..self.count];
    }

    pub fn generateMovesForPiece(self: *MoveGenerator, board: *const Board, square: Square) []const Move {
        self.reset();
        return self.generateMovesForPieceInternal(board, square);
    }

    fn generateMovesForPieceInternal(self: *MoveGenerator, board: *const Board, square: Square) []const Move {
        const start_count = self.count;

        const piece = board.getPiece(square);
        if (piece.isEmpty() or piece.getColor() != board.active_color) {
            return self.buffer[start_count..self.count];
        }

        const piece_type = piece.getType();
        const color = piece.getColor();
        const rank = square.rank();
        const file = square.file();

        switch (piece_type) {
            .Pawn => self.generatePawnMoves(board, square, color, rank, file),
            .Knight => self.generateKnightMoves(board, square, color, rank, file),
            .Bishop => self.generateSlidingMoves(board, square, color, rank, file, &.{ .{ -1, -1 }, .{ -1, 1 }, .{ 1, -1 }, .{ 1, 1 } }),
            .Rook => self.generateSlidingMoves(board, square, color, rank, file, &.{ .{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 } }),
            .Queen => self.generateSlidingMoves(board, square, color, rank, file, &.{ .{ -1, 0 }, .{ 1, 0 }, .{ 0, -1 }, .{ 0, 1 }, .{ -1, -1 }, .{ -1, 1 }, .{ 1, -1 }, .{ 1, 1 } }),
            .King => self.generateKingMoves(board, square, color, rank, file),
            else => {},
        }

        return self.buffer[start_count..self.count];
    }

    fn generatePawnMoves(self: *MoveGenerator, board: *const Board, square: Square, color: Color, rank: i8, file: i8) void {
        const dir: i8 = if (color == .White) 1 else -1;
        const start_rank: i8 = if (color == .White) 1 else 6;
        const promo_rank: i8 = if (color == .White) 7 else 0;

        // Forward 1
        const r1 = rank + dir;
        if (r1 >= 0 and r1 < 8) {
            const to1 = Square.fromCoords(r1, file);
            if (board.getPiece(to1).isEmpty()) {
                self.addPawnMove(square, to1, r1 == promo_rank, board);
                // Forward 2
                if (rank == start_rank) {
                    const r2 = rank + 2 * dir;
                    const to2 = Square.fromCoords(r2, file);
                    if (board.getPiece(to2).isEmpty()) {
                        self.addPawnMove(square, to2, false, board);
                    }
                }
            }
        }

        // Captures
        const capture_files = [_]i8{ -1, 1 };
        for (capture_files) |df| {
            const f = file + df;
            const r = rank + dir;
            if (f >= 0 and f < 8 and r >= 0 and r < 8) {
                const to = Square.fromCoords(r, f);
                const target = board.getPiece(to);
                if (!target.isEmpty() and target.getColor() != color) {
                    self.addPawnMove(square, to, r == promo_rank, board);
                } else if (board.en_passant_target) |ep| {
                    if (ep == to) {
                        self.addPawnMove(square, to, false, board);
                    }
                }
            }
        }
    }

    fn addPawnMove(self: *MoveGenerator, from: Square, to: Square, is_promo: bool, board: *const Board) void {
        if (is_promo) {
            const promos = [_]PieceType{ .Queen, .Rook, .Bishop, .Knight };
            for (promos) |p| {
                const move = Move.withPromotion(from, to, p);
                if (Rules.isMoveLegal(board, move)) self.addMove(move);
            }
        } else {
            const move = Move.init(from, to);
            if (Rules.isMoveLegal(board, move)) self.addMove(move);
        }
    }

    fn generateKnightMoves(self: *MoveGenerator, board: *const Board, square: Square, color: Color, rank: i8, file: i8) void {
        const offsets = [_][2]i8{
            .{ -2, -1 }, .{ -2, 1 }, .{ -1, -2 }, .{ -1, 2 },
            .{ 1, -2 },  .{ 1, 2 },  .{ 2, -1 },  .{ 2, 1 },
        };
        for (offsets) |off| {
            const r = rank + off[0];
            const f = file + off[1];
            if (r >= 0 and r < 8 and f >= 0 and f < 8) {
                const to = Square.fromCoords(r, f);
                const target = board.getPiece(to);
                if (target.isEmpty() or target.getColor() != color) {
                    const move = Move.init(square, to);
                    if (Rules.isMoveLegal(board, move)) self.addMove(move);
                }
            }
        }
    }

    fn generateSlidingMoves(self: *MoveGenerator, board: *const Board, square: Square, color: Color, rank: i8, file: i8, dirs: []const [2]i8) void {
        for (dirs) |dir| {
            var r = rank + dir[0];
            var f = file + dir[1];
            while (r >= 0 and r < 8 and f >= 0 and f < 8) : ({
                r += dir[0];
                f += dir[1];
            }) {
                const to = Square.fromCoords(r, f);
                const target = board.getPiece(to);
                if (target.isEmpty()) {
                    const move = Move.init(square, to);
                    if (Rules.isMoveLegal(board, move)) self.addMove(move);
                } else {
                    if (target.getColor() != color) {
                        const move = Move.init(square, to);
                        if (Rules.isMoveLegal(board, move)) self.addMove(move);
                    }
                    break;
                }
            }
        }
    }

    fn generateKingMoves(self: *MoveGenerator, board: *const Board, square: Square, color: Color, rank: i8, file: i8) void {
        // Normal moves
        var dr: i8 = -1;
        while (dr <= 1) : (dr += 1) {
            var df: i8 = -1;
            while (df <= 1) : (df += 1) {
                if (dr == 0 and df == 0) continue;
                const r = rank + dr;
                const f = file + df;
                if (r >= 0 and r < 8 and f >= 0 and f < 8) {
                    const to = Square.fromCoords(r, f);
                    const target = board.getPiece(to);
                    if (target.isEmpty() or target.getColor() != color) {
                        const move = Move.init(square, to);
                        if (Rules.isMoveLegal(board, move)) self.addMove(move);
                    }
                }
            }
        }

        // Castling
        const files = [_]i8{ 2, 6 };
        for (files) |f| {
            const to = Square.fromCoords(rank, f);
            const move = Move.init(square, to);
            if (Rules.isMoveLegal(board, move)) self.addMove(move);
        }
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
