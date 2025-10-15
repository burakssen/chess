pub const PieceType = enum(u3) {
    None = 0,
    Pawn = 1,
    Knight = 2,
    Bishop = 3,
    Rook = 4,
    Queen = 5,
    King = 6,

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

pub const Color = enum(u1) {
    White = 0,
    Black = 1,

    pub fn opposite(self: Color) Color {
        return switch (self) {
            .White => .Black,
            .Black => .White,
        };
    }

    pub fn toBit(self: Color) u8 {
        return @as(u8, @intFromEnum(self)) << 3;
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

    pub fn remove(self: *CastlingRights, color: Color, kingside: bool) void {
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

pub const GameStatus = enum {
    ongoing,
    checkmate,
    stalemate,
};
