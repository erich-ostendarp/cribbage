const std = @import("std");
const Card = @import("Card.zig");
const Player = @import("Player.zig");

const RandomPlayer = @This();

rng: std.Random,

pub fn init(rng: std.Random) RandomPlayer {
    return .{ .rng = rng };
}

pub fn draft(self: *RandomPlayer, draft_view: Player.DraftView) !Player.Draft {
    _ = self;
    _ = draft_view;
    return error.Unimplemented;
}

pub fn play(self: *RandomPlayer, play_view: Player.PlayView) !Player.Play {
    _ = self;
    _ = play_view;
    return error.Unimplemented;
}

pub fn player(self: *RandomPlayer) Player {
    return Player.init(self);
}
