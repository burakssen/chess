const std = @import("std");
const builtin = @import("builtin");
const rl = @import("ui").rl;

const engine = @import("engine");
const ChessGame = engine.ChessGame;
const ui = @import("ui");
const Renderer = ui.Renderer;
const DragState = ui.DragState;
const InputHandler = ui.InputHandler;
const constants = ui.constants;

const core = @import("core");
const Move = core.Move;
const Square = core.Square;
const Piece = core.Piece;
const PieceType = core.types.PieceType;

const PromotionState = struct {
    move: Move,
    piece: Piece,
};

const App = struct {
    game: ChessGame,
    renderer: Renderer,
    drag_state: ?DragState,
    selected_square: ?Square,
    legal_moves_buffer: [256]Move,
    legal_moves_count: usize,
    promotion_state: ?PromotionState,

    pub fn init(allocator: std.mem.Allocator) !App {
        rl.InitWindow(constants.WINDOW_WIDTH, constants.WINDOW_HEIGHT, "Chess");
        rl.SetTargetFPS(60);

        return .{
            .game = try ChessGame.init(allocator),
            .renderer = try Renderer.init(allocator),
            .drag_state = null,
            .selected_square = null,
            .legal_moves_buffer = undefined,
            .legal_moves_count = 0,
            .promotion_state = null,
        };
    }

    pub fn deinit(self: *App) void {
        self.game.deinit();
        self.renderer.deinit();
        rl.CloseWindow();
    }

    pub fn update(self: *App) !void {
        // Handle promotion selection
        if (self.promotion_state) |promo| {
            if (InputHandler.isMousePressed()) {
                if (self.getPromotionChoice()) |piece_type| {
                    var move = promo.move;
                    move.promotion = piece_type;
                    self.game.makeMove(move) catch |err| {
                        std.debug.print("Invalid promotion move: {}\n", .{err});
                    };
                    self.promotion_state = null;
                }
            }
            return;
        }

        // Handle reset
        if (InputHandler.isResetKeyPressed()) {
            try self.game.reset();
            self.drag_state = null;
            self.selected_square = null;
            self.legal_moves_count = 0;
            return;
        }

        // If game is over, click to reset
        if (self.game.status != .ongoing) {
            if (InputHandler.isMousePressed()) {
                try self.game.reset();
                self.drag_state = null;
                self.selected_square = null;
                self.legal_moves_count = 0;
            }
            return;
        }

        // Handle mouse press
        if (InputHandler.isMousePressed()) {
            if (InputHandler.getMouseSquare()) |square| {
                const piece = self.game.board.getPiece(square);

                if (!piece.isEmpty() and piece.getColor() == self.game.board.active_color) {
                    // Start dragging
                    self.drag_state = .{
                        .piece = piece,
                        .from = square,
                    };
                    self.selected_square = square;

                    // Get legal moves for this piece
                    const moves = self.game.getLegalMovesForPiece(square);
                    self.legal_moves_count = moves.len;
                    @memcpy(self.legal_moves_buffer[0..moves.len], moves);
                }
            }
        }

        // Handle mouse release
        if (InputHandler.isMouseReleased() and self.drag_state != null) {
            const drag = self.drag_state.?;

            if (InputHandler.getMouseSquare()) |to_square| {
                const move = Move.init(drag.from, to_square);

                const piece = drag.piece;
                if (piece.getType() == .Pawn) {
                    const to_rank = to_square.rank();
                    const piece_color = piece.getColor();

                    // White pawn reaching rank 8 or black pawn reaching rank 1
                    if ((piece_color == .White and to_rank == 7) or
                        (piece_color == .Black and to_rank == 0))
                    {
                        // Show promotion UI
                        self.promotion_state = .{
                            .move = move,
                            .piece = piece,
                        };
                        self.drag_state = null;
                        self.selected_square = null;
                        self.legal_moves_count = 0;
                        return;
                    }
                }

                self.game.makeMove(move) catch |err| {
                    std.debug.print("Invalid move: {}\n", .{err});
                };
            }

            self.drag_state = null;
            self.selected_square = null;
            self.legal_moves_count = 0;
        }
    }

    fn getPromotionChoice(self: *App) ?PieceType {
        const mouse_pos = InputHandler.getMousePosition();
        _ = self.promotion_state orelse return null;

        // Calculate promotion UI position (center of board)
        const board_center_x = constants.BOARD_OFFSET_X + constants.SQUARE_SIZE * 4;
        const board_center_y = constants.BOARD_OFFSET_Y + constants.SQUARE_SIZE * 4;

        const box_width = constants.SQUARE_SIZE * 4;
        const box_height = constants.SQUARE_SIZE * 1.5;
        const piece_size = constants.SQUARE_SIZE;
        const spacing = constants.SQUARE_SIZE;

        const box_x = board_center_x - box_width / 2.0;
        const box_y = board_center_y - box_height / 2.0;

        // Check if mouse is in the promotion box
        if (mouse_pos.x < box_x or mouse_pos.x > box_x + box_width or
            mouse_pos.y < box_y or mouse_pos.y > box_y + box_height)
        {
            return null;
        }

        // Calculate which piece was clicked
        const piece_y = box_y + (box_height - piece_size) / 2.0;
        const start_x = box_x + spacing / 2;

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
        self.renderer.beginFrame();
        defer self.renderer.endFrame();

        // Draw board
        self.renderer.drawBoard();

        // Highlight selected square
        if (self.selected_square) |square| {
            self.renderer.drawSelectedSquare(square);
        }

        // Draw legal move indicators
        if (self.legal_moves_count > 0) {
            self.renderer.drawLegalMoves(&self.game.board, self.legal_moves_buffer[0..self.legal_moves_count]);
        }

        // Draw pieces
        self.renderer.drawPieces(&self.game.board, self.drag_state);

        // Draw dragged piece
        if (self.drag_state) |drag| {
            const mouse_pos = InputHandler.getMousePosition();
            self.renderer.drawDraggedPiece(drag.piece, mouse_pos);
        }

        // Draw promotion UI
        if (self.promotion_state) |promo| {
            self.drawPromotionUI(promo);
        }

        // Draw game over overlay
        if (self.game.status != .ongoing) {
            const winner = if (self.game.status == .checkmate)
                self.game.board.active_color.opposite()
            else
                null;
            self.renderer.drawGameOver(self.game.status, winner);
        }
    }

    fn drawPromotionUI(self: *App, promo: PromotionState) void {
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
            self.renderer.drawPieceAt(piece, piece_x, piece_y, piece_size);
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
