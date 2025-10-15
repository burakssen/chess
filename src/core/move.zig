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
};
