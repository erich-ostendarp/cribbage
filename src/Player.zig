const std = @import("std");
const Card = @import("Card.zig");
const Player = @This();

ptr: *anyopaque,
vtable: *const VTable,
score: u8 = 0,

pub const VTable = struct {
    draft: *const fn (*anyopaque, DraftView) anyerror!Draft,
    play: *const fn (*anyopaque, PlayView) anyerror!Play,
};

pub const DraftView = struct {
    cards: []const Card,
    is_dealer: bool,
};

pub const PlayView = struct {
    hand: []const Card,
    cut_card: Card,
    pile: []const Card,
};

pub const Draft = struct {
    hand: []const Card,
    crib: []const Card,
};

pub const Play = struct { card: Card };

pub fn init(ptr: anytype) Player {
    const T = @TypeOf(ptr);
    const ptr_info = @typeInfo(T);

    const gen = struct {
        pub fn draft(pointer: *anyopaque, draft_view: DraftView) !Draft {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.pointer.child.draft(self, draft_view);
        }

        pub fn play(pointer: *anyopaque, play_view: PlayView) !Play {
            const self: T = @ptrCast(@alignCast(pointer));
            return ptr_info.pointer.child.play(self, play_view);
        }
    };

    return .{
        .ptr = ptr,
        .vtable = &.{
            .draft = gen.draft,
            .play = gen.play,
        },
    };
}

pub fn draft(self: Player, draft_view: DraftView) !Draft {
    const ret = try self.vtable.draft(self.ptr, draft_view);
    if (!isDraftLegal(draft_view.cards, ret.hand, ret.crib)) return error.IllegalDraft;
    return ret;
}

fn isDraftLegal(cards: []const Card, hand: []const Card, crib: []const Card) bool {
    if (hand.len != 4) return false;
    if (crib.len != cards.len - 4) return false;

    var seen = std.StaticBitSet(Card.Suit.len * Card.Rank.len).empty;
    for (hand) |c| seen.set(c.index());
    for (crib) |c| seen.set(c.index());
    for (cards) |c| if (!seen.isSet(c.index())) return false;

    return true;
}

pub fn play(self: Player, play_view: PlayView) !Play {
    const ret = try self.vtable.play(self.ptr, play_view);
    if (!isPlayLegal(play_view.hand, ret.card)) return error.IllegalPlay;
    return ret;
}

fn isPlayLegal(hand: []const Card, card: Card) bool {
    for (hand) |c| if (c.index() == card.index()) return true;
    return false;
}

pub fn peg(self: *Player, n: u8) void {
    self.score += n;
}
