const std = @import("std");
const builtin = @import("builtin");

const rl = @import("raylib.zig").rl;

const Chess = @import("chess");
const Square = Chess.types.Square;
const Move = Chess.types.Move;
const Color = Chess.types.Color;
const ChessState = @import("chess_state.zig");
const Constants = @import("constants.zig");
const Piece = Chess.Piece;
const PieceTextures = @import("piece_textures.zig");

const Game = @This();

allocator: std.mem.Allocator,
state: ChessState,

pub fn init(allocator: std.mem.Allocator) !*Game {
    const game = try allocator.create(Game);

    rl.InitWindow(800, 800, "Chess");
    rl.SetTargetFPS(60);

    game.* = Game{
        .allocator = allocator,
        .state = try ChessState.init(allocator),
    };

    return game;
}

pub fn deinit(self: *Game) void {
    rl.CloseWindow();
    self.state.deinit();
    self.allocator.destroy(self);
}

pub fn run(self: *Game) !void {
    if (builtin.os.tag == .emscripten) {
        const emsdk = @cImport(@cInclude("emscripten/emscripten.h"));

        const loop = struct {
            fn run(arg: ?*anyopaque) callconv(.c) void {
                const game: *Game = @ptrCast(@alignCast(arg));
                game.update() catch |err| {
                    std.debug.print("Error in update: {}\n", .{err});
                };
                game.render() catch |err| {
                    std.debug.print("Error in render: {}\n", .{err});
                };
            }
        }.run;

        emsdk.emscripten_set_main_loop_arg(loop, self, 0, true);
    } else {
        while (!rl.WindowShouldClose()) {
            try self.update();
            try self.render();
        }
    }
}

pub fn update(self: *Game) !void {
    if (rl.IsKeyPressed(rl.KEY_R)) {
        try self.state.reset();
        return;
    }

    const mouse_pos = rl.GetMousePosition();
    const mouse_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
    const mouse_released = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);

    // Convert mouse position to board square
    const maybe_square = mouseToSquare(mouse_pos);

    // If game is over, only allow reset
    if (self.state.game_status != .ongoing) {
        if (mouse_pressed) {
            try self.state.reset();
        }
        return;
    }

    if (mouse_pressed and maybe_square != null) {
        const square = maybe_square.?;
        const piece = self.state.chess.board.getPiece(square);

        if (!piece.isEmpty() and piece.getColor() == self.state.chess.board.active_color) {
            // Start dragging
            const square_pos = squareToScreen(square);
            self.state.dragging_piece = .{
                .piece = piece,
                .from = square,
                .mouse_offset = .{
                    .x = mouse_pos.x - square_pos.x,
                    .y = mouse_pos.y - square_pos.y,
                },
            };
            self.state.selected_square = square;

            // Generate legal moves for this square
            self.state.legal_moves.clearRetainingCapacity();

            var all_moves = try self.state.chess.board.getAllLegalMoves(self.state.allocator);
            defer all_moves.deinit();

            for (all_moves.items) |move| {
                if (move.from == square) {
                    try self.state.legal_moves.append(move);
                }
            }
        }
    }

    if (mouse_released and self.state.dragging_piece != null) {
        const drag = self.state.dragging_piece.?;

        if (maybe_square) |to_square| {
            // Attempt to make the move
            const move = Move.init(drag.from, to_square);
            self.state.chess.makeMove(move) catch |err| {
                std.debug.print("Invalid move: {}\n", .{err});
            };

            // Check game status AFTER the move
            // updateCheckStatus() was called in makeMove(), so is_checkmate is already set
            if (self.state.chess.board.is_checkmate) {
                self.state.game_status = .checkmate;
            } else {
                // Check if there are any legal moves left
                var all_moves = try self.state.chess.board.getAllLegalMoves(self.state.allocator);
                defer all_moves.deinit();

                if (all_moves.items.len == 0) {
                    self.state.game_status = .stalemate;
                }
            }
        }

        self.state.dragging_piece = null;
        self.state.selected_square = null;
        self.state.legal_moves.clearRetainingCapacity();
    }
}

fn render(self: *Game) !void {
    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 });

    // Draw board
    drawBoard();

    // Highlight selected square
    if (self.state.selected_square) |square| {
        const pos = squareToScreen(square);
        rl.DrawRectangle(
            @intFromFloat(pos.x),
            @intFromFloat(pos.y),
            Constants.SQUARE_SIZE,
            Constants.SQUARE_SIZE,
            Constants.SELECTED_COLOR,
        );
    }

    // Draw legal move indicators
    for (self.state.legal_moves.items) |move| {
        const pos = squareToScreen(move.to);
        const target_piece = self.state.chess.board.getPiece(move.to);

        if (target_piece.isEmpty()) {
            // Draw circle for empty square moves
            const center_x = @as(i32, @intFromFloat(pos.x)) + Constants.SQUARE_SIZE / 2;
            const center_y = @as(i32, @intFromFloat(pos.y)) + Constants.SQUARE_SIZE / 2;
            rl.DrawCircle(center_x, center_y, Constants.SQUARE_SIZE / 6, rl.Fade(Constants.HIGHLIGHT_COLOR, 0.5));
        } else {
            // Draw ring for capture moves
            rl.DrawRectangleLinesEx(
                rl.Rectangle{
                    .x = pos.x + 4,
                    .y = pos.y + 4,
                    .width = Constants.SQUARE_SIZE - 8,
                    .height = Constants.SQUARE_SIZE - 8,
                },
                4.0,
                Constants.HIGHLIGHT_COLOR,
            );
        }
    }

    // Draw pieces
    for (0..64) |i| {
        const square: Square = @enumFromInt(@as(u6, @intCast(i)));
        const piece = self.state.chess.board.getPiece(square);

        // Skip if this piece is being dragged
        if (self.state.dragging_piece != null and self.state.dragging_piece.?.from == square) {
            continue;
        }

        if (!piece.isEmpty()) {
            const pos = squareToScreen(square);
            drawPiece(&self.state.textures, piece, pos.x, pos.y);
        }
    }

    // Draw dragged piece
    if (self.state.dragging_piece) |drag| {
        const mouse_pos = rl.GetMousePosition();
        const piece_x = mouse_pos.x - @as(f32, @floatFromInt(Constants.SQUARE_SIZE)) / 2.0;
        const piece_y = mouse_pos.y - @as(f32, @floatFromInt(Constants.SQUARE_SIZE)) / 2.0;
        drawPiece(&self.state.textures, drag.piece, piece_x, piece_y);
    }

    // Draw game status overlay
    if (self.state.game_status != .ongoing) {
        self.drawGameOverOverlay();
    }
}

fn drawGameOverOverlay(self: *Game) void {
    // Semi-transparent overlay
    rl.DrawRectangle(
        0,
        0,
        Constants.WINDOW_WIDTH,
        Constants.WINDOW_HEIGHT,
        rl.Color{ .r = 0, .g = 0, .b = 0, .a = 180 },
    );

    // Determine message
    const message: [*c]const u8 = switch (self.state.game_status) {
        .checkmate => if (self.state.chess.board.active_color == Color.White)
            "Checkmate! Black Wins!"
        else
            "Checkmate! White Wins!",
        .stalemate => "Stalemate! Draw!",
        .ongoing => unreachable,
    };

    const subtitle: [*c]const u8 = "Press R or Click to Reset";

    // Measure text
    const font_size = 60;
    const subtitle_size = 30;
    const text_width = rl.MeasureText(message, font_size);
    const subtitle_width = rl.MeasureText(subtitle, subtitle_size);

    // Draw main message
    const text_x = @divTrunc(Constants.WINDOW_WIDTH - text_width, 2);
    const text_y = @divTrunc(Constants.WINDOW_HEIGHT, 2) - 50;

    // Draw text shadow
    rl.DrawText(message, text_x + 3, text_y + 3, font_size, rl.BLACK);
    // Draw main text
    rl.DrawText(message, text_x, text_y, font_size, rl.GOLD);

    // Draw subtitle
    const subtitle_x = @divTrunc(Constants.WINDOW_WIDTH - subtitle_width, 2);
    const subtitle_y = text_y + 80;
    rl.DrawText(subtitle, subtitle_x + 2, subtitle_y + 2, subtitle_size, rl.BLACK);
    rl.DrawText(subtitle, subtitle_x, subtitle_y, subtitle_size, rl.WHITE);
}

fn drawBoard() void {
    for (0..8) |rank_idx| {
        for (0..8) |file_idx| {
            const rank: u8 = @intCast(rank_idx);
            const file: u8 = @intCast(file_idx);
            const is_light = (rank + file) % 2 == 0;
            const color = if (is_light) Constants.LIGHT_SQUARE else Constants.DARK_SQUARE;

            const x = Constants.BOARD_OFFSET_X + @as(i32, @intCast(file)) * Constants.SQUARE_SIZE;
            const y = Constants.BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank)) * Constants.SQUARE_SIZE;

            rl.DrawRectangle(x, y, Constants.SQUARE_SIZE, Constants.SQUARE_SIZE, color);
        }
    }
}

fn drawPiece(textures: *const PieceTextures, piece: Piece, x: f32, y: f32) void {
    if (textures.get(piece)) |texture| {
        const scale = @as(f32, @floatFromInt(Constants.SQUARE_SIZE)) / @as(f32, @floatFromInt(texture.width));
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
            @intFromFloat(x + Constants.SQUARE_SIZE / 2),
            @intFromFloat(y + Constants.SQUARE_SIZE / 2),
            40,
            rl.RED,
        );
    }
}

fn mouseToSquare(mouse_pos: rl.Vector2) ?Square {
    const x = @as(i32, @intFromFloat(mouse_pos.x)) - Constants.BOARD_OFFSET_X;
    const y = @as(i32, @intFromFloat(mouse_pos.y)) - Constants.BOARD_OFFSET_Y;

    if (x < 0 or x >= Constants.BOARD_SIZE or y < 0 or y >= Constants.BOARD_SIZE) {
        return null;
    }

    const file: i8 = @intCast(@divTrunc(x, Constants.SQUARE_SIZE));
    const rank: i8 = @intCast(7 - @divTrunc(y, Constants.SQUARE_SIZE));

    return Square.fromCoords(rank, file);
}

fn squareToScreen(square: Square) rl.Vector2 {
    const file = square.file();
    const rank = square.rank();

    return rl.Vector2{
        .x = @floatFromInt(Constants.BOARD_OFFSET_X + @as(i32, file) * Constants.SQUARE_SIZE),
        .y = @floatFromInt(Constants.BOARD_OFFSET_Y + @as(i32, 7 - rank) * Constants.SQUARE_SIZE),
    };
}
