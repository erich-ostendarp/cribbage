const std = @import("std");
const Card = @import("Card.zig");
const Deck = @import("Deck.zig");
const Player = @import("Player.zig");

const Game = @This();

stdout: *std.Io.Writer,
p_buf: [max_players]Player,
players: std.ArrayList(Player),

state: union(enum) {
    cut: Cut,
    deal: Deal,
    play: Play,
    show: Show,
},

pub const min_players = 2;
pub const max_players = 4;

pub fn pinnedInit(self: *Game, stdout: *std.Io.Writer, players: []Player) !void {
    if (min_players > players.len or players.len > max_players) return error.PlayerCount;

    self.stdout = stdout;
    self.players = .initBuffer(&self.p_buf);

    self.players.appendSliceAssumeCapacity(players);

    self.state = .{ .cut = .{ .players = self.players.items } };
}

pub fn run(self: *Game, rng: std.Random) !void {
    self.state = switch (self.state) {
        .cut => |*c| .{ .deal = c.cut(rng) },
        .deal => |*d| .{ .play = try d.deal(rng) },
        .play => |*p| .{ .show = p.play().? },
        .show => |*s| .{ .deal = s.show().? },
    };
}

const Cut = struct {
    players: []Player,

    pub fn cut(self: *Cut, rng: std.Random) Deal {
        const dealer = rng.uintLessThan(usize, self.players.len);
        return .{
            .players = self.players,
            .dealer = dealer,
        };
    }
};

const Deal = struct {
    players: []Player,
    dealer: usize,

    pub fn deal(self: *Deal, rng: std.Random) !Play {
        var deck: Deck = undefined;
        deck.pinnedInit(rng);

        const num_cards: u8 = switch (self.players.len) {
            2 => 6,
            3, 4 => 5,
            else => unreachable,
        };

        var crib_buf: [4]Card = undefined;
        var crib = std.ArrayList(Card).initBuffer(&crib_buf);

        for (self.players, 0..) |*player, i| {
            const draft = try player.draft(.{
                .cards = deck.deal(num_cards),
                .is_dealer = i == self.dealer,
            });
            crib.appendSliceAssumeCapacity(draft.crib);
        }

        if (crib.items.len == 3) {
            crib.appendAssumeCapacity(deck.deal(1)[0]);
        }

        const cut_card = deck.deal(1)[0];

        if (cut_card.rank == .jack) {
            self.players[(self.dealer + 1) % self.players.len].peg(2);
        }

        return .{
            .players = self.players,
            .dealer = self.dealer,
        };
    }
};

const Play = struct {
    players: []Player,
    dealer: usize,

    pub fn play(self: *Play) ?Show {
        return .{
            .players = self.players,
            .dealer = self.dealer,
        };
    }
};

const Show = struct {
    players: []Player,
    dealer: usize,

    pub fn show(self: *Show) ?Deal {
        return .{
            .players = self.players,
            .dealer = (self.dealer + 1) % self.players.len,
        };
    }
};
