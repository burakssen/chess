const std = @import("std");

const rl = @import("raylib.zig").rl;

const Chess = @import("chess");
const Color = Chess.types.Color;
const PieceType = Chess.types.PieceType;
const Piece = Chess.Piece;

const PieceTextures = @This();

textures: [64]?rl.Texture2D,
allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) !PieceTextures {
    std.debug.print("Loading piece textures...\n", .{});
    var self = PieceTextures{
        .textures = [_]?rl.Texture2D{null} ** 64,
        .allocator = allocator,
    };

    // Load all possible piece textures
    const white_pawn = (@intFromEnum(Color.White) | @intFromEnum(PieceType.Pawn));
    const white_knight = (@intFromEnum(Color.White) | @intFromEnum(PieceType.Knight));
    const white_bishop = (@intFromEnum(Color.White) | @intFromEnum(PieceType.Bishop));
    const white_rook = (@intFromEnum(Color.White) | @intFromEnum(PieceType.Rook));
    const white_queen = (@intFromEnum(Color.White) | @intFromEnum(PieceType.Queen));
    const white_king = (@intFromEnum(Color.White) | @intFromEnum(PieceType.King));

    const black_pawn = (@intFromEnum(Color.Black) | @intFromEnum(PieceType.Pawn));
    const black_knight = (@intFromEnum(Color.Black) | @intFromEnum(PieceType.Knight));
    const black_bishop = (@intFromEnum(Color.Black) | @intFromEnum(PieceType.Bishop));
    const black_rook = (@intFromEnum(Color.Black) | @intFromEnum(PieceType.Rook));
    const black_queen = (@intFromEnum(Color.Black) | @intFromEnum(PieceType.Queen));
    const black_king = (@intFromEnum(Color.Black) | @intFromEnum(PieceType.King));

    const pieces = [_]u8{
        white_pawn, white_knight, white_bishop, white_rook, white_queen, white_king,
        black_pawn, black_knight, black_bishop, black_rook, black_queen, black_king,
    };

    for (pieces) |piece_value| {
        const path =
            try std.fmt.allocPrintSentinel(allocator, "assets/{b:0>4}.png", .{piece_value}, 0);
        defer allocator.free(path);

        const texture = rl.LoadTexture(path.ptr);

        if (texture.id > 0) {
            rl.SetTextureFilter(texture, rl.TEXTURE_FILTER_BILINEAR);
            self.textures[piece_value] = texture;
        }
    }

    return self;
}

pub fn deinit(self: *PieceTextures) void {
    for (self.textures) |maybe_texture| {
        if (maybe_texture) |texture| {
            rl.UnloadTexture(texture);
        }
    }
}

pub fn get(self: *const PieceTextures, piece: Piece) ?rl.Texture2D {
    if (piece.isEmpty()) return null;
    return self.textures[piece.value];
}
