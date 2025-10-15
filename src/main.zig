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

const App = struct {
    game: ChessGame,
    renderer: Renderer,
    drag_state: ?DragState,
    selected_square: ?Square,
    legal_moves_buffer: [256]Move,
    legal_moves_count: usize,

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
        };
    }

    pub fn deinit(self: *App) void {
        self.game.deinit();
        self.renderer.deinit();
        rl.CloseWindow();
    }

    pub fn update(self: *App) !void {
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
                var move = Move.init(drag.from, to_square);

                const piece = drag.piece;
                if (piece.getType() == .Pawn) {
                    const to_rank = to_square.rank();
                    const piece_color = piece.getColor();

                    // White pawn reaching rank 8 or black pawn reaching rank 1
                    if ((piece_color == .White and to_rank == 7) or
                        (piece_color == .Black and to_rank == 0))
                    {
                        // This is a promotion move
                        // TODO: Show promotion UI to let user choose piece
                        // For now, default to queen promotion
                        move.promotion = .Queen;
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

        // Draw game over overlay
        if (self.game.status != .ongoing) {
            const winner = if (self.game.status == .checkmate)
                self.game.board.active_color.opposite()
            else
                null;
            self.renderer.drawGameOver(self.game.status, winner);
        }
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
