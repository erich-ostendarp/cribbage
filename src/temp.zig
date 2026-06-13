const std = @import("std");

const Match = struct {
    num_matches: u8,
    player_buf: [PlayerOpt.max_players]Player,
    players: []Player,

    const PlayerOpt = enum(u3) {
        two = 2,
        three,
        four,

        const len = std.enums.values(PlayerOpt).len;
        const min_players = std.meta.fields(PlayerOpt)[0].value;
        const max_players = std.meta.fields(PlayerOpt)[PlayerOpt.len - 1].value;
    };

    pub fn pinnedInit(self: *Match, num_matches: u8, players: [PlayerOpt.max_players]Player, player_opt: PlayerOpt) void {
        self.* = .{
            .num_matches = num_matches,
            .player_buf = players,
            .players = self.player_buf[0..@intFromEnum(player_opt)],
        };
    }
};

const Game = struct {
    phase: enum { deal, draft, cut, play, show, game_over } = .deal,
    players: []Player,

    const winning_score = 121;
    const win_points = 1;

    const hand_size = 4;

    fn running(self: Game) bool {
        return self.phase != .game_over;
    }

    fn peg(self: *Game, player: *Player, n: u8) void {
        player.score += n;

        if (player.score >= winning_score) {
            player.matches += win_points;
            for (self.players) |p| {
                if (player.* == p) continue;
            }
            self.phase = .game_over;
        }
    }
};

const Draft = struct {};
const DraftView = struct {};
const Play = struct {};
const PlayView = struct {};

const Player = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    score: u8 = 0,
    matches: u8 = 0,

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

const HumanPlayer = struct {
    reader: *std.Io.Reader,

    pub fn init(reader: *std.Io.Reader) HumanPlayer {
        return .{ .reader = reader };
    }

    pub fn draft(self: *HumanPlayer, draft_view: DraftView) !Draft {
        _ = self;
        _ = draft_view;
        return error.Unimplemented;
    }

    pub fn play(self: *HumanPlayer, play_view: PlayView) !Play {
        _ = self;
        _ = play_view;
        return error.Unimplemented;
    }

    pub fn player(self: *HumanPlayer) Player {
        return Player.init(self);
    }
};

const Card = struct {
    rank: Rank,
    suit: Suit,

    fn value(self: Card) u8 {
        return switch (self.rank) {
            .jack, .queen, .king => 10,
            inline else => |r| @intFromEnum(r) + 1,
        };
    }
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

    const rng = (std.Random.IoSource{ .io = init.io }).interface();

    var game = Game{ .players = &[_]Player{} };
    while (game.running()) {
        // switch (game.phase) {
        //     .deal => game.deal(rng),
        //     .draft => game.draft(),
        //     .cut => game.cut(),
        //     .play => game.play(),
        //     .show => game.show(),
        //     .game_over => unreachable,
        // }
        break;
    }

    var players: [Match.PlayerOpt.max_players]Player = undefined;

    var rands: [2]RandomPlayer = undefined;
    for (&rands, players[0..rands.len]) |*rand, *player| {
        rand.* = .init(rng);
        player.* = rand.player();
    }

    var human = HumanPlayer.init(stdin);
    players[rands.len] = human.player();

    var match: Match = undefined;
    match.pinnedInit(5, players, .three);
    std.debug.print("{any}\n", .{match.players[0]});
}
