const std = @import("std");

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
        const r = std.math.clamp(rank_, 0, 7);
        const f = std.math.clamp(file_, 0, 7);
        return @enumFromInt(@as(u6, @intCast(r * 8 + f)));
    }

    pub fn fromIndex(index: u6) Square {
        return @enumFromInt(index);
    }

    pub fn toIndex(self: Square) u6 {
        return @intFromEnum(self);
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

    pub fn toAlgebraic(self: Square) [2]u8 {
        return .{
            'a' + @as(u8, @intCast(self.file())),
            '1' + @as(u8, @intCast(self.rank())),
        };
    }
};
