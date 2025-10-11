const jok = @import("jok");

pub const WINDOW_WIDTH = 800;
pub const WINDOW_HEIGHT = 800;
pub const BOARD_SIZE = 640;
pub const BOARD_OFFSET_X = (WINDOW_WIDTH - BOARD_SIZE) / 2;
pub const BOARD_OFFSET_Y = (WINDOW_HEIGHT - BOARD_SIZE) / 2;
pub const SQUARE_SIZE = BOARD_SIZE / 8;

const LIGHT_SQUARE = jok.Color.rgba(240, 217, 181, 255);
const DARK_SQUARE = jok.Color.rgba(181, 136, 99, 255);
const HIGHLIGHT_COLOR = jok.Color.rgba(0, 0, 0, 100);
const LEGAL_MOVE_COLOR = jok.Color.rgba(0, 255, 0, 150);
const SELECTED_COLOR = jok.Color.rgba(124, 252, 0, 120);
