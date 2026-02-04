const rl = @import("raylib.zig").rl;

pub const WINDOW_WIDTH = 1200;
pub const WINDOW_HEIGHT = 800;
pub const BOARD_SIZE = 760;
pub const BOARD_OFFSET_X = 20;
pub const BOARD_OFFSET_Y = (WINDOW_HEIGHT - BOARD_SIZE) / 2;
pub const SQUARE_SIZE = BOARD_SIZE / 8;

pub const PANEL_WIDTH = 380;
pub const PANEL_X = BOARD_OFFSET_X + BOARD_SIZE + 20;
pub const PANEL_Y = BOARD_OFFSET_Y;
pub const PANEL_HEIGHT = BOARD_SIZE;

pub const LIGHT_SQUARE = rl.Color{ .r = 240, .g = 217, .b = 181, .a = 255 };
pub const DARK_SQUARE = rl.Color{ .r = 181, .g = 136, .b = 99, .a = 255 };
pub const HIGHLIGHT_COLOR = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 100 };
pub const SELECTED_COLOR = rl.Color{ .r = 124, .g = 252, .b = 0, .a = 120 };
