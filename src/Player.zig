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
    return self.vtable.draft(self.ptr, draft_view);
}

pub fn play(self: Player, play_view: PlayView) !Play {
    return self.vtable.play(self.ptr, play_view);
}

pub fn peg(self: *Player, n: u8) void {
    self.score += n;
}
