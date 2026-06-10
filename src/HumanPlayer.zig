const std = @import("std");
const Card = @import("Card.zig");
const Player = @import("Player.zig");

const HumanPlayer = @This();

reader: *std.Io.Reader,

pub fn init(reader: *std.Io.Reader) HumanPlayer {
    return .{ .reader = reader };
}

pub fn draft(self: *HumanPlayer, draft_view: Player.DraftView) !Player.Draft {
    _ = self;
    _ = draft_view;
    return error.Unimplemented;
}

pub fn play(self: *HumanPlayer, play_view: Player.PlayView) !Player.Play {
    _ = self;
    _ = play_view;
    return error.Unimplemented;
}

pub fn player(self: *HumanPlayer) Player {
    return Player.init(self);
}
