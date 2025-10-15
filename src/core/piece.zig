const std = @import("std");
const types = @import("types.zig");
const PieceType = types.PieceType;
const Color = types.Color;

pub const Piece = packed struct {
    value: u8,

    pub fn init(color: Color, piece_type: PieceType) Piece {
        return .{ .value = color.toBit() | @intFromEnum(piece_type) };
    }

    pub fn empty() Piece {
        return .{ .value = 0 };
    }

    pub fn getType(self: Piece) PieceType {
        return @enumFromInt(self.value & 0b0111);
    }

    pub fn getColor(self: Piece) Color {
        return @enumFromInt((self.value & 0b1000) >> 3);
    }

    pub fn isEmpty(self: Piece) bool {
        return self.value == 0;
    }

    pub fn symbol(self: Piece) []const u8 {
        if (self.isEmpty()) return " ";
        return self.getType().symbol();
    }

    pub fn getTextureValue(self: Piece) u8 {
        return self.value;
    }
};
