const std = @import("std");
const rl = @cImport({
    @cInclude("raylib.h");
});
const Chess = @import("chess");
const types = Chess.types;
const Piece = Chess.Piece;
const Square = types.Square;
const Move = types.Move;
const Color = types.Color;

pub const WINDOW_WIDTH = 800;
pub const WINDOW_HEIGHT = 800;
pub const BOARD_SIZE = 640;
pub const BOARD_OFFSET_X = (WINDOW_WIDTH - BOARD_SIZE) / 2;
pub const BOARD_OFFSET_Y = (WINDOW_HEIGHT - BOARD_SIZE) / 2;
pub const SQUARE_SIZE = BOARD_SIZE / 8;

const LIGHT_SQUARE = rl.Color{ .r = 240, .g = 217, .b = 181, .a = 255 };
const DARK_SQUARE = rl.Color{ .r = 181, .g = 136, .b = 99, .a = 255 };
const HIGHLIGHT_COLOR = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 100 };
const LEGAL_MOVE_COLOR = rl.Color{ .r = 0, .g = 255, .b = 0, .a = 150 };
const SELECTED_COLOR = rl.Color{ .r = 124, .g = 252, .b = 0, .a = 120 };

const PieceTextures = struct {
    textures: [64]?rl.Texture2D,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !PieceTextures {
        var self = PieceTextures{
            .textures = [_]?rl.Texture2D{null} ** 64,
            .allocator = allocator,
        };

        // Load all possible piece textures
        const white_pawn = (@intFromEnum(Color.White) | @intFromEnum(types.PieceType.Pawn));
        const white_knight = (@intFromEnum(Color.White) | @intFromEnum(types.PieceType.Knight));
        const white_bishop = (@intFromEnum(Color.White) | @intFromEnum(types.PieceType.Bishop));
        const white_rook = (@intFromEnum(Color.White) | @intFromEnum(types.PieceType.Rook));
        const white_queen = (@intFromEnum(Color.White) | @intFromEnum(types.PieceType.Queen));
        const white_king = (@intFromEnum(Color.White) | @intFromEnum(types.PieceType.King));

        const black_pawn = (@intFromEnum(Color.Black) | @intFromEnum(types.PieceType.Pawn));
        const black_knight = (@intFromEnum(Color.Black) | @intFromEnum(types.PieceType.Knight));
        const black_bishop = (@intFromEnum(Color.Black) | @intFromEnum(types.PieceType.Bishop));
        const black_rook = (@intFromEnum(Color.Black) | @intFromEnum(types.PieceType.Rook));
        const black_queen = (@intFromEnum(Color.Black) | @intFromEnum(types.PieceType.Queen));
        const black_king = (@intFromEnum(Color.Black) | @intFromEnum(types.PieceType.King));

        const pieces = [_]u8{
            white_pawn, white_knight, white_bishop, white_rook, white_queen, white_king,
            black_pawn, black_knight, black_bishop, black_rook, black_queen, black_king,
        };

        for (pieces) |piece_value| {
            const path = try std.fmt.allocPrintSentinel(allocator, "assets/{b:0>4}.png", .{piece_value}, 0);
            defer allocator.free(path);

            const texture = rl.LoadTexture(path.ptr);
            if (texture.id > 0) {
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
};

const GameStatus = enum {
    ongoing,
    checkmate,
    stalemate,
};

const ChessState = struct {
    chess: Chess,
    textures: PieceTextures,
    selected_square: ?Square,
    dragging_piece: ?struct {
        piece: Piece,
        from: Square,
        mouse_offset: rl.Vector2,
    },
    legal_moves: std.array_list.Managed(Move),
    allocator: std.mem.Allocator,
    game_status: GameStatus,

    pub fn init(allocator: std.mem.Allocator) !ChessState {
        return ChessState{
            .chess = Chess.init(allocator),
            .textures = try PieceTextures.init(allocator),
            .selected_square = null,
            .dragging_piece = null,
            .legal_moves = std.array_list.Managed(Move).init(allocator),
            .allocator = allocator,
            .game_status = .ongoing,
        };
    }

    pub fn deinit(self: *ChessState) void {
        self.chess.deinit();
        self.textures.deinit();
        self.legal_moves.deinit();
    }

    pub fn reset(self: *ChessState) !void {
        self.chess.deinit();
        self.chess = Chess.init(self.allocator);
        self.selected_square = null;
        self.dragging_piece = null;
        self.legal_moves.clearRetainingCapacity();
        self.game_status = .ongoing;
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Initialize window BEFORE loading textures
    rl.InitWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "Chess Game");
    defer rl.CloseWindow();

    rl.SetTargetFPS(60);

    // Now load textures after window is initialized
    var state = try ChessState.init(allocator);
    defer state.deinit();

    while (!rl.WindowShouldClose()) {
        try handleInput(&state, allocator);
        try render(&state);
    }
}

fn handleInput(state: *ChessState, allocator: std.mem.Allocator) !void {
    // Check for reset key
    if (rl.IsKeyPressed(rl.KEY_R)) {
        try state.reset();
        return;
    }

    const mouse_pos = rl.GetMousePosition();
    const mouse_pressed = rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
    const mouse_released = rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);

    // Convert mouse position to board square
    const maybe_square = mouseToSquare(mouse_pos);

    // If game is over, only allow reset
    if (state.game_status != .ongoing) {
        if (mouse_pressed) {
            try state.reset();
        }
        return;
    }

    if (mouse_pressed and maybe_square != null) {
        const square = maybe_square.?;
        const piece = state.chess.board.getPiece(square);

        if (!piece.isEmpty() and piece.getColor() == state.chess.board.active_color) {
            // Start dragging
            const square_pos = squareToScreen(square);
            state.dragging_piece = .{
                .piece = piece,
                .from = square,
                .mouse_offset = rl.Vector2{
                    .x = mouse_pos.x - square_pos.x,
                    .y = mouse_pos.y - square_pos.y,
                },
            };
            state.selected_square = square;

            // Generate legal moves for this square
            state.legal_moves.clearRetainingCapacity();

            var all_moves = try state.chess.board.getAllLegalMoves(allocator);
            defer all_moves.deinit();

            for (all_moves.items) |move| {
                if (move.from == square) {
                    try state.legal_moves.append(move);
                }
            }
        }
    }

    if (mouse_released and state.dragging_piece != null) {
        const drag = state.dragging_piece.?;

        if (maybe_square) |to_square| {
            // Attempt to make the move
            const move = Move.init(drag.from, to_square);
            state.chess.makeMove(move) catch |err| {
                std.debug.print("Invalid move: {}\n", .{err});
            };

            // Check game status AFTER the move
            // updateCheckStatus() was called in makeMove(), so is_checkmate is already set
            if (state.chess.board.is_checkmate) {
                state.game_status = .checkmate;
            } else {
                // Check if there are any legal moves left
                var all_moves = try state.chess.board.getAllLegalMoves(allocator);
                defer all_moves.deinit();

                if (all_moves.items.len == 0) {
                    state.game_status = .stalemate;
                }
            }
        }

        state.dragging_piece = null;
        state.selected_square = null;
        state.legal_moves.clearRetainingCapacity();
    }
}

fn render(state: *ChessState) !void {
    rl.BeginDrawing();
    defer rl.EndDrawing();

    rl.ClearBackground(rl.Color{ .r = 40, .g = 40, .b = 40, .a = 255 });

    // Draw board
    drawBoard();

    // Highlight selected square
    if (state.selected_square) |square| {
        const pos = squareToScreen(square);
        rl.DrawRectangle(
            @intFromFloat(pos.x),
            @intFromFloat(pos.y),
            SQUARE_SIZE,
            SQUARE_SIZE,
            SELECTED_COLOR,
        );
    }

    // Draw legal move indicators
    for (state.legal_moves.items) |move| {
        const pos = squareToScreen(move.to);
        const target_piece = state.chess.board.getPiece(move.to);

        if (target_piece.isEmpty()) {
            // Draw circle for empty square moves
            const center_x = @as(i32, @intFromFloat(pos.x)) + SQUARE_SIZE / 2;
            const center_y = @as(i32, @intFromFloat(pos.y)) + SQUARE_SIZE / 2;
            rl.DrawCircle(center_x, center_y, SQUARE_SIZE / 6, rl.Fade(HIGHLIGHT_COLOR, 0.5));
        } else {
            // Draw ring for capture moves
            rl.DrawRectangleLinesEx(
                rl.Rectangle{
                    .x = pos.x + 4,
                    .y = pos.y + 4,
                    .width = SQUARE_SIZE - 8,
                    .height = SQUARE_SIZE - 8,
                },
                4.0,
                HIGHLIGHT_COLOR,
            );
        }
    }

    // Draw pieces
    for (0..64) |i| {
        const square: Square = @enumFromInt(@as(u6, @intCast(i)));
        const piece = state.chess.board.getPiece(square);

        // Skip if this piece is being dragged
        if (state.dragging_piece != null and state.dragging_piece.?.from == square) {
            continue;
        }

        if (!piece.isEmpty()) {
            const pos = squareToScreen(square);
            drawPiece(&state.textures, piece, pos.x, pos.y);
        }
    }

    // Draw dragged piece
    if (state.dragging_piece) |drag| {
        const mouse_pos = rl.GetMousePosition();
        const piece_x = mouse_pos.x - drag.mouse_offset.x;
        const piece_y = mouse_pos.y - drag.mouse_offset.y;
        drawPiece(&state.textures, drag.piece, piece_x, piece_y);
    }

    // Draw game status overlay
    if (state.game_status != .ongoing) {
        drawGameOverOverlay(state);
    }
}

fn drawGameOverOverlay(state: *ChessState) void {
    // Semi-transparent overlay
    rl.DrawRectangle(
        0,
        0,
        WINDOW_WIDTH,
        WINDOW_HEIGHT,
        rl.Color{ .r = 0, .g = 0, .b = 0, .a = 180 },
    );

    // Determine message
    const message: [*c]const u8 = switch (state.game_status) {
        .checkmate => if (state.chess.board.active_color == Color.White)
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
    const text_x = @divTrunc(WINDOW_WIDTH - text_width, 2);
    const text_y = @divTrunc(WINDOW_HEIGHT, 2) - 50;

    // Draw text shadow
    rl.DrawText(message, text_x + 3, text_y + 3, font_size, rl.BLACK);
    // Draw main text
    rl.DrawText(message, text_x, text_y, font_size, rl.GOLD);

    // Draw subtitle
    const subtitle_x = @divTrunc(WINDOW_WIDTH - subtitle_width, 2);
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
            const color = if (is_light) LIGHT_SQUARE else DARK_SQUARE;

            const x = BOARD_OFFSET_X + @as(i32, @intCast(file)) * SQUARE_SIZE;
            const y = BOARD_OFFSET_Y + @as(i32, @intCast(7 - rank)) * SQUARE_SIZE;

            rl.DrawRectangle(x, y, SQUARE_SIZE, SQUARE_SIZE, color);
        }
    }
}

fn drawPiece(textures: *const PieceTextures, piece: Piece, x: f32, y: f32) void {
    if (textures.get(piece)) |texture| {
        const scale = @as(f32, @floatFromInt(SQUARE_SIZE)) / @as(f32, @floatFromInt(texture.width));
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
            @intFromFloat(x + SQUARE_SIZE / 2),
            @intFromFloat(y + SQUARE_SIZE / 2),
            40,
            rl.RED,
        );
    }
}

fn squareToScreen(square: Square) rl.Vector2 {
    const file = square.file();
    const rank = square.rank();

    return rl.Vector2{
        .x = @floatFromInt(BOARD_OFFSET_X + @as(i32, file) * SQUARE_SIZE),
        .y = @floatFromInt(BOARD_OFFSET_Y + @as(i32, 7 - rank) * SQUARE_SIZE),
    };
}

fn mouseToSquare(mouse_pos: rl.Vector2) ?Square {
    const x = @as(i32, @intFromFloat(mouse_pos.x)) - BOARD_OFFSET_X;
    const y = @as(i32, @intFromFloat(mouse_pos.y)) - BOARD_OFFSET_Y;

    if (x < 0 or x >= BOARD_SIZE or y < 0 or y >= BOARD_SIZE) {
        return null;
    }

    const file: i8 = @intCast(@divTrunc(x, SQUARE_SIZE));
    const rank: i8 = @intCast(7 - @divTrunc(y, SQUARE_SIZE));

    return Square.fromCoords(rank, file);
}
