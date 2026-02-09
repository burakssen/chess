const rl = @import("raylib.zig").rl;

pub const Theme = struct {
    name: []const u8,
    light_square: rl.Color,
    dark_square: rl.Color,
    highlight_color: rl.Color,
    selected_color: rl.Color,
    panel_bg: rl.Color,
    panel_border: rl.Color,
    text_primary: rl.Color,
    text_secondary: rl.Color,
    accent: rl.Color,
    asset_path: []const u8,
};

pub const CLASSIC = Theme{
    .name = "Classic",
    .light_square = rl.Color{ .r = 240, .g = 217, .b = 181, .a = 255 },
    .dark_square = rl.Color{ .r = 181, .g = 136, .b = 99, .a = 255 },
    .highlight_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 100 },
    .selected_color = rl.Color{ .r = 124, .g = 252, .b = 0, .a = 120 },
    .panel_bg = rl.Color{ .r = 45, .g = 45, .b = 45, .a = 255 },
    .panel_border = rl.Color{ .r = 60, .g = 60, .b = 60, .a = 255 },
    .text_primary = rl.WHITE,
    .text_secondary = rl.LIGHTGRAY,
    .accent = rl.GOLD,
    .asset_path = "assets/default",
};

pub const BUBBLEGUM = Theme{
    .name = "Bubblegum",
    .light_square = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
    .dark_square = rl.Color{ .r = 252, .g = 216, .b = 220, .a = 255 },
    .highlight_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 100 },
    .selected_color = rl.Color{ .r = 255, .g = 255, .b = 0, .a = 120 },
    .panel_bg = rl.Color{ .r = 255, .g = 240, .b = 245, .a = 255 },
    .panel_border = rl.Color{ .r = 255, .g = 182, .b = 193, .a = 255 },
    .text_primary = rl.Color{ .r = 139, .g = 69, .b = 85, .a = 255 },
    .text_secondary = rl.Color{ .r = 180, .g = 100, .b = 120, .a = 255 },
    .accent = rl.Color{ .r = 255, .g = 20, .b = 147, .a = 255 },
    .asset_path = "assets/bubblegum",
};

pub const NEON = Theme{
    .name = "Neon",
    .light_square = rl.Color{ .r = 222, .g = 227, .b = 230, .a = 255 },
    .dark_square = rl.Color{ .r = 140, .g = 162, .b = 173, .a = 255 },
    .highlight_color = rl.Color{ .r = 0, .g = 0, .b = 0, .a = 100 },
    .selected_color = rl.Color{ .r = 100, .g = 149, .b = 237, .a = 120 },
    .panel_bg = rl.Color{ .r = 20, .g = 25, .b = 35, .a = 255 },
    .panel_border = rl.Color{ .r = 40, .g = 55, .b = 80, .a = 255 },
    .text_primary = rl.Color{ .r = 180, .g = 220, .b = 255, .a = 255 },
    .text_secondary = rl.Color{ .r = 120, .g = 150, .b = 180, .a = 255 },
    .accent = rl.Color{ .r = 0, .g = 255, .b = 255, .a = 255 },
    .asset_path = "assets/neon",
};

pub const ALL_THEMES = [_]Theme{ CLASSIC, BUBBLEGUM, NEON };
