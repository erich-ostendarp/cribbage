const std = @import("std");

const Game = struct {
    phase: Phase = .deal,
    players: []Player,

    const winning_score = 121;

    fn running(self: *const Game) bool {
        return self.phase != .game_over;
    }

    fn peg(self: *Game, player: *Player, n: u8) void {
        player.peg(n);

        if (player.score() >= winning_score) {
            self.phase = .game_over;
        }
    }
};

const Phase = union(enum) {
    deal,
    draft,
    cut,
    play,
    show,
    game_over,
};

const Draft = struct {};
const DraftView = struct {};
const Play = struct {};
const PlayView = struct {};

const Player = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    score: u8 = 0,

    const VTable = struct {
        draft: *const fn (*anyopaque, DraftView) anyerror!Draft,
        play: *const fn (*anyopaque, PlayView) anyerror!Play,
    };

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

    fn draft(self: Player, draft_view: DraftView) !Draft {
        return self.vtable.draft(self.ptr, draft_view);
    }

    fn play(self: Player, play_view: PlayView) !Play {
        return self.vtable.play(self.ptr, play_view);
    }
};

const RandomPlayer = struct {
    rng: std.Random,

    pub fn init(rng: std.Random) RandomPlayer {
        return .{ .rng = rng };
    }

    pub fn draft(self: *RandomPlayer, draft_view: DraftView) !Draft {
        _ = self;
        _ = draft_view;
        return error.Unimplemented;
    }

    pub fn play(self: *RandomPlayer, play_view: PlayView) !Play {
        _ = self;
        _ = play_view;
        return error.Unimplemented;
    }

    pub fn player(self: *RandomPlayer) Player {
        return Player.init(self);
    }
};

const Card = struct {
    rank: Rank,
    suit: Suit,
};

const Rank = enum {
    ace,
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

    const len = std.enums.values(Rank).len;
};

const Suit = enum {
    club,
    diamond,
    heart,
    spade,

    const len = std.enums.values(Rank).len;
};

pub fn main(init: std.process.Init) !void {
    var stdin_buf: [1024]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;
    _ = stdin;

    const rng = (std.Random.IoSource{ .io = init.io }).interface();
    _ = rng;

    var game = Game{ .players = &[_]Player{} };
    while (game.running()) {
        switch (game.phase) {
            .deal => |p| {
                _ = p;
            },
            .draft => |p| {
                _ = p;
            },
            .cut => |p| {
                _ = p;
            },
            .play => |p| {
                _ = p;
            },
            .show => |p| {
                _ = p;
            },
            .game_over => unreachable,
        }
        break;
    }
}
