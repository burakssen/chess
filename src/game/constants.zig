const rl = @import("raylib.zig").rl;

pub const WINDOW_WIDTH = 800;
pub const WINDOW_HEIGHT = 800;
pub const BOARD_SIZE = 780;
pub const BOARD_OFFSET_X = (WINDOW_WIDTH - BOARD_SIZE) / 2;
pub const BOARD_OFFSET_Y = (WINDOW_HEIGHT - BOARD_SIZE) / 2;
pub const SQUARE_SIZE = BOARD_SIZE / 8;

pub const LIGHT_SQUARE = rl.Color{ .r = 240, .g = 217, .b = 181, .a = 255 };
pub const DARK_SQUARE = rl.Color{ .r = 181, .g = 136, .b = 99, .a = 255 };
pub const HIGHLIGHT_COLOR = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 100 };
pub const LEGAL_MOVE_COLOR = rl.Color{ .r = 0, .g = 255, .b = 0, .a = 150 };
pub const SELECTED_COLOR = rl.Color{ .r = 124, .g = 252, .b = 0, .a = 120 };
