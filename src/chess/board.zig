const std = @import("std");
const types = @import("types.zig");
const Piece = @import("piece.zig");
const PieceType = types.PieceType;
const Color = types.Color;
const Square = types.Square;
const Move = types.Move;
const CastlingRights = types.CastlingRights;

pub const Board = @This();

pieces: [64]Piece,
active_color: Color,
castling_rights: CastlingRights,
en_passant_target: ?Square,
halfmove_clock: u16,
fullmove_number: u16,
is_check: bool = false,
is_checkmate: bool = false,

pub fn init() Board {
    var board = Board{
        .pieces = undefined,
        .active_color = .White,
        .castling_rights = .{},
        .en_passant_target = null,
        .halfmove_clock = 0,
        .fullmove_number = 1,
    };

    for (0..64) |i| board.pieces[i] = Piece.empty();

    for (0..8) |i| {
        board.pieces[8 + i] = Piece.init(.White, .Pawn);
        board.pieces[48 + i] = Piece.init(.Black, .Pawn);
    }

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

pub fn isSquareAttacked(self: *const Board, square: Square, by_color: Color) !bool {
    for (0..64) |i| {
        const from_sq = try Square.fromIndex(@intCast(i));
        const piece = self.getPiece(from_sq);
        if (piece.isEmpty() or piece.getColor() != by_color) continue;
        if (self.isMovePseudoLegalInternal(.{ .from = from_sq, .to = square, .promotion = null }, by_color)) return true;
    }
    return false;
}

pub fn isMovePseudoLegal(self: *const Board, move: Move) bool {
    return self.isMovePseudoLegalInternal(move, self.active_color);
}

pub fn updateCheckStatus(self: *Board) !void {
    var king_square: ?Square = null;
    for (0..64) |i| {
        const sq = try Square.fromIndex(@intCast(i));
        const piece = self.getPiece(sq);
        if (!piece.isEmpty() and piece.getType() == .King and piece.getColor() == self.active_color) {
            king_square = sq;
            break;
        }
    }

    self.is_check = if (king_square) |ksq| try self.isSquareAttacked(ksq, self.active_color.opposite()) else false;
    self.is_checkmate = self.is_check and !try self.hasLegalMoves(self.active_color);
}

pub fn hasLegalMoves(self: *const Board, color: Color) !bool {
    for (0..64) |i| {
        const from_sq = try Square.fromIndex(@intCast(i));
        const piece = self.getPiece(from_sq);
        if (piece.isEmpty() or piece.getColor() != color) continue;

        for (0..64) |j| {
            const to_sq = try Square.fromIndex(@intCast(j));
            if (self.isMoveLegal(.{ .from = from_sq, .to = to_sq, .promotion = null })) return true;
        }
    }
    return false;
}

pub fn isMoveLegal(self: *const Board, move: Move) bool {
    if (!self.isMovePseudoLegal(move)) return false;

    // Make the move temporarily to check if it leaves king in check
    var temp_board = self.*;
    temp_board.makeMoveUnchecked(move) catch return false;

    // Find our king position (still our color since active_color hasn't changed in temp_board)
    const our_color = self.active_color;
    for (0..64) |i| {
        const sq = Square.fromIndex(@intCast(i)) catch continue;
        const p = temp_board.getPiece(sq);
        if (!p.isEmpty() and p.getType() == .King and p.getColor() == our_color) {
            // Check if king is under attack after the move by the opponent
            return !(temp_board.isSquareAttacked(sq, our_color.opposite()) catch return false);
        }
    }
    return false;
}

fn isMovePseudoLegalInternal(self: *const Board, move: Move, color: Color) bool {
    const piece = self.getPiece(move.from);
    if (piece.isEmpty() or piece.getColor() != color) return false;

    const target = self.getPiece(move.to);
    if (!target.isEmpty() and target.getColor() == color) return false;

    const fr = move.from.rank();
    const ff = move.from.file();
    const tr = move.to.rank();
    const tf = move.to.file();
    const rd = tr - fr;
    const fd = tf - ff;

    return switch (piece.getType()) {
        .Pawn => blk: {
            const dir: i8 = if (piece.getColor() == .White) 1 else -1;
            const start_rank: i8 = if (piece.getColor() == .White) 1 else 6;
            const promo_rank: i8 = if (piece.getColor() == .White) 7 else 0;

            // Check if promotion is required/valid
            if (tr == promo_rank) {
                if (move.promotion == null) break :blk false;
                const promo_type = move.promotion.?;
                if (promo_type == .Pawn or promo_type == .King) break :blk false;
            } else {
                if (move.promotion != null) break :blk false;
            }

            if (fd == 0) {
                if (rd == dir and target.isEmpty()) break :blk true;
                if (rd == 2 * dir and target.isEmpty() and fr == start_rank) {
                    const mid = Square.fromCoords(@intCast(fr + dir), ff);
                    break :blk self.getPiece(mid).isEmpty();
                }
            }

            if (@abs(fd) == 1 and rd == dir) {
                if (!target.isEmpty() and target.getColor() != piece.getColor()) break :blk true;
                if (self.en_passant_target) |ep| if (ep == move.to) break :blk true;
            }
            break :blk false;
        },

        .Knight => (@abs(rd) == 1 and @abs(fd) == 2) or (@abs(rd) == 2 and @abs(fd) == 1),
        .Bishop => @abs(rd) == @abs(fd) and self.pathClear(move.from, move.to),
        .Rook => (rd == 0 or fd == 0) and self.pathClear(move.from, move.to),
        .Queen => (rd == 0 or fd == 0 or @abs(rd) == @abs(fd)) and self.pathClear(move.from, move.to),

        .King => blk: {
            if (@abs(rd) <= 1 and @abs(fd) <= 1) break :blk true;

            if (fr == tr and @abs(fd) == 2) {
                const is_kingside = tf > ff;
                const between_files: []const i8 = if (is_kingside) &.{ 5, 6 } else &.{ 1, 2, 3 };

                for (between_files) |f| {
                    if (!self.getPiece(Square.fromCoords(fr, f)).isEmpty()) break :blk false;
                }

                break :blk self.castling_rights.canCastle(piece.getColor(), is_kingside);
            }
            break :blk false;
        },
        else => false,
    };
}

pub fn pathClear(self: *const Board, from: Square, to: Square) bool {
    const rs = std.math.sign(@as(i8, to.rank()) - @as(i8, from.rank()));
    const fs = std.math.sign(@as(i8, to.file()) - @as(i8, from.file()));

    var r = from.rank() + rs;
    var f = from.file() + fs;

    while (r != to.rank() or f != to.file()) : ({
        r += rs;
        f += fs;
    }) {
        if (!self.getPiece(Square.fromCoords(r, f)).isEmpty()) return false;
    }
    return true;
}

fn makeMoveUnchecked(self: *Board, move: Move) !void {
    const piece = self.getPiece(move.from);
    const piece_type = piece.getType();

    // En passant capture
    if (piece_type == .Pawn and self.en_passant_target != null and move.to == self.en_passant_target.?) {
        self.setPiece(Square.fromCoords(move.from.rank(), move.to.file()), Piece.empty());
    }

    // Castling
    if (piece_type == .King and @abs(@as(i16, move.to.file()) - @as(i16, move.from.file())) == 2) {
        const is_kingside = move.to.file() > move.from.file();
        const rank = move.from.rank();
        const rook_from = Square.fromCoords(rank, if (is_kingside) 7 else 0);
        const rook_to = Square.fromCoords(rank, if (is_kingside) 5 else 3);

        self.setPiece(rook_to, self.getPiece(rook_from));
        self.setPiece(rook_from, Piece.empty());
    }

    // Move the piece
    const moving_piece = if (move.promotion) |promo| Piece.init(piece.getColor(), promo) else piece;
    self.setPiece(move.from, Piece.empty());
    self.setPiece(move.to, moving_piece);

    // Update en passant target
    self.en_passant_target = null;
    if (piece_type == .Pawn and @abs(@as(i16, move.to.rank()) - @as(i16, move.from.rank())) == 2) {
        self.en_passant_target = Square.fromCoords(@intCast(@divFloor(move.from.rank() + move.to.rank(), 2)), move.from.file());
    }
}

pub fn makeMove(self: *Board, move: Move) !void {
    if (!self.isMoveLegal(move)) return error.IllegalMove;

    const piece = self.getPiece(move.from);
    if (piece.isEmpty()) return error.NoPieceAtSource;
    if (piece.getColor() != self.active_color) return error.WrongColorPiece;

    const piece_type = piece.getType();

    // Execute the move
    try self.makeMoveUnchecked(move);

    // Update castling rights after the move
    if (piece_type == .King) {
        self.castling_rights.removeRights(self.active_color, true);
        self.castling_rights.removeRights(self.active_color, false);
    } else if (piece_type == .Rook) {
        if (move.from == Square.a1 or move.from == Square.a8) {
            self.castling_rights.removeRights(self.active_color, false);
        } else if (move.from == Square.h1 or move.from == Square.h8) {
            self.castling_rights.removeRights(self.active_color, true);
        }
    }

    // Switch active color
    self.active_color = self.active_color.opposite();
    if (self.active_color == .White) self.fullmove_number += 1;

    // Update check/checkmate status
    try self.updateCheckStatus();
}

pub fn display(self: *const Board, writer: anytype) !void {
    try writer.print("  a b c d e f g h\n", .{});
    var rank: i8 = 7;
    while (rank >= 0) : (rank -= 1) {
        try writer.print("{d} ", .{rank + 1});
        var file: u8 = 0;
        while (file < 8) : (file += 1) {
            const piece = self.getPiece(Square.fromCoords(@intCast(rank), file));
            try writer.print("{s} ", .{piece.symbol()});
        }
        try writer.print("{d}\n", .{rank + 1});
    }
    try writer.print("  a b c d e f g h\n", .{});
}

/// Get all legal moves for a piece at the given square
pub fn getLegalMovesForPiece(self: *const Board, square: Square, allocator: std.mem.Allocator) !std.array_list.Managed(Move) {
    var moves = std.array_list.Managed(Move).init(allocator);
    errdefer moves.deinit();

    const piece = self.getPiece(square);
    if (piece.isEmpty()) return moves;
    if (piece.getColor() != self.active_color) return moves;

    const piece_type = piece.getType();
    const color = piece.getColor();

    // Generate all possible destination squares
    for (0..64) |i| {
        const to_sq = try Square.fromIndex(@intCast(i));

        // For pawn promotions, try all promotion pieces
        if (piece_type == .Pawn) {
            const promo_rank: i8 = if (color == .White) 7 else 0;
            if (to_sq.rank() == promo_rank) {
                // Try all promotion types
                const promo_types = [_]PieceType{ .Queen, .Rook, .Bishop, .Knight };
                for (promo_types) |promo_type| {
                    const move = Move{ .from = square, .to = to_sq, .promotion = promo_type };
                    if (self.isMoveLegal(move)) {
                        try moves.append(move);
                    }
                }
                continue;
            }
        }

        // Regular move (no promotion)
        const move = Move{ .from = square, .to = to_sq, .promotion = null };
        if (self.isMoveLegal(move)) {
            try moves.append(move);
        }
    }

    return moves;
}

/// Get all legal moves for the current player
pub fn getAllLegalMoves(self: *const Board, allocator: std.mem.Allocator) !std.array_list.Managed(Move) {
    var moves = std.array_list.Managed(Move).init(allocator);
    errdefer moves.deinit();

    for (0..64) |i| {
        const from_sq = try Square.fromIndex(@intCast(i));
        const piece = self.getPiece(from_sq);
        if (piece.isEmpty() or piece.getColor() != self.active_color) continue;

        var piece_moves = try self.getLegalMovesForPiece(from_sq, allocator);
        defer piece_moves.deinit();

        try moves.appendSlice(piece_moves.items);
    }

    return moves;
}
