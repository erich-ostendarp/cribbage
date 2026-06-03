const std = @import("std");

const Rank = enum {
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

    const len = std.meta.fields(@This()).len;
};

const Suit = enum {
    club,
    diamond,
    heart,
    spade,

    const len = std.meta.fields(@This()).len;
};

const Card = struct {
    rank: Rank,
    suit: Suit,
};

const Move = struct {};

const PlayerData = struct {
    state: union(enum) {
        init,
        deal: []Card,
        draft: struct { hand: [4]Card, crib: [2]Card },
        play: []Card,
    },
    score: u8 = 0,
};

const Player = struct {
    data: PlayerData,
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getMove: *const fn (*anyopaque) anyerror!Move,
        draft: *const fn (*anyopaque) anyerror!void,
    };

    fn init(ptr: anytype) Player {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn data(pointer: *anyopaque) PlayerData {
                const self: T = @ptrCast(@alignCast(pointer));
                return self.data;
            }

            pub fn getMove(pointer: *anyopaque) anyerror!Move {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.getMove(self);
            }

            pub fn draft(pointer: *anyopaque) anyerror!void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.draft(self);
            }
        };

        return .{
            .data = gen.data(ptr),
            .ptr = ptr,
            .vtable = &.{
                .getMove = gen.getMove,
                .draft = gen.draft,
            },
        };
    }

    pub fn getMove(self: Player) !Move {
        return self.vtable.getMove(self.ptr);
    }

    pub fn draft(self: Player) !void {
        self.vtable.draft(self.ptr) catch |e| return e;
    }

    pub fn getLegalMoves(self: Player) []const Move {
        _ = self;
        return &.{ .{}, .{}, .{} };
    }
};

const RandomPlayer = struct {
    data: PlayerData,

    fn getMove(self: *RandomPlayer) !Move {
        _ = self;
        return .{};
    }

    fn draft(self: *RandomPlayer) !void {
        _ = self;
    }

    fn player(self: *RandomPlayer) Player {
        return Player.init(self);
    }
};

const HumanPlayer = struct {
    data: PlayerData,
    reader: *std.Io.Reader,

    pub fn init(reader: *std.Io.Reader) HumanPlayer {
        return .{
            .data = .{ .state = .init },
            .reader = reader,
        };
    }

    fn getMove(self: *HumanPlayer) !Move {
        const line = try self.reader.takeDelimiter('\n');
        std.debug.print("{s}\n", .{line.?});
        return .{};
    }

    fn draft(self: *HumanPlayer) !void {
        _ = self;
    }

    fn player(self: *HumanPlayer) Player {
        return Player.init(self);
    }
};

const Deck = struct {
    buf: [len]Card,
    cards: std.ArrayList(Card),

    const len = Rank.len * Suit.len;

    pub fn pinnedInit(self: *Deck, rng: std.Random) void {
        self.cards = std.ArrayList(Card).initBuffer(&self.buf);
        for (std.enums.values(Rank)) |rank| {
            for (std.enums.values(Suit)) |suit| {
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
};

const GameState = union(enum) {
    cut,
    deal,
    play: struct {
        active_player: usize,
        cut: Card = undefined,
        revealed: []Card = &[_]Card{},
        pile: []Card = &[_]Card{},
    },
    show: struct { active_player: usize },
};

const Game = struct {
    stdout: *std.Io.Writer,
    p_buf: [max_players]Player,
    players: std.ArrayList(Player),
    state: GameState,
    deck: Deck,
    dealer: usize,

    const min_players = 2;
    const max_players = 4;

    pub fn pinnedInit(self: *Game, stdin: *std.Io.Reader, stdout: *std.Io.Writer, num_players: usize) void {
        self.stdout = stdout;
        self.players = .initBuffer(&self.p_buf);

        var human = HumanPlayer.init(stdin);
        self.players.appendAssumeCapacity(human.player());
        for (0..num_players - 1) |_| {
            var ai = RandomPlayer{ .data = .{ .state = .init } };
            self.players.appendAssumeCapacity(ai.player());
        }

        self.state = .cut;
    }

    fn cut(self: *Game, rng: std.Random) !void {
        const dealer = rng.uintLessThan(usize, self.players.items.len);
        try self.stdout.print("player {} cut lowest and is dealer\n", .{dealer});
        try self.stdout.flush();

        self.dealer = dealer;
        self.state = .deal;
    }

    fn deal(self: *Game, rng: std.Random) !void {
        self.deck.pinnedInit(rng);

        self.state = .{ .play = .{ .active_player = (self.dealer + 1) % self.players.items.len } };

        const num_cards: u8 = switch (self.players.items.len) {
            2 => 6,
            3, 4 => 5,
            else => unreachable,
        };

        const dealer_gets_extra = self.players.items.len == 3;

        for (self.players.items, 0..) |*player, i| {
            const n = if (dealer_gets_extra and i == self.dealer) num_cards + 1 else num_cards;
            player.data.state = .{ .deal = self.deck.deal(n) };
            try player.draft();
        }

        self.state.play.cut = self.deck.deal(1)[0];
    }

    fn play(self: *Game) void {
        const active_player = self.state.play.active_player;

        if (active_player == self.dealer) {
            self.state = .{ .show = (self.dealer + 1) % self.players.items.len };
        } else {
            self.state.play.active_player = (active_player + 1) % self.players.items.len;
        }
    }

    fn show(self: *Game) void {
        _ = self;
    }

    fn round(self: *Game) void {
        _ = self;
    }

    fn turn(self: *Game) void {
        _ = self;
    }
};

pub fn main(init: std.process.Init) !void {
    const rng = (std.Random.IoSource{ .io = init.io }).interface();

    var stdin_buf: [64]u8 = undefined;
    var stdin_reader = std.Io.File.stdin().reader(init.io, &stdin_buf);
    const stdin = &stdin_reader.interface;

    var stdout_buf: [64]u8 = undefined;
    var stdout_writer = std.Io.File.stdout().writer(init.io, &stdout_buf);
    const stdout = &stdout_writer.interface;

    var game: Game = undefined;
    game.pinnedInit(stdin, stdout, 2);

    _ = try game.players.items[0].getMove();
    try game.cut(rng);
    try game.deal(rng);
    std.debug.print("{any}\n", .{game.players.items[0].data.state.deal});
}
