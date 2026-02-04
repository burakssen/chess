const std = @import("std");
const core = @import("core");
const engine = @import("engine");

const Move = core.Move;
const Color = core.types.Color;
const Board = engine.Board;

/// Represents a player in the game - can be human or AI
pub const PlayerType = enum {
    human,
    computer,
};

pub const Player = struct {
    player_type: PlayerType,
    color: Color,

    pub fn init(player_type: PlayerType, color: Color) Player {
        return .{
            .player_type = player_type,
            .color = color,
        };
    }

    pub fn isHuman(self: Player) bool {
        return self.player_type == .human;
    }

    pub fn isComputer(self: Player) bool {
        return self.player_type == .computer;
    }
};
