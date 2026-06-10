const std = @import("std");
const Card = @import("Card.zig");

const Deck = @This();

buf: [len]Card,
cards: std.ArrayList(Card),

const len = Card.Rank.len * Card.Suit.len;

pub fn pinnedInit(self: *Deck, rng: std.Random) void {
    self.cards = std.ArrayList(Card).initBuffer(&self.buf);
    for (std.enums.values(Card.Rank)) |rank| {
        for (std.enums.values(Card.Suit)) |suit| {
            self.cards.appendAssumeCapacity(.{ .rank = rank, .suit = suit });
        }
    }
    rng.shuffle(Card, self.cards.items);
}

pub fn deal(self: *Deck, n: usize) []Card {
    const start = self.cards.items.len - n;
    defer self.cards.items.len -= n;
    return self.cards.items[start..];
}
