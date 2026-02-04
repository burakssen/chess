const std = @import("std");
const builtin = @import("builtin");
const rl = @import("ui").rl;

const engine = @import("engine");
const ChessGame = engine.ChessGame;
const GameMode = engine.GameMode;
const ui = @import("ui");
const Renderer = ui.Renderer;
const DragState = ui.DragState;
const MoveAnimation = ui.MoveAnimation;
const InputHandler = ui.InputHandler;
const constants = ui.constants;

const ai = @import("ai");
const AIPlayer = ai.AIPlayer;
const AIDifficulty = ai.AIDifficulty;

const core = @import("core");
const Move = core.Move;
const Square = core.Square;
const Piece = core.Piece;
const PieceType = core.types.PieceType;
const Color = core.types.Color;

const PromotionState = struct {
    move: Move,
    piece: Piece,
};

const MenuState = enum {
    main_menu,
    difficulty_select,
    theme_select,
    playing,
};

const MenuSelection = struct {
    game_mode: GameMode,
    difficulty: AIDifficulty,
    selected_mode_index: usize,
    selected_difficulty_index: usize,
    selected_theme_index: usize,

    pub fn init() MenuSelection {
        return .{
            .game_mode = .human_vs_computer,
            .difficulty = .medium,
            .selected_mode_index = 1,
            .selected_difficulty_index = 1,
            .selected_theme_index = 0,
        };
    }
};

const App = struct {
    allocator: std.mem.Allocator,
    game: ?ChessGame,
    renderer: ?Renderer,
    drag_state: ?DragState,
    move_animation: ?MoveAnimation,
    selected_square: ?Square,
    legal_moves_buffer: [256]Move,
    legal_moves_count: usize,
    promotion_state: ?PromotionState,
    ai_player: ?AIPlayer,
    ai_move_delay: u32,
    ai_move_timer: u32,
    menu_state: MenuState,
    menu_selection: MenuSelection,

    pub fn init(allocator: std.mem.Allocator) !App {
        rl.SetConfigFlags(rl.FLAG_WINDOW_HIGHDPI);
        rl.InitWindow(constants.WINDOW_WIDTH, constants.WINDOW_HEIGHT, "Chess");
        rl.SetTargetFPS(60);

        return .{
            .allocator = allocator,
            .game = null,
            .renderer = null,
            .drag_state = null,
            .move_animation = null,
            .selected_square = null,
            .legal_moves_buffer = undefined,
            .legal_moves_count = 0,
            .promotion_state = null,
            .ai_player = null,
            .ai_move_delay = 30,
            .ai_move_timer = 0,
            .menu_state = .main_menu,
            .menu_selection = MenuSelection.init(),
        };
    }

    fn startGame(self: *App) !void {
        const mode = self.menu_selection.game_mode;
        const difficulty = self.menu_selection.difficulty;
        const theme = ui.ALL_THEMES[self.menu_selection.selected_theme_index];

        const needs_ai = mode != .human_vs_human;
        const human_color: Color = switch (mode) {
            .human_vs_human => .White,
            .human_vs_computer => .White,
            .computer_vs_human => .Black,
            .computer_vs_computer => .White,
        };

        self.game = try ChessGame.initWithMode(self.allocator, mode, human_color);
        self.renderer = try Renderer.init(self.allocator, theme);
        self.ai_player = if (needs_ai) AIPlayer.init(difficulty) else null;
        self.menu_state = .playing;
    }

    pub fn deinit(self: *App) void {
        if (self.game) |*game| game.deinit();
        if (self.renderer) |*renderer| renderer.deinit();
        rl.CloseWindow();
    }

    pub fn update(self: *App) !void {
        // Handle menu states
        switch (self.menu_state) {
            .main_menu => {
                self.updateMainMenu();
                return;
            },
            .difficulty_select => {
                try self.updateDifficultyMenu();
                return;
            },
            .theme_select => {
                self.updateThemeMenu();
                return;
            },
            .playing => {},
        }

        var game = &(self.game orelse return);

        // Handle animation
        if (self.move_animation) |*anim| {
            anim.progress += anim.speed;
            if (anim.progress >= 1.0) {
                // Apply move
                game.makeMove(anim.move) catch |err| {
                    std.debug.print("Animation move failed: {}\n", .{err});
                };
                self.move_animation = null;
                self.ai_move_timer = 0; // Reset timer after animation
            }
            return;
        }

        // Handle promotion selection
        if (self.promotion_state) |promo| {
            if (InputHandler.isMousePressed()) {
                if (self.getPromotionChoice()) |piece_type| {
                    var move = promo.move;
                    move.promotion = piece_type;
                    game.makeMove(move) catch |err| {
                        std.debug.print("Invalid promotion move: {}\n", .{err});
                    };
                    self.promotion_state = null;
                    self.ai_move_timer = 0;
                }
            }
            return;
        }

        // Handle reset (back to menu)
        if (InputHandler.isResetKeyPressed()) {
            self.returnToMenu();
            return;
        }

        // If game is over, click to go back to menu
        if (game.status != .ongoing) {
            if (InputHandler.isMousePressed()) {
                self.returnToMenu();
            }
            return;
        }

        // Handle AI moves
        if (game.isComputerTurn()) {
            try self.handleAIMove();
            return;
        }

        // Handle mouse press (human player)
        if (InputHandler.isMousePressed()) {
            if (InputHandler.getMouseSquare()) |square| {
                const piece = game.board.getPiece(square);

                // Only allow human to move their own pieces
                if (!piece.isEmpty() and piece.getColor() == game.board.active_color and game.isHumanTurn()) {
                    // Start dragging
                    self.drag_state = .{
                        .piece = piece,
                        .from = square,
                    };
                    self.selected_square = square;

                    // Get legal moves for this piece
                    const moves = game.getLegalMovesForPiece(square);
                    self.legal_moves_count = moves.len;
                    @memcpy(self.legal_moves_buffer[0..moves.len], moves);
                }
            }
        }

        // Handle mouse release
        if (InputHandler.isMouseReleased() and self.drag_state != null) {
            const drag = self.drag_state.?;

            if (InputHandler.getMouseSquare()) |to_square| {
                const piece = drag.piece;
                if (piece.getType() == .Pawn) {
                    const to_rank = to_square.rank();
                    const piece_color = piece.getColor();

                    // White pawn reaching rank 8 or black pawn reaching rank 1
                    if ((piece_color == .White and to_rank == 7) or
                        (piece_color == .Black and to_rank == 0))
                    {
                        // Validate that at least one promotion move is legal
                        const test_move = Move.withPromotion(drag.from, to_square, .Queen);
                        if (self.isMoveLegalFromBuffer(test_move)) {
                            // Show promotion UI
                            self.promotion_state = .{
                                .move = Move.init(drag.from, to_square),
                                .piece = piece,
                            };
                            self.drag_state = null;
                            self.selected_square = null;
                            self.legal_moves_count = 0;
                            return;
                        }
                    }
                }

                const move = Move.init(drag.from, to_square);
                if (game.makeMove(move)) |_| {
                    self.ai_move_timer = 0; // Reset AI timer after human move
                } else |err| {
                    std.debug.print("Invalid move: {}\n", .{err});
                }
            }

            self.drag_state = null;
            self.selected_square = null;
            self.legal_moves_count = 0;
        }
    }

    fn returnToMenu(self: *App) void {
        if (self.game) |*game| {
            game.deinit();
            self.game = null;
        }
        if (self.renderer) |*renderer| {
            renderer.deinit();
            self.renderer = null;
        }
        self.drag_state = null;
        self.move_animation = null;
        self.selected_square = null;
        self.legal_moves_count = 0;
        self.promotion_state = null;
        self.ai_player = null;
        self.ai_move_timer = 0;
        self.menu_state = .main_menu;
    }

    fn updateMainMenu(self: *App) void {
        const mouse_pos = InputHandler.getMousePosition();
        const center_x = @as(f32, @floatFromInt(constants.WINDOW_WIDTH)) / 2.0;
        const start_y: f32 = 250;
        const button_width: f32 = 300;
        const button_height: f32 = 60;
        const button_spacing: f32 = 20;

        const modes = [_]struct { mode: GameMode, label: [*c]const u8 }{
            .{ .mode = .human_vs_human, .label = "Player vs Player" },
            .{ .mode = .human_vs_computer, .label = "Player vs Computer" },
            .{ .mode = .computer_vs_human, .label = "Computer vs Player" },
            .{ .mode = .computer_vs_computer, .label = "Computer vs Computer" },
        };

        if (InputHandler.isMousePressed()) {
            for (modes, 0..) |m, i| {
                const button_y = start_y + @as(f32, @floatFromInt(i)) * (button_height + button_spacing);
                const button_x = center_x - button_width / 2.0;

                if (mouse_pos.x >= button_x and mouse_pos.x <= button_x + button_width and
                    mouse_pos.y >= button_y and mouse_pos.y <= button_y + button_height)
                {
                    self.menu_selection.game_mode = m.mode;
                    self.menu_selection.selected_mode_index = i;

                    if (m.mode == .human_vs_human) {
                        // No difficulty needed, start game directly
                        self.startGame() catch |err| {
                            std.debug.print("Failed to start game: {}\n", .{err});
                        };
                    } else {
                        // Go to difficulty selection
                        self.menu_state = .difficulty_select;
                    }
                    return;
                }
            }

            // Check themes button
            const themes_y = start_y + @as(f32, @floatFromInt(modes.len)) * (button_height + button_spacing) + 20;
            const themes_x = center_x - button_width / 2.0;
            if (mouse_pos.x >= themes_x and mouse_pos.x <= themes_x + button_width and
                mouse_pos.y >= themes_y and mouse_pos.y <= themes_y + button_height)
            {
                self.menu_state = .theme_select;
            }
        }
    }

    fn updateDifficultyMenu(self: *App) !void {
        const mouse_pos = InputHandler.getMousePosition();
        const center_x = @as(f32, @floatFromInt(constants.WINDOW_WIDTH)) / 2.0;
        const start_y: f32 = 280;
        const button_width: f32 = 250;
        const button_height: f32 = 60;
        const button_spacing: f32 = 20;

        const difficulties = [_]struct { diff: AIDifficulty, label: [*c]const u8 }{
            .{ .diff = .easy, .label = "Easy" },
            .{ .diff = .medium, .label = "Medium" },
            .{ .diff = .hard, .label = "Hard" },
        };

        // Handle back button (Escape or R key)
        if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
            self.menu_state = .main_menu;
            return;
        }

        if (InputHandler.isMousePressed()) {
            // Check back button
            const back_y: f32 = start_y + @as(f32, @floatFromInt(difficulties.len)) * (button_height + button_spacing) + 20;
            const back_width: f32 = 150;
            const back_x = center_x - back_width / 2.0;

            if (mouse_pos.x >= back_x and mouse_pos.x <= back_x + back_width and
                mouse_pos.y >= back_y and mouse_pos.y <= back_y + button_height)
            {
                self.menu_state = .main_menu;
                return;
            }

            // Check difficulty buttons
            for (difficulties, 0..) |d, i| {
                const button_y = start_y + @as(f32, @floatFromInt(i)) * (button_height + button_spacing);
                const button_x = center_x - button_width / 2.0;

                if (mouse_pos.x >= button_x and mouse_pos.x <= button_x + button_width and
                    mouse_pos.y >= button_y and mouse_pos.y <= button_y + button_height)
                {
                    self.menu_selection.difficulty = d.diff;
                    self.menu_selection.selected_difficulty_index = i;
                    try self.startGame();
                    break;
                }
            }
        }
    }

    fn handleAIMove(self: *App) !void {
        var game = &(self.game orelse return);

        // Add delay before AI moves
        if (self.ai_move_timer < self.ai_move_delay) {
            self.ai_move_timer += 1;
            return;
        }

        if (self.ai_player) |*ai_player| {
            const legal_moves = game.getLegalMoves();
            if (ai_player.selectMove(&game.board, legal_moves)) |move| {
                // Start animation
                self.move_animation = .{
                    .move = move,
                    .piece = game.board.getPiece(move.from),
                    .progress = 0.0,
                    .speed = 0.075, // Adjust speed as needed
                };
            }
        }
    }

    fn isMoveLegalFromBuffer(self: *App, move: Move) bool {
        for (self.legal_moves_buffer[0..self.legal_moves_count]) |legal_move| {
            if (legal_move.from == move.from and legal_move.to == move.to) {
                // For promotions, also check the promotion type matches
                if (move.promotion != null and legal_move.promotion != null) {
                    if (move.promotion == legal_move.promotion) return true;
                } else if (move.promotion == null and legal_move.promotion == null) {
                    return true;
                } else if (move.promotion != null and legal_move.promotion != null) {
                    // If checking any promotion, just return true
                    return true;
                }
            }
        }
        return false;
    }

    fn getPromotionChoice(self: *App) ?PieceType {
        const mouse_pos = InputHandler.getMousePosition();
        _ = self.promotion_state orelse return null;

        // Use the same center + sizing logic as drawPromotionUI so hitbox matches visuals
        const board_center_x_i = constants.BOARD_OFFSET_X + constants.SQUARE_SIZE * 4;
        const board_center_y_i = constants.BOARD_OFFSET_Y + constants.SQUARE_SIZE * 4;

        const box_width = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 4.5;
        const box_height = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 1.5;
        const piece_size = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 0.8;
        const spacing = box_width / 4.0;

        const box_x = @as(f32, @floatFromInt(board_center_x_i)) - box_width / 2.0;
        const box_y = @as(f32, @floatFromInt(board_center_y_i)) - box_height / 2.0;

        // Quick reject if mouse outside the promotion box
        if (mouse_pos.x < box_x or mouse_pos.x > box_x + box_width or
            mouse_pos.y < box_y or mouse_pos.y > box_y + box_height)
        {
            return null;
        }

        const piece_y = box_y + (box_height - piece_size) / 2.0;
        const start_x = box_x + (spacing - piece_size) / 2.0;

        const pieces = [_]PieceType{ .Queen, .Rook, .Bishop, .Knight };

        for (pieces, 0..) |piece_type, i| {
            const piece_x = start_x + @as(f32, @floatFromInt(i)) * spacing;

            if (mouse_pos.x >= piece_x and mouse_pos.x <= piece_x + piece_size and
                mouse_pos.y >= piece_y and mouse_pos.y <= piece_y + piece_size)
            {
                return piece_type;
            }
        }

        return null;
    }

    pub fn render(self: *App) !void {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.ClearBackground(rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 });

        switch (self.menu_state) {
            .main_menu => {
                self.drawMainMenu();
                return;
            },
            .difficulty_select => {
                self.drawDifficultyMenu();
                return;
            },
            .theme_select => {
                self.drawThemeMenu();
                return;
            },
            .playing => {},
        }

        const renderer = &(self.renderer orelse return);
        const game = &(self.game orelse return);

        // Draw board
        renderer.drawBoard();

        // Highlight selected square
        if (self.selected_square) |square| {
            renderer.drawSelectedSquare(square);
        }

        // Draw legal move indicators
        if (self.legal_moves_count > 0) {
            renderer.drawLegalMoves(&game.board, self.legal_moves_buffer[0..self.legal_moves_count]);
        }

        // Draw pieces
        renderer.drawPieces(&game.board, self.drag_state, self.move_animation);

        // Draw dragged piece
        if (self.drag_state) |drag| {
            const mouse_pos = InputHandler.getMousePosition();
            renderer.drawDraggedPiece(drag.piece, mouse_pos);
        }

        // Draw promotion UI
        if (self.promotion_state) |promo| {
            self.drawPromotionUI(promo);
        }

        // Draw game over overlay
        if (game.status != .ongoing) {
            const winner = if (game.status == .checkmate)
                game.board.active_color.opposite()
            else
                null;
            renderer.drawGameOver(game.status, winner);
        }
    }

    fn updateThemeMenu(self: *App) void {
        const mouse_pos = InputHandler.getMousePosition();
        const center_x = @as(f32, @floatFromInt(constants.WINDOW_WIDTH)) / 2.0;
        const start_y: f32 = 250;
        const button_width: f32 = 300;
        const button_height: f32 = 60;
        const button_spacing: f32 = 20;

        // Handle back button (Escape or R key)
        if (rl.IsKeyPressed(rl.KEY_ESCAPE) or rl.IsKeyPressed(rl.KEY_BACKSPACE)) {
            self.menu_state = .main_menu;
            return;
        }

        if (InputHandler.isMousePressed()) {
            // Check theme buttons
            for (ui.ALL_THEMES, 0..) |_, i| {
                const button_y = start_y + @as(f32, @floatFromInt(i)) * (button_height + button_spacing);
                const button_x = center_x - button_width / 2.0;

                if (mouse_pos.x >= button_x and mouse_pos.x <= button_x + button_width and
                    mouse_pos.y >= button_y and mouse_pos.y <= button_y + button_height)
                {
                    self.menu_selection.selected_theme_index = i;
                    // No need to start game, just select theme
                }
            }

            // Check back button
            const back_y = start_y + @as(f32, @floatFromInt(ui.ALL_THEMES.len)) * (button_height + button_spacing) + 20;
            const back_width: f32 = 150;
            const back_x = center_x - back_width / 2.0;

            if (mouse_pos.x >= back_x and mouse_pos.x <= back_x + back_width and
                mouse_pos.y >= back_y and mouse_pos.y <= back_y + button_height)
            {
                self.menu_state = .main_menu;
                return;
            }
        }
    }

    fn drawMainMenu(self: *App) void {
        const center_x = @as(f32, @floatFromInt(constants.WINDOW_WIDTH)) / 2.0;
        const start_y: f32 = 250;
        const button_width: f32 = 300;
        const button_height: f32 = 60;
        const button_spacing: f32 = 20;

        // Draw title
        const title = "CHESS";
        const title_size: i32 = 72;
        const title_width = rl.MeasureText(title, title_size);
        const title_x = @divTrunc(constants.WINDOW_WIDTH - title_width, 2);
        rl.DrawText(title, title_x + 3, 103, title_size, rl.BLACK);
        rl.DrawText(title, title_x, 100, title_size, rl.GOLD);

        // Draw subtitle
        const subtitle = "Select Game Mode";
        const subtitle_size: i32 = 28;
        const subtitle_width = rl.MeasureText(subtitle, subtitle_size);
        const subtitle_x = @divTrunc(constants.WINDOW_WIDTH - subtitle_width, 2);
        rl.DrawText(subtitle, subtitle_x, 190, subtitle_size, rl.WHITE);

        const modes = [_][*c]const u8{
            "Player vs Player",
            "Player vs Computer",
            "Computer vs Player",
            "Computer vs Computer",
        };

        const mouse_pos = InputHandler.getMousePosition();

        for (modes, 0..) |label, i| {
            const button_y = start_y + @as(f32, @floatFromInt(i)) * (button_height + button_spacing);
            const button_x = center_x - button_width / 2.0;

            // Check hover
            const is_hovered = mouse_pos.x >= button_x and mouse_pos.x <= button_x + button_width and
                mouse_pos.y >= button_y and mouse_pos.y <= button_y + button_height;

            const bg_color = if (is_hovered) rl.Color{ .r = 80, .g = 80, .b = 120, .a = 255 } else rl.Color{ .r = 60, .g = 60, .b = 80, .a = 255 };
            const border_color = if (is_hovered) rl.GOLD else rl.WHITE;

            rl.DrawRectangle(@intFromFloat(button_x), @intFromFloat(button_y), @intFromFloat(button_width), @intFromFloat(button_height), bg_color);
            rl.DrawRectangleLinesEx(rl.Rectangle{ .x = button_x, .y = button_y, .width = button_width, .height = button_height }, 2.0, border_color);

            const text_size: i32 = 24;
            const text_width = rl.MeasureText(label, text_size);
            const text_x = @as(i32, @intFromFloat(button_x + button_width / 2.0)) - @divTrunc(text_width, 2);
            const text_y = @as(i32, @intFromFloat(button_y + button_height / 2.0)) - @divTrunc(text_size, 2);
            rl.DrawText(label, text_x, text_y, text_size, rl.WHITE);
        }

        // Themes button
        const themes_y = start_y + @as(f32, @floatFromInt(modes.len)) * (button_height + button_spacing) + 20;
        const themes_x = center_x - button_width / 2.0;
        const themes_hovered = mouse_pos.x >= themes_x and mouse_pos.x <= themes_x + button_width and
            mouse_pos.y >= themes_y and mouse_pos.y <= themes_y + button_height;

        const themes_bg = if (themes_hovered) rl.Color{ .r = 100, .g = 100, .b = 100, .a = 255 } else rl.Color{ .r = 80, .g = 80, .b = 80, .a = 255 };
        const themes_border = if (themes_hovered) rl.GOLD else rl.WHITE;

        rl.DrawRectangle(@intFromFloat(themes_x), @intFromFloat(themes_y), @intFromFloat(button_width), @intFromFloat(button_height), themes_bg);
        rl.DrawRectangleLinesEx(rl.Rectangle{ .x = themes_x, .y = themes_y, .width = button_width, .height = button_height }, 2.0, themes_border);

        const current_theme = ui.ALL_THEMES[self.menu_selection.selected_theme_index].name;
        var themes_label_buf: [64]u8 = undefined;
        const themes_label = std.fmt.bufPrintZ(&themes_label_buf, "Theme: {s}", .{current_theme}) catch "Themes";

        const themes_text_size: i32 = 24;
        const themes_text_width = rl.MeasureText(themes_label, themes_text_size);
        const themes_text_x = @as(i32, @intFromFloat(themes_x + button_width / 2.0)) - @divTrunc(themes_text_width, 2);
        const themes_text_y = @as(i32, @intFromFloat(themes_y + button_height / 2.0)) - @divTrunc(themes_text_size, 2);
        rl.DrawText(themes_label, themes_text_x, themes_text_y, themes_text_size, rl.WHITE);
    }

    fn drawThemeMenu(self: *App) void {
        const center_x = @as(f32, @floatFromInt(constants.WINDOW_WIDTH)) / 2.0;
        const start_y: f32 = 250;
        const button_width: f32 = 300;
        const button_height: f32 = 60;
        const button_spacing: f32 = 20;

        // Draw title
        const title = "Select Theme";
        const title_size: i32 = 48;
        const title_width = rl.MeasureText(title, title_size);
        const title_x = @divTrunc(constants.WINDOW_WIDTH - title_width, 2);
        rl.DrawText(title, title_x + 2, 152, title_size, rl.BLACK);
        rl.DrawText(title, title_x, 150, title_size, rl.GOLD);

        const mouse_pos = InputHandler.getMousePosition();

        for (ui.ALL_THEMES, 0..) |theme, i| {
            const button_y = start_y + @as(f32, @floatFromInt(i)) * (button_height + button_spacing);
            const button_x = center_x - button_width / 2.0;

            const is_hovered = mouse_pos.x >= button_x and mouse_pos.x <= button_x + button_width and
                mouse_pos.y >= button_y and mouse_pos.y <= button_y + button_height;
            const is_selected = self.menu_selection.selected_theme_index == i;

            var bg_color = if (is_hovered) rl.Color{ .r = 80, .g = 80, .b = 100, .a = 255 } else rl.Color{ .r = 60, .g = 60, .b = 80, .a = 255 };
            if (is_selected) bg_color = rl.Color{ .r = 100, .g = 100, .b = 150, .a = 255 };
            const border_color = if (is_selected or is_hovered) rl.GOLD else rl.WHITE;

            rl.DrawRectangle(@intFromFloat(button_x), @intFromFloat(button_y), @intFromFloat(button_width), @intFromFloat(button_height), bg_color);
            rl.DrawRectangleLinesEx(rl.Rectangle{ .x = button_x, .y = button_y, .width = button_width, .height = button_height }, 2.0, border_color);

            const text_size: i32 = 24;
            const text_ptr: [*c]const u8 = @ptrCast(theme.name.ptr);
            const text_width = rl.MeasureText(text_ptr, text_size);
            const text_x = @as(i32, @intFromFloat(button_x + button_width / 2.0)) - @divTrunc(text_width, 2);
            const text_y = @as(i32, @intFromFloat(button_y + button_height / 2.0)) - @divTrunc(text_size, 2);
            rl.DrawText(text_ptr, text_x, text_y, text_size, rl.WHITE);

            // Draw theme preview colors
            const preview_size: f32 = 20;
            rl.DrawRectangle(@intFromFloat(button_x + 10), @intFromFloat(button_y + button_height / 2.0 - preview_size / 2.0), @intFromFloat(preview_size), @intFromFloat(preview_size), theme.light_square);
            rl.DrawRectangle(@intFromFloat(button_x + 10 + preview_size), @intFromFloat(button_y + button_height / 2.0 - preview_size / 2.0), @intFromFloat(preview_size), @intFromFloat(preview_size), theme.dark_square);
        }

        // Draw back button
        const back_y = start_y + @as(f32, @floatFromInt(ui.ALL_THEMES.len)) * (button_height + button_spacing) + 20;
        const back_width: f32 = 150;
        const back_x = center_x - back_width / 2.0;

        const back_hovered = mouse_pos.x >= back_x and mouse_pos.x <= back_x + back_width and
            mouse_pos.y >= back_y and mouse_pos.y <= back_y + button_height;

        const back_bg = if (back_hovered) rl.Color{ .r = 100, .g = 60, .b = 60, .a = 255 } else rl.Color{ .r = 80, .g = 50, .b = 50, .a = 255 };
        const back_border = if (back_hovered) rl.GOLD else rl.WHITE;

        rl.DrawRectangle(@intFromFloat(back_x), @intFromFloat(back_y), @intFromFloat(back_width), @intFromFloat(button_height), back_bg);
        rl.DrawRectangleLinesEx(rl.Rectangle{ .x = back_x, .y = back_y, .width = back_width, .height = button_height }, 2.0, back_border);

        const back_text = "< Back";
        const back_text_size: i32 = 24;
        const back_text_width = rl.MeasureText(back_text, back_text_size);
        const back_text_x = @as(i32, @intFromFloat(back_x + back_width / 2.0)) - @divTrunc(back_text_width, 2);
        const back_text_y = @as(i32, @intFromFloat(back_y + button_height / 2.0)) - @divTrunc(back_text_size, 2);
        rl.DrawText(back_text, back_text_x, back_text_y, back_text_size, rl.WHITE);
    }

    fn drawDifficultyMenu(self: *App) void {
        _ = self;
        const center_x = @as(f32, @floatFromInt(constants.WINDOW_WIDTH)) / 2.0;
        const start_y: f32 = 280;
        const button_width: f32 = 250;
        const button_height: f32 = 60;
        const button_spacing: f32 = 20;

        // Draw title
        const title = "Select Difficulty";
        const title_size: i32 = 48;
        const title_width = rl.MeasureText(title, title_size);
        const title_x = @divTrunc(constants.WINDOW_WIDTH - title_width, 2);
        rl.DrawText(title, title_x + 2, 152, title_size, rl.BLACK);
        rl.DrawText(title, title_x, 150, title_size, rl.GOLD);

        const difficulties = [_]struct { label: [*c]const u8, desc: [*c]const u8 }{
            .{ .label = "Easy", .desc = "Random moves" },
            .{ .label = "Medium", .desc = "Basic strategy" },
            .{ .label = "Hard", .desc = "Advanced tactics" },
        };

        const mouse_pos = InputHandler.getMousePosition();

        for (difficulties, 0..) |d, i| {
            const button_y = start_y + @as(f32, @floatFromInt(i)) * (button_height + button_spacing);
            const button_x = center_x - button_width / 2.0;

            const is_hovered = mouse_pos.x >= button_x and mouse_pos.x <= button_x + button_width and
                mouse_pos.y >= button_y and mouse_pos.y <= button_y + button_height;

            const bg_color = if (is_hovered) rl.Color{ .r = 80, .g = 100, .b = 80, .a = 255 } else rl.Color{ .r = 60, .g = 80, .b = 60, .a = 255 };
            const border_color = if (is_hovered) rl.GOLD else rl.WHITE;

            rl.DrawRectangle(@intFromFloat(button_x), @intFromFloat(button_y), @intFromFloat(button_width), @intFromFloat(button_height), bg_color);
            rl.DrawRectangleLinesEx(rl.Rectangle{ .x = button_x, .y = button_y, .width = button_width, .height = button_height }, 2.0, border_color);

            const text_size: i32 = 28;
            const text_width = rl.MeasureText(d.label, text_size);
            const text_x = @as(i32, @intFromFloat(button_x + button_width / 2.0)) - @divTrunc(text_width, 2);
            const text_y = @as(i32, @intFromFloat(button_y + 10));
            rl.DrawText(d.label, text_x, text_y, text_size, rl.WHITE);

            // Draw description
            const desc_size: i32 = 14;
            const desc_width = rl.MeasureText(d.desc, desc_size);
            const desc_x = @as(i32, @intFromFloat(button_x + button_width / 2.0)) - @divTrunc(desc_width, 2);
            const desc_y = text_y + text_size + 2;
            rl.DrawText(d.desc, desc_x, desc_y, desc_size, rl.LIGHTGRAY);
        }

        // Draw back button
        const back_y: f32 = start_y + @as(f32, @floatFromInt(difficulties.len)) * (button_height + button_spacing) + 20;
        const back_width: f32 = 150;
        const back_x = center_x - back_width / 2.0;

        const back_hovered = mouse_pos.x >= back_x and mouse_pos.x <= back_x + back_width and
            mouse_pos.y >= back_y and mouse_pos.y <= back_y + button_height;

        const back_bg = if (back_hovered) rl.Color{ .r = 100, .g = 60, .b = 60, .a = 255 } else rl.Color{ .r = 80, .g = 50, .b = 50, .a = 255 };
        const back_border = if (back_hovered) rl.GOLD else rl.WHITE;

        rl.DrawRectangle(@intFromFloat(back_x), @intFromFloat(back_y), @intFromFloat(back_width), @intFromFloat(button_height), back_bg);
        rl.DrawRectangleLinesEx(rl.Rectangle{ .x = back_x, .y = back_y, .width = back_width, .height = button_height }, 2.0, back_border);

        const back_text = "< Back";
        const back_text_size: i32 = 24;
        const back_text_width = rl.MeasureText(back_text, back_text_size);
        const back_text_x = @as(i32, @intFromFloat(back_x + back_width / 2.0)) - @divTrunc(back_text_width, 2);
        const back_text_y = @as(i32, @intFromFloat(back_y + button_height / 2.0)) - @divTrunc(back_text_size, 2);
        rl.DrawText(back_text, back_text_x, back_text_y, back_text_size, rl.WHITE);

        // Draw hint
        const hint = "Press ESC or Backspace to go back";
        const hint_size: i32 = 16;
        const hint_width = rl.MeasureText(hint, hint_size);
        const hint_x = @divTrunc(constants.WINDOW_WIDTH - hint_width, 2);
        rl.DrawText(hint, hint_x, constants.WINDOW_HEIGHT - 50, hint_size, rl.GRAY);
    }

    fn drawPromotionUI(self: *App, promo: PromotionState) void {
        const renderer = &(self.renderer orelse return);
        // Calculate position (center of board)
        const board_center_x = constants.BOARD_OFFSET_X + constants.SQUARE_SIZE * 4;
        const board_center_y = constants.BOARD_OFFSET_Y + constants.SQUARE_SIZE * 4;

        const box_width = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 4.5;
        const box_height = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 1.5;
        const piece_size = @as(f32, @floatFromInt(constants.SQUARE_SIZE)) * 0.8;
        const spacing = box_width / 4.0;

        // Fixed: Use float division consistently
        const box_x = @as(f32, @floatFromInt(board_center_x)) - box_width / 2.0;
        const box_y = @as(f32, @floatFromInt(board_center_y)) - box_height / 2.0;

        // Draw semi-transparent overlay
        rl.DrawRectangle(0, 0, constants.WINDOW_WIDTH, constants.WINDOW_HEIGHT, rl.Color{ .r = 0, .g = 0, .b = 0, .a = 180 });

        // Draw promotion box
        rl.DrawRectangle(@intFromFloat(box_x), @intFromFloat(box_y), @intFromFloat(box_width), @intFromFloat(box_height), rl.Color{ .r = 60, .g = 60, .b = 60, .a = 255 });

        rl.DrawRectangleLines(@intFromFloat(box_x), @intFromFloat(box_y), @intFromFloat(box_width), @intFromFloat(box_height), rl.WHITE);

        // Draw piece options
        const pieces = [_]PieceType{ .Queen, .Rook, .Bishop, .Knight };
        const piece_y = box_y + (box_height - piece_size) / 2.0;
        const start_x = box_x + (spacing - piece_size) / 2.0;

        for (pieces, 0..) |piece_type, i| {
            const piece_x = start_x + @as(f32, @floatFromInt(i)) * spacing;

            // Highlight on hover
            const mouse_pos = InputHandler.getMousePosition();
            if (mouse_pos.x >= piece_x and mouse_pos.x <= piece_x + piece_size and
                mouse_pos.y >= piece_y and mouse_pos.y <= piece_y + piece_size)
            {
                rl.DrawRectangle(@intFromFloat(piece_x), @intFromFloat(piece_y), @intFromFloat(piece_size), @intFromFloat(piece_size), rl.Color{ .r = 100, .g = 100, .b = 100, .a = 255 });
            }

            // Draw piece
            const piece = Piece.init(promo.piece.getColor(), piece_type);
            renderer.drawPieceAt(piece, piece_x, piece_y, piece_size);
        }

        // Draw title text
        const title = "Choose Promotion:";
        const title_size: i32 = 24;
        const title_width = rl.MeasureText(title, title_size);
        const title_x = @as(i32, @intFromFloat(board_center_x)) - @divTrunc(title_width, 2);
        const title_y = @as(i32, @intFromFloat(box_y - 40));
        rl.DrawText(title, title_x, title_y, title_size, rl.WHITE);
    }

    pub fn run(self: *App) !void {
        if (builtin.os.tag == .emscripten) {
            const emsdk = @cImport(@cInclude("emscripten/emscripten.h"));

            const loop = struct {
                fn runLoop(arg: ?*anyopaque) callconv(.c) void {
                    const app: *App = @ptrCast(@alignCast(arg));
                    app.update() catch |err| {
                        std.debug.print("Error in update: {}\n", .{err});
                    };
                    app.render() catch |err| {
                        std.debug.print("Error in render: {}\n", .{err});
                    };
                }
            }.runLoop;

            emsdk.emscripten_set_main_loop_arg(loop, self, 0, true);
        } else {
            while (!rl.WindowShouldClose()) {
                try self.update();
                try self.render();
            }
        }
    }
};

pub fn main() !void {
    var wasm_buffer: [1024 * 1024]u8 = undefined;
    var fba = std.heap.FixedBufferAllocator.init(&wasm_buffer);
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};

    const allocator = switch (builtin.os.tag) {
        .emscripten => fba.allocator(),
        else => gpa.allocator(),
    };
    defer _ = if (builtin.os.tag != .emscripten) gpa.deinit();

    var app = try App.init(allocator);
    defer app.deinit();

    try app.run();
}
