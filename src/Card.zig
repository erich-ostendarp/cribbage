const std = @import("std");

const Card = @This();

rank: Rank,
suit: Suit,

pub fn val(self: Card) u4 {
    return switch (self.rank) {
        .jack, .queen, .king => 10,
        else => |v| v,
    };
}

pub fn index(self: Card) usize {
    return @intFromEnum(self.suit) * Rank.len + @intFromEnum(self.rank);
}

pub const Rank = enum(u4) {
    ace = 1,
    two,
    three,
    four,
    five,
    six,
    seven,
    eight,
    nine,
    ten,
    jack,
    queen,
    king,

    pub const len = std.meta.fields(@This()).len;
};

pub const Suit = enum {
    club,
    diamond,
    heart,
    spade,

    pub const len = std.meta.fields(@This()).len;
};
