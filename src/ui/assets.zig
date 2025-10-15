const std = @import("std");
const rl = @import("raylib.zig").rl;
const core = @import("core");
const Piece = core.Piece;
const Color = core.types.Color;
const PieceType = core.types.PieceType;

pub const AssetManager = struct {
    textures: [64]?rl.Texture2D,

    pub fn init(allocator: std.mem.Allocator) !AssetManager {
        var self = AssetManager{
            .textures = [_]?rl.Texture2D{null} ** 64,
        };

        const pieces = [_]struct { color: Color, piece_type: PieceType }{
            .{ .color = .White, .piece_type = .Pawn },
            .{ .color = .White, .piece_type = .Knight },
            .{ .color = .White, .piece_type = .Bishop },
            .{ .color = .White, .piece_type = .Rook },
            .{ .color = .White, .piece_type = .Queen },
            .{ .color = .White, .piece_type = .King },
            .{ .color = .Black, .piece_type = .Pawn },
            .{ .color = .Black, .piece_type = .Knight },
            .{ .color = .Black, .piece_type = .Bishop },
            .{ .color = .Black, .piece_type = .Rook },
            .{ .color = .Black, .piece_type = .Queen },
            .{ .color = .Black, .piece_type = .King },
        };

        for (pieces) |p| {
            const piece = Piece.init(p.color, p.piece_type);
            const value = piece.getTextureValue();

            const path = try std.fmt.allocPrintSentinel(allocator, "assets/{b:0>4}.png", .{value}, 0);
            defer allocator.free(path);

            const texture = rl.LoadTexture(path.ptr);
            if (texture.id > 0) {
                rl.SetTextureFilter(texture, rl.TEXTURE_FILTER_BILINEAR);
                self.textures[value] = texture;
            }
        }

        return self;
    }

    pub fn deinit(self: *AssetManager) void {
        for (self.textures) |maybe_texture| {
            if (maybe_texture) |texture| {
                rl.UnloadTexture(texture);
            }
        }
    }

    pub fn getTexture(self: *const AssetManager, piece: Piece) ?rl.Texture2D {
        if (piece.isEmpty()) return null;
        return self.textures[piece.getTextureValue()];
    }
};
