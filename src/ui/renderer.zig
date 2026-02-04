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

const Theme = @import("theme.zig").Theme;

pub const DragState = struct {
    piece: Piece,
    from: Square,
};

pub const MoveAnimation = struct {
    move: Move,
    piece: Piece,
    progress: f32,
    speed: f32,
};

fn easeInOutCubic(t: f32) f32 {
    if (t < 0.5) {
        return 4.0 * t * t * t;
    } else {
        const f = -2.0 * t + 2.0;
        return 1.0 - f * f * f / 2.0;
    }
}

pub const Renderer = struct {
    assets: AssetManager,
    theme: Theme,

    pub fn init(allocator: std.mem.Allocator, theme: Theme) !Renderer {
        return .{
            .assets = try AssetManager.init(allocator, theme),
            .theme = theme,
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
        for (0..8) |rank_idx| {
            for (0..8) |file_idx| {
                const rank: u8 = @intCast(rank_idx);
                const file: u8 = @intCast(file_idx);
                const is_light_orig = (rank + file) % 2 == 0;
                const color = if (is_light_orig) self.theme.light_square else self.theme.dark_square;

                const x = constants.BOARD_OFFSET_X + @as(i32, @intCast(file)) * constants.SQUARE_SIZE;
                const y = constants.BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank)) * constants.SQUARE_SIZE;

                rl.DrawRectangle(x, y, constants.SQUARE_SIZE, constants.SQUARE_SIZE, color);
            }
        }

        self.drawCoordinates();
    }

    fn drawCoordinates(self: *Renderer) void {
        const font_size = 16;

        // Draw files (a-h) on the bottom rank squares
        for (0..8) |file_idx| {
            const label: [2]u8 = .{ @as(u8, @intCast(file_idx)) + 'a', 0 };
            const label_ptr: [*c]const u8 = @ptrCast(&label);

            // Position at bottom-right of each square in the bottom rank (rank 0)
            const x = constants.BOARD_OFFSET_X + @as(i32, @intCast(file_idx)) * constants.SQUARE_SIZE + constants.SQUARE_SIZE - 15;
            const y = constants.BOARD_OFFSET_Y + 7 * constants.SQUARE_SIZE + constants.SQUARE_SIZE - 20;

            const is_light = file_idx % 2 != 0; // Rank 0, so (0 + file_idx) % 2
            const color = if (is_light) self.theme.dark_square else self.theme.light_square;

            rl.DrawText(label_ptr, x, y, font_size, color);
        }

        // Draw ranks (1-8) on the 'a' file squares
        for (0..8) |rank_idx| {
            const label: [2]u8 = .{ @as(u8, @intCast(rank_idx)) + '1', 0 };
            const label_ptr: [*c]const u8 = @ptrCast(&label);

            // Position at top-left of each square in the 'a' file (file 0)
            const x = constants.BOARD_OFFSET_X + 5;
            const y = constants.BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank_idx)) * constants.SQUARE_SIZE + 5;

            const is_light = rank_idx % 2 != 0; // File 0, so (rank_idx + 0) % 2
            const color = if (is_light) self.theme.dark_square else self.theme.light_square;

            rl.DrawText(label_ptr, x, y, font_size, color);
        }
    }

    pub fn drawLastMoveHighlight(self: *Renderer, move: Move) void {
        _ = self;
        const color = rl.Fade(rl.YELLOW, 0.3);
        const from_pos = squareToScreen(move.from);
        const to_pos = squareToScreen(move.to);

        rl.DrawRectangle(@intFromFloat(from_pos.x), @intFromFloat(from_pos.y), constants.SQUARE_SIZE, constants.SQUARE_SIZE, color);
        rl.DrawRectangle(@intFromFloat(to_pos.x), @intFromFloat(to_pos.y), constants.SQUARE_SIZE, constants.SQUARE_SIZE, color);
    }

    pub fn drawCheckHighlight(self: *Renderer, king_square: Square) void {
        _ = self;
        const pos = squareToScreen(king_square);
        const color = rl.Fade(rl.RED, 0.5);
        rl.DrawRectangle(@intFromFloat(pos.x), @intFromFloat(pos.y), constants.SQUARE_SIZE, constants.SQUARE_SIZE, color);
    }

    pub fn drawSelectedSquare(self: *Renderer, square: Square) void {
        const pos = squareToScreen(square);
        rl.DrawRectangle(
            @intFromFloat(pos.x),
            @intFromFloat(pos.y),
            constants.SQUARE_SIZE,
            constants.SQUARE_SIZE,
            self.theme.selected_color,
        );
    }

    pub fn drawLegalMoves(self: *Renderer, board: *const Board, moves: []const Move) void {
        for (moves) |move| {
            const pos = squareToScreen(move.to);
            const target_piece = board.getPiece(move.to);

            if (target_piece.isEmpty()) {
                // Draw circle for empty square moves
                const center_x = @as(i32, @intFromFloat(pos.x)) + constants.SQUARE_SIZE / 2;
                const center_y = @as(i32, @intFromFloat(pos.y)) + constants.SQUARE_SIZE / 2;
                rl.DrawCircle(center_x, center_y, constants.SQUARE_SIZE / 6, rl.Fade(self.theme.highlight_color, 0.5));
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
                    self.theme.highlight_color,
                );
            }
        }
    }

    pub fn drawPieces(self: *Renderer, board: *const Board, dragging: ?DragState, animation: ?MoveAnimation) void {
        for (0..64) |i| {
            const square = Square.fromIndex(@intCast(i));
            const piece = board.getPiece(square);

            // Skip if this piece is being dragged
            if (dragging) |drag| {
                if (drag.from == square) continue;
            }

            // Skip if this piece is being animated
            if (animation) |anim| {
                if (anim.move.from == square) continue;
            }

            if (!piece.isEmpty()) {
                const pos = squareToScreen(square);
                self.drawPiece(piece, pos.x, pos.y);
            }
        }

        // Draw animating piece on top
        if (animation) |anim| {
            const start_pos = squareToScreen(anim.move.from);
            const end_pos = squareToScreen(anim.move.to);
            const t = easeInOutCubic(anim.progress);

            const cur_x = start_pos.x + (end_pos.x - start_pos.x) * t;
            const cur_y = start_pos.y + (end_pos.y - start_pos.y) * t;

            self.drawPiece(anim.piece, cur_x, cur_y);
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

    pub fn drawPieceAt(self: *Renderer, piece: Piece, x: f32, y: f32, size: f32) void {
        if (self.assets.getTexture(piece)) |texture| {
            const scale = size / @as(f32, @floatFromInt(texture.width));
            // The texture will be scaled to 'size', so just draw at x, y
            const position = rl.Vector2{
                .x = x,
                .y = y,
            };
            rl.DrawTextureEx(
                texture,
                position,
                0.0,
                scale,
                rl.WHITE,
            );
        } else {
            // Fallback: draw text symbol centered
            const symbol_ptr: [*c]const u8 = @ptrCast(piece.symbol().ptr);
            const text_size: i32 = 40;
            const text_width = rl.MeasureText(symbol_ptr, text_size);
            rl.DrawText(
                symbol_ptr,
                @intFromFloat(x + (size - @as(f32, @floatFromInt(text_width))) / 2.0),
                @intFromFloat(y + (size - @as(f32, @floatFromInt(text_size))) / 2.0),
                text_size,
                rl.RED,
            );
        }
    }

    pub fn drawRightPanel(self: *Renderer, move_history: []const Move) void {
        _ = self;
        // Panel Background
        rl.DrawRectangle(
            constants.PANEL_X,
            constants.PANEL_Y,
            constants.PANEL_WIDTH,
            constants.PANEL_HEIGHT,
            rl.Color{ .r = 45, .g = 45, .b = 45, .a = 255 },
        );
        rl.DrawRectangleLines(
            constants.PANEL_X,
            constants.PANEL_Y,
            constants.PANEL_WIDTH,
            constants.PANEL_HEIGHT,
            rl.Color{ .r = 60, .g = 60, .b = 60, .a = 255 },
        );

        // Header
        const header = "Move History";
        const header_size = 24;
        const header_width = rl.MeasureText(header, header_size);
        rl.DrawText(
            header,
            constants.PANEL_X + @divTrunc(constants.PANEL_WIDTH - header_width, 2),
            constants.PANEL_Y + 20,
            header_size,
            rl.LIGHTGRAY,
        );

        // Move History List
        const list_y = constants.PANEL_Y + 60;
        const list_height = constants.PANEL_HEIGHT - 160;
        const row_height = 25;
        const moves_per_page = @divTrunc(list_height, row_height);

        const total_moves = move_history.len;
        const start_move = if (total_moves > moves_per_page * 2)
            ((total_moves - 1) / 2 - moves_per_page + 1) * 2
        else
            0;

        var i: usize = start_move;
        var row: i32 = 0;
        while (i < total_moves) : (row += 1) {
            const move_num = i / 2 + 1;
            var buf: [32]u8 = undefined;
            const num_text = std.fmt.bufPrintZ(&buf, "{d}.", .{move_num}) catch "?.";

            const y = list_y + row * row_height;

            // Draw move number
            rl.DrawText(num_text, constants.PANEL_X + 20, y, 20, rl.GRAY);

            // White move
            var white_buf: [16]u8 = undefined;
            const white_text = move_history[i].toNotation(&white_buf) catch "??";
            const white_text_z = std.fmt.bufPrintZ(&buf, "{s}", .{white_text}) catch "??";
            rl.DrawText(white_text_z, constants.PANEL_X + 60, y, 20, rl.WHITE);

            // Black move
            if (i + 1 < total_moves) {
                var black_buf: [16]u8 = undefined;
                const black_text = move_history[i + 1].toNotation(&black_buf) catch "??";
                const black_text_z = std.fmt.bufPrintZ(&buf, "{s}", .{black_text}) catch "??";
                rl.DrawText(black_text_z, constants.PANEL_X + 160, y, 20, rl.WHITE);
            }

            i += 2;
            if (row >= moves_per_page) break;
        }

        // Buttons at the bottom
        // Draw buttons is handled by main app for click detection but we can draw them here
    }

    pub fn drawButton(self: *Renderer, rect: rl.Rectangle, text: [*c]const u8, hovered: bool) void {
        _ = self;
        const bg_color = if (hovered) rl.Color{ .r = 80, .g = 80, .b = 80, .a = 255 } else rl.Color{ .r = 60, .g = 60, .b = 60, .a = 255 };
        rl.DrawRectangleRec(rect, bg_color);
        rl.DrawRectangleLinesEx(rect, 2, rl.GRAY);

        const font_size = 20;
        const text_width = rl.MeasureText(text, font_size);
        const text_x = rect.x + (rect.width - @as(f32, @floatFromInt(text_width))) / 2.0;
        const text_y = rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2.0;

        rl.DrawText(text, @intFromFloat(text_x), @intFromFloat(text_y), font_size, rl.WHITE);
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
