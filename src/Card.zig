const std = @import("std");

const Card = @This();

rank: Rank,
suit: Suit,

pub const Rank = enum {
    ace,
    @"2",
    @"3",
    @"4",
    @"5",
    @"6",
    @"7",
    @"8",
    @"9",
    @"10",
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
