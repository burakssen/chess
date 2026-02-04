const std = @import("std");
const rl = @import("raylib.zig").rl;
const core = @import("core");
const Piece = core.Piece;
const Color = core.types.Color;
const PieceType = core.types.PieceType;

const Theme = @import("theme.zig").Theme;

pub const AssetManager = struct {
    textures: [64]?rl.Texture2D,

    pub fn init(allocator: std.mem.Allocator, theme: Theme) !AssetManager {
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

            // Try the path as specified in the theme
            const path = try std.fmt.allocPrintSentinel(allocator, "{s}/{b:0>4}.png", .{ theme.asset_path, value }, 0);
            defer allocator.free(path);

            var texture = rl.LoadTexture(path.ptr);

            // If it failed and the path starts with "assets/", try without it
            if (texture.id == 0 and std.mem.startsWith(u8, theme.asset_path, "assets/")) {
                const sub_path = theme.asset_path["assets/".len..];
                const alt_path = try std.fmt.allocPrintSentinel(allocator, "{s}/{b:0>4}.png", .{ sub_path, value }, 0);
                defer allocator.free(alt_path);
                texture = rl.LoadTexture(alt_path.ptr);
            }

            // Fallback to default assets if theme assets are still missing
            if (texture.id == 0) {
                // Try assets/default/...
                const fallback_path = try std.fmt.allocPrintSentinel(allocator, "assets/default/{b:0>4}.png", .{value}, 0);
                defer allocator.free(fallback_path);
                texture = rl.LoadTexture(fallback_path.ptr);

                // If that also fails, try default/... (in case we are already in assets/)
                if (texture.id == 0) {
                    const fallback_path_alt = try std.fmt.allocPrintSentinel(allocator, "default/{b:0>4}.png", .{value}, 0);
                    defer allocator.free(fallback_path_alt);
                    texture = rl.LoadTexture(fallback_path_alt.ptr);
                }
            }

            if (texture.id > 0) {
                rl.SetTextureFilter(texture, rl.TEXTURE_FILTER_POINT);
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
