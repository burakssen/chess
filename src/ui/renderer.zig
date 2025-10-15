const std = @import("std");
const rl = @import("raylib.zig").rl;

const engine = @import("engine");
const Board = engine.Board;

const core = @import("core");
const Piece = core.Piece;
const Square = core.Square;
const Move = core.Move;
const Color = core.types.Color;
const GameStatus = core.types.GameStatus;

const constants = @import("constants.zig");
const AssetManager = @import("assets.zig").AssetManager;

pub const DragState = struct {
    piece: Piece,
    from: Square,
};

pub const Renderer = struct {
    assets: AssetManager,

    pub fn init(allocator: std.mem.Allocator) !Renderer {
        return .{
            .assets = try AssetManager.init(allocator),
        };
    }

    pub fn deinit(self: *Renderer) void {
        self.assets.deinit();
    }

    pub fn beginFrame(self: *Renderer) void {
        _ = self;
        rl.BeginDrawing();
        rl.ClearBackground(rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 });
    }

    pub fn endFrame(self: *Renderer) void {
        _ = self;
        rl.EndDrawing();
    }

    pub fn drawBoard(self: *Renderer) void {
        _ = self;
        for (0..8) |rank_idx| {
            for (0..8) |file_idx| {
                const rank: u8 = @intCast(rank_idx);
                const file: u8 = @intCast(file_idx);
                const is_light = (rank + file) % 2 == 0;
                const color = if (is_light) constants.LIGHT_SQUARE else constants.DARK_SQUARE;

                const x = constants.BOARD_OFFSET_X + @as(i32, @intCast(file)) * constants.SQUARE_SIZE;
                const y = constants.BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank)) * constants.SQUARE_SIZE;

                rl.DrawRectangle(x, y, constants.SQUARE_SIZE, constants.SQUARE_SIZE, color);
            }
        }
    }

    pub fn drawSelectedSquare(self: *Renderer, square: Square) void {
        _ = self;
        const pos = squareToScreen(square);
        rl.DrawRectangle(
            @intFromFloat(pos.x),
            @intFromFloat(pos.y),
            constants.SQUARE_SIZE,
            constants.SQUARE_SIZE,
            constants.SELECTED_COLOR,
        );
    }

    pub fn drawLegalMoves(self: *Renderer, board: *const Board, moves: []const Move) void {
        _ = self;
        for (moves) |move| {
            const pos = squareToScreen(move.to);
            const target_piece = board.getPiece(move.to);

            if (target_piece.isEmpty()) {
                // Draw circle for empty square moves
                const center_x = @as(i32, @intFromFloat(pos.x)) + constants.SQUARE_SIZE / 2;
                const center_y = @as(i32, @intFromFloat(pos.y)) + constants.SQUARE_SIZE / 2;
                rl.DrawCircle(center_x, center_y, constants.SQUARE_SIZE / 6, rl.Fade(constants.HIGHLIGHT_COLOR, 0.5));
            } else {
                // Draw ring for capture moves
                rl.DrawRectangleLinesEx(
                    rl.Rectangle{
                        .x = pos.x + 4,
                        .y = pos.y + 4,
                        .width = constants.SQUARE_SIZE - 8,
                        .height = constants.SQUARE_SIZE - 8,
                    },
                    4.0,
                    constants.HIGHLIGHT_COLOR,
                );
            }
        }
    }

    pub fn drawPieces(self: *Renderer, board: *const Board, dragging: ?DragState) void {
        for (0..64) |i| {
            const square = Square.fromIndex(@intCast(i));
            const piece = board.getPiece(square);

            // Skip if this piece is being dragged
            if (dragging) |drag| {
                if (drag.from == square) continue;
            }

            if (!piece.isEmpty()) {
                const pos = squareToScreen(square);
                self.drawPiece(piece, pos.x, pos.y);
            }
        }
    }

    pub fn drawDraggedPiece(self: *Renderer, piece: Piece, mouse_pos: rl.Vector2) void {
        const piece_x = mouse_pos.x - @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / 2.0;
        const piece_y = mouse_pos.y - @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / 2.0;
        self.drawPiece(piece, piece_x, piece_y);
    }

    pub fn drawGameOver(self: *Renderer, status: GameStatus, winner: ?Color) void {
        _ = self;
        // Semi-transparent overlay
        rl.DrawRectangle(
            0,
            0,
            constants.WINDOW_WIDTH,
            constants.WINDOW_HEIGHT,
            rl.Color{ .r = 0, .g = 0, .b = 0, .a = 180 },
        );

        const message: [*c]const u8 = switch (status) {
            .checkmate => if (winner == .Black)
                "Checkmate! Black Wins!"
            else
                "Checkmate! White Wins!",
            .stalemate => "Stalemate! Draw!",
            .ongoing => unreachable,
        };

        const subtitle: [*c]const u8 = "Press R or Click to Reset";

        const font_size = 60;
        const subtitle_size = 30;
        const text_width = rl.MeasureText(message, font_size);
        const subtitle_width = rl.MeasureText(subtitle, subtitle_size);

        const text_x = @divTrunc(constants.WINDOW_WIDTH - text_width, 2);
        const text_y = @divTrunc(constants.WINDOW_HEIGHT, 2) - 50;

        // Draw text shadow
        rl.DrawText(message, text_x + 3, text_y + 3, font_size, rl.BLACK);
        rl.DrawText(message, text_x, text_y, font_size, rl.GOLD);

        // Draw subtitle
        const subtitle_x = @divTrunc(constants.WINDOW_WIDTH - subtitle_width, 2);
        const subtitle_y = text_y + 80;
        rl.DrawText(subtitle, subtitle_x + 2, subtitle_y + 2, subtitle_size, rl.BLACK);
        rl.DrawText(subtitle, subtitle_x, subtitle_y, subtitle_size, rl.WHITE);
    }

    fn drawPiece(self: *Renderer, piece: Piece, x: f32, y: f32) void {
        if (self.assets.getTexture(piece)) |texture| {
            const scale = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / @as(f32, @floatFromInt(texture.width));
            rl.DrawTextureEx(
                texture,
                rl.Vector2{ .x = x, .y = y },
                0.0,
                scale,
                rl.WHITE,
            );
        } else {
            // Fallback: draw text symbol
            const symbol_ptr: [*c]const u8 = @ptrCast(piece.symbol().ptr);
            rl.DrawText(
                symbol_ptr,
                @intFromFloat(x + @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / 2),
                @intFromFloat(y + @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / 2),
                40,
                rl.RED,
            );
        }
    }
};

fn squareToScreen(square: Square) rl.Vector2 {
    const file = square.file();
    const rank = square.rank();

    return rl.Vector2{
        .x = @floatFromInt(constants.BOARD_OFFSET_X + @as(i32, file) * constants.SQUARE_SIZE),
        .y = @floatFromInt(constants.BOARD_OFFSET_Y + @as(i32, 7 - rank) * constants.SQUARE_SIZE),
    };
}
