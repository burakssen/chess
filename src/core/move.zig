const std = @import("std");
const Square = @import("square.zig").Square;
const PieceType = @import("types.zig").PieceType;

pub const Move = struct {
    from: Square,
    to: Square,
    promotion: ?PieceType = null,

    pub fn init(from: Square, to: Square) Move {
        return .{ .from = from, .to = to };
    }

    pub fn withPromotion(from: Square, to: Square, piece: PieceType) Move {
        return .{ .from = from, .to = to, .promotion = piece };
    }

    pub fn eql(self: Move, other: Move) bool {
        return self.from == other.from and
            self.to == other.to and
            self.promotion == other.promotion;
    }

    pub fn toNotation(self: Move, buffer: []u8) ![]const u8 {
        const from_alg = self.from.toAlgebraic();
        const to_alg = self.to.toAlgebraic();
        if (self.promotion) |promo| {
            const promo_char: u8 = switch (promo) {
                .Queen => 'q',
                .Rook => 'r',
                .Bishop => 'b',
                .Knight => 'n',
                else => '?',
            };
            return try std.fmt.bufPrint(buffer, "{s}{s}{c}", .{ from_alg, to_alg, promo_char });
        } else {
            return try std.fmt.bufPrint(buffer, "{s}{s}", .{ from_alg, to_alg });
        }
    }
};
