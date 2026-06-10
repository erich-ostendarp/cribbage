const std = @import("std");

const Player = @import("Player.zig");
const HumanPlayer = @import("HumanPlayer.zig");
const RandomPlayer = @import("RandomPlayer.zig");
const Game = @import("Game.zig");

pub fn main(init: std.process.Init) !void {
    const rng = (std.Random.IoSource{ .io = init.io }).interface();

    var stdin_buf: [64]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("How many players: ", .{});
    try stdout.flush();

    const input = try stdin.takeDelimiter('\n');
    const num_players = try std.fmt.parseInt(u3, input.?, 10);

    var human = HumanPlayer.init(stdin);
    var ais: [Game.max_players - 1]RandomPlayer = undefined;
    for (ais[0 .. num_players - 1]) |*ai| {
        ai.* = .init(rng);
    }

    var players: [Game.max_players]Player = undefined;
    players[0] = human.player();
    for (players[1..num_players], ais[0 .. num_players - 1]) |*player, *ai| {
        player.* = ai.player();
    }

    var game: Game = undefined;
    try game.pinnedInit(stdout, players[0..num_players]);
    try game.run(rng);
}
