const rl = @import("raylib.zig").rl;
const core = @import("core");
const Square = core.Square;
const constants = @import("constants.zig");

pub const InputHandler = struct {
    pub fn getMouseSquare() ?Square {
        const mouse_pos = rl.GetMousePosition();
        return mouseToSquare(mouse_pos);
    }

    pub fn isMousePressed() bool {
        return rl.IsMouseButtonPressed(rl.MOUSE_BUTTON_LEFT);
    }

    pub fn isMouseReleased() bool {
        return rl.IsMouseButtonReleased(rl.MOUSE_BUTTON_LEFT);
    }

    pub fn isResetKeyPressed() bool {
        return rl.IsKeyPressed(rl.KEY_R);
    }

    pub fn getMousePosition() rl.Vector2 {
        return rl.GetMousePosition();
    }

    fn mouseToSquare(mouse_pos: rl.Vector2) ?Square {
        const x = @as(i32, @intFromFloat(mouse_pos.x)) - constants.BOARD_OFFSET_X;
        const y = @as(i32, @intFromFloat(mouse_pos.y)) - constants.BOARD_OFFSET_Y;

        if (x < 0 or x >= constants.BOARD_SIZE or y < 0 or y >= constants.BOARD_SIZE) {
            return null;
        }

        const file: i8 = @intCast(@divTrunc(x, constants.SQUARE_SIZE));
        const rank: i8 = @intCast(7 - @divTrunc(y, constants.SQUARE_SIZE));

        return Square.fromCoords(rank, file);
    }
};
