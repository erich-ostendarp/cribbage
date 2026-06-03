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

const Player = struct {
    data: *Data,
    ptr: *anyopaque,
    vtable: *const VTable,

    const VTable = struct {
        getMove: *const fn (*anyopaque) anyerror!Move,
        draft: *const fn (*anyopaque) anyerror![]Card,
    };

    const Data = struct {
        state: union(enum) {
            init,
            deal: struct { is_dealer: bool = false, cards: []Card },
            draft: struct { hand: [4]Card },
            play: struct { hand: []Card, cut_card: Card, pile: []Card },
            show: struct { hand: []Card, cut_card: Card },
        },
        score: u8 = 0,
        crib: ?[4]Card = null,
    };

    fn init(ptr: anytype) Player {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn data(pointer: *anyopaque) *Data {
                const self: T = @ptrCast(@alignCast(pointer));
                return &self.data;
            }

            pub fn getMove(pointer: *anyopaque) anyerror!Move {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.pointer.child.getMove(self);
            }

            pub fn draft(pointer: *anyopaque) anyerror![]Card {
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

    pub fn draft(self: Player) ![]Card {
        return self.vtable.draft(self.ptr);
    }

    pub fn getLegalMoves(self: Player) []const Move {
        _ = self;
        return &.{ .{}, .{}, .{} };
    }
};

const RandomPlayer = struct {
    data: Player.Data,
    rng: std.Random,

    pub fn init(rng: std.Random) RandomPlayer {
        return .{
            .data = .{ .state = .init },
            .rng = rng,
        };
    }

    fn getMove(self: *RandomPlayer) !Move {
        _ = self;
        return .{};
    }

    fn draft(self: *RandomPlayer) ![]Card {
        const deal = self.data.state.deal;

        var cards = deal.cards;
        self.rng.shuffle(Card, cards);

        const hand = cards[0..4];
        const crib = cards[4..];

        self.data.state = .{ .draft = .{ .hand = hand.* } };

        return crib;
    }

    fn player(self: *RandomPlayer) Player {
        return Player.init(self);
    }
};

const HumanPlayer = struct {
    data: Player.Data,
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

    // FIX: take user input
    fn draft(self: *HumanPlayer) ![]Card {
        const deal = self.data.state.deal;

        var cards = deal.cards;

        const hand = cards[0..4];
        const crib = cards[4..];

        self.data.state = .{ .draft = .{ .hand = hand.* } };

        return crib;
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

const Game = struct {
    stdout: *std.Io.Writer,
    p_buf: [max_players]Player,
    players: std.ArrayList(Player),
    state: State,
    deck: Deck,
    dealer: usize,

    const min_players = 2;
    const max_players = 4;

    const State = union(enum) {
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

    pub fn pinnedInit(self: *Game, stdout: *std.Io.Writer, players: []Player) void {
        self.stdout = stdout;
        self.players = .initBuffer(&self.p_buf);

        self.players.appendSliceAssumeCapacity(players);

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

        var crib_buf: [4]Card = undefined;
        var crib = std.ArrayList(Card).initBuffer(&crib_buf);

        for (self.players.items, 0..) |*player, i| {
            player.data.state = .{ .deal = .{
                .is_dealer = i == self.dealer,
                .cards = self.deck.deal(num_cards),
            } };

            crib.appendSliceAssumeCapacity(try player.draft());
        }

        if (crib.items.len == 3) {
            crib.appendAssumeCapacity(self.deck.deal(1)[0]);
        }

        self.players.items[self.dealer].data.crib = crib.items[0..4].*;

        const cut_card = self.deck.deal(1)[0];

        self.state.play.cut = cut_card;
        if (cut_card.rank == .jack) {
            self.players.items[(self.dealer + 1) % self.players.items.len].data.score += 2;
        }
    }

    fn play(self: *Game) void {
        const active_player = self.state.play.active_player;

        self.players.items[active_player].play();

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

    var human = HumanPlayer.init(stdin);
    var ais: [2]RandomPlayer = undefined;
    for (&ais) |*ai| {
        ai.* = .init(rng);
    }

    var players: [3]Player = undefined;
    players[0] = human.player();
    players[1] = ais[0].player();
    players[2] = ais[1].player();

    var game: Game = undefined;
    game.pinnedInit(stdout, &players);

    try game.cut(rng);
    try game.deal(rng);
}
