const std = @import("std");
const core = @import("core");
const engine = @import("engine");

const Move = core.Move;
const Square = core.Square;
const Piece = core.Piece;
const PieceType = core.types.PieceType;
const Color = core.types.Color;
const Board = engine.Board;

pub const AIDifficulty = enum {
    easy, // Random moves
    medium, // 2-ply minimax
    hard, // 4-ply minimax with alpha-beta pruning
};

pub const AIPlayer = struct {
    difficulty: AIDifficulty,
    prng: std.Random.DefaultPrng,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, difficulty: AIDifficulty) AIPlayer {
        var seed: u64 = undefined;
        std.posix.getrandom(std.mem.asBytes(&seed)) catch {
            seed = @intCast(std.time.milliTimestamp());
        };
        return .{
            .difficulty = difficulty,
            .prng = std.Random.DefaultPrng.init(seed),
            .allocator = allocator,
        };
    }

    pub fn initWithSeed(allocator: std.mem.Allocator, difficulty: AIDifficulty, seed: u64) AIPlayer {
        return .{
            .difficulty = difficulty,
            .prng = std.Random.DefaultPrng.init(seed),
            .allocator = allocator,
        };
    }

    /// Selects the best move for the current position
    pub fn selectMove(self: *AIPlayer, board: *const Board, legal_moves: []const Move) ?Move {
        if (legal_moves.len == 0) return null;

        return switch (self.difficulty) {
            .easy => self.selectRandomMove(legal_moves),
            .medium => self.selectMinimaxMove(board, legal_moves, 2),
            .hard => self.selectMinimaxMove(board, legal_moves, 4),
        };
    }

    fn selectRandomMove(self: *AIPlayer, legal_moves: []const Move) Move {
        const index = self.prng.random().intRangeAtMost(usize, 0, legal_moves.len - 1);
        return legal_moves[index];
    }

    fn selectMinimaxMove(self: *AIPlayer, board: *const Board, legal_moves: []const Move, depth: u8) Move {
        var mutable_board = board.*;
        const moves = self.allocator.dupe(Move, legal_moves) catch {
            return legal_moves[0];
        };
        defer self.allocator.free(moves);

        self.orderMoves(&mutable_board, moves);

        var best_move = moves[0];
        var best_score: i32 = std.math.minInt(i32);
        const maximizing = mutable_board.active_color == .White;

        for (moves) |move| {
            const undo = mutable_board.makeMove(move);
            const score = self.minimax(&mutable_board, depth - 1, std.math.minInt(i32), std.math.maxInt(i32), !maximizing);
            mutable_board.unmakeMove(move, undo);

            const adjusted_score = if (maximizing) score else -score;
            if (adjusted_score > best_score) {
                best_score = adjusted_score;
                best_move = move;
            }
        }

        return best_move;
    }

    fn minimax(self: *AIPlayer, board: *Board, depth: u8, alpha_in: i32, beta_in: i32, maximizing: bool) i32 {
        if (depth == 0) {
            return self.evaluatePosition(board);
        }

        // Generate legal moves for current position
        var move_gen = engine.MoveGenerator.init();
        const legal_moves = move_gen.generateLegalMoves(board);

        if (legal_moves.len == 0) {
            // Check if it's checkmate or stalemate
            const king_square = board.findKing(board.active_color) orelse return 0;
            if (engine.Rules.isSquareAttacked(board, king_square, board.active_color.opposite())) {
                // Checkmate - return very bad score for the side in checkmate
                return if (maximizing) -100000 + @as(i32, @intCast(depth)) else 100000 - @as(i32, @intCast(depth));
            }
            return 0; // Stalemate
        }

        var moves_buf: [256]Move = undefined;
        @memcpy(moves_buf[0..legal_moves.len], legal_moves);
        const moves = moves_buf[0..legal_moves.len];
        self.orderMoves(board, moves);

        var alpha = alpha_in;
        var beta = beta_in;

        if (maximizing) {
            var max_eval: i32 = std.math.minInt(i32);
            for (moves) |move| {
                const undo = board.makeMove(move);
                const eval = self.minimax(board, depth - 1, alpha, beta, false);
                board.unmakeMove(move, undo);

                max_eval = @max(max_eval, eval);
                alpha = @max(alpha, eval);
                if (beta <= alpha) break; // Alpha-beta pruning
            }
            return max_eval;
        } else {
            var min_eval: i32 = std.math.maxInt(i32);
            for (moves) |move| {
                const undo = board.makeMove(move);
                const eval = self.minimax(board, depth - 1, alpha, beta, true);
                board.unmakeMove(move, undo);

                min_eval = @min(min_eval, eval);
                beta = @min(beta, eval);
                if (beta <= alpha) break; // Alpha-beta pruning
            }
            return min_eval;
        }
    }

    fn orderMoves(self: *AIPlayer, board: *const Board, moves: []Move) void {
        _ = self;
        // Simple MVV-LVA (Most Valuable Victim - Least Valuable Aggressor)
        // Also prioritize promotions
        const MoveScore = struct {
            move: Move,
            score: i32,
        };

        var move_scores_buf: [256]MoveScore = undefined;
        var move_scores_count: usize = 0;

        for (moves) |move| {
            var score: i32 = 0;
            const piece = board.getPiece(move.from);
            const target = board.getPiece(move.to);

            if (!target.isEmpty()) {
                score = 10 * getPieceValue(target.getType()) - getPieceValue(piece.getType());
            }

            if (move.promotion) |promo| {
                score += getPieceValue(promo);
            }

            move_scores_buf[move_scores_count] = .{ .move = move, .score = score };
            move_scores_count += 1;
        }

        const move_scores = move_scores_buf[0..move_scores_count];

        // Sort moves by score descending
        std.mem.sort(MoveScore, move_scores, {}, struct {
            fn lessThan(_: void, a: MoveScore, b: MoveScore) bool {
                return a.score > b.score;
            }
        }.lessThan);

        for (move_scores, 0..) |ms, i| {
            moves[i] = ms.move;
        }
    }

    /// Evaluates the position from White's perspective (positive = good for white)
    fn evaluatePosition(self: *AIPlayer, board: *const Board) i32 {
        _ = self;
        var score: i32 = 0;

        for (0..64) |i| {
            const piece = board.pieces[i];
            if (piece.isEmpty()) continue;

            const piece_value = getPieceValue(piece.getType());
            const position_bonus = getPositionBonus(piece.getType(), @intCast(i), piece.getColor());

            if (piece.getColor() == .White) {
                score += piece_value + position_bonus;
            } else {
                score -= piece_value + position_bonus;
            }
        }

        return score;
    }
};

fn getPieceValue(piece_type: PieceType) i32 {
    return switch (piece_type) {
        .Pawn => 100,
        .Knight => 320,
        .Bishop => 330,
        .Rook => 500,
        .Queen => 900,
        .King => 20000,
        .None => 0,
    };
}

/// Position bonus tables for piece-square tables
fn getPositionBonus(piece_type: PieceType, square_index: u6, color: Color) i32 {
    const rank = square_index / 8;
    const file = square_index % 8;

    // Mirror for black pieces
    const effective_rank: usize = if (color == .White) rank else 7 - rank;

    return switch (piece_type) {
        .Pawn => getPawnPositionBonus(effective_rank, file),
        .Knight => getKnightPositionBonus(effective_rank, file),
        .Bishop => getBishopPositionBonus(effective_rank, file),
        .Rook => getRookPositionBonus(effective_rank, file),
        .Queen => getQueenPositionBonus(effective_rank, file),
        .King => getKingPositionBonus(effective_rank, file),
        .None => 0,
    };
}

fn getPawnPositionBonus(rank: usize, file: usize) i32 {
    const table = [8][8]i32{
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
        .{ 5, 10, 10, -20, -20, 10, 10, 5 },
        .{ 5, -5, -10, 0, 0, -10, -5, 5 },
        .{ 0, 0, 0, 20, 20, 0, 0, 0 },
        .{ 5, 5, 10, 25, 25, 10, 5, 5 },
        .{ 10, 10, 20, 30, 30, 20, 10, 10 },
        .{ 50, 50, 50, 50, 50, 50, 50, 50 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    return table[rank][file];
}

fn getKnightPositionBonus(rank: usize, file: usize) i32 {
    const table = [8][8]i32{
        .{ -50, -40, -30, -30, -30, -30, -40, -50 },
        .{ -40, -20, 0, 5, 5, 0, -20, -40 },
        .{ -30, 5, 10, 15, 15, 10, 5, -30 },
        .{ -30, 0, 15, 20, 20, 15, 0, -30 },
        .{ -30, 5, 15, 20, 20, 15, 5, -30 },
        .{ -30, 0, 10, 15, 15, 10, 0, -30 },
        .{ -40, -20, 0, 0, 0, 0, -20, -40 },
        .{ -50, -40, -30, -30, -30, -30, -40, -50 },
    };
    return table[rank][file];
}

fn getBishopPositionBonus(rank: usize, file: usize) i32 {
    const table = [8][8]i32{
        .{ -20, -10, -10, -10, -10, -10, -10, -20 },
        .{ -10, 5, 0, 0, 0, 0, 5, -10 },
        .{ -10, 10, 10, 10, 10, 10, 10, -10 },
        .{ -10, 0, 10, 10, 10, 10, 0, -10 },
        .{ -10, 5, 5, 10, 10, 5, 5, -10 },
        .{ -10, 0, 5, 10, 10, 5, 0, -10 },
        .{ -10, 0, 0, 0, 0, 0, 0, -10 },
        .{ -20, -10, -10, -10, -10, -10, -10, -20 },
    };
    return table[rank][file];
}

fn getRookPositionBonus(rank: usize, file: usize) i32 {
    const table = [8][8]i32{
        .{ 0, 0, 0, 5, 5, 0, 0, 0 },
        .{ -5, 0, 0, 0, 0, 0, 0, -5 },
        .{ -5, 0, 0, 0, 0, 0, 0, -5 },
        .{ -5, 0, 0, 0, 0, 0, 0, -5 },
        .{ -5, 0, 0, 0, 0, 0, 0, -5 },
        .{ -5, 0, 0, 0, 0, 0, 0, -5 },
        .{ 5, 10, 10, 10, 10, 10, 10, 5 },
        .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    };
    return table[rank][file];
}

fn getQueenPositionBonus(rank: usize, file: usize) i32 {
    const table = [8][8]i32{
        .{ -20, -10, -10, -5, -5, -10, -10, -20 },
        .{ -10, 0, 0, 0, 0, 0, 0, -10 },
        .{ -10, 0, 5, 5, 5, 5, 0, -10 },
        .{ -5, 0, 5, 5, 5, 5, 0, -5 },
        .{ 0, 0, 5, 5, 5, 5, 0, -5 },
        .{ -10, 5, 5, 5, 5, 5, 0, -10 },
        .{ -10, 0, 5, 0, 0, 0, 0, -10 },
        .{ -20, -10, -10, -5, -5, -10, -10, -20 },
    };
    return table[rank][file];
}

fn getKingPositionBonus(rank: usize, file: usize) i32 {
    // Early/mid game king position (prefer castled position)
    const table = [8][8]i32{
        .{ 20, 30, 10, 0, 0, 10, 30, 20 },
        .{ 20, 20, 0, 0, 0, 0, 20, 20 },
        .{ -10, -20, -20, -20, -20, -20, -20, -10 },
        .{ -20, -30, -30, -40, -40, -30, -30, -20 },
        .{ -30, -40, -40, -50, -50, -40, -40, -30 },
        .{ -30, -40, -40, -50, -50, -40, -40, -30 },
        .{ -30, -40, -40, -50, -50, -40, -40, -30 },
        .{ -30, -40, -40, -50, -50, -40, -40, -30 },
    };
    return table[rank][file];
}
