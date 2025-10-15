const std = @import("std");

pub const PieceType = enum(u8) {
    None = 0b0000,
    Pawn = 0b0001,
    Knight = 0b0010,
    Bishop = 0b0011,
    Rook = 0b0100,
    Queen = 0b0101,
    King = 0b0110,

    pub fn symbol(self: PieceType) []const u8 {
        return switch (self) {
            .None => " ",
            .Pawn => "P",
            .Knight => "N",
            .Bishop => "B",
            .Rook => "R",
            .Queen => "Q",
            .King => "K",
        };
    }
};

pub const Color = enum(u8) {
    White = 0b0000,
    Black = 0b1000,

    pub fn opposite(self: Color) Color {
        return switch (self) {
            .White => .Black,
            .Black => .White,
        };
    }
};

pub const Square = enum(u6) {
    a1,
    b1,
    c1,
    d1,
    e1,
    f1,
    g1,
    h1,
    a2,
    b2,
    c2,
    d2,
    e2,
    f2,
    g2,
    h2,
    a3,
    b3,
    c3,
    d3,
    e3,
    f3,
    g3,
    h3,
    a4,
    b4,
    c4,
    d4,
    e4,
    f4,
    g4,
    h4,
    a5,
    b5,
    c5,
    d5,
    e5,
    f5,
    g5,
    h5,
    a6,
    b6,
    c6,
    d6,
    e6,
    f6,
    g6,
    h6,
    a7,
    b7,
    c7,
    d7,
    e7,
    f7,
    g7,
    h7,
    a8,
    b8,
    c8,
    d8,
    e8,
    f8,
    g8,
    h8,

    pub fn fromCoords(rank_: i8, file_: i8) Square {
        const r = if (rank_ < 0) 0 else if (rank_ > 7) 7 else rank_;
        const f = if (file_ < 0) 0 else if (file_ > 7) 7 else file_;
        return @enumFromInt(@as(i8, r) * 8 + f);
    }

    pub fn toIndex(self: Square) u8 {
        return @intFromEnum(self);
    }

    pub fn fromIndex(index: u8) !Square {
        if (index > 63) return error.InvalidSquare;
        return @enumFromInt(index);
    }

    pub fn rank(self: Square) i8 {
        return @intCast(@intFromEnum(self) / 8);
    }

    pub fn file(self: Square) i8 {
        return @intCast(@intFromEnum(self) % 8);
    }

    pub fn fromAlgebraic(notation: []const u8) !Square {
        if (notation.len != 2) return error.InvalidNotation;
        const file_ = notation[0] - 'a';
        const rank_ = notation[1] - '1';
        if (file_ > 7 or rank_ > 7) return error.InvalidNotation;
        return fromCoords(@intCast(rank_), @intCast(file_));
    }

    pub fn toAlgebraic(self: Square, buf: *[2]u8) []const u8 {
        buf[0] = 'a' + @as(u8, self.file());
        buf[1] = '1' + @as(u8, self.rank());
        return buf[0..2];
    }
};

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
};

pub const CastlingRights = packed struct {
    white_kingside: bool = true,
    white_queenside: bool = true,
    black_kingside: bool = true,
    black_queenside: bool = true,

    pub fn canCastle(self: CastlingRights, color: Color, kingside: bool) bool {
        return switch (color) {
            .White => if (kingside) self.white_kingside else self.white_queenside,
            .Black => if (kingside) self.black_kingside else self.black_queenside,
        };
    }

    pub fn removeRights(self: *CastlingRights, color: Color, kingside: bool) void {
        switch (color) {
            .White => if (kingside) {
                self.white_kingside = false;
            } else {
                self.white_queenside = false;
            },
            .Black => if (kingside) {
                self.black_kingside = false;
            } else {
                self.black_queenside = false;
            },
        }
    }
};
