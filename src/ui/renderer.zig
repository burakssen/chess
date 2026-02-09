const std = @import("std");
const rl = @import("raylib.zig").rl;

const engine = @import("engine");
const Board = engine.Board;
const ChessGame = engine.ChessGame;

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
        rl.ClearBackground(rl.Color{ .r = 20, .g = 20, .b = 20, .a = 255 });
    }

    pub fn endFrame(self: *Renderer) void {
        _ = self;
        rl.EndDrawing();
    }

    pub fn drawBoard(self: *Renderer) void {
        // Draw board shadow/outer border
        const shadow_rect = rl.Rectangle{
            .x = @as(f32, @floatFromInt(constants.BOARD_OFFSET_X)) - 5,
            .y = @as(f32, @floatFromInt(constants.BOARD_OFFSET_Y)) - 5,
            .width = @as(f32, @floatFromInt(constants.BOARD_SIZE)) + 10,
            .height = @as(f32, @floatFromInt(constants.BOARD_SIZE)) + 10,
        };
        rl.DrawRectangleRounded(shadow_rect, 0.02, 10, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 150 });
        
        // Draw board background
        const board_rect = rl.Rectangle{
            .x = @floatFromInt(constants.BOARD_OFFSET_X),
            .y = @floatFromInt(constants.BOARD_OFFSET_Y),
            .width = @floatFromInt(constants.BOARD_SIZE),
            .height = @floatFromInt(constants.BOARD_SIZE),
        };
        rl.DrawRectangleRec(board_rect, self.theme.dark_square);

        for (0..8) |rank_idx| {
            for (0..8) |file_idx| {
                const rank: u8 = @intCast(rank_idx);
                const file: u8 = @intCast(file_idx);
                const is_light_orig = (rank + file) % 2 == 0;
                
                if (is_light_orig) {
                    const x = constants.BOARD_OFFSET_X + @as(i32, @intCast(file)) * constants.SQUARE_SIZE;
                    const y = constants.BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank)) * constants.SQUARE_SIZE;
                    rl.DrawRectangle(x, y, constants.SQUARE_SIZE, constants.SQUARE_SIZE, self.theme.light_square);
                }
            }
        }

        self.drawCoordinates();
    }

    fn drawCoordinates(self: *Renderer) void {
        const font_size = 18;

        // Draw files (a-h) on the bottom rank squares
        for (0..8) |file_idx| {
            const label: [2]u8 = .{ @as(u8, @intCast(file_idx)) + 'a', 0 };
            const label_ptr: [*c]const u8 = @ptrCast(&label);

            const x = constants.BOARD_OFFSET_X + @as(i32, @intCast(file_idx)) * constants.SQUARE_SIZE + constants.SQUARE_SIZE - 15;
            const y = constants.BOARD_OFFSET_Y + 7 * constants.SQUARE_SIZE + constants.SQUARE_SIZE - 22;

            const is_light = file_idx % 2 != 0;
            const color = if (is_light) self.theme.dark_square else self.theme.light_square;

            rl.DrawText(label_ptr, x, y, font_size, color);
        }

        // Draw ranks (1-8) on the 'a' file squares
        for (0..8) |rank_idx| {
            const label: [2]u8 = .{ @as(u8, @intCast(rank_idx)) + '1', 0 };
            const label_ptr: [*c]const u8 = @ptrCast(&label);

            const x = constants.BOARD_OFFSET_X + 5;
            const y = constants.BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank_idx)) * constants.SQUARE_SIZE + 5;

            const is_light = rank_idx % 2 != 0;
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
        
        // Draw a glowing effect for check
        const x = @as(i32, @intFromFloat(pos.x));
        const y = @as(i32, @intFromFloat(pos.y));
        rl.DrawRectangle(x, y, constants.SQUARE_SIZE, constants.SQUARE_SIZE, color);
        rl.DrawRectangleLinesEx(rl.Rectangle{ .x = pos.x, .y = pos.y, .width = @floatFromInt(constants.SQUARE_SIZE), .height = @floatFromInt(constants.SQUARE_SIZE) }, 3, rl.RED);
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
                const center_x = @as(i32, @intFromFloat(pos.x)) + constants.SQUARE_SIZE / 2;
                const center_y = @as(i32, @intFromFloat(pos.y)) + constants.SQUARE_SIZE / 2;
                rl.DrawCircle(center_x, center_y, constants.SQUARE_SIZE / 6, rl.Fade(self.theme.highlight_color, 0.3));
            } else {
                rl.DrawRectangleLinesEx(
                    rl.Rectangle{
                        .x = pos.x + 4,
                        .y = pos.y + 4,
                        .width = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) - 8,
                        .height = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) - 8,
                    },
                    5.0,
                    rl.Fade(self.theme.highlight_color, 0.4),
                );
            }
        }
    }

    pub fn drawPieces(self: *Renderer, board: *const Board, dragging: ?DragState, animation: ?MoveAnimation) void {
        for (0..64) |i| {
            const square = Square.fromIndex(@intCast(i));
            const piece = board.getPiece(square);

            if (dragging) |drag| {
                if (drag.from == square) continue;
            }

            if (animation) |anim| {
                if (anim.move.from == square) continue;
            }

            if (!piece.isEmpty()) {
                const pos = squareToScreen(square);
                self.drawPiece(piece, pos.x, pos.y);
            }
        }

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
        const piece_x = mouse_pos.x - @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 0.5;
        const piece_y = mouse_pos.y - @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 0.5;
        
        // Draw shadow under dragged piece
        rl.DrawCircle(@intFromFloat(mouse_pos.x), @intFromFloat(mouse_pos.y + 5), @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 0.4, rl.Fade(rl.BLACK, 0.3));
        
        self.drawPiece(piece, piece_x, piece_y);
    }

    pub fn drawGameOver(self: *Renderer, status: GameStatus, winner: ?Color) void {
        // Full screen dimming
        rl.DrawRectangle(0, 0, constants.WINDOW_WIDTH, constants.WINDOW_HEIGHT, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 180 });

        const card_width: f32 = 540;
        const card_height: f32 = 320;
        const card_x = (@as(f32, @floatFromInt(constants.WINDOW_WIDTH)) - card_width) / 2.0;
        const card_y = (@as(f32, @floatFromInt(constants.WINDOW_HEIGHT)) - card_height) / 2.0;

        const card_rect = rl.Rectangle{ .x = card_x, .y = card_y, .width = card_width, .height = card_height };
        
        // Draw card shadow
        rl.DrawRectangleRounded(rl.Rectangle{ .x = card_x + 6, .y = card_y + 6, .width = card_width, .height = card_height }, 0.1, 10, rl.Fade(rl.BLACK, 0.5));
        
        // Draw card background
        rl.DrawRectangleRounded(card_rect, 0.1, 10, self.theme.panel_bg);
        rl.DrawRectangleRoundedLines(card_rect, 0.1, 10, self.theme.accent);

        const title: [*c]const u8 = "Game Over";
        const title_size = 32;
        const title_width = rl.MeasureText(title, title_size);
        rl.DrawText(title, @intFromFloat(card_x + (card_width - @as(f32, @floatFromInt(title_width))) / 2.0), @intFromFloat(card_y + 30), title_size, self.theme.text_secondary);

        const message: [*c]const u8 = switch (status) {
            .checkmate => if (winner == .Black) "Black Wins by Checkmate!" else "White Wins by Checkmate!",
            .stalemate => "Draw by Stalemate!",
            .ongoing => unreachable,
        };

        const msg_size = 36;
        const msg_width = rl.MeasureText(message, msg_size);
        rl.DrawText(message, @intFromFloat(card_x + (card_width - @as(f32, @floatFromInt(msg_width))) / 2.0), @intFromFloat(card_y + 110), msg_size, self.theme.accent);

        const subtitle: [*c]const u8 = "Press R or Click to Play Again";
        const sub_size = 24;
        const sub_width = rl.MeasureText(subtitle, sub_size);
        rl.DrawText(subtitle, @intFromFloat(card_x + (card_width - @as(f32, @floatFromInt(sub_width))) / 2.0), @intFromFloat(card_y + 220), sub_size, self.theme.text_primary);
        
        // Pulse effect for the border
        const time = @as(f32, @floatCast(rl.GetTime()));
        const alpha = 0.3 + 0.3 * @sin(time * 3.0);
        rl.DrawRectangleRoundedLines(card_rect, 0.1, 10, rl.Fade(self.theme.accent, alpha));
    }

    fn drawPiece(self: *Renderer, piece: Piece, x: f32, y: f32) void {
        if (self.assets.getTexture(piece)) |texture| {
            const scale = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / @as(f32, @floatFromInt(texture.width));
            rl.DrawTextureEx(texture, rl.Vector2{ .x = x, .y = y }, 0.0, scale, rl.WHITE);
        } else {
            const symbol_ptr: [*c]const u8 = @ptrCast(piece.symbol().ptr);
            rl.DrawText(symbol_ptr, @intFromFloat(x + @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / 4), @intFromFloat(y + @as(f32, @floatFromInt(constants.SQUARE_SIZE)) / 4), 48, rl.RED);
        }
    }

    pub fn drawPieceAt(self: *Renderer, piece: Piece, x: f32, y: f32, size: f32) void {
        if (self.assets.getTexture(piece)) |texture| {
            const scale = size / @as(f32, @floatFromInt(texture.width));
            rl.DrawTextureEx(texture, rl.Vector2{ .x = x, .y = y }, 0.0, scale, rl.WHITE);
        } else {
            const symbol_ptr: [*c]const u8 = @ptrCast(piece.symbol().ptr);
            rl.DrawText(symbol_ptr, @intFromFloat(x), @intFromFloat(y), @intFromFloat(size), rl.RED);
        }
    }

    pub fn drawRightPanel(self: *Renderer, game: *const ChessGame) void {
        const panel_rect = rl.Rectangle{
            .x = @floatFromInt(constants.PANEL_X),
            .y = @floatFromInt(constants.PANEL_Y),
            .width = @floatFromInt(constants.PANEL_WIDTH),
            .height = @floatFromInt(constants.PANEL_HEIGHT),
        };

        // Panel Shadow
        rl.DrawRectangleRounded(rl.Rectangle{ .x = panel_rect.x + 5, .y = panel_rect.y + 5, .width = panel_rect.width, .height = panel_rect.height }, constants.CORNER_RADIUS, 10, rl.Fade(rl.BLACK, 0.4));
        
        // Panel Background
        rl.DrawRectangleRounded(panel_rect, constants.CORNER_RADIUS, 10, self.theme.panel_bg);
        rl.DrawRectangleRoundedLines(panel_rect, constants.CORNER_RADIUS, 10, self.theme.panel_border);

        // Turn Indicator
        self.drawTurnIndicator(game.board.active_color);

        // Header
        const header = "Move History";
        const header_size = 28;
        const header_width = rl.MeasureText(header, header_size);
        rl.DrawText(header, constants.PANEL_X + @divTrunc(constants.PANEL_WIDTH - header_width, 2), constants.PANEL_Y + 100, header_size, self.theme.text_primary);

        // Separator
        rl.DrawLine(constants.PANEL_X + 40, constants.PANEL_Y + 140, constants.PANEL_X + constants.PANEL_WIDTH - 40, constants.PANEL_Y + 140, rl.Fade(self.theme.panel_border, 0.5));

        // Move History List
        const list_y = constants.PANEL_Y + 160;
        const list_height = constants.PANEL_HEIGHT - 350;
        const row_height = 30;
        const moves_per_page = @divTrunc(list_height, row_height);

        const total_moves = game.move_history.items.len;
        const start_move = if (total_moves > moves_per_page * 2) ((total_moves - 1) / 2 - moves_per_page + 1) * 2 else 0;

        var i: usize = start_move;
        var row: i32 = 0;
        while (i < total_moves) : (row += 1) {
            const move_num = i / 2 + 1;
            var buf: [32]u8 = undefined;
            const num_text = std.fmt.bufPrintZ(&buf, "{d}.", .{move_num}) catch "?.";

            const y = list_y + row * row_height;

            rl.DrawText(num_text, constants.PANEL_X + 30, y, 22, self.theme.text_secondary);

            // White move
            var white_buf: [16]u8 = undefined;
            const white_text = game.move_history.items[i].toNotation(&white_buf) catch "??";
            const white_text_z = std.fmt.bufPrintZ(&buf, "{s}", .{white_text}) catch "??";
            rl.DrawText(white_text_z, constants.PANEL_X + 80, y, 22, self.theme.text_primary);

            // Black move
            if (i + 1 < total_moves) {
                var black_buf: [16]u8 = undefined;
                const black_text = game.move_history.items[i + 1].toNotation(&black_buf) catch "??";
                const black_text_z = std.fmt.bufPrintZ(&buf, "{s}", .{black_text}) catch "??";
                rl.DrawText(black_text_z, constants.PANEL_X + 180, y, 22, self.theme.text_primary);
            }

            i += 2;
            if (row >= moves_per_page) break;
        }

        // Captured Pieces
        self.drawCapturedPieces(game);
    }

    fn drawTurnIndicator(self: *Renderer, active_color: Color) void {
        const x = constants.PANEL_X + 30;
        const y = constants.PANEL_Y + 30;
        const width = constants.PANEL_WIDTH - 60;
        const height = 50;

        const rect = rl.Rectangle{ .x = @floatFromInt(x), .y = @floatFromInt(y), .width = @floatFromInt(width), .height = height };
        rl.DrawRectangleRounded(rect, 0.5, 10, rl.Fade(self.theme.panel_border, 0.3));

        const text = if (active_color == .White) "White's Turn" else "Black's Turn";
        const font_size = 24;
        const text_width = rl.MeasureText(text, font_size);
        const text_x = x + @divTrunc(width - text_width, 2);
        const text_y = y + @divTrunc(height - font_size, 2);

        // Small indicator circle
        const circle_color = if (active_color == .White) self.theme.light_square else self.theme.dark_square;
        rl.DrawCircle(x + 25, y + @divTrunc(height, 2), 10, circle_color);
        rl.DrawCircleLines(x + 25, y + @divTrunc(height, 2), 10, self.theme.text_primary);

        rl.DrawText(text, text_x, text_y, font_size, self.theme.text_primary);
    }

    fn drawCapturedPieces(self: *Renderer, game: *const ChessGame) void {
        const start_y = constants.PANEL_Y + constants.PANEL_HEIGHT - 180;
        const piece_size = 35.0;

        // Draw labels
        rl.DrawText("Captured Pieces", constants.PANEL_X + 30, start_y, 20, self.theme.text_secondary);

        var white_captured = std.EnumMap(core.types.PieceType, u32).init(.{});
        var black_captured = std.EnumMap(core.types.PieceType, u32).init(.{});

        for (game.undo_history.items) |undo| {
            if (!undo.captured_piece.isEmpty()) {
                const p = undo.captured_piece;
                const map = if (p.getColor() == .White) &white_captured else &black_captured;
                const count = map.get(p.getType()) orelse 0;
                map.put(p.getType(), count + 1);
            }
        }

        const piece_types = [_]core.types.PieceType{ .Pawn, .Knight, .Bishop, .Rook, .Queen };

        // Draw white captured pieces (by black)
        var wx: f32 = @as(f32, @floatFromInt(constants.PANEL_X)) + 30;
        for (piece_types) |pt| {
            if (white_captured.get(pt)) |count| {
                const piece = Piece.init(.White, pt);
                for (0..count) |_| {
                    self.drawPieceAt(piece, wx, @floatFromInt(start_y + 30), piece_size);
                    wx += piece_size * 0.4;
                }
                wx += piece_size * 0.6;
            }
        }

        // Draw black captured pieces (by white)
        var bx: f32 = @as(f32, @floatFromInt(constants.PANEL_X)) + 30;
        for (piece_types) |pt| {
            if (black_captured.get(pt)) |count| {
                const piece = Piece.init(.Black, pt);
                for (0..count) |_| {
                    self.drawPieceAt(piece, bx, @floatFromInt(start_y + 80), piece_size);
                    bx += piece_size * 0.4;
                }
                bx += piece_size * 0.6;
            }
        }
    }

    pub fn drawButton(self: *Renderer, rect: rl.Rectangle, text: [*c]const u8, hovered: bool) void {
        const bg_color = if (hovered) self.theme.accent else self.theme.panel_bg;
        const text_color = if (hovered) rl.BLACK else self.theme.text_primary;

        rl.DrawRectangleRounded(rect, constants.BUTTON_CORNER_RADIUS, 10, bg_color);
        rl.DrawRectangleRoundedLines(rect, constants.BUTTON_CORNER_RADIUS, 10, self.theme.accent);

        const font_size = 22;
        const text_width = rl.MeasureText(text, font_size);
        const text_x = rect.x + (rect.width - @as(f32, @floatFromInt(text_width))) / 2.0;
        const text_y = rect.y + (rect.height - @as(f32, @floatFromInt(font_size))) / 2.0;

        rl.DrawText(text, @intFromFloat(text_x), @intFromFloat(text_y), font_size, text_color);
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
